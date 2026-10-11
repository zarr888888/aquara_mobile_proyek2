import 'dart:async';
import 'dart:convert';
import 'package:aquara_mobile/screens/notifikasi_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/pasar_screen.dart';
import 'package:aquara_mobile/screens/forum_screen.dart';
import 'package:aquara_mobile/screens/consultation_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

Map<String, Object?> item({
  Object? read = false,
  String type = 'unknown',
  int id = 1,
}) => {
  'id': id,
  'title': 'Notice $id',
  'message': 'Plain message',
  'type': type,
  'is_read': read,
  'reference_id': null,
  'user_id': null,
  'created_at': '2026-09-29T08:00:00Z',
};
http.Response listing(List<Object?> items) =>
    http.Response(jsonEncode({'success': true, 'data': items}), 200);

class DestinationFakeApi extends ApiService {
  DestinationFakeApi({required super.session, required super.client});
  @override
  Future<ApiResult<List<dynamic>>> fetchPasar({
    required SessionSnapshot expectedSession,
  }) async => const ApiResult.success(data: [], statusCode: 200);
  @override
  Future<ApiResult<List<dynamic>>> fetchForumPosts({
    required SessionSnapshot expectedSession,
    bool mine = false,
  }) async => const ApiResult.success(data: [], statusCode: 200);
}

