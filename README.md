# Subly

Subscriptions-only YouTube feed client for Android (Flutter).

Subly is an **independent application** that integrates with the YouTube Data API v3. It is not affiliated with, endorsed by, or sponsored by YouTube or Google.

## What it does

- Connects to your Google account with read-only YouTube access (`youtube.readonly`).
- Reads your subscription list and shows videos only from those channels.
- Plays videos through the official YouTube embedded player.
- Keeps search history, watch history, saved videos and theme on the device only.

It does **not** download videos, extract streams, show trending or recommended videos, or sync with YouTube Watch Later.

## Feed semantics

Each feed page reads the uploads playlist of a small batch of subscribed channels, enriches details with `videos.list`, filters against the subscription set, de-duplicates by video ID and sorts newest first. This is not a copy of YouTube's own Home or Subscriptions ordering.

## Requirements

- Flutter 3.22 or newer (Dart 3.4 or newer). Check with `flutter --version`.
- Android SDK with platform 34 or newer and build-tools installed (`flutter doctor`).
- A Google account that has at least one YouTube subscription.

## 1. Create the Google Cloud project

1. Open https://console.cloud.google.com and create a project (for example `subly-dev`).
2. Go to **APIs & Services → Library**, search **YouTube Data API v3**, and click **Enable**.
3. Go to **APIs & Services → OAuth consent screen**:
   - User type: **External**.
   - Fill in app name, support email and developer contact.
   - Add the scope `https://www.googleapis.com/auth/youtube.readonly`.
   - While the app is in **Testing**, add your own Google account under **Test users**. Only test users can sign in until the app is verified.

## 2. Create the Android OAuth client

1. Get your package name. It is set in `android/app/build.gradle` as `applicationId`. The default is `com.example.subly`. Change it to your own reverse-domain name if you plan to publish.
2. Get the SHA-1 fingerprint of your debug keystore:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

   Copy the **SHA1** and **SHA256** values. For a release build, use your release keystore instead:

   ```bash
   keytool -list -v -keystore /path/to/release.keystore -alias your_alias
   ```

3. Go to **APIs & Services → Credentials → Create credentials → OAuth client ID**.
   - Application type: **Android**.
   - Package name: your `applicationId`.
   - SHA-1: the value from step 2.
4. No client secret is needed in the app. Google Sign-In on Android uses the package name and signing certificate.

Add a separate OAuth client for each signing key you use, for example one for debug and one for release.

## 3. Create the API key

1. Go to **APIs & Services → Credentials → Create credentials → API key**.
2. Click **Edit API key** and set:
   - **Application restrictions**: Android apps, with your package name and SHA-1.
   - **API restrictions**: restrict to **YouTube Data API v3** only.
3. Copy the key. Pass it at build time as shown below. Never commit it.

The API key is used only for public requests. Subscription requests use the OAuth access token, not the API key.

## 4. Configure the project

```bash
cp .env.example .env.local
# edit .env.local and set YOUTUBE_API_KEY
```

`.env.local` is git-ignored. Keep it out of source control.

## 5. Generate the Android project and permissions

This repo ships the Dart code. Generate the platform folders once:

```bash
flutter create --platforms=android --org com.example --project-name subly .
```

Then add internet permission to `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` and above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Set `minSdkVersion` to at least 21 in `android/app/build.gradle`. Google Sign-In and the embedded player both support it.

## 6. Install dependencies and run

```bash
flutter pub get
flutter run --dart-define=YOUTUBE_API_KEY=AIzaSyD4G7yP16IQtsn9p1twAcjgS5Y-aIz3llM
```

Or load everything from the env file:

```bash
flutter run --dart-define-from-file=.env.local
```

Note: `--dart-define-from-file` expects a JSON file. If you use the `.env.local` format above, convert it first:

```bash
python3 -c "import json;print(json.dumps(dict(l.strip().split('=',1) for l in open('.env.local') if '=' in l and not l.startswith('#'))))" > .dart-defines.json
flutter run --dart-define-from-file=.dart-defines.json
```

Add `.dart-defines.json` to `.gitignore` as well.

## 7. Test Google authorization

1. Launch the app. The splash screen runs a silent session restore, then opens **Connect with YouTube**.
2. Tap **Connect with YouTube** and pick a test-user account.
3. Approve the YouTube read-only permission. If you decline, the app stays on the connect screen and tells you how to retry.
4. The Home feed loads videos from your subscriptions.

## 8. Build a debug APK

```bash
flutter build apk --debug --dart-define=YOUTUBE_API_KEY=your_key_here
```

The file is at `build/app/outputs/flutter-apk/app-debug.apk`.

For a release build, create a keystore, configure signing in `android/app/build.gradle`, and run:

```bash
flutter build apk --release --dart-define-from-file=.dart-defines.json
```

## 9. Run tests

```bash
flutter test
```

Unit tests use no network and need no credentials.

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| "Developer setup needed" on connect screen | `YOUTUBE_API_KEY` not passed. Add `--dart-define`. |
| Sign-in fails immediately, or `ApiException: 10` in logs | SHA-1 or package name mismatch with the Android OAuth client. Re-check the fingerprint for the keystore you are running with. |
| `ApiException: 12500` or `sign_in_failed` | Consent screen not configured, or your account is not a test user while the app is in Testing. |
| "YouTube access was not granted" | You declined the YouTube permission. Tap Connect again and allow it. |
| "Your YouTube session expired" | The access token expired. Reconnect from the Profile screen. |
| "No subscriptions found" | The signed-in account has no subscriptions, or you signed in with a different Google account. |
| "Daily YouTube API quota reached" | The project used its daily quota (10,000 units by default). Quota resets at midnight Pacific time. Reduce refreshes or request a quota increase in Google Cloud. |
| "Too many requests" | Rate limited. Wait and pull to refresh. |
| "Access denied. Check API key restrictions" | The key's API or Android restrictions do not allow this request. Re-check step 3. |
| Video shows "could not be played here" | The video is private, removed, age- or region-restricted, or embedding is disabled. Use **Open in YouTube**. |

## Quota notes

`subscriptions.list`, `channels.list`, `playlistItems.list` and `videos.list` each cost 1 unit per call. `search.list` costs 100 units and is not used by the feed. Feed loads are batched and paginated, and the feed is cached on the device for 15 minutes to reduce calls.

## Project layout

```
lib/
  main.dart                  entry point, opens local store
  app.dart                   MaterialApp.router with theme
  core/                      config, errors, theme
  data/
    models/                  typed YouTube models with JSON parsing
    services/                auth, API client, local store
    repositories/            subscription and feed logic
  features/                  splash, auth, home, subscriptions, channel,
                             search, player, library, profile
  routing/                   go_router with bottom-nav shell
  shared/                    providers and reusable widgets
test/unit/                   offline unit tests
```

## Disclaimers

- Packages were chosen from memory of their APIs. Run `flutter pub outdated` and check each package's changelog before first build. `google_sign_in` 7.x has a different API from 6.x, so keep the 6.x pin unless you port the auth code.
- YouTube API Terms of Service and Developer Policies apply. Review them before publishing, especially rules on storing API data and displaying YouTube content.
- Subly is not an official YouTube application.

## Credentials

### API KEY:
AIzaSyD4G7yP16IQtsn9p1twAcjgS5Y-aIz3llM

### Package name:
com.example.subly

### SHA1:
C2:47:ED:E0:1D:25:3D:7B:9A:6E:C2:C7:66:17:52:01:7C:84:D9:E6
