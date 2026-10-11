import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:http/http.dart' as http;

import 'api_result.dart';
import 'session_service.dart';

enum ApiAccess { public, private }

/// Mobile HTTP boundary. Paths are relative to an explicitly configured HTTPS
/// API base, e.g. `user`, NOT `/api/user` or an absolute URL.
///
/// Each exchange owns a fresh client, including injected clients. This permits
/// closing only that exchange on timeout without aborting concurrent requests.
/// Do not inject a shared client, RetryClient, or a redirect-following wrapper.
class ApiClient {
  ApiClient({
    required Uri baseUrl,
    SessionService? session,
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
    this.maxResponseBytes = 5 * 1024 * 1024,
    DateTime Function()? clock,
  }) : _baseUrl = _validateBase(baseUrl),
       _session = session ?? SessionService.instance,
       _clientFactory = clientFactory ?? http.Client.new,
       _clock = clock ?? DateTime.now {
    if (timeout <= Duration.zero || maxResponseBytes <= 0) {
      throw ArgumentError('Batas request harus lebih besar dari nol.');
    }
  }

  final Uri _baseUrl;
  final SessionService _session;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;
  final Duration timeout;
  final int maxResponseBytes;

  static const _publicPaths = {
    'login',
    'register',
    'google-login',
    'register/send-otp',
    'register/verify-otp',
    'send-otp-wa',
    'verify-otp-wa',
    'lupa-password/send-otp',
    'lupa-password/verify',
    'info/kkp',
    'info/cuaca',
    'info/tpi',
  };
  static const _privateOtpPaths = {'ubah-kontak', 'hapus-akun'};

  static Uri _validateBase(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.any((p) => p == '..' || p == '.')) {
      throw ArgumentError('Base URL API harus HTTPS tanpa kredensial/query.');
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }

  Uri _uri(String path, Map<String, String>? query) {
    // A deliberately narrow grammar also excludes encoded traversal, query
    // credentials, fragments, network-path references and backslash ambiguity.
    if (!RegExp(r'^[a-zA-Z0-9_-]+(?:/[a-zA-Z0-9_-]+)*$').hasMatch(path)) {
      throw const FormatException('Path API tidak valid.');
    }
    if (query != null &&
        query.keys.any(
          (key) => RegExp(
            r'token|password|otp|secret|authorization|login_id|email|phone',
            caseSensitive: false,
          ).hasMatch(key),
        )) {
      throw const FormatException('Kredensial tidak boleh berada di URL.');
    }
    return _baseUrl.resolve(path).replace(queryParameters: query);
  }

  Future<ApiResult<Object?>> get(
    String path, {
    ApiAccess access = ApiAccess.private,
    Map<String, String>? query,
  }) => request('GET', path, access: access, query: query);

  Future<ApiResult<Object?>> post(
    String path, {
    ApiAccess access = ApiAccess.private,
    Map<String, Object?>? body,
  }) => request('POST', path, access: access, body: body);

  Future<ApiResult<Object?>> delete(
    String path, {
    ApiAccess access = ApiAccess.private,
    Map<String, Object?>? body,
  }) => request('DELETE', path, access: access, body: body);

