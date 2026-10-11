import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';
import 'api_result.dart';
import 'session_service.dart';

/// Auth methods inherited by ApiService; legacy feature methods migrate later.
class AuthService {
  AuthService({
    ApiClient? client,
    SessionService? session,
    Future<String?> Function()? googleIdToken,
  }) : session = session ?? SessionService.instance,
       _googleIdToken = googleIdToken ?? _getGoogleIdToken {
    authClient =
        client ??
        ApiClient(baseUrl: Uri.parse(apiBaseUrl), session: this.session);
  }

  static const apiBaseUrl = String.fromEnvironment(
    'SAMUDERA_API_URL',
    defaultValue: 'https://aquara.app/api',
  );
  final SessionService session;
  late final ApiClient authClient;
  final Future<String?> Function() _googleIdToken;
  static Future<void>? _googleInitialization;

  static Future<String?> _getGoogleIdToken() async {
    try {
      await (_googleInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: const String.fromEnvironment(
          'GOOGLE_SERVER_CLIENT_ID',
          defaultValue:
              '525481370217-qpvpucpii0qbttmrf5knk34a86nqs9ips.apps.googleusercontent.com',
        ),
      ));
    } catch (_) {
      _googleInitialization = null;
      rethrow;
    }
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken;
  }

  ApiResult<Object?> _invalid(String message) => ApiResult.failure(
    ApiFailure(kind: ApiErrorKind.validation, message: message),
  );
  ApiResult<Object?> _sessionError() => ApiResult.failure(
    ApiFailure(
      kind: ApiErrorKind.session,
      message: 'Penyimpanan sesi aman tidak tersedia. Silakan coba kembali.',
    ),
  );

  Future<ApiResult<Object?>> _authenticate(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final before = await session.snapshot();
      final result = await authClient.post(
        path,
        access: ApiAccess.public,
        body: body,
      );
      if (!result.isSuccess) return result;
      final payload = result.data;
      if (payload is! Map ||
          payload['token'] is! String ||
          payload['data'] is! Map ||
          payload['success'] == false) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.invalidResponse,
            message: 'Respons login tidak valid.',
          ),
          statusCode: result.statusCode,
        );
      }
      final user = Map<String, dynamic>.from(payload['data'] as Map);
      if (user['id'] is! int ||
          user['name'] is! String ||
          (user['foto_profil'] != null && user['foto_profil'] is! String)) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.invalidResponse,
            message: 'Data pengguna tidak valid.',
          ),
          statusCode: result.statusCode,
        );
      }
      if (!await session.saveIfCurrent(
        payload['token'] as String,
        expected: before,
        user: user,
      )) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.staleSession,
            message: 'Sesi berubah. Silakan ulangi login.',
          ),
        );
      }
      // Do not expose the bearer to widgets through the result payload.
      return ApiResult.success(data: user, statusCode: result.statusCode);
    } catch (_) {
      return _sessionError();
    }
  }

  Future<ApiResult<Object?>> loginUser(String loginId, String password) =>
      _authenticate('login', {'login_id': loginId, 'password': password});

  Future<ApiResult<Object?>> registerUser(
    String name,
    String email,
    String phone,
    String password,
  ) => authClient.post(
    'register',
    access: ApiAccess.public,
    body: {
      'name': name,
      if (email.isNotEmpty) 'email': email,
      'phone': phone,
      'password': password,
    },
  );

  Future<ApiResult<Object?>> loginWithGoogle() async {
    try {
      final idToken = await _googleIdToken();
      if (idToken == null || idToken.isEmpty || idToken.length > 10000) {
        return _invalid('Google tidak memberikan ID token yang valid.');
      }
      return _authenticate('google-login', {'id_token': idToken});
    } catch (_) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.unauthorized,
          message:
              'Login Google dibatalkan atau tidak tersedia. Silakan coba kembali.',
        ),
      );
    }
  }

  Future<ApiResult<Object?>> requestRegistrationOtp(
    String loginId,
    String method,
  ) => _send('register/send-otp', {'login_id': loginId, 'method': method});
  Future<ApiResult<Object?>> requestResetOtp(String loginId, String method) =>
      _send('lupa-password/send-otp', {'login_id': loginId, 'method': method});
  Future<ApiResult<Object?>> sendOtpWa(String phone) =>
      _send('send-otp-wa', {'phone': phone});
  Future<ApiResult<Object?>> requestUbahKontakOtp(
    String targetContact,
    String method,
  ) => _send('ubah-kontak/send-otp', {
    'target_contact': targetContact,
    'method': method,
  });
  Future<ApiResult<Object?>> requestHapusAkunOtp(String method) =>
      _send('hapus-akun/send-otp', {'method': method});

  Future<ApiResult<Object?>> _send(
    String path,
    Map<String, Object?> body,
  ) async {
    if (body.containsKey('method') &&
        !{'email', 'wa'}.contains(body['method'])) {
      return _invalid('Pilih metode email atau WhatsApp.');
    }
    return authClient.post(path, body: body);
  }

  bool _validOtp(String otp) => RegExp(r'^[0-9]{6}$').hasMatch(otp);
  Future<ApiResult<Object?>> verifyRegistrationOtp(
    String loginId,
    String otp,
  ) async => _validOtp(otp)
      ? _authenticate('register/verify-otp', {'login_id': loginId, 'otp': otp})
      : _invalid('OTP wajib tepat 6 digit.');
  Future<ApiResult<Object?>> verifyOtpWa(String phone, String otp) async =>
      _validOtp(otp)
      ? _authenticate('verify-otp-wa', {'phone': phone, 'otp': otp})
      : _invalid('OTP wajib tepat 6 digit.');

  Future<ApiResult<Object?>> resetPasswordWithOtp(
    String loginId,
    String otp,
    String newPassword,
  ) async {
    if (!_validOtp(otp) ||
        newPassword.length < 12 ||
        newPassword.length > 128) {
      return _invalid('OTP wajib 6 digit dan password baru 12–128 karakter.');
    }
    return _revokeLocalOnSuccess(
      () => authClient.post(
        'lupa-password/verify',
        body: {'login_id': loginId, 'otp': otp, 'new_password': newPassword},
      ),
    );
  }

  Future<ApiResult<Object?>> ubahKontak(
    String method,
    String targetContact,
    String otp,
  ) async {
    if (!_validOtp(otp) || !{'email', 'wa'}.contains(method)) {
      return _invalid('Metode atau OTP tidak valid.');
    }
    return _revokeLocalOnSuccess(
      () => authClient.post(
        'ubah-kontak',
        body: {'method': method, 'target_contact': targetContact, 'otp': otp},
      ),
    );
  }

  Future<ApiResult<Object?>> hapusAkun(String otp) async {
    if (!_validOtp(otp)) return _invalid('OTP wajib tepat 6 digit.');
    return _revokeLocalOnSuccess(
      () => authClient.delete('hapus-akun', body: {'otp': otp}),
    );
  }

  Future<ApiResult<Object?>> _revokeLocalOnSuccess(
    Future<ApiResult<Object?>> Function() call,
  ) async {
    try {
      final before = await session.snapshot();
      final result = await call();
      if (result.isSuccess) await session.invalidate(before);
      return result;
    } catch (_) {
      return _sessionError();
    }
  }

  Future<ApiResult<Object?>> logout() async {
    try {
      final before = await session.snapshot();
      final result = await authClient.post('logout');
      await session.invalidate(before); // local logout also works offline
      return result;
    } catch (_) {
      return _sessionError();
    }
  }

  Future<ApiResult<Object?>> currentUser({
    SessionSnapshot? expectedSession,
  }) async {
    try {
      final before = expectedSession ?? await session.snapshot();
      final version = session.metadataVersion;
      final result = await authClient.request(
        'GET',
        'user',
        expectedSession: before,
      );
      if (!result.isSuccess) return result;
      final data = result.data;
      if (data is! Map ||
          data['id'] is! int ||
          data['id'] <= 0 ||
          data['name'] is! String ||
          (data['foto_profil'] != null && data['foto_profil'] is! String) ||
          (data['fokus_budidaya'] != null &&
              data['fokus_budidaya'] is! String)) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.invalidResponse,
            message: 'Data pengguna tidak valid.',
          ),
        );
      }
      if (!await session.updateMetadata(
        before,
        Map<String, dynamic>.from(result.data as Map),
        expectedMetadataVersion: version,
      )) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.staleSession,
            message: 'Sesi berubah. Muat ulang data.',
          ),
        );
      }
      return result;
    } catch (_) {
      return _sessionError();
    }
  }

  Future<ApiResult<Object?>> changePassword(
    String oldPassword,
    String newPassword,
  ) => authClient.post(
    'ubah-password',
    body: {
      'old_password': oldPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    },
  );
}
