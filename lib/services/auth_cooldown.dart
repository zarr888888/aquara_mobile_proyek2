import 'api_result.dart';

/// UX throttling only; the server is authoritative. Reopening a screen does not
/// reset this deadline. No OTP, password or identifier is persisted here.
class AuthCooldown {
  static final instance = AuthCooldown();
  final Map<String, DateTime> _until = {};
  int remaining(String bucket) {
    final end = _until[bucket];
    if (end == null) return 0;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    return ms > 0 ? (ms / 1000).ceil() : 0;
  }

  void wait(String bucket, Duration duration) {
    final end = DateTime.now().add(duration);
    if (end.isAfter(_until[bucket] ?? DateTime.fromMillisecondsSinceEpoch(0))) {
      _until[bucket] = end;
    }
  }

  void record(ApiResult<Object?> result, String bucket) {
    if (result.failure?.kind == ApiErrorKind.rateLimited) {
      wait(bucket, result.failure?.retryAfter ?? const Duration(seconds: 60));
    }
  }
}
