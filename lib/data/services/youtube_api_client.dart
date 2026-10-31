import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_error.dart';

/// Thin HTTP layer over YouTube Data API v3. Knows nothing about models.
class YouTubeApiClient {
  YouTubeApiClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static const _base = 'https://www.googleapis.com/youtube/v3';
  final http.Client _http;

  /// [accessToken] is required for `mine=true` calls. Public calls use the API key.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> query = const {},
    String? accessToken,
  }) async {
    if (!AppConfig.hasApiKey && accessToken == null) {
      throw const AppError(
        AppErrorType.missingApiKey,
        'Developer config missing: set YOUTUBE_API_KEY via --dart-define.',
      );
    }

    final uri = Uri.parse('$_base/$path').replace(queryParameters: {
      ...query,
      if (accessToken == null) 'key': AppConfig.youtubeApiKey,
    });

    final headers = <String, String>{
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    };

    http.Response response;
    try {
      response = await _http
          .get(uri, headers: headers)
          .timeout(AppConfig.requestTimeout);
    } on http.ClientException {
      throw const AppError(
        AppErrorType.noInternet,
        'Network error. Check your connection and retry.',
        retryable: true,
      );
    } on Exception catch (e) {
      final str = e.toString();
      if (str.contains('SocketException') || str.contains('HttpException')) {
        throw const AppError(
          AppErrorType.noInternet,
          'Network error. Check your connection and retry.',
          retryable: true,
        );
      }
      if (str.contains('TimeoutException')) {
        throw const AppError(
          AppErrorType.timeout,
          'The request timed out. Please retry.',
          retryable: true,
        );
      }
      rethrow;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const AppError(AppErrorType.parse, 'Unexpected response shape.');
        }
        return decoded;
      } on FormatException {
        throw const AppError(AppErrorType.parse, 'Could not read server response.');
      }
    }

    throw _mapHttpError(response);
  }

  AppError _mapHttpError(http.Response response) {
    final reason = _extractReason(response.body);
    switch (response.statusCode) {
      case 400:
        return AppError(
          reason == 'keyInvalid'
              ? AppErrorType.missingApiKey
              : AppErrorType.unknown,
          reason == 'keyInvalid'
              ? 'The YouTube API key is invalid. Check YOUTUBE_API_KEY.'
              : 'Bad request to YouTube API.',
        );
      case 401:
        return const AppError(
          AppErrorType.unauthorized,
          'Your YouTube session expired. Reconnect to continue.',
        );
      case 403:
        if (reason == 'quotaExceeded' || reason == 'dailyLimitExceeded') {
          return const AppError(
            AppErrorType.quotaExceeded,
            'Daily YouTube API quota reached. Try again after it resets.',
          );
        }
        if (reason == 'rateLimitExceeded' || reason == 'userRateLimitExceeded') {
          return const AppError(
            AppErrorType.rateLimited,
            'Too many requests. Wait a moment and retry.',
            retryable: true,
          );
        }
        return const AppError(
          AppErrorType.forbidden,
          'Access denied. Check API key restrictions and granted permissions.',
        );
      case 404:
        return const AppError(AppErrorType.notFound, 'Content not found or unavailable.');
      case 429:
        return const AppError(
          AppErrorType.rateLimited,
          'Too many requests. Wait a moment and retry.',
          retryable: true,
        );
      default:
        final transient = response.statusCode >= 500;
        return AppError(
          AppErrorType.unknown,
          'YouTube API error (${response.statusCode}).',
          retryable: transient,
        );
    }
  }

  String? _extractReason(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final errors = (json['error'] as Map?)?['errors'];
      if (errors is List && errors.isNotEmpty) {
        return (errors.first as Map)['reason'] as String?;
      }
    } catch (_) {}
    return null;
  }

  void close() => _http.close();
}
