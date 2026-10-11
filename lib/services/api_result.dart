enum ApiErrorKind {
  unauthenticated,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
  server,
  http,
  network,
  timeout,
  invalidResponse,
  invalidRequest,
  session,
  staleSession,
}

/// Does not expose response bodies or transport exception strings on failures.
class ApiFailure {
  ApiFailure({
    required this.kind,
    required this.message,
    Map<String, List<String>> fieldErrors = const {},
    this.retryAfter,
    this.retryAt,
  }) : fieldErrors = Map<String, List<String>>.unmodifiable(
         fieldErrors.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );

  final ApiErrorKind kind;
  final String message;
  final Map<String, List<String>> fieldErrors;

  /// Null means the server did not provide a usable Retry-After, NOT zero wait.
  final Duration? retryAfter;
  final DateTime? retryAt;

  @override
  String toString() => 'ApiFailure(${kind.name})';
}

/// [data] is the entire decoded JSON payload, not an automatically unwrapped
/// `data` property. This preserves raw User objects and nested paginators alike.
class ApiResult<T> {
  const ApiResult.success({required this.data, required this.statusCode})
    : failure = null;

  const ApiResult.failure(ApiFailure error, {this.statusCode})
    : failure = error,
      data = null;

  final T? data;
  final int? statusCode;
  final ApiFailure? failure;

  bool get isSuccess => failure == null;

  @override
  String toString() => 'ApiResult(status: $statusCode, success: $isSuccess)';
}
