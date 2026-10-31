import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

/// Everything here is LOCAL to this app on this device. It is not your
/// YouTube watch history, and it is not synced with YouTube Watch Later.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final store = ref.watch(localStoreProvider);
    final saved = store.savedVideos();
    final watched = store.watchHistory();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Saved'), Tab(text: 'Watched')],
          ),
        ),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Stored on this device only. Not your YouTube account data.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _list(
                    items: saved,
                    empty: const EmptyState(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Nothing saved yet',
                      subtitle: 'Saved videos stay on this device.',
                    ),
                    trailing: (v) => IconButton(
                      tooltip: 'Remove from saved',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () async {
                        await store.removeSaved(v.id);
                        setState(() {});
                      },
                    ),
                  ),
                  Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: watched.isEmpty
                              ? null
                              : () async {
                                  await store.clearWatchHistory();
                                  setState(() {});
                                },
                          child: const Text('Clear history'),
                        ),
                      ),
                      Expanded(
                        child: _list(
                          items: watched,
                          empty: const EmptyState(
                            icon: Icons.history_rounded,
                            title: 'No watch history',
                            subtitle: 'Videos you open in Subly appear here.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list({
    required List items,
    required Widget empty,
    Widget Function(dynamic v)? trailing,
  }) {
    if (items.isEmpty) return empty;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final v = items[i];
        final card = VideoCard(video: v, onTap: () => context.push('/watch/${v.id}', extra: v));
        if (trailing == null) return card;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card),
            trailing(v),
          ],
        );
      },
    );
  }
}
