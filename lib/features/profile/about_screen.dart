import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('${AppConfig.appName} is an independent app.',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'It is not affiliated with, endorsed by, or sponsored by YouTube or Google. '
            'It uses the YouTube Data API v3 with your permission.',
          ),
          const SizedBox(height: 20),
          Text('How the feed works',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            '1. Your subscription list is read after you grant read-only access.\n'
            '2. Recent uploads are read from each subscribed channel\'s uploads list, in batches.\n'
            '3. Results are merged, de-duplicated by video ID, and sorted newest first.\n'
            '4. Only channels in your subscription list are ever shown.\n\n'
            'This is not a copy of YouTube\'s own Home or Subscriptions ordering.',
          ),
          const SizedBox(height: 20),
          Text('Local data',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Search history, watch history, saved videos and theme are stored on this device. '
            'Saved videos are not synced with YouTube Watch Later.',
          ),
        ],
      ),
    );
  }
}