  Future<ApiResult<Object?>> request(
    String method,
    String path, {
    ApiAccess access = ApiAccess.private,
    Map<String, String>? query,
    Map<String, Object?>? body,
    SessionSnapshot? expectedSession,
  }) => _execute(method, path, access, query, (uri) {
    final request = http.Request(method, uri);
    if (body != null) {
      request.body = jsonEncode(body);
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    return request;
  }, expectedSession: expectedSession);

  /// Files are single-use http.MultipartFiles. A manual retry must rebuild them.
  Future<ApiResult<Object?>> multipart(
    String path, {
    String method = 'POST',
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
    SessionSnapshot? expectedSession,
    Duration? requestTimeout,
  }) => _execute(
    method,
    path,
    ApiAccess.private,
    null,
    (uri) {
      return http.MultipartRequest(method, uri)
        ..fields.addAll(fields)
        ..files.addAll(files);
    },
    expectedSession: expectedSession,
    requestTimeout: requestTimeout,
  );

  Future<ApiResult<Object?>> _execute(
    String method,
    String path,
    ApiAccess access,
    Map<String, String>? query,
    http.BaseRequest Function(Uri) build, {
    SessionSnapshot? expectedSession,
    Duration? requestTimeout,
  }) async {
    http.BaseRequest request;
    try {
      if (requestTimeout != null && requestTimeout <= Duration.zero) {
        throw const FormatException();
      }
      if (!{'GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'}.contains(method)) {
        throw const FormatException();
      }
      if (access == ApiAccess.public && !_publicPaths.contains(path)) {
        throw const FormatException();
      }
      request = build(_uri(path, query));
    } catch (_) {
      return _failure(
        ApiErrorKind.invalidRequest,
        'Permintaan API tidak valid.',
      );
    }

    // Public auth/info requests never receive a bearer, even if access was left
    // at its safe default by the caller.
    final isPrivate = !_publicPaths.contains(path);
    SessionSnapshot? snapshot;
    if (isPrivate) {
      try {
        snapshot = await _session.snapshot().timeout(timeout);
      } catch (_) {
        return _failure(ApiErrorKind.session, 'Sesi lokal tidak dapat dibaca.');
      }
      if (!snapshot.isAuthenticated) {
        return _failure(
          ApiErrorKind.unauthenticated,
          'Silakan login terlebih dahulu.',
        );
      }
      if (expectedSession != null &&
          snapshot.revision != expectedSession.revision) {
        return _failure(
          ApiErrorKind.staleSession,
          'Sesi berubah. Muat ulang data.',
        );
      }
    }

    http.Response response;
    try {
      response = await _exchange(request, snapshot, requestTimeout);
    } on TimeoutException {
      return _failure(
        ApiErrorKind.timeout,
        'Waktu tunggu habis. Periksa koneksi dan status transaksi sebelum mengulang.',
      );
    } on _ResponseTooLarge {
      return _failure(
        ApiErrorKind.invalidResponse,
        'Respons server terlalu besar.',
      );
    } catch (_) {
      return _failure(
        ApiErrorKind.network,
        'Tidak dapat terhubung ke server. Silakan coba kembali.',
      );
    }

    Object? payload;
    bool malformed = false;
    try {
      if (response.bodyBytes.isNotEmpty) {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      } else if (response.statusCode != 204 &&
          response.statusCode != 205 &&
          method != 'HEAD') {
        malformed = true;
      }
    } catch (_) {
      malformed = true;
    }

    final status = response.statusCode;
    if (snapshot != null) {
      try {
        if (!await _session.isCurrent(snapshot).timeout(timeout)) {
          return _failure(
            ApiErrorKind.staleSession,
            'Sesi telah berubah. Muat ulang data.',
            status: status,
          );
        }
        if (status == 401) {
          bool invalidToken =
              !_privateOtpPaths.contains(path) ||
              (payload is Map && payload['message'] == 'Unauthenticated.');
          if (!invalidToken) {
            // OTP failure and Sanctum failure share 401. Verify the SAME session,
            // never log out solely because a protected challenge was rejected.
            try {
              final probe = await _exchange(
                http.Request('GET', _uri('user', null)),
                snapshot,
              );
              invalidToken = probe.statusCode == 401;
            } catch (_) {
              // Inconclusive/offline: retain session; user can retry later.
            }
            if (!await _session.isCurrent(snapshot).timeout(timeout)) {
              return _failure(
                ApiErrorKind.staleSession,
                'Sesi telah berubah. Muat ulang data.',
                status: status,
              );
            }
          }
          if (invalidToken) {
            final cleared = await _session
                .invalidate(snapshot)
                .timeout(timeout);
            if (!cleared) {
              return _failure(
                ApiErrorKind.staleSession,
                'Sesi telah berubah. Muat ulang data.',
                status: status,
              );
            }
            return _failure(
              ApiErrorKind.unauthenticated,
              'Sesi berakhir. Silakan login kembali.',
              status: status,
            );
          }
        }
      } catch (_) {
        return _failure(
          ApiErrorKind.session,
          'Sesi tidak dapat dibersihkan sepenuhnya. Silakan coba kembali.',
          status: status,
        );
      }
    }

    if (status >= 200 && status < 300) {
      if (malformed) {
        return _failure(
          ApiErrorKind.invalidResponse,
          'Format respons server tidak valid.',
          status: status,
        );
      }
      return ApiResult.success(data: payload, statusCode: status);
    }
    return _httpFailure(response, payload);
  }

  Future<http.Response> _exchange(
    http.BaseRequest request,
    SessionSnapshot? session, [
    Duration? requestTimeout,
  ]) async {
    final client = _clientFactory();
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.headers['Accept'] = 'application/json';
    if (session?.token != null) {
      request.headers['Authorization'] = 'Bearer ${session!.token}';
    }
    StreamIterator<List<int>>? iterator;
    bool finished = false;
    try {
      // Timeout covers send AND the whole response body, not merely headers.
      return await (() async {
        final streamed = await client.send(request);
        final body = StreamIterator<List<int>>(streamed.stream);
        iterator = body;
        if (finished) {
          unawaited(body.cancel());
          throw TimeoutException('Request sudah berakhir.');
        }
        if ((streamed.contentLength ?? 0) > maxResponseBytes) {
          throw const _ResponseTooLarge();
        }
        final bytes = <int>[];
        while (await body.moveNext()) {
          final chunk = body.current;
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw const _ResponseTooLarge();
          }
          bytes.addAll(chunk);
        }
        return http.Response.bytes(
          bytes,
          streamed.statusCode,
          headers: streamed.headers,
        );
      })().timeout(requestTimeout ?? timeout);
    } finally {
      finished = true;
      final body = iterator;
      if (body != null) unawaited(body.cancel());
      client.close();
    }
  }

