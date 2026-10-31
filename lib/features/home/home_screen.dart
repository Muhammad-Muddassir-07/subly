import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_error.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    Future.microtask(() async {
      final notifier = ref.read(feedControllerProvider.notifier);
      await notifier.load();
      // Make sure we have the full subscription list for chips.
      final repo = ref.read(youtubeRepositoryProvider);
      try {
        await repo.loadAllSubscriptions(maxPages: 2);
        if (mounted) setState(() {});
      } on AppError {
        // Feed errors are already shown; chips simply stay empty.
      }
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedControllerProvider);
    final notifier = ref.read(feedControllerProvider.notifier);
    final subs = ref.watch(youtubeRepositoryProvider).subscriptions;
    final profile = ref.watch(authControllerProvider).profile;
    final visible = feed.visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.go('/search'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: ChannelAvatar(
                url: profile?.photoUrl,
                name: profile?.displayName ?? '',
                radius: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (subs.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  ChannelChip(
                    label: 'All',
                    selected: feed.activeChannelId == null,
                    onTap: () => notifier.selectChannel(null),
                  ),
                  for (final s in subs)
                    ChannelChip(
                      label: s.title,
                      selected: feed.activeChannelId == s.channelId,
                      onTap: () => notifier.selectChannel(s.channelId),
                    ),
                ],
              ),
            ),
          Expanded(child: _body(feed, visible, notifier)),
        ],
      ),
    );
  }

  Widget _body(FeedState feed, List visible, FeedController notifier) {
    if (feed.loading && feed.videos.isEmpty) return const VideoFeedSkeleton();

    if (feed.error != null && feed.videos.isEmpty) {
      return ErrorState(error: feed.error!, onRetry: () => notifier.load(force: true));
    }

    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => notifier.load(force: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.subscriptions_outlined,
              title: 'No recent uploads',
              subtitle: 'Videos from your subscribed channels will appear here. Pull down to refresh.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.load(force: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: visible.length + (feed.loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= visible.length) {
            return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingIndicator(),
          );
          }
          final video = visible[i];
          return VideoCard(
            video: video,
            onTap: () => context.push('/watch/${video.id}', extra: video),
          );
        },
      ),
    );
  }
}
