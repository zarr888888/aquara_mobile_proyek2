import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aquara_mobile/models/external_info.dart';
import 'package:aquara_mobile/screens/external_info_screen.dart';
import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/external_info_api.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/fake_token_store.dart';

Map<String, dynamic> payload(ExternalInfoKind kind, {bool empty = false}) => {
  'success': true,
  'message': externalInfoWarning,
  'data': <String, dynamic>{
    'is_mock': kind == ExternalInfoKind.cuaca,
    'source': 'Kurasi SAMUDERA',
    'generated_at': '2026-10-18T08:00:00+00:00',
    'items': empty
        ? []
        : [
            switch (kind) {
              ExternalInfoKind.kkp => {
                'id': 'kkp-demo-1',
                'judul': 'Pembinaan contoh',
                'ringkasan': 'Jadwal resmi belum tersedia.',
                'penerbit': 'Diskanla',
                'source_url': 'https://diskanla.indramayukab.go.id/',
                'published_at': null,
              },
              ExternalInfoKind.cuaca => {
                'id': 'cuaca-demo-1',
                'wilayah': 'Indramayu (simulasi)',
                'kondisi': 'Berawan (contoh)',
                'suhu_c': 29,
                'kecepatan_angin_kmh': 12,
                'tinggi_gelombang_m': 0.5,
                'valid_at': null,
              },
              ExternalInfoKind.tpi => {
                'id': 'tpi-demo-1',
                'nama': 'TPI Contoh',
                'alamat': 'Indramayu (ilustrasi)',
                'kecamatan': 'Juntinyuat',
                'coordinate_source_url': 'https://indramayukab.go.id/',
                'lat': -6.33,
                'lng': 108.32,
              },
            },
          ],
  },
};

