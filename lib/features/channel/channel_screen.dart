import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../data/models/youtube_models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class ChannelScreen extends ConsumerStatefulWidget {
  const ChannelScreen({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends ConsumerState<ChannelScreen> {
  List<YouTubeVideo>? _videos;
  AppError? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await ref.read(youtubeRepositoryProvider).channelUploads(widget.channelId);
      if (mounted) setState(() => _videos = v);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel = ref.watch(youtubeRepositoryProvider).cachedChannel(widget.channelId);
    final title = channel?.title ?? 'Channel';

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: _body(channel),
    );
  }

  Widget _body(YouTubeChannel? channel) {
    if (_loading && _videos == null) return const VideoFeedSkeleton();
    if (_error != null) return ErrorState(error: _error!, onRetry: _load);
    final videos = _videos ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (channel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                ChannelAvatar(url: channel.thumbnailUrl, name: channel.title, radius: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(channel.title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        if (videos.isEmpty)
          const EmptyState(
            icon: Icons.video_library_outlined,
            title: 'No recent uploads',
            subtitle: 'This channel has no uploads we could load.',
          )
        else
          for (final v in videos)
            VideoCard(video: v, onTap: () => context.push('/watch/${v.id}', extra: v)),
      ],
    );
  }
}
