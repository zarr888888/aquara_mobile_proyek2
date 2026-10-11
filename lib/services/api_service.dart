import '../models/reference_data.dart';
import 'forum_api.dart';
import 'pasar_api.dart';
import 'ai_analysis_api.dart';
import 'sos_api.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'api_result.dart';
import 'auth_service.dart';
import 'api_client.dart';
import 'session_service.dart';
import '../models/app_notification.dart';

class ApiService extends AuthService
    with ForumApi, PasarApi, AiAnalysisApi, SosApi {
  ApiService({
    ApiClient? client,
    SessionService? session,
    Future<String?> Function()? googleIdToken,
  }) : super(client: client, session: session, googleIdToken: googleIdToken);
  final String baseUrl = AuthService.apiBaseUrl;

  Future<ApiResult<List<dynamic>>> fetchFishTypes({
    required SessionSnapshot expectedSession,
  }) => _fetchReference('fish-types', expectedSession);

  Future<ApiResult<List<dynamic>>> fetchPosts({
    required SessionSnapshot expectedSession,
  }) => _fetchReference('posts', expectedSession);

  Future<ApiResult<List<dynamic>>> fetchStocks({
    required SessionSnapshot expectedSession,
  }) => _fetchReference('stocks', expectedSession);

  final _referenceFlights = <String, Future<ApiResult<List<dynamic>>>>{};
  final _referenceWaits = <String, ({DateTime until, ApiFailure failure})>{};
  int? _referenceRevision;

  Future<ApiResult<List<dynamic>>> _fetchReference(
    String path,
    SessionSnapshot owner,
  ) {
    if (!session.owns(owner)) {
      return Future.value(
        ApiResult.failure(
          ApiFailure(
            kind: owner.isAuthenticated
                ? ApiErrorKind.staleSession
                : ApiErrorKind.unauthenticated,
            message: owner.isAuthenticated
                ? 'Sesi berubah.'
                : 'Silakan login terlebih dahulu.',
          ),
        ),
      );
    }
    if (_referenceRevision != owner.revision) {
      _referenceFlights.clear();
      _referenceWaits.clear();
      _referenceRevision = owner.revision;
    }
    final wait = _referenceWaits[path];
    if (wait != null && DateTime.now().isBefore(wait.until)) {
      return Future.value(
        ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.rateLimited,
            message: wait.failure.message,
            retryAfter: wait.failure.retryAfter == null
                ? null
                : wait.until.difference(DateTime.now()),
            retryAt: wait.until,
          ),
          statusCode: 429,
        ),
      );
    }
    return _referenceFlights.putIfAbsent(path, () async {
      try {
        final result = await _requestReference(path, owner);
        if (session.owns(owner) &&
            result.failure?.kind == ApiErrorKind.rateLimited) {
          final failure = result.failure!;
          _referenceWaits[path] = (
            until:
                failure.retryAt ??
                DateTime.now().add(
                  failure.retryAfter ?? const Duration(seconds: 60),
                ),
            failure: failure,
          );
        }
        return result;
      } finally {
        if (_referenceRevision == owner.revision) {
          _referenceFlights.remove(path);
        }
      }
    });
  }

  Future<ApiResult<List<dynamic>>> _requestReference(
    String path,
    SessionSnapshot owner,
  ) async {
    final result = await authClient.request(
      'GET',
      path,
      expectedSession: owner,
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    try {
      return ApiResult.success(
        data: parseReferenceList(result.data, path),
        statusCode: result.statusCode,
      );
    } on FormatException {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidResponse,
          message: 'Format data tidak valid. Silakan coba kembali.',
        ),
        statusCode: result.statusCode,
      );
    }
  }

  Future<List<dynamic>> fetchBeritaNasional() async {
    try {
      final String rssUrl =
          'https://news.google.com/rss/search?q=perikanan+budidaya+ikan+tawar&hl=id&gl=ID&ceid=ID:id';
      final String url =
          'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(rssUrl)}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          return data['items'];
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetchBeritaNasional: $e");
      return [];
    }
  }

  Future<ApiResult<Object?>> updateProfile(
    String name,
    String fokusBudidaya,
    File? fotoProfil, {
    SessionSnapshot? expectedSession,
  }) async {
    try {
      final before = expectedSession ?? await session.snapshot();
      if (!session.owns(before)) return _staleProfile();
      if (name.trim().isEmpty || name.runes.length > 255) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.validation,
            message: 'Nama wajib diisi, maksimal 255 karakter.',
          ),
        );
      }
      final files = <http.MultipartFile>[];
      if (fotoProfil != null) {
        if (await fotoProfil.length() > 2048 * 1024 ||
            !RegExp(
              r'\.(jpe?g|png)$',
              caseSensitive: false,
            ).hasMatch(fotoProfil.path)) {
          return ApiResult.failure(
            ApiFailure(
              kind: ApiErrorKind.validation,
              message: 'Foto harus JPEG/PNG maksimal 2 MB.',
            ),
          );
        }
        final bytes = await fotoProfil.readAsBytes();
        final jpeg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        final png =
            bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
        if (bytes.length > 2048 * 1024 || (!jpeg && !png)) {
          return ApiResult.failure(
            ApiFailure(
              kind: ApiErrorKind.validation,
              message: 'Foto harus JPEG/PNG maksimal 2048 KB.',
            ),
          );
        }
        files.add(
          http.MultipartFile.fromBytes(
            'foto_profil',
            bytes,
            filename: png ? 'profil.png' : 'profil.jpg',
          ),
        );
      }
      if (!session.owns(before)) return _staleProfile();
      final fields = {
        'name': name,
        if (fokusBudidaya.trim().isNotEmpty) 'fokus_budidaya': fokusBudidaya,
      };
      final result = fotoProfil == null
          ? await authClient.request(
              'POST',
              'profil/update',
              body: fields,
              expectedSession: before,
            )
          : await authClient.multipart(
              'profil/update',
              fields: fields,
              files: files,
              expectedSession: before,
            );
      if (!result.isSuccess) return result;
      final data = result.data;
      if (data is! Map ||
          data['data'] is! Map ||
          data['success'] != true ||
          data['data']['id'] is! int ||
          data['data']['id'] <= 0 ||
          data['data']['name'] is! String ||
          (data['data']['foto_profil'] != null &&
              data['data']['foto_profil'] is! String)) {
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.invalidResponse,
            message: 'Respons profil tidak valid.',
          ),
        );
      }
      if (!await session.updateMetadata(
        before,
        Map<String, dynamic>.from(data['data'] as Map),
      )) {
        return _staleProfile();
      }
      return result;
    } catch (_) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.session,
          message: 'Profil tidak dapat diperbarui. Silakan coba kembali.',
        ),
      );
    }
  }

  ApiResult<Object?> _staleProfile() => ApiResult.failure(
    ApiFailure(
      kind: ApiErrorKind.staleSession,
      message: 'Sesi berubah. Muat ulang profil.',
    ),
  );

  Future<ApiResult<List<AppNotification>>> fetchNotifications({
    required SessionSnapshot expectedSession,
  }) async {
    final result = await authClient.request(
      'GET',
      'notifications',
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    try {
      final payload = result.data;
      if (payload is! Map ||
          payload['success'] != true ||
          payload['data'] is! List) {
        throw const FormatException();
      }
      return ApiResult.success(
        data: List<AppNotification>.unmodifiable(
          (payload['data'] as List).map(AppNotification.fromJson),
        ),
        statusCode: result.statusCode,
      );
    } on FormatException {
      return ApiResult.failure(
        _invalidNotification(),
        statusCode: result.statusCode,
      );
    }
  }

  Future<ApiResult<Object?>> markNotificationRead(
    int id, {
    required SessionSnapshot expectedSession,
  }) async {
    if (id <= 0) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Notifikasi tidak tersedia.',
        ),
      );
    }
    final result = await authClient.request(
      'POST',
      'notifications/$id/read',
      expectedSession: expectedSession,
    );
    if (!result.isSuccess) return result;
    final payload = result.data;
    if (payload is! Map || payload['success'] != true) {
      return ApiResult.failure(
        _invalidNotification(),
        statusCode: result.statusCode,
      );
    }
    return result;
  }

  ApiFailure _invalidNotification() => ApiFailure(
    kind: ApiErrorKind.invalidResponse,
    message: 'Format notifikasi tidak valid. Silakan coba kembali.',
  );
}
