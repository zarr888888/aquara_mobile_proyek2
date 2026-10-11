import 'dart:async';
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
  late SessionService session;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = SessionService(store: FakeTokenStore());
  });
  tearDown(() => session.dispose());

  test('orphan metadata removed without losing theme/onboarding', () async {
    SharedPreferences.setMockInitialValues({
      'user_id': '9',
      'user_name': 'orphan',
      'foto_profil': 'private',
      'showOnboarding': false,
      'theme': 'dark',
    });
    await session.snapshot();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'showOnboarding', 'theme'});
    expect(prefs.getBool('showOnboarding'), false);
    expect(prefs.getString('theme'), 'dark');
    expect(session.metadata, isEmpty);
  });

  test('delayed profile A cannot commit after logout and login B', () async {
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    final sent = Completer<void>();
    final response = Completer<http.Response>();
    final api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer A');
          sent.complete();
          return response.future;
        }),
      ),
    );
    final pending = api.updateProfile('old A', '', null);
    await sent.future;
    await session.clear();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    response.complete(
      http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 1, 'name': 'old A'},
        }),
        200,
      ),
    );
    expect((await pending).failure?.kind, ApiErrorKind.staleSession);
    expect(session.metadata['user_name'], 'B');
    expect(session.metadata['user_id'], '2');
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test(
    'queued metadata commit is atomic with credential replacement',
    () async {
      await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
      final owner = await session.snapshot();
      final logout = session.clear();
      final login = session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      final stale = session.updateMetadata(owner, {'id': 1, 'name': 'stale'});
      await logout;
      await login;
      expect(await stale, false);
      expect(session.metadata['user_name'], 'B');
    },
  );

  test('normal metadata update keeps revision and 429 remains typed', () async {
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    final owner = await session.snapshot();
    expect(await session.updateMetadata(owner, {'id': 1, 'name': 'new'}), true);
    expect(session.revision, owner.revision);
    var calls = 0;
    final api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((_) async {
          calls++;
          return http.Response('{}', 429, headers: {'retry-after': '17'});
        }),
      ),
    );
    final result = await api.updateProfile('new', '', null);
    expect(result.failure?.kind, ApiErrorKind.rateLimited);
    expect(result.failure?.retryAfter, const Duration(seconds: 17));
    expect(calls, 1);
    expect(session.metadata['user_name'], 'new');
  });
}
