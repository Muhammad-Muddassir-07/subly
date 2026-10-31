import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/youtube_models.dart';
import '../../data/repositories/youtube_repository.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/local_store.dart';
import '../../data/services/youtube_api_client.dart';
import '../../core/errors/app_error.dart';

/// Overridden in main() with the opened store.
final localStoreProvider = Provider<LocalStore>((ref) {
  throw UnimplementedError('localStoreProvider must be overridden in main()');
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final youtubeApiProvider = Provider<YouTubeApiClient>((ref) {
  final client = YouTubeApiClient();
  ref.onDispose(client.close);
  return client;
});

final youtubeRepositoryProvider = Provider<YouTubeRepository>((ref) {
  return YouTubeRepository(
    api: ref.watch(youtubeApiProvider),
    auth: ref.watch(authServiceProvider),
  );
});

/// Auth state -------------------------------------------------------------

class AuthState {
  const AuthState({
    this.profile,
    this.busy = false,
    this.error,
    this.checked = false,
  });

  final GoogleAccountProfile? profile;
  final bool busy;
  final AppError? error;
  final bool checked;

  bool get connected => profile != null;

  AuthState copyWith({
    GoogleAccountProfile? profile,
    bool? busy,
    AppError? error,
    bool? checked,
    bool clearError = false,
    bool clearProfile = false,
  }) =>
      AuthState(
        profile: clearProfile ? null : (profile ?? this.profile),
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        checked: checked ?? this.checked,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._auth) : super(const AuthState());

  final AuthService _auth;

  Future<void> restore() async {
    final profile = await _auth.tryRestoreSession();
    state = state.copyWith(profile: profile, checked: true, clearError: true);
  }

  Future<void> connect() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final profile = await _auth.connect();
      state = state.copyWith(profile: profile, busy: false, checked: true);
    } on AppError catch (e) {
      state = state.copyWith(busy: false, error: e, checked: true);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState(checked: true);
  }

  Future<void> disconnect() async {
    await _auth.disconnect();
    state = const AuthState(checked: true);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});

/// Feed state ------------------------------------------------------------

class FeedState {
  const FeedState({
    this.videos = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.hasMore = true,
    this.activeChannelId,
  });

  final List<YouTubeVideo> videos;
  final bool loading;
  final bool loadingMore;
  final AppError? error;
  final bool hasMore;

  /// null means "All" subscriptions.
  final String? activeChannelId;

  List<YouTubeVideo> get visible => activeChannelId == null
      ? videos
      : videos.where((v) => v.channelId == activeChannelId).toList();

  FeedState copyWith({
    List<YouTubeVideo>? videos,
    bool? loading,
    bool? loadingMore,
    AppError? error,
    bool? hasMore,
    String? activeChannelId,
    bool clearError = false,
    bool clearChannel = false,
  }) =>
      FeedState(
        videos: videos ?? this.videos,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
        activeChannelId: clearChannel ? null : (activeChannelId ?? this.activeChannelId),
      );
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._repo, this._store) : super(const FeedState());

  final YouTubeRepository _repo;
  final LocalStore _store;

  /// Shows cached feed immediately if fresh, then refreshes from the API.
  Future<void> load({bool force = false}) async {
    if (state.loading) return;
    if (!force) {
      final cached = _store.cachedFeed();
      if (cached != null && cached.isNotEmpty) {
        state = state.copyWith(videos: cached, hasMore: true);
        return;
      }
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      _repo.resetFeedCursor();
      final batch = await _repo.loadFeedBatch();
      await _store.cacheFeed(batch);
      state = state.copyWith(
        videos: batch,
        loading: false,
        hasMore: _repo.hasMoreFeed,
      );
    } on AppError catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    try {
      final batch = await _repo.loadFeedBatch();
      final seen = state.videos.map((v) => v.id).toSet();
      final merged = [
        ...state.videos,
        ...batch.where((v) => !seen.contains(v.id)),
      ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      state = state.copyWith(
        videos: merged,
        loadingMore: false,
        hasMore: _repo.hasMoreFeed,
      );
    } on AppError catch (e) {
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  Future<void> selectChannel(String? channelId) async {
    if (channelId == null) {
      state = state.copyWith(clearChannel: true);
      return;
    }
    state = state.copyWith(activeChannelId: channelId);
    final hasVideos = state.videos.any((v) => v.channelId == channelId);
    if (!hasVideos) {
      try {
        final uploads = await _repo.channelUploads(channelId);
        if (uploads.isNotEmpty) {
          final seen = state.videos.map((v) => v.id).toSet();
          final merged = [
            ...state.videos,
            ...uploads.where((v) => !seen.contains(v.id)),
          ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
          state = state.copyWith(videos: merged);
        }
      } catch (_) {}
    }
  }
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>((ref) {
  return FeedController(
    ref.watch(youtubeRepositoryProvider),
    ref.watch(localStoreProvider),
  );
});

/// Theme ----------------------------------------------------------------

final themeModeProvider = StateNotifierProvider<ThemeController, ThemeMode>((ref) {
  return ThemeController(ref.watch(localStoreProvider));
});

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController(this._store) : super(_parse(_store.themeMode));

  final LocalStore _store;

  static ThemeMode _parse(String s) => switch (s) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _store.setThemeMode(mode.name);
  }
}
