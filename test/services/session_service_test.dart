import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('failed deletion tombstone survives restart', () async {
    final store = FakeTokenStore();
    final first = SessionService(store: store);
    await first.saveToken('1|secret');
    store.failDelete = true;
    await expectLater(first.clear(), throwsStateError);
    await first.dispose();
    final restarted = SessionService(store: store);
    await expectLater(restarted.readToken(), throwsStateError);
    store.failDelete = false;
    expect(await restarted.readToken(), isNull);
    expect(store.value, isNull);
    await restarted.dispose();
  });

  test(
    'delete failure blocks stale credential restore until cleanup succeeds',
    () async {
      final store = FakeTokenStore();
      final session = SessionService(store: store);
      await session.saveToken('1|secret');
      store.failDelete = true;
      await expectLater(session.clear(), throwsStateError);
      await expectLater(session.readToken(), throwsStateError);
      store.failDelete = false;
      expect(await session.readToken(), isNull);
      expect(store.value, isNull);
      await session.dispose();
    },
  );

  test(
    'read failure is not interpreted as guest or plaintext fallback',
    () async {
      final store = FakeTokenStore()..failRead = true;
      final session = SessionService(store: store);
      await expectLater(session.readToken(), throwsStateError);
      await session.dispose();
    },
  );

  test(
    'legacy removed, secure token persists across service restart',
    () async {
      SharedPreferences.setMockInitialValues({
        'token': 'old',
        'user_id': '1',
        'user_name': 'User',
        'foto_profil': 'photo',
        'showOnboarding': false,
      });
      final store = FakeTokenStore();
      final session = SessionService(store: store);
      expect(await session.readToken(), isNull);
      await session.saveToken('1|secret');
      final preferences = await SharedPreferences.getInstance();
      for (final key in ['token', 'user_id', 'user_name', 'foto_profil']) {
        expect(preferences.containsKey(key), isFalse);
      }
      expect(preferences.getBool('showOnboarding'), isFalse);
      expect(await session.readToken(), '1|secret');
      expect((await session.snapshot()).toString(), isNot(contains('secret')));
      await session.dispose();
      final restarted = SessionService(store: store);
      expect(await restarted.readToken(), '1|secret');
      await restarted.clear();
      expect(store.value, isNull);
      await restarted.dispose();
    },
  );

  test(
    'reject blank, whitespace and header injection without losing session',
    () async {
      final session = SessionService(
        clearLegacySession: () async {},
        store: FakeTokenStore(),
      );
      await session.saveToken('1|valid');
      for (final token in ['', ' ', ' secret', 'a\r\nX-Test: x']) {
        await expectLater(session.saveToken(token), throwsArgumentError);
      }
      expect(await session.readToken(), '1|valid');
      await session.dispose();
    },
  );

  test('concurrent invalidations clear and notify only once', () async {
    final session = SessionService(
      clearLegacySession: () async {},
      store: FakeTokenStore(),
    );
    await session.saveToken('1|valid');
    final before = await session.snapshot();
    final events = <int>[];
    final subscription = session.changes.listen(events.add);
    expect(
      await Future.wait([
        session.invalidate(before),
        session.invalidate(before),
      ]),
      [true, false],
    );
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
    expect(await session.readToken(), isNull);
    await subscription.cancel();
    await session.dispose();
  });

  test('old snapshot cannot invalidate re-saved identical token', () async {
    final session = SessionService(
      clearLegacySession: () async {},
      store: FakeTokenStore(),
    );
    await session.saveToken('1|same');
    final before = await session.snapshot();
    await session.saveToken('1|same');
    expect(await session.invalidate(before), isFalse);
    expect(await session.readToken(), '1|same');
    await session.dispose();
  });

  test('cleanup failure fails closed and queue can recover', () async {
    var fail = false;
    final session = SessionService(
      store: FakeTokenStore(),
      clearLegacySession: () async {
        if (fail) throw StateError('disk unavailable');
      },
    );
    await session.saveToken('1|secret');
    fail = true;
    await expectLater(session.clear(), throwsStateError);
    await expectLater(session.readToken(), throwsStateError);
    fail = false;
    expect(await session.readToken(), isNull);
    await session.saveToken('2|new');
    expect(await session.readToken(), '2|new');
    await session.dispose();
  });
}
