import '../../core/config/app_config.dart';
import '../../core/errors/app_error.dart';
import '../models/youtube_models.dart';
import '../services/auth_service.dart';
import '../services/youtube_api_client.dart';

/// Feed semantics (documented for users in the About screen):
/// - Only channels in the authenticated user's subscription list are used.
/// - For each channel we read its uploads playlist (playlistItems.list), then
///   enrich duration/views with videos.list in batches of 50.
/// - Results are merged, de-duplicated by video ID, sorted newest first.
/// - This is NOT a copy of YouTube's native Subscriptions feed ordering.
class YouTubeRepository {
  YouTubeRepository({
    required YouTubeApiClient api,
    required AuthService auth,
  })  : _api = api,
        _auth = auth;

  final YouTubeApiClient _api;
  final AuthService _auth;

  final List<YouTubeSubscription> _subscriptions = [];
  final Map<String, YouTubeChannel> _channelCache = {};
  final Set<String> _subscribedIds = {};
  String? _subsNextPage;
  bool _subsExhausted = false;
  int _channelCursor = 0;

  List<YouTubeSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get hasMoreSubscriptions => !_subsExhausted;
  bool get hasMoreFeed => _channelCursor < _subscribedIds.length || !_subsExhausted;

  /// Fetches the next page of subscriptions (subscriptions.list, mine=true).
  Future<void> loadMoreSubscriptions() async {
    if (_subsExhausted) return;
    final token = await _auth.accessToken();
    final json = await _api.get(
      'subscriptions',
      accessToken: token,
      query: {
        'part': 'snippet',
        'mine': 'true',
        'maxResults': '50',
        'order': 'alphabetical',
        if (_subsNextPage != null) 'pageToken': _subsNextPage!,
      },
    );

    final items = (json['items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(YouTubeSubscription.fromJson)
        .where((s) => s.channelId.isNotEmpty);

    for (final sub in items) {
      if (_subscribedIds.add(sub.channelId)) _subscriptions.add(sub);
    }

    _subsNextPage = json['nextPageToken'] as String?;
    if (_subsNextPage == null) _subsExhausted = true;

    if (_subscriptions.isEmpty && _subsExhausted) {
      throw const AppError(
        AppErrorType.noSubscriptions,
        'No subscriptions found on this YouTube account.',
      );
    }
  }

  /// Loads all subscriptions up to [maxPages] pages, to avoid long loops.
  Future<void> loadAllSubscriptions({int maxPages = 10}) async {
    for (var i = 0; i < maxPages && !_subsExhausted; i++) {
      await loadMoreSubscriptions();
    }
  }

  Future<void> _ensureChannels(List<String> channelIds) async {
    final missing = channelIds.where((id) => !_channelCache.containsKey(id)).toList();
    for (var i = 0; i < missing.length; i += 50) {
      final batch = missing.sublist(i, i + 50 > missing.length ? missing.length : i + 50);
      final token = await _auth.accessToken();
      final json = await _api.get(
        'channels',
        accessToken: token,
        query: {
          'part': 'snippet,contentDetails',
          'id': batch.join(','),
          'maxResults': '50',
        },
      );
      for (final raw in (json['items'] as List? ?? []).cast<Map<String, dynamic>>()) {
        final ch = YouTubeChannel.fromJson(raw);
        _channelCache[ch.id] = ch;
      }
    }
  }

  /// Returns the next batch of feed videos, merged and sorted newest first.
  /// Collects up to [minVideos] (or until subscriptions are exhausted),
  /// skipping any channel whose uploads are unavailable or fail.
  Future<List<YouTubeVideo>> loadFeedBatch({int minVideos = 10}) async {
    if (_subscriptions.isEmpty) await loadMoreSubscriptions();
    if (_subscribedIds.isEmpty) return [];

    final videos = <String, YouTubeVideo>{};

    while (videos.length < minVideos && (_channelCursor < _subscriptions.length || !_subsExhausted)) {
      if (_channelCursor >= _subscriptions.length && !_subsExhausted) {
        await loadMoreSubscriptions();
      }
      if (_channelCursor >= _subscriptions.length) break;

      final ids = _subscriptions
          .skip(_channelCursor)
          .take(AppConfig.channelsPerFeedBatch)
          .map((s) => s.channelId)
          .toList();
      if (ids.isEmpty) break;
      _channelCursor += ids.length;

      await _ensureChannels(ids);

      for (final id in ids) {
        final channel = _channelCache[id];
        if (channel == null) continue;
        try {
          final uploads = await _uploadsFor(channel);
          for (final v in uploads) {
            if (_subscribedIds.contains(v.channelId)) {
              videos.putIfAbsent(v.id, () => v);
            }
          }
        } on AppError catch (e) {
          if (e.type == AppErrorType.quotaExceeded || e.type == AppErrorType.unauthorized) {
            rethrow;
          }
          // Individual channel failure (e.g. not found, private) must not crash the feed.
        } catch (_) {}
      }
    }

    final enriched = await _enrich(videos.values.toList());
    enriched.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return enriched;
  }

  Future<List<YouTubeVideo>> _uploadsFor(YouTubeChannel channel) async {
    var uploadsId = channel.uploadsPlaylistId;
    if (uploadsId.isEmpty && channel.id.startsWith('UC')) {
      uploadsId = 'UU${channel.id.substring(2)}';
    }
    if (uploadsId.isEmpty) return const [];

    try {
      final token = await _auth.accessToken();
      final json = await _api.get(
        'playlistItems',
        accessToken: token,
        query: {
          'part': 'snippet',
          'playlistId': uploadsId,
          'maxResults': '${AppConfig.uploadsPerChannel}',
        },
      );
      return (json['items'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(YouTubeVideo.fromPlaylistItem)
          .where((v) => v.id.isNotEmpty)
          .toList();
    } on AppError catch (e) {
      if (e.type == AppErrorType.notFound) {
        // Channel uploads playlist does not exist or has no accessible items.
        return const [];
      }
      rethrow;
    }
  }

  Future<List<YouTubeVideo>> _enrich(List<YouTubeVideo> videos) async {
    if (videos.isEmpty) return videos;
    final byId = {for (final v in videos) v.id: v};
    final ids = byId.keys.toList();
    final out = <YouTubeVideo>[];
    for (var i = 0; i < ids.length; i += 50) {
      final batch = ids.sublist(i, i + 50 > ids.length ? ids.length : i + 50);
      try {
        final token = await _auth.accessToken();
        final json = await _api.get(
          'videos',
          accessToken: token,
          query: {
            'part': 'contentDetails,statistics',
            'id': batch.join(','),
            'maxResults': '50',
          },
        );
        final details = <String, Map<String, dynamic>>{
          for (final raw in (json['items'] as List? ?? []).cast<Map<String, dynamic>>())
            (raw['id'] as String? ?? ''): raw,
        };
        for (final id in batch) {
          final base = byId[id]!;
          final d = details[id];
          // Private or deleted videos drop out of the feed when details are missing.
          if (d == null) continue;
          out.add(base.withDetails(d));
        }
      } catch (_) {
        // Fall back to un-enriched videos if details request fails
        for (final id in batch) {
          out.add(byId[id]!);
        }
      }
    }
    return out;
  }

  /// Channel detail: info plus recent uploads.
  Future<List<YouTubeVideo>> channelUploads(String channelId) async {
    await _ensureChannels([channelId]);
    final channel = _channelCache[channelId];
    if (channel == null) {
      throw const AppError(AppErrorType.notFound, 'Channel not found.');
    }
    final uploads = await _uploadsFor(channel);
    final enriched = await _enrich(uploads);
    enriched.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return enriched;
  }

  /// Fetch a single video's metadata by ID.
  Future<YouTubeVideo?> getVideo(String videoId) async {
    try {
      final token = await _auth.accessToken();
      final json = await _api.get(
        'videos',
        accessToken: token,
        query: {
          'part': 'snippet,contentDetails,statistics',
          'id': videoId,
        },
      );
      final items = (json['items'] as List? ?? []).cast<Map<String, dynamic>>();
      if (items.isEmpty) return null;
      return YouTubeVideo.fromVideoItem(items.first);
    } catch (_) {
      return null;
    }
  }

  YouTubeChannel? cachedChannel(String id) => _channelCache[id];

  void resetFeedCursor() => _channelCursor = 0;

  /// Filters any video list against the authorized subscription set.
  List<YouTubeVideo> onlySubscribed(Iterable<YouTubeVideo> videos) =>
      videos.where((v) => _subscribedIds.contains(v.channelId)).toList();
}
