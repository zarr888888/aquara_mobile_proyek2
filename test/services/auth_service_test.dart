import 'dart:convert';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeTokenStore store;
  late SessionService session;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeTokenStore();
    session = SessionService(store: store);
  });
  tearDown(() => session.dispose());
  ApiService api(Future<http.Response> Function(http.Request) handler) =>
      ApiService(
        session: session,
        googleIdToken: () async => 'google-id-token',
        client: ApiClient(
          baseUrl: Uri.parse('https://test.example/api'),
          session: session,
          clientFactory: () => MockClient(handler),
        ),
      );
  http.Response login() => http.Response(
    jsonEncode({
      'success': true,
      'token': '1|sanctum',
      'data': {'id': 1, 'name': 'Budi'},
    }),
    200,
  );

  test(
    'password login uses JSON and securely stores token, not in UI result/prefs',
    () async {
      final service = api((r) async {
        expect(jsonDecode(r.body), {
          'login_id': 'budi@test.id',
          'password': 'secret',
        });
        expect(r.headers.containsKey('Authorization'), isFalse);
        return login();
      });
      final result = await service.loginUser('budi@test.id', 'secret');
      expect(result.isSuccess, isTrue);
      expect(store.value, '1|sanctum');
      expect((result.data as Map).containsKey('token'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('token'), isNull);
      expect(prefs.getString('user_id'), isNull);
      expect(service.session.metadata['user_id'], '1');
    },
  );
  test(
    'registration never saves token and omits optional blank email',
    () async {
      final result = await api((r) async {
        expect(r.url.path, '/api/register');
        expect(jsonDecode(r.body), {
          'name': 'Budi',
          'phone': '081234567890',
          'password': 'secret',
        });
        return http.Response('{"success":true,"data":{"id":1}}', 201);
      }).registerUser('Budi', '', '081234567890', 'secret');
      expect(result.isSuccess, isTrue);
      expect(store.value, isNull);
    },
  );
  test('Google sends id_token only', () async {
    final result = await api((r) async {
      expect(jsonDecode(r.body), {'id_token': 'google-id-token'});
      return login();
    }).loginWithGoogle();
    expect(result.isSuccess, isTrue);
  });
  test(
    'OTP request preserves channel independently of login identifier',
    () async {
      await api((r) async {
        expect(jsonDecode(r.body), {
          'login_id': 'budi@test.id',
          'method': 'wa',
        });
        return http.Response('{}', 200);
      }).requestRegistrationOtp('budi@test.id', 'wa');
    },
  );
  test(
    'OTP remains string with leading zero; invalid code never sent',
    () async {
      var calls = 0;
      final service = api((r) async {
        calls++;
        expect(jsonDecode(r.body), {'phone': '081234567890', 'otp': '012345'});
        return login();
      });
      expect(
        (await service.verifyOtpWa('081234567890', '12345')).isSuccess,
        isFalse,
      );
      expect(calls, 0);
      expect(
        (await service.verifyOtpWa('081234567890', '012345')).isSuccess,
        isTrue,
      );
    },
  );
  test('contact exact payload and token revocation', () async {
    await session.saveToken('1|old');
    final result = await api((r) async {
      expect(r.headers['Authorization'], 'Bearer 1|old');
      expect(jsonDecode(r.body), {
        'method': 'email',
        'target_contact': 'new@test.id',
        'otp': '012345',
      });
      return http.Response('{}', 200);
    }).ubahKontak('email', 'new@test.id', '012345');
    expect(result.isSuccess, isTrue);
    expect(store.value, isNull);
  });
  test(
    'reset validates 12-128 characters, correct keys, clears token',
    () async {
      await session.saveToken('1|old');
      var calls = 0;
      final service = api((r) async {
        calls++;
        expect(jsonDecode(r.body), {
          'login_id': '081234567890',
          'otp': '012345',
          'new_password': '123456789012',
        });
        return http.Response('{}', 200);
      });
      expect(
        (await service.resetPasswordWithOtp(
          '081234567890',
          '012345',
          'short',
        )).isSuccess,
        isFalse,
      );
      expect(calls, 0);
      expect(
        (await service.resetPasswordWithOtp(
          '081234567890',
          '012345',
          '123456789012',
        )).isSuccess,
        isTrue,
      );
      expect(store.value, isNull);
    },
  );
  test(
    'password change retains token and account deletion clears it',
    () async {
      await session.saveToken('1|old');
      final service = api((r) async => http.Response('{}', 200));
      await service.changePassword('old', 'new-password');
      expect(store.value, '1|old');
      await service.hapusAkun('012345');
      expect(store.value, isNull);
    },
  );
  test('offline logout still deletes persisted token', () async {
    await session.saveToken('1|old');
    final result = await api(
      (r) async => throw http.ClientException('offline'),
    ).logout();
    expect(result.isSuccess, isFalse);
    expect(store.value, isNull);
  });
  test('storage write failure fails login closed', () async {
    store.failWrite = true;
    final result = await api((r) async => login()).loginUser('test', 'secret');
    expect(result.failure?.kind, ApiErrorKind.session);
    expect(await session.readToken(), isNull);
  });
  test('malformed success cannot authenticate', () async {
    final result = await api(
      (r) async => http.Response('{"token":"x"}', 200),
    ).loginUser('test', 'secret');
    expect(result.failure?.kind, ApiErrorKind.invalidResponse);
    expect(store.value, isNull);
  });
  test('late login cannot undo logout', () async {
    final result = await api((r) async {
      await session.clear();
      return login();
    }).loginUser('test', 'secret');
    expect(result.failure?.kind, ApiErrorKind.staleSession);
    expect(store.value, isNull);
  });
}
