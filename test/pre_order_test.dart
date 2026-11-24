import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aquara_mobile/models/pre_order.dart';
import 'package:aquara_mobile/screens/pre_order_screen.dart';
import 'package:aquara_mobile/screens/retail_screen.dart';
import 'package:aquara_mobile/services/retail_api.dart';
import 'package:aquara_mobile/screens/pasar_screen.dart';
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
import 'pasar_test.dart' show product;

Map<String, Object?> order({int id = 1}) => {
  'id': id,
  'user_id': 1,
  'pasar_id': 10,
  'total_tonase': '2.50',
  'tgl_pengambilan': '2026-10-20',
  'status_bayar': 'Belum Bayar',
  'created_at': '2026-10-15T08:00:00.000000Z',
  'updated_at': null,
};
Map<String, Object?> page(
  List<Object?> items, {
  int current = 1,
  int last = 1,
}) => {
  'data': items,
  'current_page': current,
  'last_page': last,
  'per_page': 20,
  'total': last == 1 ? items.length : (last - 1) * 20 + 1,
  'from': items.isEmpty ? null : (current - 1) * 20 + 1,
  'to': items.isEmpty ? null : (current - 1) * 20 + items.length,
  'next_page_url': 'https://evil.test/steal',
};
http.Response envelope(Object? data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  late ApiService api;
  late SessionSnapshot owner;
  late Future<http.Response> Function(http.Request) handler;
  late DateTime now;
  final requests = <http.Request>[];
  Future<void> initialize({
    Duration timeout = const Duration(milliseconds: 100),
  }) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    now = DateTime.utc(2026, 10, 15);
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    owner = await session.snapshot();
    handler = (r) async {
      if (r.url.path.endsWith('pasars')) {
        return envelope([
          {...product(), 'tipe_penjualan': 'grosir'},
        ]);
      }
      return envelope(
        r.method == 'POST' || r.url.path.endsWith('/1')
            ? order()
            : page([order()]),
        r.method == 'POST' ? 201 : 200,
      );
    };
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clock: () => now,
        timeout: timeout,
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  setUp(initialize);
  test('retail quantities follow seller unit, no unit inferred', () {
    expect(validRetailQuantity('kg', '0.125'), isTrue);
    for (final unit in ['ekor', 'kemasan']) {
      expect(validRetailQuantity(unit, '2'), isTrue);
      expect(validRetailQuantity(unit, '2.5'), isFalse);
    }
    for (final text in ['0', '0.000', '1e3', '1.0001', '-1']) {
      expect(validRetailQuantity('kg', text), isFalse);
    }
    expect(validRetailQuantity('', '1'), isFalse);
  });
  test(
    'seller confirmation checks id, confirmed timestamp and keeps payment separate',
    () async {
      handler = (r) async {
        expect(r.method, 'PUT');
        expect(r.url.path, '/api/pre-order/1/confirmation');
        return envelope({
          ...order(),
          'confirmed_at': '2026-11-24T12:00:00Z',
          'can_confirm': false,
        });
      };
      final result = await api.confirmPreOrder(1, expectedSession: owner);
      expect(result.data?.paymentStatus, 'Belum Bayar');
      expect(result.data?.canConfirm, false);
      handler = (_) async => envelope(order());
      expect(
        (await api.confirmPreOrder(1, expectedSession: owner)).isSuccess,
        false,
      );
    },
  );
  void orderWidget(String name, Future<void> Function(WidgetTester) body) {
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

  Future<ApiResult<PreOrder>> create({
    String ton = '2,50',
    String date = '2026-10-20',
  }) => api.createPreOrder(
    expectedSession: owner,
    pasarId: 10,
    tonnage: ton,
    pickupDate: date,
  );

  for (final text in [
    '',
    '0',
    '-1',
    '1.5',
    '1.000',
    '1,001',
    '1,',
    'NaN',
    'Infinity',
    '1e2',
    '100000000',
    '99 999',
    ' 2',
    '+2',
  ]) {
    test('reject tonnage $text without dispatch', () async {
      expect(preOrderHundredths(text), isNull);
      expect((await create(ton: text)).failure!.kind, ApiErrorKind.validation);
      expect(requests, isEmpty);
    });
  }
  test('decimal bounds and calendar roundtrip', () {
    expect(preOrderHundredths('0,01'), 1);
    expect(preOrderHundredths('99999999,99'), 9999999999);
    expect(preOrderHundredths('2,5'), 250);
    for (final date in [
      '2026-02-29',
      '2026-13-01',
      '2026-1-01',
      '0000-01-01',
      '2026-10-20Z',
    ]) {
      expect(preOrderDateValid(date), isFalse);
    }
    expect(preOrderDateValid('2028-02-29'), isTrue);
    expect(
      preOrderDateValid('2026-10-14'),
      isTrue,
    ); // Server owns today's boundary.
  });
  test(
    'exact payload, numeric tonnage, bearer, paths and page query',
    () async {
      expect((await create()).data!.tonnage, '2,50');
      final post = requests.single;
      expect(jsonDecode(post.body), {
        'pasar_id': 10,
        'total_tonase': 2.5,
        'tgl_pengambilan': '2026-10-20',
      });
      expect(post.headers['Authorization'], 'Bearer A');
      expect(post.url.toString(), 'https://example.test/api/pre-order');
      await api.preOrderHistory(expectedSession: owner);
      await api.preOrderDetail(1, expectedSession: owner);
      expect(requests[1].url.queryParameters, {'page': '1'});
      expect(requests[2].url.path, '/api/pre-order/1');
      expect(requests.every((r) => r.url.host == 'example.test'), isTrue);
    },
  );
  test('empty versus malformed and mismatched identities', () async {
    handler = (_) async => envelope(page([]));
    expect(
      (await api.preOrderHistory(expectedSession: owner)).data!.items,
      isEmpty,
    );
    for (final invalid in [
      null,
      [],
      {'data': []},
      {...page([]), 'per_page': 10},
      {...page([]), 'from': 1},
    ]) {
      handler = (_) async => envelope(invalid);
      expect(
        (await api.preOrderHistory(expectedSession: owner)).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
    }
    for (final invalid in [
      {...order(), 'id': 0},
      {...order(), 'user_id': null},
      {...order(), 'total_tonase': 2.5},
      {...order(), 'total_tonase': 'NaN'},
      {...order(), 'tgl_pengambilan': '2026-02-30'},
      {...order(), 'created_at': 'bad'},
      {...order(), 'status_bayar': null},
    ]) {
      expect(() => PreOrder.parse(invalid), throwsFormatException);
    }
    expect(
      PreOrder.parse({...order(), 'status_bayar': 'baru'}).statusLabel,
      'Status belum dikenal',
    );
    handler = (_) async => envelope(order(id: 2));
    expect(
      (await api.preOrderDetail(1, expectedSession: owner)).isSuccess,
      isFalse,
    );
    handler = (_) async => envelope({...order(), 'pasar_id': 11}, 201);
    expect((await create()).isSuccess, isFalse);
  });
  for (final input in ['0,01', '99999999,99']) {
    test('numeric serialization preserves boundary $input', () async {
      handler = (request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['total_tonase'], isA<num>());
        expect(body['total_tonase'].toString(), input.replaceAll(',', '.'));
        return envelope({
          ...order(),
          'total_tonase': input.replaceAll(',', '.'),
        }, 201);
      };
      expect((await create(ton: input)).isSuccess, isTrue);
    });
  }
  test(
    'invalid pagination metadata and calendar never become empty success',
    () async {
      for (final invalid in [
        {...page([]), 'total': -1},
        {...page([]), 'last_page': 2},
        {
          ...page([order()]),
          'to': 2,
        },
        {
          ...page([order()]),
          'from': 2,
          'to': 2,
        },
        {...page([]), 'current_page': '1'},
      ]) {
        expect(() => PreOrderPage.parse(invalid), throwsFormatException);
      }
      expect(
        (await create(date: '2026-02-30')).failure!.kind,
        ApiErrorKind.validation,
      );
      expect(
        (await api.preOrderHistory(expectedSession: owner, page: 0)).isSuccess,
        isFalse,
      );
      expect(
        (await api.preOrderDetail(0, expectedSession: owner)).isSuccess,
        isFalse,
      );
      expect(requests, isEmpty);
    },
  );
  for (final status in [403, 404, 422, 429, 500, 503]) {
    test('typed error $status retains session and sanitizes fields', () async {
      handler = (_) async => http.Response(
        jsonEncode({
          'message': 'secret raw',
          'errors': {
            'total_tonase': ['secret'],
            'user_id': ['secret'],
          },
        }),
        status,
        headers: {'retry-after': '5'},
      );
      final result = await create();
      expect(result.statusCode, status);
      expect(session.hasSession, isTrue);
      expect(result.failure!.message, isNot(contains('secret')));
      expect(result.failure!.fieldErrors.containsKey('user_id'), isFalse);
      if (status == 429) {
        expect(result.failure!.retryAfter, const Duration(seconds: 5));
      }
      if (status == 403 || status == 404) {
        expect(result.failure!.message, 'Pesanan tidak tersedia.');
      }
    });
  }
  test(
    '401 invalidates current session; late A 401 cannot invalidate B',
    () async {
      final pending = Completer<http.Response>();
      handler = (_) => pending.future;
      final flight = create();
      await Future<void>.delayed(Duration.zero);
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      pending.complete(http.Response('{}', 401));
      expect((await flight).failure!.kind, ApiErrorKind.staleSession);
      expect(session.hasSession, isTrue);
      handler = (_) async => http.Response('{}', 401);
      await api.preOrderHistory(expectedSession: await session.snapshot());
      expect(session.hasSession, isFalse);
    },
  );
  test('network timeout and non JSON never retry', () async {
    handler = (_) async => throw const SocketException('private');
    expect((await create()).failure!.kind, ApiErrorKind.network);
    handler = (_) => Completer<http.Response>().future;
    expect((await create()).failure!.kind, ApiErrorKind.timeout);
    handler = (_) async => http.Response('<html>', 201);
    expect((await create()).failure!.kind, ApiErrorKind.invalidResponse);
    expect(requests.length, 3);
  });

  Future<void> mount(
    WidgetTester tester, {
    PreOrderView view = PreOrderView.form,
    Widget? screen,
    bool small = false,
    bool dark = false,
  }) async {
    if (small) {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(small ? 1.8 : 1),
            viewInsets: EdgeInsets.only(bottom: small ? 240 : 0),
          ),
          child: child!,
        ),
        home:
            screen ??
            PreOrderScreen(
              api: api,
              view: view,
              id: view == PreOrderView.form ? 10 : 1,
              clock: () => now,
            ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('order-tonnage')), '2,50');
    await tester.enterText(find.byKey(const Key('order-date')), '2026-10-20');
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    for (var i = 0; i < 20 && finder.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -160));
      await tester.pump();
    }
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  orderWidget('double submit one POST, success and detail fetch', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester);
    final pending = Completer<http.Response>();
    final original = handler;
    handler = (r) => r.method == 'POST' ? pending.future : original(r);
    final submit = find.byKey(const Key('order-submit'));
    await tester.ensureVisible(submit);
    final callback = tester.widget<FilledButton>(submit).onPressed!;
    callback();
    callback();
    await tester.pump();
    expect(requests.where((r) => r.method == 'POST').length, 1);
    pending.complete(envelope(order(), 201));
    await tester.pumpAndSettle();
    expect(find.text('Pengajuan berhasil dicatat.'), findsOneWidget);
    await tap(tester, find.text('Lihat detail pesanan'));
    expect(requests.last.url.path, '/api/pre-order/1');
    expect(find.text('Status pembayaran: Belum Bayar'), findsOneWidget);
  });
  for (final failure in ['network', '500', '503', 'malformed']) {
    orderWidget('uncertain $failure no automatic retry', (tester) async {
      await mount(tester);
      await fill(tester);
      handler = (_) async {
        if (failure == 'network') throw const SocketException('offline');
        return http.Response(
          '{}',
          failure == 'malformed' ? 201 : int.parse(failure),
        );
      };
      await tap(tester, find.byKey(const Key('order-submit')));
      expect(
        find.textContaining('Hasil pengiriman belum dapat dipastikan'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('order-submit')))
            .onPressed,
        isNull,
      );
      expect(requests.where((r) => r.method == 'POST').length, 1);
      expect(find.text('Pengajuan berhasil dicatat.'), findsNothing);
    });
  }
  orderWidget('422 draft and known safe inline errors', (tester) async {
    await mount(tester);
    await fill(tester);
    handler = (_) async => http.Response(
      jsonEncode({
        'errors': {
          'tgl_pengambilan': ['raw secret'],
          'total_tonase': ['raw secret'],
          'user_id': ['raw secret'],
        },
      }),
      422,
    );
    await tap(tester, find.byKey(const Key('order-submit')));
    expect(find.text('2,50'), findsOneWidget);
    expect(find.text(preOrderDateError), findsOneWidget);
    expect(find.textContaining('raw secret'), findsNothing);
  });
  orderWidget('pagination dedup failure retention refresh ignores old page', (
    tester,
  ) async {
    handler = (_) async => envelope(page([order()], last: 2));
    await mount(tester, view: PreOrderView.history);
    handler = (_) async => http.Response('{}', 500);
    await tap(tester, find.byKey(const Key('order-more')));
    expect(find.byKey(const Key('order-1')), findsOneWidget);
    handler = (_) async =>
        envelope(page([order(), order(id: 2)], current: 2, last: 3));
    await tap(tester, find.byKey(const Key('order-more')));
    expect(find.byKey(const Key('order-1')), findsOneWidget);
    expect(find.byKey(const Key('order-2')), findsOneWidget);
    final pending = Completer<http.Response>();
    handler = (r) => r.url.queryParameters['page'] == '3'
        ? pending.future
        : Future.value(envelope(page([order(id: 9)])));
    await tester.ensureVisible(find.byKey(const Key('order-more')));
    await tester.tap(find.byKey(const Key('order-more')));
    await tester.pump();
    await tester.ensureVisible(find.text('Muat ulang'));
    await tester.tap(find.text('Muat ulang'));
    await tester.pumpAndSettle();
    pending.complete(envelope(page([order(id: 8)], current: 3, last: 3)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('order-9')), findsOneWidget);
    expect(find.byKey(const Key('order-8')), findsNothing);
    expect(find.textContaining('Produk #10'), findsOneWidget);
    expect(requests.every((r) => r.url.host == 'example.test'), isTrue);
  });
  for (final view in PreOrderView.values) {
    orderWidget('guest direct $view and session change cleanup', (
      tester,
    ) async {
      await session.invalidate(owner);
      await mount(tester, view: view);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(requests, isEmpty);
    });
    orderWidget('logout $view removes private screen and back access', (
      tester,
    ) async {
      await mount(tester, view: view);
      if (view == PreOrderView.form) await fill(tester);
      await session.invalidate(await session.snapshot());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(PreOrderScreen), findsNothing);
      expect(find.text('2,50'), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    });
    for (final dark in [false, true]) {
      orderWidget('320 text keyboard $view dark=$dark', (tester) async {
        await mount(tester, view: view, small: true, dark: dark);
        if (view == PreOrderView.form) {
          await fill(tester);
          await tap(tester, find.byKey(const Key('order-submit')));
          expect(find.text('Pengajuan berhasil dicatat.'), findsOneWidget);
          expect(requests.where((r) => r.method == 'POST').length, 1);
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  orderWidget('Pasar empty still opens history', (tester) async {
    handler = (r) async =>
        envelope(r.url.path.endsWith('pasars') ? [] : page([]));
    await mount(tester, screen: PasarScreen(api: api));
    await tap(tester, find.byTooltip('Riwayat pre-order'));
    expect(find.text('Belum ada pesanan.'), findsOneWidget);
  });
  orderWidget('own grosir zero stock allowed entry, eceran no entry', (
    tester,
  ) async {
    await mount(tester, screen: PasarScreen(api: api));
    await tap(tester, find.text('Ajukan pre-order'));
    expect(find.byKey(const Key('order-tonnage')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    handler = (_) async => envelope([product()]);
    await mount(tester, screen: PasarScreen(api: api));
    expect(find.text('Ajukan pre-order'), findsNothing);
  });

  orderWidget('eceran: pembeli memesan kg; jumlah dan total dari server', (
    tester,
  ) async {
    handler = (r) async {
      expect(r.method, 'POST');
      expect(r.url.path, '/api/retail-orders');
      expect(jsonDecode(r.body), {
        'pasar_id': 10,
        'expected_unit': 'kg',
        'expected_price': 1002,
        'jumlah': '1.250',
      });
      return envelope({
        'id': 12,
        'pasar_id': 10,
        'buyer_id': 1,
        'seller_id': 2,
        'nama_ikan': 'LATIHAN',
        'satuan_jual': 'kg',
        'jumlah': '1.250',
        'harga_satuan': 1002,
        'total_harga': 1253,
        'confirmed_at': null,
        'status_bayar': 'Belum Bayar',
      }, 201);
    };
    await mount(
      tester,
      screen: RetailScreen(
        api: api,
        product: {
          ...product(),
          'id': 10,
          'user_id': 2,
          'satuan_jual': 'kg',
          'harga': 1002,
        },
      ),
    );
    await tester.enterText(find.byType(TextField), '1,250');
    await tap(tester, find.text('Pesan kepada penjual'));
    expect(find.textContaining('Total Rp 1253'), findsOneWidget);
    expect(
      find.textContaining('Menunggu konfirmasi · Belum Bayar'),
      findsOneWidget,
    );
    expect(find.text('Konfirmasi pesanan'), findsNothing);
  });
  orderWidget(
    'eceran: penjual melihat pesanan masuk dan mengonfirmasi tanpa pelunasan',
    (tester) async {
      final row = {
        'id': 12,
        'pasar_id': 10,
        'buyer_id': 2,
        'seller_id': 1,
        'nama_ikan': 'LATIHAN',
        'satuan_jual': 'kemasan',
        'jumlah': '2.000',
        'harga_satuan': 500,
        'total_harga': 1000,
        'confirmed_at': null,
        'status_bayar': 'Belum Bayar',
      };
      handler = (r) async {
        if (r.method == 'GET') {
          return envelope({
            'current_page': 1,
            'last_page': 1,
            'data': [row],
          });
        }
        expect(r.method, 'PUT');
        expect(r.url.path, '/api/retail-orders/12/confirmation');
        return envelope({...row, 'confirmed_at': '2026-11-24T04:00:00Z'});
      };
      await mount(tester, screen: RetailScreen(api: api));
      await tap(tester, find.text('Konfirmasi pesanan'));
      expect(
        find.textContaining('Dikonfirmasi penjual · Belum Bayar'),
        findsOneWidget,
      );
      expect(find.text('Konfirmasi pesanan'), findsNothing);
    },
  );

  for (final header in ['seconds', 'date', 'none']) {
    orderWidget('429 $header deadline lifecycle and disposal', (tester) async {
      await mount(tester);
      await fill(tester);
      handler = (_) async => http.Response(
        '{}',
        429,
        headers: {
          if (header == 'seconds') 'retry-after': '5',
          if (header == 'date')
            'retry-after': HttpDate.format(now.add(const Duration(seconds: 5))),
        },
      );
      await tap(tester, find.byKey(const Key('order-submit')));
      expect(requests.where((r) => r.method == 'POST').length, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('order-submit')))
            .onPressed,
        isNull,
      );
      expect(
        find.textContaining(header == 'none' ? 'Jeda lokal' : 'Tunggu 5'),
        findsOneWidget,
      );
      final count = requests.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 61));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(requests.length, count);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('order-submit')))
            .onPressed,
        isNotNull,
      );
      handler = (_) async => http.Response('{}', 429);
      await tap(tester, find.byKey(const Key('order-submit')));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 61));
      expect(tester.takeException(), isNull);
    });
  }

  for (final view in PreOrderView.values) {
    for (final status in [200, 401]) {
      orderWidget(
        'late A $view $status after account B cannot restore private state',
        (tester) async {
          final pending = Completer<http.Response>();
          if (view == PreOrderView.form) {
            await mount(tester);
            await fill(tester);
            handler = (_) => pending.future;
            final submit = find.byKey(const Key('order-submit'));
            await tester.ensureVisible(submit);
            tester.widget<FilledButton>(submit).onPressed!();
          } else {
            handler = (_) => pending.future;
            await tester.pumpWidget(
              MaterialApp(
                home: PreOrderScreen(api: api, view: view, id: 1),
              ),
            );
          }
          await tester.pump();
          expect(requests, isNotEmpty);
          await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
          await tester.pumpAndSettle();
          pending.complete(
            status == 401
                ? http.Response('{}', 401)
                : envelope(
                    view == PreOrderView.history ? page([order()]) : order(),
                    view == PreOrderView.form ? 201 : 200,
                  ),
          );
          await tester.pumpAndSettle();
          expect(session.metadata['user_id'], '2');
          expect(session.hasSession, isTrue);
          expect(find.byType(PreOrderScreen), findsNothing);
          expect(find.text('2,50'), findsNothing);
          expect(find.textContaining('Pesanan #1'), findsNothing);
          expect(find.textContaining('Lele 10'), findsNothing);
        },
      );
    }
  }

  orderWidget(
    'explicit history check then manual retry; failed history is not proof',
    (tester) async {
      await mount(tester);
      await fill(tester);
      handler = (_) async => http.Response('{}', 500);
      await tap(tester, find.byKey(const Key('order-submit')));
      await tap(tester, find.text('Riwayat pre-order'));
      expect(find.text('Riwayat pesanan'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tidak muncul pada satu halaman bukan bukti'),
        findsOneWidget,
      );
      expect(requests.where((r) => r.method == 'POST').length, 1);
      handler = (_) async => envelope(order(), 201);
      await tap(tester, find.byKey(const Key('order-submit')));
      expect(requests.where((r) => r.method == 'POST').length, 2);
      expect(find.text('Pengajuan berhasil dicatat.'), findsOneWidget);
    },
  );

  orderWidget('success followed by failed detail never repeats POST', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester);
    await tap(tester, find.byKey(const Key('order-submit')));
    handler = (_) async => http.Response('{}', 404);
    await tap(tester, find.text('Lihat detail pesanan'));
    expect(find.text('Pesanan tidak tersedia.'), findsOneWidget);
    expect(session.hasSession, isTrue);
    await tap(tester, find.text('Muat ulang'));
    expect(requests.where((r) => r.method == 'POST').length, 1);
    expect(find.text('Pesanan #1'), findsNothing);
  });

  orderWidget('POST timeout retains draft and leaves outcome uncertain', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester);
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    final submit = find.byKey(const Key('order-submit'));
    await tester.ensureVisible(submit);
    tester.widget<FilledButton>(submit).onPressed!();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Hasil pengiriman belum dapat dipastikan'),
      findsOneWidget,
    );
    expect(find.text('2,50'), findsOneWidget);
    pending.complete(envelope(order(), 201));
    await tester.pumpAndSettle();
    expect(find.text('Pengajuan berhasil dicatat.'), findsNothing);
    expect(requests.where((r) => r.method == 'POST').length, 1);
  });
}