void main() {
  late SessionService session;
  late ApiService api;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    handler = (_) async => listing([]);
  });
  Future<void> loginA() async {
    session = SessionService(store: FakeTokenStore());
    api = DestinationFakeApi(
      session: session,
      client: ApiClient(
        session: session,
        baseUrl: Uri.parse('https://example.test/api'),
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
  }

  Future<void> mount(WidgetTester tester) async {
    await loginA();
    await tester.pumpWidget(MaterialApp(home: NotifikasiScreen(api: api)));
    await tester.pumpAndSettle();
  }

  Color? cardColor(WidgetTester tester) =>
      (tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byKey(const ValueKey('notification-1')),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration)
          .color;

  test(
    'endpoint contract, explicit bool/number normalization and backend order',
    () async {
      handler = (r) async => r.method == 'POST'
          ? http.Response('{"success":true}', 200)
          : listing([
              item(read: true, id: 4),
              item(read: false, id: 3),
              item(read: 1, id: 2),
              item(read: 0),
            ]);
      await loginA();
      final owner = await session.snapshot();
      final result = await api.fetchNotifications(expectedSession: owner);
      expect(result.data!.map((n) => n.id), [4, 3, 2, 1]);
      expect(result.data!.map((n) => n.isRead), [true, false, true, false]);
      expect(result.data!.first.referenceId, isNull);
      expect(
        (await api.markNotificationRead(1, expectedSession: owner)).isSuccess,
        true,
      );
      expect(requests.map((r) => r.method), ['GET', 'POST']);
      expect(requests.map((r) => r.url.path), [
        '/api/notifications',
        '/api/notifications/1/read',
      ]);
      for (final r in requests) {
        expect(r.url.origin, 'https://example.test');
        expect(r.url.hasQuery, false);
        expect(r.body, isEmpty);
        expect(r.headers['Authorization'], 'Bearer A');
        expect(r.headers['Accept'], 'application/json');
        expect(r.followRedirects, false);
      }
    },
  );

  test(
    'empty differs from malformed envelope, item, read value and mark response',
    () async {
      await loginA();
      final owner = await session.snapshot();
      expect(
        (await api.fetchNotifications(expectedSession: owner)).data,
        isEmpty,
      );
      for (final response in [
        http.Response('{}', 200),
        http.Response('broken', 200),
        listing([null]),
        listing([item(read: '1')]),
        listing([item(read: 2)]),
      ]) {
        handler = (_) async => response;
        final result = await api.fetchNotifications(expectedSession: owner);
        expect(result.failure!.kind, ApiErrorKind.invalidResponse);
        expect(result.data, isNull);
      }
      handler = (_) async => http.Response('{"success":false}', 200);
      expect(
        (await api.markNotificationRead(
          1,
          expectedSession: owner,
        )).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
    },
  );

  for (final status in [401, 403, 404, 429]) {
    test('typed $status for both endpoints; only 401 clears session', () async {
      for (final mark in [false, true]) {
        await loginA();
        final owner = await session.snapshot();
        handler = (_) async => http.Response(
          '{"message":"private raw error"}',
          status,
          headers: {'retry-after': '3'},
        );
        final result = mark
            ? await api.markNotificationRead(1, expectedSession: owner)
            : await api.fetchNotifications(expectedSession: owner);
        expect(result.isSuccess, false);
        expect(result.statusCode, status);
        expect(result.failure!.message, isNot(contains('private raw error')));
        expect(session.hasSession, status != 401);
        if (status == 429) {
          expect(result.failure!.retryAfter, const Duration(seconds: 3));
        }
      }
    });
  }

  for (final mark in [false, true]) {
    test(
      'stale ${mark ? "mark" : "list"} never sends B token or clears B',
      () async {
        await loginA();
        final owner = await session.snapshot();
        final pending = Completer<http.Response>();
        final sent = Completer<void>();
        handler = (_) {
          sent.complete();
          return pending.future;
        };
        final operation = mark
            ? api.markNotificationRead(1, expectedSession: owner)
            : api.fetchNotifications(expectedSession: owner);
        await sent.future;
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        pending.complete(http.Response('{}', 401));
        expect((await operation).failure!.kind, ApiErrorKind.staleSession);
        expect(session.metadata['user_name'], 'B');
        expect(await session.readToken(), 'B');
        final rejected = mark
            ? await api.markNotificationRead(1, expectedSession: owner)
            : await api.fetchNotifications(expectedSession: owner);
        expect(rejected.failure!.kind, ApiErrorKind.staleSession);
        expect(requests.length, 1);
        expect(requests.single.headers['Authorization'], 'Bearer A');
      },
    );
  }

  testWidgets('personal read succeeds and refresh reflects backend state', (
    tester,
  ) async {
    var read = false;
    handler = (r) async {
      if (r.method == 'POST') {
        read = true;
        return http.Response('{"success":true}', 200);
      }
      return listing([
        {...item(read: read), 'user_id': 1},
      ]);
    };
    await mount(tester);
    await tester.tap(find.text('Notice 1'));
    await tester.pumpAndSettle();
    expect(read, true);
    expect(cardColor(tester), Colors.white);
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pumpAndSettle();
    expect(cardColor(tester), Colors.white);
    await tester.pumpWidget(const SizedBox());
  });

  for (final status in [403, 404]) {
    testWidgets('$status retains unread and active screen', (tester) async {
      handler = (r) async =>
          r.method == 'GET' ? listing([item()]) : http.Response('{}', status);
      await mount(tester);
      final unread = cardColor(tester);
      await tester.tap(find.text('Notice 1'));
      await tester.pumpAndSettle();
      expect(cardColor(tester), unread);
      expect(
        find.text('Akses atau data notifikasi tidak tersedia.'),
        findsOneWidget,
      );
      expect(session.hasSession, true);
      expect(find.byType(LoginScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final type in ['pasar', 'forum', 'ai']) {
    testWidgets(
      'allowlisted $type null reference opens existing guarded destination',
      (tester) async {
        handler = (r) async => r.method == 'GET'
            ? listing([item(type: type)])
            : http.Response('{"success":true}', 200);
        await mount(tester);
        await tester.tap(find.text('Notice 1'));
        await tester.pumpAndSettle();
        expect(
          find.byType(switch (type) {
            'pasar' => PasarScreen,
            'forum' => ForumScreen,
            _ => ConsultationScreen,
          }),
          findsOneWidget,
        );
        expect(requests.where((r) => r.method == 'POST').length, 1);
        await session.clear();
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Notice 1', skipOffstage: false), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('320px large text empty/error/list dark=$dark', (tester) async {
      await loginA();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: NotifikasiScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada notifikasi.'), findsOneWidget);
      handler = (_) async => http.Response('invalid', 200);
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada notifikasi.'), findsNothing);
      expect(find.textContaining('Format'), findsOneWidget);
      handler = (_) async => listing([
        {...item(), 'reference_id': 'https://evil.test', 'created_at': 'bad'},
      ]);
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('Tanggal tidak tersedia'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'global local read only after success; repeated taps deduplicated; refresh authoritative',
    (tester) async {
      final pending = Completer<http.Response>();
      handler = (r) async =>
          r.method == 'GET' ? listing([item()]) : pending.future;
      await mount(tester);
      final unread = cardColor(tester);
      await tester.tap(find.text('Notice 1'));
      await tester.tap(find.text('Notice 1'));
      await tester.pump();
      expect(requests.where((r) => r.method == 'POST').length, 1);
      expect(cardColor(tester), unread);
      pending.complete(http.Response('{"success":true}', 200));
      await tester.pumpAndSettle();
      expect(cardColor(tester), Colors.white);
      expect(find.text('Tujuan notifikasi belum tersedia.'), findsOneWidget);
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(cardColor(tester), unread);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final header in [true, false]) {
    for (final mark in [true, false]) {
      testWidgets(
        '429 header=$header mark=$mark blocks refresh and taps, no auto retry',
        (tester) async {
          var limited = !mark;
          handler = (r) async {
            if (r.method == 'POST') limited = true;
            if (limited) {
              return http.Response(
                '{}',
                429,
                headers: header ? {'retry-after': '3'} : {},
              );
            }
            return listing([item()]);
          };
          await mount(tester);
          Color? unread;
          if (mark) {
            unread = cardColor(tester);
            await tester.tap(find.text('Notice 1'));
            await tester.pumpAndSettle();
            expect(cardColor(tester), unread);
            await tester.tap(find.text('Notice 1'));
          }
          expect(
            find.textContaining(
              header ? 'Tunggu 3 detik' : 'Jeda lokal 60 detik',
            ),
            findsOneWidget,
          );
          final count = requests.length;
          expect(
            tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
            isNull,
          );
          await tester.pump(Duration(seconds: header ? 3 : 60));
          await tester.pump();
          expect(requests.length, count);
          expect(
            tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
            isNotNull,
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('401 leaves via boundary, removes private data and back stack', (
    tester,
  ) async {
    handler = (r) async =>
        r.method == 'GET' ? listing([item()]) : http.Response('{}', 401);
    await mount(tester);
    await tester.tap(find.text('Notice 1'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Notice 1', skipOffstage: false), findsNothing);
    expect(session.metadata, isEmpty);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      false,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final mark in [false, true]) {
    testWidgets('late $mark response cannot alter B list or navigate', (
      tester,
    ) async {
      await loginA();
      final pending = Completer<http.Response>();
      handler = (r) async => mark && r.method == 'GET'
          ? listing([item(type: 'pasar')])
          : pending.future;
      await tester.pumpWidget(MaterialApp(home: NotifikasiScreen(api: api)));
      await tester.pump();
      await tester.pump();
      if (mark) {
        await tester.pumpAndSettle();
        await tester.tap(find.text('Notice 1'));
        await tester.pump();
      } else {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      }
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      await tester.pumpAndSettle();
      handler = (_) async => listing([item(id: 2)]);
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: NotifikasiScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      pending.complete(
        mark ? http.Response('{"success":true}', 200) : listing([item()]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notice 2'), findsOneWidget);
      expect(find.text('Notice 1', skipOffstage: false), findsNothing);
      expect(find.byType(NotifikasiScreen), findsOneWidget);
      expect(session.metadata['user_name'], 'B');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
