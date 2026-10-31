class YouTubeSubscription {
  const YouTubeSubscription({
    required this.channelId,
    required this.title,
    this.description,
    this.thumbnailUrl,
  });

  final String channelId;
  final String title;
  final String? description;
  final String? thumbnailUrl;

  factory YouTubeSubscription.fromJson(Map<String, dynamic> json) {
    final snippet = _map(json['snippet']);
    final resourceId = _map(snippet['resourceId']);
    return YouTubeSubscription(
      channelId: resourceId['channelId'] as String? ?? '',
      title: snippet['title'] as String? ?? 'Unknown channel',
      description: snippet['description'] as String?,
      thumbnailUrl: _thumb(snippet['thumbnails']),
    );
  }

  Map<String, dynamic> toJson() => {
        'channelId': channelId,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
      };

  factory YouTubeSubscription.fromCacheJson(Map<String, dynamic> json) =>
      YouTubeSubscription(
        channelId: json['channelId'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        thumbnailUrl: json['thumbnailUrl'] as String?,
      );
}

class YouTubeChannel {
  const YouTubeChannel({
    required this.id,
    required this.title,
    required this.uploadsPlaylistId,
    this.thumbnailUrl,
    this.description,
  });

  final String id;
  final String title;
  final String uploadsPlaylistId;
  final String? thumbnailUrl;
  final String? description;

  factory YouTubeChannel.fromJson(Map<String, dynamic> json) {
    final snippet = _map(json['snippet']);
    final content = _map(json['contentDetails']);
    final related = _map(content['relatedPlaylists']);
    final id = json['id'] as String? ?? '';
    var uploads = related['uploads'] as String? ?? '';
    if (uploads.isEmpty && id.startsWith('UC')) {
      uploads = 'UU${id.substring(2)}';
    }
    return YouTubeChannel(
      id: id,
      title: snippet['title'] as String? ?? '',
      uploadsPlaylistId: uploads,
      thumbnailUrl: _thumb(snippet['thumbnails']),
      description: snippet['description'] as String?,
    );
  }
}

class YouTubeVideo {
  const YouTubeVideo({
    required this.id,
    required this.channelId,
    required this.channelTitle,
    required this.title,
    required this.publishedAt,
    this.thumbnailUrl,
    this.durationIso,
    this.viewCount,
  });

  final String id;
  final String channelId;
  final String channelTitle;
  final String title;
  final DateTime publishedAt;
  final String? thumbnailUrl;

  /// ISO 8601 duration as returned by the API, e.g. PT4M13S.
  final String? durationIso;
  final int? viewCount;

  factory YouTubeVideo.fromPlaylistItem(Map<String, dynamic> json) {
    final snippet = _map(json['snippet']);
    final resource = _map(snippet['resourceId']);
    final published = snippet['publishedAt'] as String?;
    return YouTubeVideo(
      id: resource['videoId'] as String? ?? '',
      channelId: snippet['channelId'] as String? ?? '',
      channelTitle: snippet['channelTitle'] as String? ?? '',
      title: snippet['title'] as String? ?? 'Untitled',
      publishedAt: DateTime.tryParse(published ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      thumbnailUrl: _thumb(snippet['thumbnails']),
    );
  }

  factory YouTubeVideo.fromVideoItem(Map<String, dynamic> json) {
    final snippet = _map(json['snippet']);
    final content = _map(json['contentDetails']);
    final stats = _map(json['statistics']);
    final published = snippet['publishedAt'] as String?;
    return YouTubeVideo(
      id: json['id'] as String? ?? '',
      channelId: snippet['channelId'] as String? ?? '',
      channelTitle: snippet['channelTitle'] as String? ?? '',
      title: snippet['title'] as String? ?? 'Untitled',
      publishedAt: DateTime.tryParse(published ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      thumbnailUrl: _thumb(snippet['thumbnails']),
      durationIso: content['duration'] as String?,
      viewCount: int.tryParse('${stats['viewCount'] ?? ''}'),
    );
  }

  /// Merge in duration and view count from a videos.list item.
  YouTubeVideo withDetails(Map<String, dynamic> json) {
    final content = _map(json['contentDetails']);
    final stats = _map(json['statistics']);
    return YouTubeVideo(
      id: id,
      channelId: channelId,
      channelTitle: channelTitle,
      title: title,
      publishedAt: publishedAt,
      thumbnailUrl: thumbnailUrl,
      durationIso: content['duration'] as String?,
      viewCount: int.tryParse('${stats['viewCount'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelId': channelId,
        'channelTitle': channelTitle,
        'title': title,
        'publishedAt': publishedAt.toIso8601String(),
        'thumbnailUrl': thumbnailUrl,
        'durationIso': durationIso,
        'viewCount': viewCount,
      };

  factory YouTubeVideo.fromCacheJson(Map<String, dynamic> json) => YouTubeVideo(
        id: json['id'] as String,
        channelId: json['channelId'] as String,
        channelTitle: json['channelTitle'] as String,
        title: json['title'] as String,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        thumbnailUrl: json['thumbnailUrl'] as String?,
        durationIso: json['durationIso'] as String?,
        viewCount: json['viewCount'] as int?,
      );
}

/// Formats an ISO 8601 duration like PT1H4M5S into 1:04:05.
String? formatIsoDuration(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final match = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?').firstMatch(iso);
  if (match == null) return null;
  final h = int.tryParse(match.group(1) ?? '') ?? 0;
  final m = int.tryParse(match.group(2) ?? '') ?? 0;
  final s = int.tryParse(match.group(3) ?? '') ?? 0;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String? _thumb(dynamic thumbnails) {
  if (thumbnails is! Map) return null;
  for (final key in const ['medium', 'high', 'default']) {
    final entry = thumbnails[key];
    if (entry is Map && entry['url'] is String) return entry['url'] as String;
  }
  return null;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}
