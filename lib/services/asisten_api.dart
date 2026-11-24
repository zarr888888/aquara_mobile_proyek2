import '../models/asisten_chat.dart';
import 'api_result.dart';
import 'auth_service.dart';
import 'session_service.dart';

/// Only non-content metadata survives closing a screen. Weak session keys and
/// revision checks prevent cooldowns/in-flight mutations crossing logins.
class AsistenGate {
  static final _sessions = Expando<AsistenGate>();
  static AsistenGate forSession(SessionService session) {
    var gate = _sessions[session];
    if (gate == null || gate.revision != session.revision) {
      gate = AsistenGate._(session.revision);
      _sessions[session] = gate;
    }
    return gate;
  }

  AsistenGate._(this.revision);
  final int revision;
  DateTime? until;
  bool localFallback = false;
  bool sending = false;
  int seconds(DateTime now) {
    final ms = until?.difference(now).inMilliseconds ?? 0;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void record(ApiFailure failure, DateTime now) {
    if (failure.kind != ApiErrorKind.rateLimited) return;
    final deadline =
        failure.retryAt ??
        now.add(failure.retryAfter ?? const Duration(seconds: 60));
    if (until == null || deadline.isAfter(until!)) {
      until = deadline;
      localFallback = failure.retryAt == null && failure.retryAfter == null;
    }
  }
}

mixin AsistenApi on AuthService {
  DateTime asistenNow() => DateTime.now();
  AsistenGate get asistenGate => AsistenGate.forSession(session);

  ApiResult<T> _invalidChat<T>([int? status]) => ApiResult.failure(
    ApiFailure(
      kind: ApiErrorKind.invalidResponse,
      message: 'Respons Asisten tidak valid.',
    ),
    statusCode: status,
  );

  Future<ApiResult<Object?>> _chatRequest(
    String method,
    String path,
    SessionSnapshot owner, {
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    if (!session.owns(owner)) {
      return ApiResult.failure(
        ApiFailure(
          kind: owner.isAuthenticated
              ? ApiErrorKind.staleSession
              : ApiErrorKind.unauthenticated,
          message: 'Silakan login kembali.',
        ),
      );
    }
    final gate = asistenGate;
    if (gate.seconds(asistenNow()) > 0) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.rateLimited,
          message: 'Tunggu sebelum menggunakan Asisten kembali.',
          retryAt: gate.until,
        ),
        statusCode: 429,
      );
    }
    final result = await authClient.request(
      method,
      path,
      expectedSession: owner,
      body: body,
      query: query,
    );
    if (!session.owns(owner)) {
      return ApiResult.failure(
        ApiFailure(kind: ApiErrorKind.staleSession, message: 'Sesi berubah.'),
        statusCode: result.statusCode,
      );
    }
    if (result.isSuccess) return result;
    final failure = result.failure!;
    gate.record(failure, asistenNow());
    return ApiResult.failure(
      ApiFailure(
        kind: failure.kind,
        message: switch (failure.kind) {
          ApiErrorKind.server when method == 'POST' => 'Asisten belum tersedia',
          ApiErrorKind.forbidden ||
          ApiErrorKind.notFound => 'Chat tidak tersedia.',
          ApiErrorKind.validation => asistenMessageError,
          _ => failure.message,
        },
        fieldErrors: {
          if (failure.fieldErrors.containsKey('message'))
            'message': [asistenMessageError],
        },
        retryAt: failure.retryAt,
        retryAfter: failure.retryAfter,
      ),
      statusCode: result.statusCode,
    );
  }

  ApiResult<AsistenChat> _chat(
    ApiResult<Object?> result, {
    bool post = false,
    int? id,
  }) {
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    final raw = result.data;
    try {
      if (result.statusCode != (post ? 201 : 200) ||
          raw is! Map ||
          raw['success'] != true) {
        throw const FormatException();
      }
      final chat = AsistenChat.parse(raw['data'], post: post);
      if (id != null && chat.id != id) throw const FormatException();
      return ApiResult.success(data: chat, statusCode: result.statusCode);
    } on FormatException {
      return _invalidChat(result.statusCode);
    }
  }

  Future<ApiResult<AsistenChat>> sendAsisten(
    String message, {
    required SessionSnapshot expectedSession,
  }) async {
    if (!asistenMessageValid(message)) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.validation,
          message: asistenMessageError,
          fieldErrors: const {
            'message': [asistenMessageError],
          },
        ),
      );
    }
    final gate = asistenGate;
    if (gate.sending) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Pengiriman masih berlangsung.',
        ),
      );
    }
    gate.sending = true;
    try {
      return _chat(
        await _chatRequest(
          'POST',
          'asisten/chat',
          expectedSession,
          body: {'message': message},
        ),
        post: true,
      );
    } finally {
      gate.sending = false;
    }
  }

  Future<ApiResult<AsistenPage>> asistenHistory({
    required SessionSnapshot expectedSession,
    int page = 1,
  }) async {
    if (page < 1) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Halaman tidak valid.',
        ),
      );
    }
    final result = await _chatRequest(
      'GET',
      'asisten/chat',
      expectedSession,
      query: {'page': '$page'},
    );
    if (!result.isSuccess) {
      return ApiResult.failure(result.failure!, statusCode: result.statusCode);
    }
    final raw = result.data;
    try {
      if (result.statusCode != 200 || raw is! Map || raw['success'] != true) {
        throw const FormatException();
      }
      final parsed = AsistenPage.parse(raw['data']);
      if (parsed.currentPage != page) throw const FormatException();
      return ApiResult.success(data: parsed, statusCode: 200);
    } on FormatException {
      return _invalidChat(result.statusCode);
    }
  }

  Future<ApiResult<AsistenChat>> asistenDetail(
    int id, {
    required SessionSnapshot expectedSession,
  }) async {
    if (id < 1) {
      return ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.invalidRequest,
          message: 'Chat tidak tersedia.',
        ),
      );
    }
    return _chat(
      await _chatRequest('GET', 'asisten/chat/$id', expectedSession),
      id: id,
    );
  }
}
