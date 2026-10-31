import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 46, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(AppConfig.appName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 32),
              Text(
                'Your subscriptions.\nNothing else.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
              ),
              const SizedBox(height: 16),
              const Text(
                'Subly reads your YouTube subscription list to build a focused feed. '
                'It does not use trending or recommended videos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),
              if (!AppConfig.hasApiKey)
                const _Notice(
                  text: 'Developer setup needed: YOUTUBE_API_KEY is not set. See README.',
                ),
              if (auth.error != null) _Notice(text: auth.error!.message),
              FilledButton.icon(
                onPressed: auth.busy || !AppConfig.hasApiKey
                    ? null
                    : () => ref.read(authControllerProvider.notifier).connect(),
                icon: auth.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(auth.busy ? 'Connecting…' : 'Connect with YouTube'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(AppConfig.privacyPolicyUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Privacy policy'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Subly is an independent app and is not affiliated with or endorsed by YouTube or Google.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.danger)),
    );
  }
}