  ApiResult<Object?> _httpFailure(http.Response response, Object? payload) {
    final status = response.statusCode;
    final kind = switch (status) {
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      422 => ApiErrorKind.validation,
      429 => ApiErrorKind.rateLimited,
      >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.http,
    };
    final fallback = switch (kind) {
      ApiErrorKind.unauthorized =>
        'Kredensial atau kode verifikasi tidak valid.',
      ApiErrorKind.forbidden => 'Akses ditolak atau akun belum diverifikasi.',
      ApiErrorKind.notFound => 'Data tidak ditemukan atau tidak dapat diakses.',
      ApiErrorKind.validation => 'Periksa kembali data yang dimasukkan.',
      ApiErrorKind.rateLimited =>
        'Terlalu banyak permintaan. Tunggu sebelum mencoba kembali.',
      ApiErrorKind.server =>
        'Layanan sedang tidak tersedia. Silakan coba kembali nanti.',
      _ => 'Permintaan tidak dapat diproses.',
    };
    // Do not expose framework internals, stack traces, or echoed secrets. UI gets
    // stable localized messages and generic field errors, not raw server text.
    final fields = <String, List<String>>{};
    if (status == 422 && payload is Map && payload['errors'] is Map) {
      for (final key in (payload['errors'] as Map).keys) {
        if (key is String &&
            RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.]{0,63}$').hasMatch(key)) {
          fields[key] = [
            'Nilai tidak valid. Periksa format atau ketentuan kolom ini.',
          ];
        }
      }
    }
    final now = _clock().toUtc();
    final retry = status == 429
        ? _retryAfter(response.headers['retry-after'], now)
        : null;
    return ApiResult.failure(
      ApiFailure(
        kind: kind,
        message: retry == null
            ? fallback
            : '$fallback Coba lagi dalam ${retry.inSeconds} detik.',
        fieldErrors: fields,
        retryAfter: retry,
        retryAt: retry == null ? null : now.add(retry),
      ),
      statusCode: status,
    );
  }

  Duration? _retryAfter(String? header, DateTime now) {
    if (header == null) return null;
    final value = header.trim();
    if (RegExp(r'^\d+$').hasMatch(value)) {
      final seconds = int.tryParse(value);
      // Keep DateTime arithmetic bounded even for hostile header values.
      if (seconds == null || seconds > 31536000) return null;
      return Duration(seconds: seconds);
    }
    try {
      final difference = HttpDate.parse(value).toUtc().difference(now);
      if (difference.isNegative) return Duration.zero;
      if (difference > const Duration(days: 365)) return null;
      return Duration(seconds: (difference.inMilliseconds / 1000).ceil());
    } catch (_) {
      return null;
    }
  }

  ApiResult<Object?> _failure(
    ApiErrorKind kind,
    String message, {
    int? status,
  }) => ApiResult.failure(
    ApiFailure(kind: kind, message: message),
    statusCode: status,
  );
}

class _ResponseTooLarge implements Exception {
  const _ResponseTooLarge();
}
