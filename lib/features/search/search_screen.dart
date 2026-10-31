import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/youtube_models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

/// Subscription-focused search only. Matches loaded channel names and the
/// cached/retrieved video metadata. YouTube-wide search is intentionally not
/// implemented here to save quota and avoid mixing in unrelated results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = ref.read(youtubeRepositoryProvider);
      if (repo.subscriptions.isEmpty) {
        try {
          await repo.loadAllSubscriptions(maxPages: 2);
          if (mounted) setState(() {});
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final store = ref.read(localStoreProvider);
    await store.addSearch(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(localStoreProvider);
    final repo = ref.watch(youtubeRepositoryProvider);
    final feed = ref.watch(feedControllerProvider);
    final q = _query.trim().toLowerCase();

    final channelMatches = q.isEmpty
        ? const <YouTubeSubscription>[]
        : repo.subscriptions
            .where((s) => s.title.toLowerCase().contains(q))
            .take(8)
            .toList();

    final candidates = <YouTubeVideo>{...feed.videos, ...store.watchHistory(), ...store.savedVideos()};
    final List<YouTubeVideo> videoMatches;
    if (q.isEmpty) {
      videoMatches = const [];
    } else {
      videoMatches = candidates
          .where((v) => v.title.toLowerCase().contains(q) || v.channelTitle.toLowerCase().contains(q))
          .toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          onSubmitted: _submit,
          decoration: InputDecoration(
            hintText: 'Search your subscriptions',
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: q.isEmpty
          ? _history(store)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (channelMatches.isNotEmpty) ...[
                  const _SectionLabel('Channels'),
                  for (final s in channelMatches)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ChannelAvatar(url: s.thumbnailUrl, name: s.title),
                      title: Text(s.title),
                      onTap: () => context.push('/channel/${s.channelId}'),
                    ),
                ],
                if (videoMatches.isNotEmpty) ...[
                  const _SectionLabel('Videos'),
                  for (final v in videoMatches.take(30))
                    VideoCard(
                      video: v,
                      onTap: () => context.push('/watch/${v.id}', extra: v),
                    ),
                ],
                if (channelMatches.isEmpty && videoMatches.isEmpty)
                  const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matches',
                    subtitle: 'Only loaded subscriptions and videos are searched.',
                  ),
              ],
            ),
    );
  }

  Widget _history(store) {
    final history = store.searchHistory();
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.manage_search_rounded,
        title: 'Search your subscriptions',
        subtitle: 'Channel names and loaded video titles are matched.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            const Expanded(child: _SectionLabel('Recent searches')),
            TextButton(
              onPressed: () async {
                await store.clearSearchHistory();
                setState(() {});
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        for (final h in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded),
            title: Text(h),
            onTap: () {
              _controller.text = h;
              setState(() => _query = h);
            },
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );
}
