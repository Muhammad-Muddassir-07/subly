import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as ypf;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as ypi;

import '../../core/theme/app_theme.dart';
import '../../data/models/youtube_models.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key, required this.videoId, this.initialVideo});

  final String videoId;
  final YouTubeVideo? initialVideo;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  // Mobile (Android/iOS) controller
  ypf.YoutubePlayerController? _mobileController;

  // Web controller
  ypi.YoutubePlayerController? _webController;

  YouTubeVideo? _video;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _video = widget.initialVideo;

    if (kIsWeb) {
      // ── Web: iframe embed ──────────────────────────────────────────
      _webController = ypi.YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: true,
        params: const ypi.YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: false,
          showControls: true,
          enableCaption: true,
        ),
      );
      _webController!.listen((value) {
        if (value.playerState == ypi.PlayerState.playing && !_recorded) {
          _recorded = true;
          _recordWatch();
        }
      });
    } else {
      // ── Mobile: native youtube_player_flutter ──────────────────────
      _mobileController = ypf.YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const ypf.YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          forceHD: false,
          useHybridComposition: true,
        ),
      );
      _mobileController!.addListener(() {
        if (_mobileController!.value.isPlaying && !_recorded) {
          _recorded = true;
          _recordWatch();
        }
      });
    }

    Future.microtask(() async {
      _video ??= _findVideo();
      if (_video == null) {
        final fetched =
            await ref.read(youtubeRepositoryProvider).getVideo(widget.videoId);
        if (fetched != null && mounted) setState(() => _video = fetched);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  YouTubeVideo? _findVideo() {
    if (_video != null) return _video;
    final feed = ref.read(feedControllerProvider).videos;
    for (final v in feed) {
      if (v.id == widget.videoId) return v;
    }
    final store = ref.read(localStoreProvider);
    for (final v in store.watchHistory()) {
      if (v.id == widget.videoId) return v;
    }
    for (final v in store.savedVideos()) {
      if (v.id == widget.videoId) return v;
    }
    return null;
  }

  Future<void> _recordWatch() async {
    final video = _video ?? _findVideo();
    if (video != null) {
      await ref.read(localStoreProvider).addWatched(video);
    }
  }

  @override
  void dispose() {
    _mobileController?.dispose();
    _webController?.close();
    super.dispose();
  }

  Future<void> _openInYouTube() => launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}'),
        mode: LaunchMode.externalApplication,
      );

  @override
  Widget build(BuildContext context) {
    final video = _findVideo();
    final store = ref.watch(localStoreProvider);
    final saved = store.isSaved(widget.videoId);
    final theme = Theme.of(context);

    return kIsWeb ? _buildWebScaffold(video, store, saved, theme)
                  : _buildMobileScaffold(video, store, saved, theme);
  }

  // ── MOBILE layout (youtube_player_flutter wraps the whole scaffold) ──────
  Widget _buildMobileScaffold(
      YouTubeVideo? video, dynamic store, bool saved, ThemeData theme) {
    return ypf.YoutubePlayerBuilder(
      player: ypf.YoutubePlayer(
        controller: _mobileController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: const ypf.ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
        ),
        onReady: () {
          _mobileController!.play();
        },
      ),
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                tooltip: saved ? 'Remove from saved' : 'Save',
                icon: Icon(saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded),
                onPressed: video == null
                    ? null
                    : () async {
                        await store.toggleSaved(video);
                        setState(() {});
                      },
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Native player ──────────────────────────────────────
              player,

              // ── Open in YouTube below player ───────────────────────
              Container(
                width: double.infinity,
                color: theme.colorScheme.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: _openInYouTube,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red, width: 1.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open in YouTube',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),

              // ── Info ───────────────────────────────────────────────
              Expanded(
                child: _buildInfoSection(video, theme, context),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── WEB layout (youtube_player_iframe) ──────────────────────────────────
  Widget _buildWebScaffold(
      YouTubeVideo? video, dynamic store, bool saved, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove from saved' : 'Save',
            icon: Icon(saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded),
            onPressed: video == null
                ? null
                : () async {
                    await store.toggleSaved(video);
                    setState(() {});
                  },
          ),
        ],
      ),
      body: Column(
        children: [
          ypi.YoutubePlayer(
              controller: _webController!, aspectRatio: 16 / 9),
          Container(
            width: double.infinity,
            color: theme.colorScheme.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _openInYouTube,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in YouTube',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(child: _buildInfoSection(video, theme, context)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      YouTubeVideo? video, ThemeData theme, BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          video?.title ?? 'Video',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (video != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (video.viewCount != null)
                video.viewCount! >= 1000000
                    ? '${(video.viewCount! / 1000000).toStringAsFixed(1)}M views'
                    : video.viewCount! >= 1000
                        ? '${(video.viewCount! / 1000).toStringAsFixed(1)}K views'
                        : '${video.viewCount} views',
              relativeTime(video.publishedAt),
            ].join(' · '),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        if (video != null)
          InkWell(
            onTap: () => context.push('/channel/${video.channelId}'),
            child: Row(
              children: [
                ChannelAvatar(name: video.channelTitle, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    video.channelTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
