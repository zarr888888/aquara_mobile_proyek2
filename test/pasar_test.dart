import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aquara_mobile/models/pasar_item.dart';
import 'package:aquara_mobile/screens/pasar_screen.dart';
import 'package:aquara_mobile/screens/tambah_jualan_screen.dart';
import 'package:aquara_mobile/screens/edit_jualan_screen.dart';
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

Map<String, dynamic> product({int id = 10, int? owner = 1}) => {
  'id': id,
  'user_id': owner,
  'nama_ikan': 'Lele $id',
  'harga': 0,
  'deskripsi': '<b>Ikan sehat</b>',
  'nomor_wa': '08123456789',
  'lokasi': 'Indramayu',
  'stok': 0,
  'kategori': 'tawar',
  'tipe_penjualan': 'eceran',
  'foto': null,
  'created_at': 'invalid',
  'user': {'id': owner, 'name': 'Penjual', 'email': 'private'},
};
http.Response listResponse(List<Object?> data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  late SessionService session;
  late ApiService api;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  Future<void> initialize() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    requests.clear();
    handler = (r) async => r.method == 'GET'
        ? listResponse([product()])
        : r.method == 'DELETE'
        ? http.Response('{"message":"deleted"}', 200)
        : http.Response(
            jsonEncode({
              'success': true,
              'data': {...product(), 'user': null},
            }),
            r.url.path.endsWith('update') ? 200 : 201,
          );
    api = ApiService(
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
  }

  setUp(initialize);
  Future<ApiResult<Map<String, dynamic>>> create({
    String price = '0',
    String? stock,
    String? category,
    String? type,
    File? photo,
    SessionSnapshot? owner,
  }) async => api.createPasar(
    expectedSession: owner ?? await session.snapshot(),
    namaIkan: 'Lele',
    harga: price,
    deskripsi: 'Ikan',
    nomorWa: '+62 (123)',
    lokasi: 'Tambak',
    stok: stock,
    kategori: category,
    tipePenjualan: type,
    foto: photo,
  );

  test(
    'four methods paths bearer and clean bodies; delete without success',
    () async {
      final owner = await session.snapshot();
      expect((await api.fetchPasar(expectedSession: owner)).isSuccess, isTrue);
      expect(
        (await create(stock: '0', category: 'laut', type: 'grosir')).isSuccess,
        isTrue,
      );
      expect(
        (await api.updatePasarItem(
          id: 10,
          expectedSession: owner,
          namaIkan: 'Lele',
          harga: '999999999',
          deskripsi: 'Ikan',
          nomorWa: 'x',
          lokasi: 'Tambak',
          stok: '0',
        )).isSuccess,
        isTrue,
      );
      expect(
        (await api.deletePasarItem(10, expectedSession: owner)).isSuccess,
        isTrue,
      );
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/pasars',
        'POST /api/pasars',
        'POST /api/pasars/10/update',
        'DELETE /api/pasars/10',
      ]);
      for (final r in requests) {
        expect(r.url.query, isEmpty);
        expect(r.headers['authorization'], 'Bearer A');
        expect(r.headers['accept'], 'application/json');
      }
      expect(requests.first.body, isEmpty);
      expect(requests.last.body, isEmpty);
      expect(jsonDecode(requests[1].body), {
        'nama_ikan': 'Lele',
        'harga': 0,
        'deskripsi': 'Ikan',
        'nomor_wa': '+62 (123)',
        'lokasi': 'Tambak',
        'stok': 0,
        'kategori': 'laut',
        'tipe_penjualan': 'grosir',
      });
      final update = jsonDecode(requests[2].body) as Map;
      expect(update['stok'], 0);
      expect(update.containsKey('foto'), isFalse);
      expect(update.containsKey('kategori'), isFalse);
    },
  );
  test('omitted optionals use server default, never explicit null', () async {
    await create();
    expect((jsonDecode(requests.single.body) as Map).keys.toSet(), {
      'nama_ikan',
      'harga',
      'deskripsi',
      'nomor_wa',
      'lokasi',
    });
  });
  test(
    'integer UI policy and boundaries reject ambiguous or fractional input',
    () async {
      for (final v in ['-1', '1000000000', '1.5', '1,5', '25.000', '1e2', '']) {
        expect((await create(price: v)).failure?.kind, ApiErrorKind.validation);
      }
      expect(
        (await create(stock: '1.2')).failure?.fieldErrors,
        contains('stok'),
      );
      expect(
        (await create(category: 'unknown')).failure?.fieldErrors,
        contains('kategori'),
      );
      expect(
        (await create(type: 'unknown')).failure?.fieldErrors,
        contains('tipe_penjualan'),
      );
      expect(requests, isEmpty);
      expect(
        (await create(price: '999999999', stock: '999999999')).isSuccess,
        isTrue,
      );
    },
  );
  test(
    'required strings and maxima validated without OTP number rules',
    () async {
      expect(pasarTextError('', 20), isNotNull);
      expect(pasarTextError('x' * 21, 20), isNotNull);
      expect(pasarTextError('x' * 255, 255), isNull);
      expect(pasarTextError('x' * 2001, 2000), isNotNull);
      expect((await create()).isSuccess, isTrue);
    },
  );
  test(
    'parse optional seller nullable photo invalid dates and unknown legacy values',
    () async {
      final row = parsePasarItem({
        ...product(),
        'stok': 'broken',
        'kategori': 'legacy',
      });
      expect(row['stok'], isNull);
      expect(row['created_at'], isNull);
      expect(row['kategori'], 'legacy');
      expect(row['user'], {'name': 'Penjual'});
      expect(row['foto'], isNull);
      expect((await create()).data!['user'], isNull);
      expect(
        () => parsePasarItem({...product(), 'harga': 'broken'}),
        throwsFormatException,
      );
      expect(ownsPasar(product(owner: null), '1'), isFalse);
    },
  );
  test('empty distinct from malformed and non JSON responses', () async {
    handler = (_) async => listResponse([]);
    expect(
      (await api.fetchPasar(expectedSession: await session.snapshot())).data,
      isEmpty,
    );
    for (final body in ['no JSON', '{}', '{"success":true,"data":[{}]}']) {
      handler = (_) async => http.Response(body, 200);
      expect(
        (await api.fetchPasar(
          expectedSession: await session.snapshot(),
        )).failure?.kind,
        ApiErrorKind.invalidResponse,
      );
    }
  });
  test(
    'multipart binary boundary size and type; edit without photo is JSON',
    () async {
      final dir = await Directory.systemTemp.createTemp('pasar-photo');
      addTearDown(() => dir.delete(recursive: true));
      final photo = File('${dir.path}/image.png');
      await photo.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 255, 1]);
      expect((await create(photo: photo)).isSuccess, isTrue);
      expect(
        requests.single.headers['content-type'],
        contains('multipart/form-data; boundary='),
      );
      expect(
        requests.single.bodyBytes,
        containsAllInOrder([137, 80, 78, 71, 13, 10, 26, 10, 0, 255, 1]),
      );
      expect(
        latin1.decode(requests.single.bodyBytes),
        contains('name="foto"; filename="foto.png"'),
      );
      await photo.writeAsBytes(List.filled(2048 * 1024 + 1, 0));
      expect(
        (await create(photo: photo)).failure?.kind,
        ApiErrorKind.validation,
      );
      await photo.writeAsBytes([1, 2, 3]);
      expect(
        (await create(photo: photo)).failure?.kind,
        ApiErrorKind.validation,
      );
      final gif = File('${dir.path}/image.gif');
      await gif.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      expect((await create(photo: gif)).failure?.kind, ApiErrorKind.validation);
      expect(requests, hasLength(1));
      final exact = List<int>.filled(2048 * 1024, 0);
      exact.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
      await photo.writeAsBytes(exact);
      expect((await create(photo: photo)).isSuccess, isTrue);
    },
  );
  for (final status in [403, 404, 422, 429]) {
    test('$status typed failure never logs out', () async {
      handler = (_) async =>
          http.Response('{"errors":{"harga":["secret"]}}', status);
      final result = await create();
      expect(result.statusCode, status);
      expect(session.hasSession, isTrue);
      expect(result.failure!.message, isNot(contains('secret')));
      if (status == 422) {
        expect(
          result.failure!.fieldErrors['harga']!.single,
          isNot(contains('secret')),
        );
      }
      expect(requests, hasLength(1));
    });
  }
  test('private 401 centralized and stale A 401 cannot invalidate B', () async {
    final owner = await session.snapshot();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    final flight = api.fetchPasar(expectedSession: owner);
    await Future<void>.delayed(Duration.zero);
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    pending.complete(http.Response('{}', 401));
    expect((await flight).failure?.kind, ApiErrorKind.staleSession);
    expect(await session.readToken(), 'B');
    final before = requests.length;
    expect(
      (await create(owner: owner)).failure?.kind,
      ApiErrorKind.staleSession,
    );
    expect(requests.length, before);
    handler = (_) async => http.Response('{}', 401);
    await api.fetchPasar(expectedSession: await session.snapshot());
    expect(session.hasSession, isFalse);
  });
  testWidgets('local filters and ownership with plaintext and external image', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => listResponse([
      product(),
      {
        ...product(id: 11, owner: 2),
        'kategori': 'laut',
        'foto': 'https://res.cloudinary.com/demo/image.png',
      },
    ]);
    await tester.pumpWidget(MaterialApp(home: PasarScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(find.text('<b>Ikan sehat</b>'), findsWidgets);
    await tester.tap(find.text('Semua kategori').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('laut').last);
    await tester.pumpAndSettle();
    expect(find.text('Lele 10'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    final image =
        tester.widget<Image>(find.byType(Image).first).image as NetworkImage;
    expect(image.url, 'https://res.cloudinary.com/demo/image.png');
    expect(image.headers, isNull);
    expect(requests, hasLength(1));
  });
  testWidgets('edit without optional changes omits values and old image', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: EditJualanScreen(api: api, jualan: product()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    await tester.pumpAndSettle();
    final body = jsonDecode(requests.single.body) as Map;
    for (final key in ['stok', 'kategori', 'tipe_penjualan', 'foto']) {
      expect(body.containsKey(key), isFalse);
    }
  });
  testWidgets('direct edit denied for non owner, even with local admin role', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: EditJualanScreen(api: api, jualan: product(owner: 2)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Akses atau data Pasar tidak tersedia.'), findsOneWidget);
    expect(find.text('SIMPAN PERUBAHAN'), findsNothing);
    expect(requests, isEmpty);
  });
  testWidgets('form 320 large text keyboard light dark has no overflow', (
    tester,
  ) async {
    await initialize();
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.8),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: TambahJualanScreen(api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('POSTING JUALAN SEKARANG'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(requests, isEmpty);
  });
  testWidgets('429 local cooldown blocks refresh without retry', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => http.Response('{}', 429);
    await tester.pumpWidget(MaterialApp(home: PasarScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Jeda lokal'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Muat ulang Pasar',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(requests, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('422 retains draft and duplicate submission is blocked', (
    tester,
  ) async {
    await initialize();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: EditJualanScreen(api: api, jualan: product()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Draft pribadi');
    await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    await tester.pump();
    expect(requests, hasLength(1));
    pending.complete(
      http.Response('{"errors":{"nama_ikan":["secret raw"]}}', 422),
    );
    await tester.pumpAndSettle();
    expect(find.text('Draft pribadi'), findsOneWidget);
    expect(find.textContaining('secret raw'), findsNothing);
    expect(find.textContaining('nama_ikan:'), findsOneWidget);
  });
  testWidgets('late A list cannot render after account B replaces session', (
    tester,
  ) async {
    await initialize();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.pumpWidget(MaterialApp(home: PasarScreen(api: api)));
    await tester.pump();
    await tester.pump();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    pending.complete(listResponse([product()]));
    await tester.pumpAndSettle();
    expect(find.text('Lele 10'), findsNothing);
    expect(await session.readToken(), 'B');
  });
  testWidgets('successful delete then failed refresh never repeats mutation', (
    tester,
  ) async {
    await initialize();
    var reads = 0;
    handler = (r) async {
      if (r.method == 'DELETE') {
        return http.Response('{"message":"deleted"}', 200);
      }
      return ++reads == 1
          ? listResponse([product()])
          : http.Response('{}', 503);
    };
    await tester.pumpWidget(MaterialApp(home: PasarScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Jualan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aksi sudah berhasil'), findsOneWidget);
    await tester.tap(find.text('Periksa ulang daftar'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'DELETE'), hasLength(1));
  });
  testWidgets('mutation timeout offers list check not automatic resubmit', (
    tester,
  ) async {
    await initialize();
    api = ApiService(
      session: session,
      client: ApiClient(
        session: session,
        baseUrl: Uri.parse('https://example.test/api'),
        timeout: const Duration(seconds: 1),
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return Completer<http.Response>().future;
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EditJualanScreen(api: api, jualan: product()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Hasil aksi belum dapat dipastikan'),
      findsOneWidget,
    );
    expect(find.text('Periksa ulang daftar'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(requests, hasLength(1));
  });
  for (final header in [false, true]) {
    testWidgets('cooldown resume deadline with header=$header', (tester) async {
      await initialize();
      var now = DateTime.now();
      handler = (_) async => http.Response(
        '{}',
        429,
        headers: header ? {'retry-after': '60'} : {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PasarScreen(api: api, clock: () => now),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 70));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Muat ulang Pasar',
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('direct private list add edit reject guest before requests', (
    tester,
  ) async {
    await initialize();
    await session.invalidate(await session.snapshot());
    for (final screen in [
      PasarScreen(api: api),
      TambahJualanScreen(api: api),
      EditJualanScreen(api: api, jualan: product()),
    ]) {
      await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: screen));
      await tester.pumpAndSettle();
      expect(find.text('SIMPAN PERUBAHAN'), findsNothing);
      expect(find.text('POSTING JUALAN SEKARANG'), findsNothing);
      expect(find.text('Lele 10'), findsNothing);
    }
    expect(requests, isEmpty);
  });
  testWidgets('late edit A success cannot restore draft or pop B', (
    tester,
  ) async {
    await initialize();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: EditJualanScreen(api: api, jualan: product()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Draft A');
    await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    await tester.pump();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpAndSettle();
    pending.complete(
      http.Response(jsonEncode({'success': true, 'data': product()}), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Draft A'), findsNothing);
    expect(find.text('Jualan berhasil diperbarui!'), findsNothing);
    expect(await session.readToken(), 'B');
  });
  testWidgets('list and edit 320 large text light dark remain usable', (
    tester,
  ) async {
    await initialize();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final edit in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(1.8),
              ),
              child: edit
                  ? EditJualanScreen(api: api, jualan: product())
                  : PasarScreen(api: api),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.text(edit ? 'SIMPAN PERUBAHAN' : 'NEGO VIA WHATSAPP'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
