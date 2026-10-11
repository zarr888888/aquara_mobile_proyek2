import 'dart:async';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/notifikasi_screen.dart';
import 'package:aquara_mobile/screens/pasar_screen.dart';
import 'package:aquara_mobile/screens/forum_screen.dart';
import 'package:aquara_mobile/screens/otp_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/session_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;
}

void main() {
  late SessionService session;
  late ApiService api;
  void initialize() {
    SharedPreferences.setMockInitialValues({});
    session = SessionService(store: FakeTokenStore());
    api = ApiService(session: session);
  }

  testWidgets('parallel private 401 clears data and Back cannot restore A', (
    tester,
  ) async {
    initialize();
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    final response = Completer<http.Response>();
    var calls = 0;
    final sent = Completer<void>();
    final client = ApiClient(
      baseUrl: Uri.parse('https://example.test/api'),
      session: session,
      clientFactory: () => MockClient((_) {
        if (++calls == 2) sent.complete();
        return response.future;
      }),
    );
    final key = GlobalKey<NavigatorState>();
    final observer = _Observer();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [observer],
        home: SessionBoundary(
          api: api,
          builder: (_) => const Scaffold(body: Text('private A')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('private A'), findsOneWidget);
    final first = client.get('user');
    final second = client.get('notifications');
    await tester.pump();
    expect(sent.isCompleted, true);
    response.complete(http.Response('{}', 401));
    await tester.pump();
    await Future.wait([first, second]);
    await tester.pumpAndSettle();
    expect(session.metadata, isEmpty);
    expect(find.text('private A', skipOffstage: false), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(observer.pushes, 2);
    expect(await key.currentState!.maybePop(), false);
    expect(find.text('private A', skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
  });

  testWidgets(
    'direct private route denied before child creation; public guest allowed',
    (tester) async {
      initialize();
      final key = GlobalKey<NavigatorState>();
      var privateBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: SessionBoundary(
            api: api,
            private: false,
            builder: (_) => const Scaffold(body: Text('public guest')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('public guest'), findsOneWidget);
      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => SessionBoundary(
            api: api,
            builder: (_) {
              privateBuilds++;
              return const Text('notification target');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(privateBuilds, 0);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await key.currentState!.maybePop(), false);
      await tester.pumpWidget(const SizedBox());
      await session.dispose();
    },
  );

  testWidgets(
    'profile refresh retains screen; account replacement removes old subtree',
    (tester) async {
      initialize();
      await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
      final owner = await session.snapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: SessionBoundary(
            api: api,
            builder: (_) =>
                Scaffold(body: Text(session.metadata['user_name']!)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await session.updateMetadata(owner, {'id': 1, 'name': 'updated A'});
      await tester.pumpAndSettle();
      expect(find.text('updated A'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      await tester.pumpAndSettle();
      expect(find.text('updated A', skipOffstage: false), findsNothing);
      expect(session.metadata['user_name'], 'B');
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await session.dispose();
    },
  );

  testWidgets('actual notification and private destinations reject guest', (
    tester,
  ) async {
    initialize();
    var requests = 0;
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((_) async {
          requests++;
          return http.Response('{}', 500);
        }),
      ),
    );
    for (final screen in <Widget>[
      NotifikasiScreen(api: api),
      PasarScreen(api: api),
      ForumScreen(api: api),
      OtpScreen(
        identifier: '',
        purpose: OtpPurpose.delete,
        method: 'wa',
        api: api,
      ),
    ]) {
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: screen));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
  });

  testWidgets('private OTP business 401 retains session and screen', (
    tester,
  ) async {
    initialize();
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    var probes = 0;
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((request) async {
          if (request.url.path.endsWith('/send-otp')) {
            return http.Response('{}', 200);
          }
          if (request.url.path.endsWith('/user')) {
            probes++;
            return http.Response('{"id":1,"name":"A"}', 200);
          }
          return http.Response('{"message":"OTP salah"}', 401);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OtpScreen(
          identifier: '081234567890',
          purpose: OtpPurpose.contact,
          method: 'wa',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '012345');
    await tester.tap(find.widgetWithText(FilledButton, 'Verifikasi'));
    await tester.pumpAndSettle();
    expect(probes, 1);
    expect(session.hasSession, true);
    expect(session.metadata['user_name'], 'A');
    expect(
      find.text('Kode OTP salah, kedaluwarsa, atau sudah digunakan.'),
      findsOneWidget,
    );
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
  });

  testWidgets('late profile response A cannot replace visible metadata B', (
    tester,
  ) async {
    initialize();
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    final response = Completer<http.Response>();
    var sent = false;
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((_) {
          sent = true;
          return response.future;
        }),
      ),
    );
    final update = api.updateProfile('late A', '', null);
    await tester.pump();
    expect(sent, true);
    await session.clear();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpWidget(
      MaterialApp(
        home: SessionBoundary(
          api: api,
          builder: (_) => Scaffold(body: Text(session.metadata['user_name']!)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    response.complete(
      http.Response('{"success":true,"data":{"id":1,"name":"late A"}}', 200),
    );
    await tester.pump();
    expect((await update).isSuccess, false);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('late A', skipOffstage: false), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
  });
}
