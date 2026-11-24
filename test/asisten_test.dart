import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aquara_mobile/models/asisten_chat.dart';
import 'package:aquara_mobile/screens/asisten_samudera_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

Map<String, Object?> chat({int id = 1, bool post = false}) => {
  'id': id,
  if (post) 'is_mock': true,
  if (!post) 'user_id': 1,
  post ? 'message' : 'pertanyaan': 'Pesan bersih $id',
  post ? 'reply' : 'jawaban': '<b>Simulasi</b> &amp; https://example.test/$id',
  'created_at': '2026-10-26T08:00:00.000000Z',
};
Map<String, Object?> history(
  List<Object?> items, {
  int current = 1,
  int total = 1,
}) => {
  'data': items,
  'current_page': current,
  'last_page': total == 0 ? 1 : (total + 19) ~/ 20,
  'per_page': 20,
  'total': total,
  'from': items.isEmpty ? null : (current - 1) * 20 + 1,
  'to': items.isEmpty ? null : (current - 1) * 20 + items.length,
  'next_page_url': 'https://evil.test/steal',
};
http.Response envelope(Object? data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

class ClockApi extends ApiService {
  ClockApi({required super.session, required super.client, required this.now});
  final DateTime Function() now;
  @override
  DateTime asistenNow() => now();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  late ClockApi api;
  late SessionSnapshot owner;
  late DateTime now;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  Future<void> initialize({
    Duration timeout = const Duration(milliseconds: 100),
  }) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    now = DateTime.utc(2026, 10, 26);
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    owner = await session.snapshot();
    handler = (r) async => envelope(
      r.method == 'POST'
          ? chat(post: true)
          : r.url.path.endsWith('/1')
          ? chat()
          : history([chat()]),
      r.method == 'POST' ? 201 : 200,
    );
    api = ClockApi(
      session: session,
      now: () => now,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        timeout: timeout,
        clock: () => now,
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  setUp(initialize);
  Future<ApiResult<AsistenChat>> send([
    String message = 'raw <b>message</b>',
  ]) => api.sendAsisten(message, expectedSession: owner);
  void widgetTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await initialize(timeout: const Duration(seconds: 30));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        final disposed = session.dispose();
        await tester.pump();
        await disposed;
      });
      await body(tester);
    });
  }

  Future<void> mount(
    WidgetTester tester, {
    int? id,
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AsistenSamuderaScreen(api: api, id: id),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pump();
  }

  test(
    'POST payload/path/auth and distinct GET schemas, clean server text',
    () async {
      expect((await send()).data!.question, 'Pesan bersih 1');
      expect(jsonDecode(requests.single.body), {
        'message': 'raw <b>message</b>',
      });
      expect(
        requests.single.url.toString(),
        'https://example.test/api/asisten/chat',
      );
      expect(requests.single.headers['Authorization'], 'Bearer A');
      expect(requests.single.headers['Accept'], 'application/json');
      expect(
        (await api.asistenHistory(
          expectedSession: owner,
        )).data!.items.single.id,
        1,
      );
      expect(
        (await api.asistenDetail(1, expectedSession: owner)).data!.answer,
        chat()['jawaban'],
      );
      expect(requests[1].url.queryParameters, {'page': '1'});
      expect(requests[1].body, isEmpty);
      expect(requests[2].url.path, '/api/asisten/chat/1');
      expect(requests[2].url.query, isEmpty);
      expect(requests.every((r) => r.url.host == 'example.test'), isTrue);
    },
  );
  for (final value in [
    '',
    ' \n\t ',
    'a' * 2001,
    '🐟' * 2001,
    'e\u0301' * 1001,
  ]) {
    test(
      'reject invalid input ${value.runes.length} codepoints ${value.length} units',
      () async {
        expect((await send(value)).failure!.kind, ApiErrorKind.validation);
        expect(requests, isEmpty);
      },
    );
  }
  for (final value in ['a' * 2000, '🐟' * 2000, 'e\u0301' * 1000]) {
    test('allow 2000 codepoints ${value.length} units', () async {
      expect((await send(value)).isSuccess, isTrue);
      expect(jsonDecode(requests.single.body)['message'], value);
    });
  }
  for (final status in [200, 202, 204, 500, 503]) {
    test('POST rejects status $status, never retries', () async {
      handler = (_) async => envelope(chat(post: true), status);
      expect((await send()).isSuccess, isFalse);
      expect(requests.length, 1);
    });
  }
  final malformed = <Object?>[
    null,
    [],
    {},
    chat(),
    {...chat(post: true), 'id': 0},
    {...chat(post: true), 'id': '1'},
    {...chat(post: true), 'is_mock': null},
    {...chat(post: true), 'is_mock': 'true'},
    {...chat(post: true), 'message': ''},
    {...chat(post: true), 'reply': ' '},
    {...chat(post: true), 'created_at': null},
    {...chat(post: true), 'created_at': 'yesterday'},
    {...chat(post: true), 'created_at': '2026-02-30T08:00:00Z'},
  ];
  for (var i = 0; i < malformed.length; i++) {
    test('POST malformed $i', () async {
      handler = (_) async => envelope(malformed[i], 201);
      expect((await send()).failure!.kind, ApiErrorKind.invalidResponse);
    });
  }
  test(
    'GET empty valid, empty intermediate page retains hasNext; malformed distinct',
    () async {
      handler = (_) async => envelope(history([], total: 0));
      expect(
        (await api.asistenHistory(expectedSession: owner)).data!.items,
        isEmpty,
      );
      handler = (_) async => envelope(history([], total: 41));
      expect(
        (await api.asistenHistory(expectedSession: owner)).data!.hasNext,
        isTrue,
      );
      for (final data in [
        null,
        {},
        {'data': []},
        history([chat(post: true)]),
        {...history([]), 'per_page': 10},
        {...history([]), 'last_page': 8},
      ]) {
        handler = (_) async => envelope(data);
        expect(
          (await api.asistenHistory(expectedSession: owner)).failure!.kind,
          ApiErrorKind.invalidResponse,
        );
      }
    },
  );
  test('positive page/id only, detail mismatched id rejected', () async {
    expect(
      (await api.asistenHistory(expectedSession: owner, page: 0)).isSuccess,
      isFalse,
    );
    expect(
      (await api.asistenDetail(-1, expectedSession: owner)).isSuccess,
      isFalse,
    );
    expect(requests, isEmpty);
    handler = (_) async => envelope(chat(id: 2));
    expect(
      (await api.asistenDetail(1, expectedSession: owner)).failure!.kind,
      ApiErrorKind.invalidResponse,
    );
  });
  test('merge deduplicates POST and GET and sorts timestamp then id', () {
    final posted = AsistenChat.parse(chat(id: 3, post: true), post: true);
    final items = AsistenChat.merge(
      [posted],
      [
        AsistenChat.parse(chat(id: 3)),
        AsistenChat.parse(chat(id: 1)),
        AsistenChat.parse({
          ...chat(id: 8),
          'created_at': '2026-10-25T00:00:00Z',
        }),
      ],
    );
    expect(items.map((e) => e.id), [8, 1, 3]);
  });
  for (final status in [403, 404, 422]) {
    test(
      'safe $status retains session and only known validation field',
      () async {
        handler = (_) async => http.Response(
          jsonEncode({
            'message': 'SECRET',
            'errors': {
              'message': ['SECRET'],
              'user_id': ['SECRET'],
            },
          }),
          status,
        );
        final result = await send();
        expect(result.statusCode, status);
        expect(result.failure!.message, isNot(contains('SECRET')));
        expect(
          result.failure!.fieldErrors.keys,
          status == 422 ? ['message'] : isEmpty,
        );
        expect(session.owns(owner), isTrue);
      },
    );
  }
  test('401 invalidates centrally', () async {
    handler = (_) async => http.Response('{}', 401);
    expect((await send()).isSuccess, isFalse);
    expect(session.hasSession, isFalse);
  });
  for (final header in ['12', 'date', 'bad', '-1', '']) {
    test(
      'shared cooldown Retry-After $header across operations and facade reopen',
      () async {
        handler = (_) async => http.Response(
          'not-json',
          429,
          headers: {
            if (header.isNotEmpty)
              'retry-after': header == 'date'
                  ? HttpDate.format(now.add(const Duration(seconds: 12)))
                  : header,
          },
        );
        await send();
        expect(
          api.asistenGate.seconds(now),
          ['12', 'date'].contains(header) ? 12 : 60,
        );
        expect(api.asistenGate.localFallback, !['12', 'date'].contains(header));
        await api.asistenHistory(expectedSession: owner);
        await api.asistenDetail(1, expectedSession: owner);
        final reopened = ApiService(session: session);
        expect(identical(reopened.asistenGate, api.asistenGate), isTrue);
        expect(requests.length, 1);
        now = now.add(const Duration(seconds: 61));
        expect(api.asistenGate.seconds(now), 0);
        expect(requests.length, 1);
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        expect(api.asistenGate.until, isNull);
      },
    );
  }
  for (final type in ['timeout', 'network', 'non-json']) {
    test('POST $type typed failure no retry', () async {
      handler = (_) async {
        if (type == 'timeout') return Completer<http.Response>().future;
        if (type == 'network') throw const SocketException('private');
        return http.Response('<html>private</html>', 201);
      };
      final result = await send();
      expect(result.failure!.kind, switch (type) {
        'timeout' => ApiErrorKind.timeout,
        'network' => ApiErrorKind.network,
        _ => ApiErrorKind.invalidResponse,
      });
      expect(requests.length, 1);
    });
  }
  for (final status in [201, 401, 429]) {
    test('late account A $status never changes B or cooldown', () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      handler = (_) {
        started.complete();
        return pending.future;
      };
      final future = send();
      await started.future;
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      pending.complete(envelope(chat(post: true), status));
      expect((await future).failure!.kind, ApiErrorKind.staleSession);
      expect(await session.readToken(), 'B');
      expect(api.asistenGate.until, isNull);
    });
  }
  test('service rejects simultaneous send', () async {
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    final first = send();
    expect((await send()).isSuccess, isFalse);
    pending.complete(envelope({...chat(post: true), 'is_mock': false}, 201));
    expect((await first).isSuccess, isTrue);
    expect(requests.length, 1);
  });

  widgetTest('double submit, server text, plain text and detail endpoint', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byKey(const Key('asisten-draft')), 'raw draft');
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tap(tester, 'asisten-send');
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('asisten-send')),
    );
    expect(button.onPressed, isNull);
    expect(requests.where((r) => r.method == 'POST').length, 1);
    pending.complete(envelope({...chat(post: true), 'is_mock': false}, 201));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asisten-1')), findsOneWidget);
    expect(find.text('Gombyang • AI'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('asisten-draft')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text(chat()['jawaban'] as String), findsOneWidget);
    handler = (_) async =>
        envelope({...chat(), 'jawaban': 'Detail dari endpoint'});
    await tester.ensureVisible(find.text('Buka detail'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Buka detail')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    expect(find.text('Buka detail').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Buka detail'));
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/asisten/chat/1');
    expect(find.text('Detail dari endpoint'), findsOneWidget);
    expect(find.text('Gombyang • Simulasi'), findsOneWidget);
    expect(find.text(asistenSimulationLabel), findsOneWidget);
  });

  widgetTest(
    'chat bubbles use actual text/time; menu is manual and preserves draft',
    (tester) async {
      await mount(tester);
      final question = find.byKey(const Key('asisten-question-1'));
      final answer = find.byKey(const Key('asisten-answer-1'));
      expect(
        tester.getRect(question).right,
        greaterThan(tester.getRect(answer).left),
      );
      expect(tester.getSize(question).width, lessThan(800));
      expect(
        find.text(
          DateTime.parse(chat()['created_at'] as String).toLocal().toString(),
        ),
        findsNWidgets(2),
      );
      expect(find.text('Balasan otomatis'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('asisten-draft')),
        'draft tetap',
      );
      final count = requests.length;
      await tester.tap(find.byKey(const Key('asisten-menu')));
      await tester.pumpAndSettle();
      expect(requests.length, count);
      await tester.tap(find.text('Periksa / muat ulang riwayat').last);
      await tester.pumpAndSettle();
      expect(requests.length, count + 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('asisten-draft')))
            .controller!
            .text,
        'draft tetap',
      );
    },
  );
  for (final status in [500, 503, 201, 422]) {
    widgetTest('draft retained failure $status uncertainty honest', (
      tester,
    ) async {
      await mount(tester);
      await tester.enterText(
        find.byKey(const Key('asisten-draft')),
        'keep draft',
      );
      handler = (_) async => http.Response('bad', status);
      await tap(tester, 'asisten-send');
      await tester.pumpAndSettle();
      if (status == 503) {
        expect(find.text('Asisten belum tersedia'), findsOneWidget);
      }
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('asisten-draft')))
            .controller!
            .text,
        'keep draft',
      );
      expect(
        find.byKey(const Key('asisten-uncertain')),
        status == 422 ? findsNothing : findsOneWidget,
      );
      expect(find.text(asistenSimulationLabel), findsOneWidget);
      expect(requests.length, 2);
    });
  }
  widgetTest(
    'next page failure preserves items, refresh discards stale next response',
    (tester) async {
      handler = (_) async => envelope(history([chat(id: 21)], total: 21));
      await mount(tester);
      handler = (_) async => http.Response('{}', 500);
      await tap(tester, 'asisten-more');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asisten-21')), findsOneWidget);
      final pending = Completer<http.Response>();
      handler = (r) => r.url.queryParameters['page'] == '2'
          ? pending.future
          : Future.value(envelope(history([chat(id: 22)])));
      await tap(tester, 'asisten-more');
      // Do not pumpAndSettle while a progress indicator is active.
      await tester.ensureVisible(find.byKey(const Key('asisten-refresh')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('asisten-refresh')));
      await tester.pumpAndSettle();
      pending.complete(envelope(history([chat(id: 1)], current: 2, total: 21)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asisten-22')), findsOneWidget);
      expect(find.byKey(const Key('asisten-1')), findsNothing);
      expect(find.byKey(const Key('asisten-21')), findsNothing);
    },
  );
  widgetTest(
    'manual pagination merges posted ID; empty intermediate page permits next page',
    (tester) async {
      handler = (_) async => envelope(history([chat(id: 21)], total: 41));
      await mount(tester);
      await tester.enterText(find.byKey(const Key('asisten-draft')), 'new');
      handler = (_) async => envelope(chat(id: 22, post: true), 201);
      await tap(tester, 'asisten-send');
      await tester.pumpAndSettle();
      expect(requests.length, 2); // No GET after POST.
      handler = (_) async =>
          envelope(history([chat(id: 22), chat(id: 1)], current: 2, total: 41));
      await tap(tester, 'asisten-more');
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {'page': '2'});
      expect(find.byKey(const Key('asisten-22')), findsOneWidget);
      handler = (_) async => envelope(history([], total: 41));
      await tester.scrollUntilVisible(
        find.byKey(const Key('asisten-refresh')),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tap(tester, 'asisten-refresh');
      await tester.pumpAndSettle();
      handler = (_) async => envelope(history([], current: 2, total: 41));
      await tap(tester, 'asisten-more');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asisten-more')), findsOneWidget);
      handler = (_) async => envelope(history([chat()], current: 3, total: 41));
      await tap(tester, 'asisten-more');
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {'page': '3'});
      expect(find.byKey(const Key('asisten-more')), findsNothing);
    },
  );

  widgetTest('dispose during GET and POST has no late UI effect', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byKey(const Key('asisten-draft')), 'private');
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tap(tester, 'asisten-send');
    await tester.pumpWidget(const SizedBox());
    pending.complete(envelope(chat(post: true), 201));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final get = Completer<http.Response>();
    handler = (_) => get.future;
    await tester.pumpWidget(
      MaterialApp(home: AsistenSamuderaScreen(api: api, id: 1)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    get.complete(envelope(chat()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  widgetTest('logout removes detail and prevents back to private content', (
    tester,
  ) async {
    await mount(tester, id: 1);
    expect(find.text('Pesan bersih 1'), findsOneWidget);
    final logout = session.clear();
    await tester.pump();
    await logout;
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Pesan bersih 1'), findsNothing);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
  });

  widgetTest('cooldown reopen and expiry/resume never auto fetch', (
    tester,
  ) async {
    handler = (_) async => http.Response('{}', 429);
    await mount(tester);
    expect(find.textContaining('Jeda lokal aplikasi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester);
    expect(requests.length, 1);
    now = now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 61));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(requests.length, 1);
    expect(find.textContaining('Jeda lokal aplikasi'), findsNothing);
  });
  for (final id in [null, 1]) {
    widgetTest('guest direct entry $id has no chat request', (tester) async {
      final clear = session.clear();
      await tester.pump();
      await clear;
      await mount(tester, id: id);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(requests, isEmpty);
    });
  }
  widgetTest('switch/dispose erases draft and ignores late response', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(
      find.byKey(const Key('asisten-draft')),
      'private draft A',
    );
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tap(tester, 'asisten-send');
    final switchAccount = session.saveIfCurrent(
      'B',
      user: {'id': 2, 'name': 'B'},
    );
    await tester.pump();
    await switchAccount;
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    pending.complete(envelope(chat(post: true), 201));
    await tester.pumpAndSettle();
    expect(find.text('private draft A'), findsNothing);
    expect(find.text('Pesan bersih 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    widgetTest('320px 2x keyboard loading empty error label dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      handler = (_) async => envelope(history([], total: 0));
      await mount(tester, dark: dark, scale: 2);
      await tester.scrollUntilVisible(
        find.text('Belum ada riwayat.'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Belum ada riwayat.'), findsOneWidget);
      expect(find.text(asistenSimulationLabel).hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('asisten-draft')),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.showKeyboard(find.byKey(const Key('asisten-draft')));
      await tester.enterText(find.byKey(const Key('asisten-draft')), 'test');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('asisten-send')).hitTestable(),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('asisten-draft')),
        List.filled(30, 'baris panjang').join('\n'),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('asisten-draft')))
            .maxLines,
        2,
      );
      final pending = Completer<http.Response>();
      handler = (_) => pending.future;
      await tap(tester, 'asisten-send');
      expect(find.text(asistenSimulationLabel).hitTestable(), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.complete(http.Response('{}', 500));
      await tester.pumpAndSettle();
      expect(find.text(asistenSimulationLabel).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
