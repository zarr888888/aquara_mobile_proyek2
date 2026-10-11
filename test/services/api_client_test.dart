import 'dart:async';
import 'dart:convert';

import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_token_store.dart';

class StreamingClient extends http.BaseClient {
  StreamingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
  @override
  void close() => closed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  final base = Uri.parse('https://backend.example/api');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = SessionService(
      clearLegacySession: () async {},
      store: FakeTokenStore(),
    );
    await session.saveToken('1|test-token');
  });
  tearDown(() => session.dispose());

  ApiClient client(Future<http.Response> Function(http.Request) handler) =>
      ApiClient(
        baseUrl: base,
        session: session,
        clientFactory: () => MockClient(handler),
        clock: () => DateTime.utc(2026, 9, 30, 12),
      );

  test('private JSON has bearer, Accept and no redirects', () async {
    final result = await client((request) async {
      expect(request.url.toString(), 'https://backend.example/api/pre-order');
      expect(request.headers['Authorization'], 'Bearer 1|test-token');
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(request.followRedirects, isFalse);
      expect(jsonDecode(request.body), {'total_tonase': 2.5});
      return http.Response('{"data":{"id":1}}', 201);
    }).post('pre-order', body: {'total_tonase': 2.5});
    expect(result.isSuccess, isTrue);
    expect(result.statusCode, 201);
    expect(result.data, {
      'data': {'id': 1},
    });
  });

  test('public login never gets bearer and 401 preserves session', () async {
    final result = await client((request) async {
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers['Accept'], 'application/json');
      return http.Response('{"message":"wrong password"}', 401);
    }).post('login');
    expect(result.failure?.kind, ApiErrorKind.unauthorized);
    expect(await session.readToken(), '1|test-token');
  });

  test('missing session never sends private request', () async {
    await session.clear();
    final result = await client(
      (_) async => throw StateError('must not send'),
    ).get('user');
    expect(result.failure?.kind, ApiErrorKind.unauthenticated);
  });

  test('private 401 clears session even for non JSON response', () async {
    final result = await client(
      (_) async => http.Response('<html>401</html>', 401),
    ).get('user');
    expect(result.failure?.kind, ApiErrorKind.unauthenticated);
    expect(await session.readToken(), isNull);
  });

  test('protected OTP 401 probes session instead of logging out', () async {
    final paths = <String>[];
    final result = await client((request) async {
      paths.add(request.url.path);
      return request.url.path.endsWith('/user')
          ? http.Response('{"id":1}', 200)
          : http.Response('{"message":"OTP tidak valid"}', 401);
    }).post('ubah-kontak');
    expect(paths, ['/api/ubah-kontak', '/api/user']);
    expect(result.failure?.kind, ApiErrorKind.unauthorized);
    expect(await session.readToken(), isNotNull);
  });

  test('protected OTP with invalid token clears session', () async {
    final result = await client(
      (_) async => http.Response('{}', 401),
    ).delete('hapus-akun');
    expect(result.failure?.kind, ApiErrorKind.unauthenticated);
    expect(await session.readToken(), isNull);
  });

  for (final code in [200, 401]) {
    test('late $code from old login cannot affect new login', () async {
      final result = await client((_) async {
        await session.saveToken('2|new-token');
        return http.Response('{"id":1}', code);
      }).get('user');
      expect(result.failure?.kind, ApiErrorKind.staleSession);
      expect(await session.readToken(), '2|new-token');
    });
  }

  for (final entry in <String, int?>{
    '60': 60,
    'Wed, 30 Sep 2026 12:02:00 GMT': 120,
    'Tue, 29 Sep 2026 12:00:00 GMT': 0,
    '-1': null,
    'bad': null,
    '9999999999999999999999': null,
  }.entries) {
    test('429 Retry-After ${entry.key}', () async {
      var calls = 0;
      final result = await client((_) async {
        calls++;
        return http.Response('{}', 429, headers: {'retry-after': entry.key});
      }).get('user');
      expect(result.failure?.kind, ApiErrorKind.rateLimited);
      expect(result.failure?.retryAfter?.inSeconds, entry.value);
      expect(calls, 1);
      expect(await session.readToken(), isNotNull);
    });
  }

  test('429 without header leaves countdown unknown', () async {
    final result = await client(
      (_) async => http.Response('busy', 429),
    ).get('user');
    expect(result.failure?.retryAt, isNull);
    expect(result.failure?.kind, ApiErrorKind.rateLimited);
  });

  test(
    '422 preserves field locations without exposing echoed secrets',
    () async {
      final result = await client(
        (_) async => http.Response(
          '{"message":"secret","errors":{"otp":["secret"],"email":["taken"]}}',
          422,
        ),
      ).post('ubah-kontak');
      expect(result.failure?.fieldErrors.keys, ['otp', 'email']);
      expect(result.failure?.message, isNot(contains('secret')));
      expect(
        result.failure?.fieldErrors['otp']!.single,
        isNot(contains('secret')),
      );
    },
  );

  for (final code in [403, 404, 500, 503]) {
    test('$code does not clear session or expose raw body', () async {
      final result = await client(
        (_) async => http.Response('secret stack trace', code),
      ).get('user');
      expect(result.isSuccess, isFalse);
      expect(result.statusCode, code);
      expect(result.failure?.message, isNot(contains('secret')));
      expect(await session.readToken(), isNotNull);
    });
  }

  test('malformed success fails but empty 204 succeeds', () async {
    expect(
      (await client(
        (_) async => http.Response('oops', 200),
      ).get('user')).failure?.kind,
      ApiErrorKind.invalidResponse,
    );
    expect(
      (await client(
        (_) async => http.Response('', 204),
      ).delete('forum/1')).isSuccess,
      isTrue,
    );
  });

  test('nested paginator and raw user are not unwrapped', () async {
    for (final payload in [
      '{"id":1}',
      '{"data":{"data":[],"current_page":1}}',
    ]) {
      final result = await client(
        (_) async => http.Response(payload, 200),
      ).get('user');
      expect(result.data, jsonDecode(payload));
    }
  });

  test(
    'external URLs, traversal and public bypass rejected before network',
    () async {
      final api = client((_) async => throw StateError('must not send'));
      for (final path in [
        'https://evil.example',
        '//evil.example',
        '../user',
        '%2e%2e/user',
        'user?token=x',
      ]) {
        expect(
          (await api.get(path)).failure?.kind,
          ApiErrorKind.invalidRequest,
        );
      }
      expect(
        (await api.get('user', access: ApiAccess.public)).failure?.kind,
        ApiErrorKind.invalidRequest,
      );
      expect(
        (await api.get('user', query: {'token': 'secret'})).failure?.kind,
        ApiErrorKind.invalidRequest,
      );
      expect(
        () => ApiClient(baseUrl: Uri.parse('http://backend.example')),
        throwsArgumentError,
      );
    },
  );

  test('multipart bearer and client-generated boundary', () async {
    final transport = StreamingClient((request) async {
      final body = await request.finalize().bytesToString();
      expect(request.headers['Authorization'], 'Bearer 1|test-token');
      expect(request.headers['Accept'], 'application/json');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      expect(body, contains('name="foto"'));
      expect(body, contains('Wabah Penyakit'));
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 201);
    });
    final result =
        await ApiClient(
          baseUrl: base,
          session: session,
          clientFactory: () => transport,
        ).multipart(
          'lapor-darurat',
          fields: {'jenis_sos': 'Wabah Penyakit'},
          files: [
            http.MultipartFile.fromString(
              'foto',
              'image',
              filename: 'test.png',
            ),
          ],
        );
    expect(result.isSuccess, isTrue);
    expect(transport.closed, isTrue);
  });

  for (final stallBody in [false, true]) {
    test(
      'timeout covers ${stallBody ? 'body stream' : 'headers'} and closes client',
      () async {
        final stream = StreamController<List<int>>();
        final transport = StreamingClient((_) async {
          if (!stallBody) return Completer<http.StreamedResponse>().future;
          return http.StreamedResponse(stream.stream, 200);
        });
        final result = await ApiClient(
          baseUrl: base,
          session: session,
          clientFactory: () => transport,
          timeout: const Duration(milliseconds: 20),
        ).get('user');
        expect(result.failure?.kind, ApiErrorKind.timeout);
        expect(transport.closed, isTrue);
        unawaited(stream.close());
      },
    );
  }

  test('oversized body rejected and client closed', () async {
    final transport = StreamingClient(
      (_) async => http.StreamedResponse(Stream.value([1, 2, 3]), 200),
    );
    final result = await ApiClient(
      baseUrl: base,
      session: session,
      clientFactory: () => transport,
      maxResponseBytes: 2,
    ).get('user');
    expect(result.failure?.kind, ApiErrorKind.invalidResponse);
    expect(transport.closed, isTrue);
  });

  test('login change during OTP probe cannot log out new session', () async {
    final result = await client((request) async {
      if (request.url.path.endsWith('/user')) {
        await session.saveToken('2|new-token');
      }
      return http.Response('{}', 401);
    }).post('ubah-kontak');
    expect(result.failure?.kind, ApiErrorKind.staleSession);
    expect(await session.readToken(), '2|new-token');
  });

  test('offline OTP probe retains session', () async {
    final result = await client((request) async {
      if (request.url.path.endsWith('/user')) {
        throw http.ClientException('offline');
      }
      return http.Response('{}', 401);
    }).post('ubah-kontak');
    expect(result.failure?.kind, ApiErrorKind.unauthorized);
    expect(await session.readToken(), '1|test-token');
  });

  test('transport exception is redacted', () async {
    final result = await client(
      (_) async => throw http.ClientException('secret token'),
    ).get('user');
    expect(result.failure?.kind, ApiErrorKind.network);
    expect(result.toString(), isNot(contains('secret')));
  });
}
