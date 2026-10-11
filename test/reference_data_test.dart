import 'dart:async';
import 'dart:convert';
import 'package:aquara_mobile/models/reference_data.dart';
import 'package:aquara_mobile/screens/catalog_screen.dart';
import 'package:aquara_mobile/screens/analysis_screen.dart';
import 'package:aquara_mobile/screens/info_dinas_screen.dart';
import 'package:aquara_mobile/screens/berita_screen.dart';
import 'package:aquara_mobile/screens/market_price_screen.dart';
import 'package:aquara_mobile/screens/semua_komoditas_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/reference_list_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

Map<String, dynamic> fish() => {
  'id': 1,
  'name': 'Lele',
  'image': null,
  'image_url': null,
  'fcr_ratio': '1.20',
  'harvest_duration_days': 90,
  'market_price_per_kg': '25000.00',
  'standard_density_per_m2': 100,
  'survival_rate': '90.00',
  'feed_price_per_kg': '12000.00',
};
http.Response listing(String path, List items) => http.Response(
  jsonEncode({
    if (path == 'fish-types') 'status': 'success' else 'success': true,
    'data': items,
  }),
  200,
);

void main() {
  late SessionService session;
  late ApiService api;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    handler = (r) async => listing(r.url.pathSegments.last, []);
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  setUp(initialize);
  Future<ApiResult<List<dynamic>>> fetch(String path) async {
    final owner = await session.snapshot();
    return switch (path) {
      'fish-types' => api.fetchFishTypes(expectedSession: owner),
      'stocks' => api.fetchStocks(expectedSession: owner),
      _ => api.fetchPosts(expectedSession: owner),
    };
  }

  for (final path in ['fish-types', 'stocks', 'posts']) {
    test('$path GET contract and empty success', () async {
      expect((await fetch(path)).data, isEmpty);
      final r = requests.single;
      expect(r.method, 'GET');
      expect(r.url.toString(), 'https://example.test/api/$path');
      expect(r.body, isEmpty);
      expect(r.headers['Authorization'], 'Bearer A');
      expect(r.headers['Accept'], 'application/json');
      expect(r.followRedirects, false);
    });
    test('$path malformed never becomes empty success', () async {
      for (final body in [
        '<html>private</html>',
        '{',
        '{}',
        '{"success":true,"data":{}}',
        jsonEncode({
          'status': 'success',
          'success': true,
          'data': [false],
        }),
      ]) {
        handler = (_) async => http.Response(body, 200);
        final result = await fetch(path);
        expect(result.failure?.kind, ApiErrorKind.invalidResponse);
        expect(result.data, isNull);
      }
    });
    for (final status in [401, 403, 404]) {
      test('$path $status centralized session semantics', () async {
        handler = (_) async => http.Response('{}', status);
        final result = await fetch(path);
        expect(result.isSuccess, false);
        expect(session.hasSession, status != 401);
      });
    }
    for (final status in [200, 401]) {
      test('$path stale A $status cannot overwrite or invalidate B', () async {
        final pending = Completer<http.Response>();
        handler = (_) => pending.future;
        final owner = await session.snapshot();
        final future = fetch(path);
        while (requests.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        await session.invalidate(owner);
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        pending.complete(
          status == 200 ? listing(path, []) : http.Response('{}', 401),
        );
        expect((await future).failure?.kind, ApiErrorKind.staleSession);
        expect(await session.readToken(), 'B');
      });
    }
    test('$path deduplicates pending requests and blocks cooldown', () async {
      final pending = Completer<http.Response>();
      handler = (_) => pending.future;
      final one = fetch(path), two = fetch(path);
      while (requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      pending.complete(
        http.Response('{}', 429, headers: {'retry-after': '30'}),
      );
      expect((await one).failure!.retryAfter, const Duration(seconds: 30));
      expect((await two).failure!.kind, ApiErrorKind.rateLimited);
      expect((await fetch(path)).failure!.kind, ApiErrorKind.rateLimited);
      expect(requests, hasLength(1));
    });
  }
  test(
    'fish status not success; numeric strings preserved, no invented zero',
    () async {
      handler = (_) async => listing('fish-types', [fish()]);
      final result = await fetch('fish-types');
      expect(result.data!.single['fcr_ratio'], '1.20');
      expect(result.data!.single['image_url'], isNull);
      for (final invalid in [null, 'oops', 'NaN']) {
        handler = (_) async =>
            listing('fish-types', [fish()..['fcr_ratio'] = invalid]);
        expect(
          (await fetch('fish-types')).failure!.kind,
          ApiErrorKind.invalidResponse,
        );
      }
      handler = (_) async => http.Response('{"success":true,"data":[]}', 200);
      expect((await fetch('fish-types')).isSuccess, false);
    },
  );
  test(
    'stock snake relation and backend order; nullable date and relation',
    () async {
      handler = (_) async => listing('stocks', [
        {
          'id': 3,
          'amount_kg': '500.25',
          'fish_type': {'id': 1, 'name': 'Lele', 'image': null},
        },
        {'id': 2, 'amount_kg': 100, 'fish_type': null, 'created_at': 'bad'},
      ]);
      final data = (await fetch('stocks')).data!;
      expect(data.map((v) => v['id']), [3, 2]);
      expect(data.first['fish_type']['name'], 'Lele');
      expect(data.last['created_at'], '');
      expect(data.last['fish_type'], isNull);
    },
  );
  test(
    'posts order and plain content; invalid date not current time',
    () async {
      handler = (_) async => listing('posts', [
        {
          'id': 9,
          'content': '<script>doNotExecute()</script>',
          'created_at': 'x',
        },
        {'id': 4, 'created_at': null},
      ]);
      final data = (await fetch('posts')).data!;
      expect(data.map((v) => v['id']), [9, 4]);
      expect(data.first['content'], '<script>doNotExecute()</script>');
      expect(data.first['created_at'], '');
    },
  );
  test(
    'HTTPS image absolute wins over broken accessor; legacy relative and null',
    () {
      expect(
        referenceImage({
          'image': 'https://res.cloudinary.com/a.png',
          'image_url':
              'https://example.test/storage/https://res.cloudinary.com/a.png',
        }),
        'https://res.cloudinary.com/a.png',
      );
      expect(
        referenceImage({'image': 'fish/a.png'}),
        'https://aquara.app/storage/fish/a.png',
      );
      expect(referenceImage({'image': null}), isNull);
      expect(referenceImage({'image': 'http://unsafe.test/a'}), isNull);
      expect(referenceImage({'image': '../secret'}), isNull);
    },
  );
  test('guest and stale owner never issue request', () async {
    final owner = await session.snapshot();
    await session.invalidate(owner);
    expect(
      (await api.fetchPosts(expectedSession: owner)).failure!.kind,
      ApiErrorKind.staleSession,
    );
    expect((await fetch('posts')).failure!.kind, ApiErrorKind.unauthenticated);
    expect(requests, isEmpty);
  });
  test('RSS uses a separate fake transport with no SAMUDERA bearer', () async {
    final external = <http.Request>[];
    final items = await http.runWithClient(
      () => api.fetchBeritaNasional(),
      () => MockClient((r) async {
        external.add(r);
        return http.Response('{"status":"ok","items":[]}', 200);
      }),
    );
    expect(items, isEmpty);
    expect(external.single.url.host, 'api.rss2json.com');
    expect(external.single.headers.containsKey('Authorization'), false);
    expect(requests, isEmpty);
  });
  test(
    '429 without header blocks repeated service calls with honest metadata',
    () async {
      handler = (_) async => http.Response('{}', 429);
      expect((await fetch('posts')).failure!.retryAfter, isNull);
      expect((await fetch('posts')).failure!.retryAfter, isNull);
      expect(requests, hasLength(1));
    },
  );
  testWidgets(
    'news nullable dates and script content render as data, RSS mocked',
    (tester) async {
      await initialize();
      handler = (_) async => listing('posts', [
        {
          'id': 1,
          'title': 'Berita backend',
          'content': '<script>doNotExecute()</script>',
          'created_at': 'x',
          'image': null,
        },
      ]);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(MaterialApp(home: BeritaScreen(api: api)));
          await tester.pumpAndSettle();
          expect(find.text('Berita backend'), findsOneWidget);
          expect(find.text('-'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Berita backend'));
          await tester.pumpAndSettle();
          expect(find.text('<script>doNotExecute()</script>'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((r) async {
          expect(r.headers.containsKey('Authorization'), false);
          return http.Response('{"status":"ok","items":[]}', 200);
        }),
      );
    },
  );
  testWidgets('pending A widget disposed, B remains unchanged after A 401', (
    tester,
  ) async {
    await initialize();
    final pending = Completer<http.Response>();
    handler = (r) async => r.url.path.endsWith('fish-types')
        ? pending.future
        : listing('stocks', []);
    await tester.pumpWidget(MaterialApp(home: CatalogScreen(api: api)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    final owner = await session.snapshot();
    await tester.pumpWidget(const SizedBox());
    await session.invalidate(owner);
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    handler = (r) async => listing(r.url.pathSegments.last, []);
    await tester.pumpWidget(MaterialApp(home: CatalogScreen(api: api)));
    await tester.pumpAndSettle();
    pending.complete(http.Response('{}', 401));
    await tester.pumpAndSettle();
    expect(session.metadata['user_name'], 'B');
    expect(find.text('Belum ada data jenis ikan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('catalog nullable fish image does not request placeholder host', (
    tester,
  ) async {
    await initialize();
    handler = (r) async => listing(
      r.url.pathSegments.last,
      r.url.path.endsWith('fish-types')
          ? [fish()]
          : [
              {
                'id': 1,
                'amount_kg': '500.25',
                'pengepul_name': 'Bahari',
                'fish_type': {'id': 1, 'name': 'Lele', 'image': null},
              },
            ],
    );
    await tester.pumpWidget(MaterialApp(home: CatalogScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Lele'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('Bursa Stok'));
    await tester.pumpAndSettle();
    expect(find.text(' 500.25 Kg'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final withHeader in [true, false]) {
    testWidgets('429 wait, manual retry and double tap header=$withHeader', (
      tester,
    ) async {
      handler = (_) async => http.Response(
        '{}',
        429,
        headers: withHeader ? {'retry-after': '2'} : {},
      );
      var calls = 0;
      Future<ApiResult<List<dynamic>>> load() async {
        calls++;
        // UI timer is virtual; transport clock remains real in this test.
        return ApiResult.failure(
          ApiFailure(
            kind: ApiErrorKind.rateLimited,
            message: 'Terlalu banyak permintaan.',
            retryAfter: withHeader ? const Duration(seconds: 2) : null,
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReferenceListBuilder(
              clock: tester.binding.clock.now,
              future: load(),
              retry: load,
              builder: (_, snapshot) => Text('items ${snapshot.data!.length}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(withHeader ? 'Tunggu 2' : 'Jeda lokal 60'),
        findsOneWidget,
      );
      await tester.tap(find.text('Coba lagi'));
      expect(calls, 1);
      await tester.pump(Duration(seconds: withHeader ? 2 : 60));
      await tester.tap(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('catalog distinguishes empty and failure and retries', (
    tester,
  ) async {
    await initialize();
    handler = (r) async => r.url.path.endsWith('stocks')
        ? listing('stocks', [])
        : http.Response('{}', 403);
    await tester.pumpWidget(MaterialApp(home: CatalogScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Akses atau data tidak tersedia.'), findsOneWidget);
    expect(find.text('Belum ada data jenis ikan.'), findsNothing);
    expect(session.hasSession, true);
    handler = (r) async => listing(r.url.pathSegments.last, []);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada data jenis ikan.'), findsOneWidget);
  });
  testWidgets('calculator retains numeric string data and auto selection', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => listing('fish-types', [fish()]);
    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisScreen(api: api, autoFishName: 'Lele'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lele'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('public info links remain for guest with no Sanctum call', (
    tester,
  ) async {
    await initialize();
    await session.invalidate(await session.snapshot());
    await tester.pumpWidget(MaterialApp(home: InfoDinasScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Akses Cepat Website'), findsOneWidget);
    expect(find.text('Silakan login terlebih dahulu.'), findsOneWidget);
    expect(requests, isEmpty);
  });
  testWidgets('private 401 removes catalog via existing boundary', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => http.Response('{}', 401);
    await tester.pumpWidget(MaterialApp(home: CatalogScreen(api: api)));
    await tester.pumpAndSettle();
    expect(session.hasSession, false);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Katalog Ikan'), findsNothing);
  });
  testWidgets(
    'price and commodities callers retain parsed values with null images',
    (tester) async {
      await initialize();
      handler = (_) async => listing('fish-types', [fish()]);
      await tester.pumpWidget(MaterialApp(home: MarketPriceScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Lele'), findsOneWidget);
      expect(find.textContaining('25.000'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(home: SemuaKomoditasScreen(api: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lele'), findsOneWidget);
      expect(find.textContaining('25.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('320px large text error and empty retry $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: ReferenceListBuilder(
                future: Future.value(
                  ApiResult.failure(
                    ApiFailure(
                      kind: ApiErrorKind.notFound,
                      message: 'raw must not display',
                    ),
                  ),
                ),
                retry: () async =>
                    const ApiResult.success(data: [], statusCode: 200),
                builder: (_, snapshot) =>
                    Text(snapshot.data!.isEmpty ? 'Kosong' : 'Data'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Akses atau data tidak tersedia.'), findsOneWidget);
      expect(find.text('raw must not display'), findsNothing);
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Kosong'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final serverDeadline in [true, false]) {
    testWidgets('cooldown resume uses elapsed deadline server=$serverDeadline', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 5);
      var retries = 0;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReferenceListBuilder(
              clock: () => now,
              future: Future.value(
                ApiResult.failure(
                  ApiFailure(
                    kind: ApiErrorKind.rateLimited,
                    message: 'Terlalu banyak permintaan.',
                    retryAfter: serverDeadline
                        ? const Duration(seconds: 90)
                        : null,
                    retryAt: serverDeadline
                        ? now.add(const Duration(seconds: 10))
                        : null,
                  ),
                ),
              ),
              retry: () async {
                retries++;
                return const ApiResult.success(data: [], statusCode: 200);
              },
              builder: (_, snapshot) => const Text('Kosong'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(serverDeadline ? 'Tunggu 10' : 'Jeda lokal 60'),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      // No timer ticks: simulate the OS suspending Dart while wall time passes.
      now = now.add(Duration(seconds: serverDeadline ? 7 : 57));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.textContaining(serverDeadline ? 'Tunggu 3' : 'Jeda lokal 3'),
        findsOneWidget,
      );
      await tester.tap(find.text('Coba lagi'));
      expect(retries, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('detik'), findsNothing);
      expect(retries, 0); // Resume must not trigger automatic retry.
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(find.text('Kosong'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'new future clears cooldown and ignores old completion; dispose cleans timer',
    (tester) async {
      var now = DateTime.utc(2026, 10, 5);
      final pending = Completer<ApiResult<List<dynamic>>>();
      final rateLimit = ApiResult<List<dynamic>>.failure(
        ApiFailure(
          kind: ApiErrorKind.rateLimited,
          message: 'Kuota',
          retryAt: now.add(const Duration(seconds: 60)),
        ),
      );
      Widget view(Future<ApiResult<List<dynamic>>> future) => MaterialApp(
        home: Scaffold(
          body: ReferenceListBuilder(
            clock: () => now,
            future: future,
            retry: () => pending.future,
            builder: (_, snapshot) => const Text('Data baru'),
          ),
        ),
      );
      await tester.pumpWidget(view(Future.value(rateLimit)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Jeda lokal 60'), findsOneWidget);
      await tester.pumpWidget(view(pending.future));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(
        view(
          Future.value(
            ApiResult.failure(
              ApiFailure(
                kind: ApiErrorKind.forbidden,
                message: 'Tidak tersedia',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('detik'), findsNothing);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNotNull,
      );
      pending.complete(rateLimit);
      await tester.pump();
      expect(find.textContaining('detik'), findsNothing);
      expect(find.text('Akses atau data tidak tersedia.'), findsOneWidget);
      await tester.pumpWidget(view(Future.value(rateLimit)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      now = now.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 2));
      expect(tester.takeException(), isNull);
    },
  );
}
