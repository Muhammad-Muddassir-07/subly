enum AppErrorType {
  missingApiKey,
  authCancelled,
  authDenied,
  authFailed,
  unauthorized, // 401 / expired token
  forbidden, // 403 / insufficient permission
  quotaExceeded,
  rateLimited,
  notFound,
  noInternet,
  timeout,
  noSubscriptions,
  parse,
  unknown,
}

class AppError implements Exception {
  const AppError(this.type, this.message, {this.retryable = false});

  final AppErrorType type;
  final String message;
  final bool retryable;

  @override
  String toString() => 'AppError($type): $message';
}
