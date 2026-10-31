import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/youtube_models.dart';
import '../features/auth/connect_screen.dart';
import '../features/channel/channel_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/player_screen.dart';
import '../features/profile/about_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../shared/providers/app_providers.dart';
import '../shared/widgets/app_bottom_navigation.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, __) {
    authListenable.value++;
  });
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      if (!auth.checked) return loc == '/splash' ? null : '/splash';
      if (!auth.connected && loc != '/connect') return '/connect';
      if (auth.connected && (loc == '/connect' || loc == '/splash')) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/connect', builder: (_, __) => const ConnectScreen()),
      ShellRoute(
        builder: (context, state, child) => _Shell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionsScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(
        path: '/watch/:videoId',
        builder: (_, state) => PlayerScreen(
          videoId: state.pathParameters['videoId']!,
          initialVideo: state.extra is YouTubeVideo ? state.extra as YouTubeVideo : null,
        ),
      ),
      GoRoute(
        path: '/channel/:channelId',
        builder: (_, state) => ChannelScreen(channelId: state.pathParameters['channelId']!),
      ),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  static const _tabs = ['/home', '/subscriptions', '/search', '/library', '/profile'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere(location.startsWith).clamp(0, _tabs.length - 1);
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: index,
        onSelected: (i) => context.go(_tabs[i]),
      ),
    );
  }
}
