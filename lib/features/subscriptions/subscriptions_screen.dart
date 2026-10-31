import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/youtube_models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _initial();
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initial() async {
    final repo = ref.read(youtubeRepositoryProvider);
    if (repo.subscriptions.isNotEmpty) return;
    await _run(() => repo.loadMoreSubscriptions());
  }

  Future<void> _loadMore() async {
    final repo = ref.read(youtubeRepositoryProvider);
    if (_loading || !repo.hasMoreSubscriptions) return;
    await _run(() => repo.loadMoreSubscriptions());
  }

  Future<void> _run(Future<void> Function() op) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await op();
    } on AppError catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(youtubeRepositoryProvider);
    final q = _query.text.trim().toLowerCase();
    final list = repo.subscriptions
        .where((s) => q.isEmpty || s.title.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Filter loaded channels',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(child: _body(repo, list)),
        ],
      ),
    );
  }

  Widget _body(repo, List<YouTubeSubscription> list) {
    if (_loading && repo.subscriptions.isEmpty) return const VideoFeedSkeleton(count: 6);
    if (_error != null && repo.subscriptions.isEmpty) {
      return ErrorState(error: _error!, onRetry: _initial);
    }
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.subscriptions_outlined,
        title: 'No channels match',
        subtitle: 'Try a different filter, or load more subscriptions.',
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length + (_loading ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i >= list.length) {
          return const Padding(
          padding: EdgeInsets.all(16),
          child: LoadingIndicator(),
        );
        }
        final s = list[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: ChannelAvatar(url: s.thumbnailUrl, name: s.title, radius: 22),
          title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: s.description == null || s.description!.isEmpty
              ? null
              : Text(s.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary)),
          onTap: () => context.push('/channel/${s.channelId}'),
        );
      },
    );
  }
}
