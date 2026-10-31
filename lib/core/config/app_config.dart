/// Build-time configuration.
/// API key is pre-configured — just run `flutter run` without any extra flags.
class AppConfig {
  const AppConfig._();

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Subly',
  );

  // ── YouTube Data API v3 key ─────────────────────────────────────────────
  // Pre-configured so no --dart-define flag is needed.
  // To override: flutter run --dart-define=YOUTUBE_API_KEY=your_other_key
  static const String youtubeApiKey = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: 'AIzaSyBXNJNJ8kTnxkSMfxjmLekzalRYKIMb5ow',
  );

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://example.com/privacy',
  );

  /// Minimum read-only scope needed to list the user's subscriptions.
  static const List<String> oauthScopes = [
    'https://www.googleapis.com/auth/youtube.readonly',
  ];

  static bool get hasApiKey => youtubeApiKey.isNotEmpty;

  /// Number of channels whose uploads are fetched per feed page.
  static const int channelsPerFeedBatch = 10;

  /// Uploads fetched per channel.
  static const int uploadsPerChannel = 5;

  static const Duration requestTimeout = Duration(seconds: 15);
}