http.Response ok(ExternalInfoKind kind, {bool empty = false}) => http.Response(
  jsonEncode(payload(kind, empty: empty)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Routes extends NavigatorObserver {
  int count = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    count++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  late ExternalInfoRequests requests;
  late DateTime now;
  late Future<http.Response> Function(http.Request) handler;
  late ApiService api;
  final sent = <http.Request>[];
  bool widgetOwnsSession = false;

  ApiService facade({Duration timeout = const Duration(seconds: 30)}) =>
      ApiService(
        session: session,
        externalInfoRequests: requests,
        client: ApiClient(
          baseUrl: Uri.parse('https://example.test/api'),
          session: session,
          clock: () => now,
          timeout: timeout,
          clientFactory: () => MockClient((r) {
            sent.add(r);
            return handler(r);
          }),
        ),
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    widgetOwnsSession = false;
    GoogleFonts.config.allowRuntimeFetching = false;
    session = SessionService(
      store: FakeTokenStore(),
      clearLegacySession: () async {},
    );
    now = DateTime.utc(2026, 10, 18, 8);
    requests = ExternalInfoRequests(clock: () => now);
    sent.clear();
    handler = (r) async =>
        ok(ExternalInfoKind.values.byName(r.url.pathSegments.last));
    api = facade();
    await session.snapshot();
  });
  tearDown(() async {
    if (!widgetOwnsSession) await session.dispose();
  });

  Future<void> widgetSetup(WidgetTester tester) async {
    widgetOwnsSession = true;
    await tester.runAsync(() => session.dispose());
    session = SessionService(store: FakeTokenStore());
    requests = ExternalInfoRequests(clock: () => now);
    api = facade();
    await session.snapshot();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final closing = session.dispose();
      await tester.pump();
      await closing;
    });
  }

  for (final loggedIn in [false, true]) {
    for (final kind in [ExternalInfoKind.kkp, ExternalInfoKind.tpi]) {
      test(
        'public ${kind.name}, authenticated=$loggedIn, exact request',
        () async {
          if (loggedIn) await session.saveToken('synthetic-token');
          final result = await api.fetchExternalInfo(kind);
          expect(result.isSuccess, isTrue);
          expect(result.data!.isMock, isFalse);
          expect(result.data!.message, externalInfoWarning);
          expect(result.data!.source, 'Kurasi SAMUDERA');
          expect(result.data!.generatedAt, now);
          final r = sent.single;
          expect(r.method, 'GET');
          expect(r.url.toString(), 'https://example.test/api/${kind.path}');
          expect(r.body, isEmpty);
          expect(r.headers.containsKey('Authorization'), isFalse);
          expect(r.headers['Accept'], 'application/json');
        },
      );
    }
  }

  for (final kind in [ExternalInfoKind.kkp, ExternalInfoKind.tpi]) {
    test('${kind.name} empty is valid, malformed is not empty', () async {
      handler = (_) async => ok(kind, empty: true);
      expect((await api.fetchExternalInfo(kind)).data!.items, isEmpty);
      for (final bad in [
        null,
        {},
        'bad',
        [null],
        [{}],
      ]) {
        final p = payload(kind);
        p['data']['items'] = bad;
        handler = (_) async => http.Response(
          jsonEncode(p),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        expect(
          (await api.fetchExternalInfo(kind)).failure?.kind,
          ApiErrorKind.invalidResponse,
        );
      }
    });
  }

  test('nullable dates and exact numeric values, no defaults', () {
    final k = ExternalInfo.parse(
      payload(ExternalInfoKind.kkp),
      ExternalInfoKind.kkp,
    );
    expect((k.items.single as KkpInfoItem).publishedAt, isNull);
    expect(
      () => ExternalInfo.parse(
        payload(ExternalInfoKind.cuaca),
        ExternalInfoKind.cuaca,
      ),
      throwsFormatException,
    );
  });

  test('reject missing dates, invalid dates/envelope/mock/source', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (p) => p['success'] = false,
      (p) => p['success'] = 'true',
      (p) => p.remove('message'),
      (p) => p['data']['is_mock'] = true,
      (p) => p['data']['source'] = null,
      (p) => p['data']['generated_at'] = '2026-02-30T08:00:00Z',
      (p) => p['data']['items'][0].remove('published_at'),
      (p) => p['data']['items'][0]['published_at'] = 'broken',
    ];
    for (final mutate in mutations) {
      final p = payload(ExternalInfoKind.kkp);
      mutate(p);
      expect(
        () => ExternalInfo.parse(p, ExternalInfoKind.kkp),
        throwsFormatException,
      );
    }
  });

  for (final status in [401, 403, 404, 500]) {
    test(
      'public $status non-JSON preserves private session, safe error',
      () async {
        await session.saveToken('synthetic-token');
        handler = (_) async =>
            http.Response('<html>private raw error</html>', status);
        final result = await api.fetchExternalInfo(ExternalInfoKind.kkp);
        expect(result.isSuccess, isFalse);
        expect(result.failure!.message, isNot(contains('private raw')));
        expect(await session.readToken(), 'synthetic-token');
        expect(sent.length, 1);
      },
    );
  }
  test('200 non-JSON is malformed', () async {
    handler = (_) async => http.Response('not JSON', 200);
    expect(
      (await api.fetchExternalInfo(ExternalInfoKind.kkp)).failure!.kind,
      ApiErrorKind.invalidResponse,
    );
  });
  test('timeout and network exception are typed without retry', () async {
    handler = (_) => Completer<http.Response>().future;
    api = facade(timeout: const Duration(milliseconds: 10));
    expect(
      (await api.fetchExternalInfo(ExternalInfoKind.kkp)).failure!.kind,
      ApiErrorKind.timeout,
    );
    handler = (_) async => throw const SocketException('sensitive');
    expect(
      (await api.fetchExternalInfo(ExternalInfoKind.kkp)).failure!.kind,
      ApiErrorKind.network,
    );
    expect(sent.length, 2);
  });

  for (final header in [
    '12',
    'Sun, 18 Oct 2026 08:00:20 GMT',
    'invalid',
    null,
  ]) {
    test(
      'shared cooldown Retry-After=$header persists across facades',
      () async {
        handler = (_) async =>
            http.Response('{}', 429, headers: {'retry-after': ?header});
        await api.fetchExternalInfo(ExternalInfoKind.kkp);
        final duration = header == '12'
            ? 12
            : header != null && header.startsWith('Sun')
            ? 20
            : 60;
        expect(requests.remaining.inSeconds, duration);
        expect(requests.usesServerWait, header != null && header != 'invalid');
        final another = facade();
        for (final kind in ExternalInfoKind.values) {
          expect((await another.fetchExternalInfo(kind)).statusCode, 429);
        }
        expect(sent.length, 1);
        now = now.add(Duration(seconds: duration));
        expect(sent.length, 1); // no automatic request at expiry
        handler = (_) async => ok(ExternalInfoKind.tpi);
        expect(
          (await another.fetchExternalInfo(ExternalInfoKind.tpi)).isSuccess,
          isTrue,
        );
        expect(sent.length, 2);
      },
    );
  }

  test(
    'deduplicate in-flight and do not shorten concurrent cooldown',
    () async {
      final a = Completer<http.Response>();
      final b = Completer<http.Response>();
      handler = (r) => r.url.path.endsWith('kkp') ? a.future : b.future;
      final one = api.fetchExternalInfo(ExternalInfoKind.kkp);
      final duplicate = facade().fetchExternalInfo(ExternalInfoKind.kkp);
      final two = api.fetchExternalInfo(ExternalInfoKind.cuaca);
      expect(identical(one, duplicate), isTrue);
      a.complete(http.Response('{}', 429, headers: {'retry-after': '60'}));
      await one;
      b.complete(http.Response('{}', 429, headers: {'retry-after': '5'}));
      await two;
      expect(requests.remaining.inSeconds, 60);
      expect(sent.length, 2);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    ExternalInfoKind kind, {
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
        home: ExternalInfoScreen(key: ValueKey(kind), kind: kind, api: api),
      ),
    );
  }

  http.Response forecast(
    String code, {
    bool upcoming = false,
    bool empty = false,
    bool expired = false,
  }) {
    final start = upcoming ? '2026-10-18T09:00:00Z' : '2026-10-18T00:00:00Z';
    return http.Response(
      jsonEncode({
        'success': true,
        'message': 'OK',
        'data': {
          'location': {
            'code': code,
            'name': code == 'XJ021' ? 'Eretan' : 'Karangsong',
          },
          'status': upcoming ? 'upcoming' : 'available',
          'is_mock': false,
          'source': 'BMKG',
          'generated_at': '2026-10-18T07:00:00Z',
          'valid_from': start,
          'valid_to': expired ? '2026-10-18T08:00:00Z' : '2026-10-19T00:00:00Z',
          'items': empty
              ? []
              : [
                  for (final stamp in [
                    start,
                    '2026-10-18T15:00:00+07:00',
                    '2026-10-18T12:00:00Z',
                  ])
                    {
                      'id': '$code@$stamp',
                      'valid_at': stamp,
                      'pasang_surut_m': -0.4,
                      'tinggi_gelombang_m': 0,
                      'angin_dari': null,
                    },
                ],
        },
      }),
      200,
    );
  }

  testWidgets(
    'Cuaca: slot berlaku (WIB), nol, negatif, upcoming dan GET publik',
    (tester) async {
      await widgetSetup(tester);
      await session.saveToken('synthetic');
      handler = (r) async {
        final code = r.url.queryParameters['kode']!;
        return forecast(code, upcoming: code == 'XJ021');
      };
      await mount(tester, ExternalInfoKind.cuaca);
      await tester.pumpAndSettle();
      expect(find.text('Prakiraan 18/10/2026 15:00 WIB'), findsOneWidget);
      expect(find.text('Angin dari: Tidak tersedia'), findsOneWidget);
      expect(find.text('0 m'), findsOneWidget);
      expect(find.text('-0,4 m'), findsOneWidget);
      await tester.tap(find.text('Eretan'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.key == const Key('weather-port') &&
              w.data == 'Eretan',
        ),
        findsOneWidget,
      );
      expect(find.text('Berlaku mulai 18/10/2026 16:00 WIB'), findsOneWidget);
      expect(find.text('Prakiraan 18/10/2026 16:00 WIB'), findsOneWidget);
      expect(find.text('Sumber: BMKG'), findsOneWidget);
      expect(sent.map((r) => r.url.query), ['kode=XJ022', 'kode=XJ021']);
      for (final r in sent) {
        expect(r.method, 'GET');
        expect(r.url.path, '/api/info/cuaca');
        expect(r.headers.containsKey('Authorization'), isFalse);
        expect(r.headers.containsKey('Cookie'), isFalse);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Cuaca: dua awan putih hanya untuk Berawan dan Berawan Tebal', (
    tester,
  ) async {
    await widgetSetup(tester);
    var condition = 'Berawan';
    handler = (_) async {
      final payload = jsonDecode(forecast('XJ022').body);
      for (final row in payload['data']['items']) {
        row['kondisi'] = condition;
      }
      return http.Response(jsonEncode(payload), 200);
    };
    await mount(tester, ExternalInfoKind.cuaca);
    for (final label in ['Berawan', 'Berawan Tebal', 'Cerah', 'Hujan ringan']) {
      condition = label;
      if (label != 'Berawan') await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      final cloudy = label.startsWith('Berawan');
      for (final glyph in [Icons.cloud_queue_rounded, Icons.cloud_rounded]) {
        final icon = find.byIcon(glyph);
        expect(icon, cloudy ? findsOneWidget : findsNothing);
        if (cloudy) expect(tester.widget<Icon>(icon).color, Colors.white);
      }
      if (!cloudy) {
        expect(
          find.byIcon(label == 'Cerah' ? Icons.wb_sunny : Icons.water_drop),
          findsOneWidget,
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Cuaca: respons lokasi lama tidak mengganti lokasi baru', (
    tester,
  ) async {
    await widgetSetup(tester);
    final old = Completer<http.Response>();
    handler = (r) async => r.url.queryParameters['kode'] == 'XJ022'
        ? old.future
        : forecast('XJ021');
    await mount(tester, ExternalInfoKind.cuaca);
    await tester.tap(find.text('Eretan'));
    await tester.pumpAndSettle();
    old.complete(forecast('XJ022'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.key == const Key('weather-port') &&
            w.data == 'Karangsong',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.key == const Key('weather-port') &&
            w.data == 'Eretan',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Cuaca: kosong, kedaluwarsa, 503, mock, dan cooldown 429', (
    tester,
  ) async {
    await widgetSetup(tester);
    handler = (_) async => forecast('XJ022', empty: true);
    await mount(tester, ExternalInfoKind.cuaca);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada prakiraan.'), findsOneWidget);
    for (final (response, status) in [
      (forecast('XJ022', expired: true), 'Prakiraan kedaluwarsa.'),
      (
        http.Response('{"data":{"status":"expired"}}', 503),
        'Prakiraan kedaluwarsa.',
      ),
      (
        http.Response('{"data":{"status":"unavailable"}}', 503),
        'Layanan cuaca tidak tersedia.',
      ),
      (
        ok(ExternalInfoKind.cuaca),
        'Format informasi tidak valid. Silakan coba kembali.',
      ),
      (
        http.Response('{}', 429, headers: {'retry-after': '30'}),
        'Permintaan informasi dibatasi. Tunggu sebelum mencoba kembali.',
      ),
    ]) {
      handler = (_) async => response;
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text(status), findsOneWidget);
      expect(find.textContaining(RegExp(r'Prakiraan \d')), findsNothing);
      if (response.statusCode != 200 || status.startsWith('Format')) {
        expect(find.text('Sumber: BMKG'), findsNothing);
      }
    }
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('external-info-refresh')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final single in [true, false]) {
    testWidgets('Cuaca 320px teks 2x, batas hari WIB dan tren single=$single', (
      tester,
    ) async {
      await widgetSetup(tester);
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final payload = jsonDecode(forecast('XJ022').body);
      payload['data']['items'] = [
        {'id': 'a', 'valid_at': '2026-10-18T07:00:00Z', 'suhu_c': 0},
        {
          'id': 'b',
          'valid_at': '2026-10-18T17:05:00Z',
          'suhu_c': single ? null : -1.5,
        },
      ];
      handler = (_) async => http.Response(jsonEncode(payload), 200);
      await mount(tester, ExternalInfoKind.cuaca, scale: 2, dark: single);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final day = find.text('Senin, 19/10/2026');
      await tester.scrollUntilVisible(day, 260);
      expect(
        find.byKey(const Key('temperature-line')),
        single ? findsNothing : findsOneWidget,
      );
      if (single) {
        expect(find.text('0 °C  ·  18/10/2026 14:00 WIB'), findsOneWidget);
      }
      await tester.drag(find.byType(ListView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsNWidgets(2));
      await tester.tap(day);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('00:05 WIB').hitTestable(), findsOneWidget);
      expect(
        find.text(
          'Tidak tersedia  ·  ${single ? 'Tidak tersedia' : '-1,5 °C'}',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final dark in [false, true]) {
    for (final kind in [ExternalInfoKind.kkp, ExternalInfoKind.tpi]) {
      testWidgets('${kind.name} 320px text2 dark=$dark all states and scroll', (
        tester,
      ) async {
        await widgetSetup(tester);
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<http.Response>();
        handler = (_) => pending.future;
        await mount(tester, kind, dark: dark, scale: 2);
        expect(find.text(externalInfoWarning), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
        pending.complete(ok(kind));
        await tester.pumpAndSettle();
        expect(
          find.text(kind == ExternalInfoKind.kkp ? 'Diskanla' : 'TPI Contoh'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(find.text(externalInfoWarning), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, 1500));
        await tester.pumpAndSettle();
        handler = (_) async => http.Response('raw sensitive text', 503);
        final refresh = find.byKey(const Key('external-info-refresh'));
        await tester.ensureVisible(refresh);
        await tester.pumpAndSettle();
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(sent.length, 2);
        await tester.drag(find.byType(ListView), const Offset(0, 1500));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('DATA LAMA — penyegaran gagal.'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('DATA LAMA — penyegaran gagal.'), findsOneWidget);
        expect(find.text('raw sensitive text'), findsNothing);
        expect(find.text(externalInfoWarning), findsNothing);
        expect(tester.takeException(), isNull);
        handler = (_) async => ok(kind, empty: true);
        await tester.scrollUntilVisible(
          refresh,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(
          find.text(
            kind == ExternalInfoKind.kkp
                ? 'Belum ada informasi resmi.'
                : 'Tidak ada TPI yang cocok.',
          ),
          findsOneWidget,
        );
        expect(find.text(externalInfoWarning), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('cooldown close/reopen another kind, resume/expiry never fetch', (
    tester,
  ) async {
    await widgetSetup(tester);
    handler = (_) async => http.Response('{}', 429);
    await mount(tester, ExternalInfoKind.kkp);
    await tester.pumpAndSettle();
    expect(find.textContaining('kebijakan aplikasi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api = facade();
    await mount(tester, ExternalInfoKind.tpi);
    await tester.pumpAndSettle();
    expect(sent.length, 1);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const Key('external-info-refresh')),
          )
          .onPressed,
      isNull,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 61));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sent.length, 1);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(const Key('external-info-refresh')),
          )
          .onPressed,
      isNotNull,
    );
    handler = (_) async => ok(ExternalInfoKind.tpi);
    await tester.tap(find.byKey(const Key('external-info-refresh')));
    await tester.pumpAndSettle();
    expect(sent.length, 2);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-flight disposal and duplicate refresh callbacks are safe', (
    tester,
  ) async {
    await widgetSetup(tester);
    await mount(tester, ExternalInfoKind.kkp);
    await tester.pumpAndSettle();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    final callback = tester
        .widget<ButtonStyleButton>(
          find.byKey(const Key('external-info-refresh')),
        )
        .onPressed!;
    callback();
    callback();
    callback();
    await tester.pump();
    expect(sent.length, 2);
    await tester.pumpWidget(const SizedBox());
    pending.complete(ok(ExternalInfoKind.kkp));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final loggedIn in [false, true]) {
    testWidgets(
      'Beranda keeps existing menus, single public route login=$loggedIn',
      (tester) async {
        await widgetSetup(tester);
        if (loggedIn) {
          await session.saveIfCurrent(
            'synthetic',
            user: {'id': 1, 'name': 'A'},
          );
        }
        handler = (r) async => r.url.path.endsWith('fish-types')
            ? http.Response('{"status":"success","data":[]}', 200)
            : ok(ExternalInfoKind.values.byName(r.url.pathSegments.last));
        final routes = _Routes();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [routes],
            home: HomeScreen(api: api),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in [
          'Pasar Ikan',
          'Analisa Usaha',
          'Forum Komunitas',
          'Katalog Ikan',
        ]) {
          expect(find.text(label), findsWidgets);
        }
        for (final kind in ExternalInfoKind.values) {
          final tile = find.byKey(
            ValueKey('service-external-info-${kind.name}'),
          );
          final callback = tester.widget<InkWell>(tile).onTap!;
          callback();
          callback();
          callback();
          await tester.pumpAndSettle();
          expect(find.byType(ExternalInfoScreen), findsOneWidget);
          expect(find.text(externalInfoWarning), findsNothing);
          expect(routes.count, 2 + kind.index);
          final r = sent.last;
          expect(r.url.path, '/api/${kind.path}');
          expect(r.headers.containsKey('Authorization'), isFalse);
          Navigator.of(tester.element(find.byType(ExternalInfoScreen))).pop();
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
