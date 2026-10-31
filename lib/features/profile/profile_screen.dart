import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    final theme = ref.watch(themeModeProvider);
    final store = ref.watch(localStoreProvider);

    void snack(String msg) => ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ChannelAvatar(
              url: profile?.photoUrl,
              name: profile?.displayName ?? '',
              radius: 26,
            ),
            title: Text(profile?.displayName ?? 'Not connected'),
            subtitle: Text(profile?.email ?? 'Connect a YouTube account to start'),
          ),
          const Divider(),
          const _Section('Feed'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Refresh subscriptions and feed'),
            onTap: () async {
              ref.invalidate(youtubeRepositoryProvider);
              await ref.read(feedControllerProvider.notifier).load(force: true);
              snack('Feed refreshed');
            },
          ),
          const _Section('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: theme,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              ],
              onChanged: (m) {
                if (m != null) ref.read(themeModeProvider.notifier).set(m);
              },
            ),
          ),
          const _Section('Local data (this device only)'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear local cache'),
            onTap: () async {
              await store.clearCache();
              snack('Cache cleared');
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_search_rounded),
            title: const Text('Clear search history'),
            onTap: () async {
              await store.clearSearchHistory();
              snack('Search history cleared');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_toggle_off_rounded),
            title: const Text('Clear watch history'),
            onTap: () async {
              await store.clearWatchHistory();
              snack('Watch history cleared');
            },
          ),
          const _Section('Account'),
          if (profile != null) ...[
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
            ListTile(
              leading: const Icon(Icons.link_off_rounded, color: Colors.redAccent),
              title: const Text('Disconnect YouTube account',
                  style: TextStyle(color: Colors.redAccent)),
              subtitle: const Text('Removes Subly access from your Google account.'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Disconnect?'),
                    content: const Text('Subly will lose access to your subscriptions.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnect')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(authControllerProvider.notifier).disconnect();
                }
              },
            ),
          ],
          const _Section('About'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl),
                mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Subly'),
            subtitle: const Text(
              'Independent app. Not affiliated with YouTube or Google. '
              'Feed = videos from your subscribed channels, newest first, '
              'not a copy of YouTube\'s own Subscriptions ordering.',
            ),
            onTap: () => context.push('/about'),
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => ListTile(
              leading: const Icon(Icons.numbers_rounded),
              title: const Text('Version'),
              subtitle: Text(snap.hasData
                  ? '${snap.data!.version} (${snap.data!.buildNumber})'
                  : '…'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
        child: Text(text,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}
