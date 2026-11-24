import '../models/external_info.dart';
import 'api_client.dart';
import 'api_result.dart';
import 'auth_service.dart';

/// Public request coordination only: no tokens, user data, disk cache or timers.
/// The default lives across facade/route recreation for the configured backend.
class ExternalInfoRequests {
  ExternalInfoRequests({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  static final shared = ExternalInfoRequests();
  final DateTime Function() _clock;
  DateTime get now => _clock();
  final _flights =
      <(ExternalInfoKind, String?), Future<ApiResult<ExternalInfo>>>{};
  DateTime? _until;
  bool _serverWait = false;

  Duration get remaining {
    final duration = _until?.difference(_clock()) ?? Duration.zero;
    return duration.isNegative ? Duration.zero : duration;
  }

  bool get usesServerWait => _serverWait;

  ApiResult<ExternalInfo> _limited() => ApiResult.failure(
    ApiFailure(
      kind: ApiErrorKind.rateLimited,
      message: 'Permintaan informasi dibatasi. Tunggu sebelum mencoba kembali.',
      retryAt: _until,
      retryAfter: _serverWait ? remaining : null,
    ),
    statusCode: 429,
  );

  Future<ApiResult<ExternalInfo>> fetch(
    ApiClient client,
    ExternalInfoKind kind, {
    String code = 'XJ022',
  }) {
    if (remaining > Duration.zero) return Future.value(_limited());
    final key = (kind, kind == ExternalInfoKind.cuaca ? code : null);
    return _flights.putIfAbsent(key, () async {
      try {
        final result = await client.get(
          kind.path,
          access: ApiAccess.public,
          query: key.$2 == null ? null : {'kode': code},
        );
        if (!result.isSuccess) {
          final failure = result.failure!;
          if (failure.kind == ApiErrorKind.rateLimited) {
            final until =
                failure.retryAt ??
                _clock().add(failure.retryAfter ?? const Duration(seconds: 60));
            // A later concurrent response must not shorten an existing wait.
            if (_until == null || until.isAfter(_until!)) {
              _until = until;
              _serverWait = failure.retryAfter != null;
            }
            return _limited();
          }
          return ApiResult.failure(failure, statusCode: result.statusCode);
        }
        try {
          return ApiResult.success(
            data: ExternalInfo.parse(result.data, kind, code: code),
            statusCode: result.statusCode,
          );
        } on FormatException {
          return ApiResult.failure(
            ApiFailure(
              kind: ApiErrorKind.invalidResponse,
              message: 'Format informasi tidak valid. Silakan coba kembali.',
            ),
            statusCode: result.statusCode,
          );
        }
      } finally {
        _flights.remove(key);
      }
    });
  }
}

mixin ExternalInfoApi on AuthService {
  ExternalInfoRequests get externalInfoRequests;
  Future<ApiResult<ExternalInfo>> fetchExternalInfo(
    ExternalInfoKind kind, {
    String code = 'XJ022',
  }) => externalInfoRequests.fetch(authClient, kind, code: code);
}
