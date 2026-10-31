import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/youtube_models.dart';

/// Non-sensitive local data only: search history, local watch history,
/// local saved list, theme, and a short-lived feed cache.
/// No tokens are stored here. Access tokens live in memory via google_sign_in.
class LocalStore {
  LocalStore(this._prefs);

  static const _kSearch = 'search_history';
  static const _kWatched = 'watch_history';
  static const _kSaved = 'saved_videos';
  static const _kTheme = 'theme_mode';
  static const _kFeedCache = 'feed_cache';
  static const _kFeedCacheAt = 'feed_cache_at';

  static const _maxSearch = 20;
  static const _maxWatched = 100;
  static const feedCacheTtl = Duration(minutes: 15);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  // Search history
  List<String> searchHistory() => _prefs.getStringList(_kSearch) ?? const [];

  Future<void> addSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = [q, ...searchHistory().where((e) => e != q)];
    await _prefs.setStringList(_kSearch, list.take(_maxSearch).toList());
  }

  Future<void> clearSearchHistory() => _prefs.remove(_kSearch);

  // Watch history (local to this app)
  List<YouTubeVideo> watchHistory() => _readVideos(_kWatched);

  Future<void> addWatched(YouTubeVideo v) async {
    final list = [v, ...watchHistory().where((e) => e.id != v.id)];
    await _writeVideos(_kWatched, list.take(_maxWatched).toList());
  }

  Future<void> clearWatchHistory() => _prefs.remove(_kWatched);

  // Locally saved list (not synced with YouTube Watch Later)
  List<YouTubeVideo> savedVideos() => _readVideos(_kSaved);

  bool isSaved(String id) => savedVideos().any((v) => v.id == id);

  Future<void> toggleSaved(YouTubeVideo v) async {
    final current = savedVideos();
    final next = current.any((e) => e.id == v.id)
        ? current.where((e) => e.id != v.id).toList()
        : [v, ...current];
    await _writeVideos(_kSaved, next);
  }

  Future<void> removeSaved(String id) async {
    await _writeVideos(_kSaved, savedVideos().where((e) => e.id != id).toList());
  }

  // Theme
  String get themeMode => _prefs.getString(_kTheme) ?? 'dark';
  Future<void> setThemeMode(String mode) => _prefs.setString(_kTheme, mode);

  // Feed cache (metadata only, short TTL per YouTube API policy guidance)
  List<YouTubeVideo>? cachedFeed() {
    final at = _prefs.getInt(_kFeedCacheAt);
    if (at == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - at;
    if (age > feedCacheTtl.inMilliseconds) return null;
    return _readVideos(_kFeedCache);
  }

  Future<void> cacheFeed(List<YouTubeVideo> videos) async {
    await _writeVideos(_kFeedCache, videos);
    await _prefs.setInt(_kFeedCacheAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearCache() async {
    await _prefs.remove(_kFeedCache);
    await _prefs.remove(_kFeedCacheAt);
  }

  List<YouTubeVideo> _readVideos(String key) {
    final raw = _prefs.getStringList(key) ?? const [];
    final out = <YouTubeVideo>[];
    for (final s in raw) {
      try {
        out.add(YouTubeVideo.fromCacheJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupt entries instead of crashing.
      }
    }
    return out;
  }

  Future<void> _writeVideos(String key, List<YouTubeVideo> list) =>
      _prefs.setStringList(key, list.map((v) => jsonEncode(v.toJson())).toList());
}
