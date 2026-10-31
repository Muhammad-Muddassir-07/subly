import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_error.dart';

class GoogleAccountProfile {
  const GoogleAccountProfile({
    required this.displayName,
    required this.email,
    this.photoUrl,
  });

  final String displayName;
  final String email;
  final String? photoUrl;
}

/// Wraps google_sign_in (v6 API). Requires the YouTube readonly scope.
/// A signed-in Google account alone does NOT grant YouTube access; we
/// always request the scope and check the granted result.
class AuthService {
  AuthService({GoogleSignIn? googleSignIn})
      : _google = googleSignIn ??
            GoogleSignIn(
              scopes: AppConfig.oauthScopes,
              clientId: kIsWeb
                  ? '188429767801-9aerq6gqkp1mj0ju6a8jhmqggjntqjql.apps.googleusercontent.com'
                  : null,
            );

  final GoogleSignIn _google;

  /// Silent restore on launch. Returns null if no valid session.
  Future<GoogleAccountProfile?> tryRestoreSession() async {
    try {
      final account = await _google.signInSilently();
      if (account == null) return null;
      final granted = await _google.canAccessScopes(AppConfig.oauthScopes);
      if (!granted) return null;
      return _toProfile(account);
    } catch (_) {
      return null;
    }
  }

  /// Interactive connect. Throws AppError on cancel, denial or failure.
  Future<GoogleAccountProfile> connect() async {
    try {
      final account = await _google.signIn();
      if (account == null) {
        throw const AppError(
          AppErrorType.authCancelled,
          'Sign-in was cancelled. Tap Connect to try again.',
          retryable: true,
        );
      }
      final granted = await _google.requestScopes(AppConfig.oauthScopes);
      if (!granted) {
        throw const AppError(
          AppErrorType.authDenied,
          'YouTube access was not granted. Allow subscriptions access to continue.',
          retryable: true,
        );
      }
      return _toProfile(account);
    } on AppError {
      rethrow;
    } catch (e) {
      throw AppError(
        AppErrorType.authFailed,
        'Google sign-in failed. Check your connection and OAuth setup. ($e)',
        retryable: true,
      );
    }
  }

  /// Returns a fresh OAuth access token for YouTube API calls.
  Future<String> accessToken() async {
    final account = _google.currentUser ?? await _google.signInSilently();
    if (account == null) {
      throw const AppError(
        AppErrorType.unauthorized,
        'Not connected. Reconnect your YouTube account.',
      );
    }
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null) {
      throw const AppError(
        AppErrorType.unauthorized,
        'Access token unavailable. Reconnect your YouTube account.',
      );
    }
    return token;
  }

  Future<void> signOut() => _google.signOut();

  /// Revokes the grant (removes app access from the Google account).
  Future<void> disconnect() async {
    try {
      await _google.disconnect();
    } catch (_) {
      await _google.signOut();
    }
  }

  GoogleAccountProfile _toProfile(GoogleSignInAccount a) => GoogleAccountProfile(
        displayName: a.displayName ?? a.email,
        email: a.email,
        photoUrl: a.photoUrl,
      );
}
