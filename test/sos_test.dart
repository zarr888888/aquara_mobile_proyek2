import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aquara_mobile/models/sos_report.dart';
import 'package:aquara_mobile/screens/sos_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/services/sos_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

Map<String, Object?> report({int id = 1}) => {
  'id': id,
  'jenis_sos': 'Wabah Penyakit',
  'deskripsi': 'Laporan uji',
  'status_laporan': 'Pending',
  'foto': null,
  'created_at': 'rusak',
};
http.Response envelope(Object? data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late SessionService session;
  late ApiService api;
  late SessionSnapshot owner;
  late Future<http.Response> Function(http.Request) handler;
  late DateTime now;
  final requests = <http.Request>[];

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    now = DateTime.utc(2026, 10, 9);
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    owner = await session.snapshot();
    handler = (r) async => envelope(
      r.url.path.endsWith('/1')
          ? report()
          : r.method == 'POST'
          ? report()
          : <Object?>[],
      r.method == 'POST' ? 201 : 200,
    );
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clock: () => now,
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  setUp(initialize);

  void sosWidget(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      await initialize();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        final disposed = session.dispose();
        await tester.pump();
        await disposed;
      });
      await body(tester);
    });
  }

  Future<void> show(
    WidgetTester tester, {
    SosPage page = SosPage.form,
    Future<XFile?> Function(ImageSource)? picker,
    bool dark = false,
    bool small = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        builder: small
            ? (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.8),
                  viewInsets: const EdgeInsets.only(bottom: 200),
                ),
                child: child!,
              )
            : null,
        home: SosScreen(
          api: api,
          page: page,
          id: 1,
          pickPhoto: picker,
          clock: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> draft(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Laporan uji');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  test(
    'GET list/detail method path headers empty body/query and id rejection',
    () async {
      expect((await api.sosHistory(expectedSession: owner)).data, isEmpty);
      expect((await api.sosDetail(1, expectedSession: owner)).data!.id, 1);
      expect(
        (await api.sosDetail(-1, expectedSession: owner)).isSuccess,
        false,
      );
      expect(requests.map((r) => r.url.path), [
        '/api/lapor-darurat',
        '/api/lapor-darurat/1',
      ]);
      for (final r in requests) {
        expect(r.method, 'GET');
        expect(r.body, isEmpty);
        expect(r.url.query, isEmpty);
        expect(r.headers['Authorization'], 'Bearer A');
        expect(r.headers['Accept'], 'application/json');
      }
      handler = (_) async => envelope(report(id: 2));
      expect(
        (await api.sosDetail(1, expectedSession: owner)).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
    },
  );
  for (final type in sosTypes) {
    test('JSON allowlist and exact description boundary $type', () async {
      final result = await api.sendSos(
        expectedSession: owner,
        type: type,
        description: 'x' * 5000,
      );
      expect(result.statusCode, 201);
      expect(result.isSuccess, true);
      expect(jsonDecode(requests.single.body), {
        'jenis_sos': type,
        'deskripsi': 'x' * 5000,
      });
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/lapor-darurat');
      for (final description in ['', ' ', 'x' * 5001]) {
        expect(
          (await api.sendSos(
            expectedSession: owner,
            type: type,
            description: description,
          )).failure!.kind,
          ApiErrorKind.validation,
        );
      }
      expect(requests.length, 1);
    });
  }
  test('unknown type rejected without request', () async {
    expect(
      (await api.sendSos(
        expectedSession: owner,
        type: 'wabah penyakit',
        description: 'test',
      )).isSuccess,
      false,
    );
    expect(requests, isEmpty);
  });
  for (final png in [true, false]) {
    test('binary signature exact 2048 KB and oversize png=$png', () async {
      final bytes = Uint8List(2048 * 1024);
      final signature = png
          ? [137, 80, 78, 71, 13, 10, 26, 10]
          : [255, 216, 255];
      bytes.setRange(0, signature.length, signature);
      final photo = await SosPhoto.read(
        XFile.fromData(bytes, name: 'private-path.txt'),
      );
      expect(
        (await api.sendSos(
          expectedSession: owner,
          type: sosTypes.first,
          description: 'test',
          photo: photo,
        )).isSuccess,
        true,
      );
      final r = requests.single;
      expect(
        r.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = latin1.decode(r.bodyBytes);
      expect(body, contains('filename="foto.${png ? 'png' : 'jpg'}"'));
      expect(body, contains('name="jenis_sos"'));
      expect(body, contains('name="deskripsi"'));
      for (final field in [
        'user_id',
        'status_laporan',
        'admin_id',
        'private-path',
      ]) {
        expect(body, isNot(contains(field)));
      }
      expect(r.bodyBytes.length, greaterThan(bytes.length));
      await expectLater(
        SosPhoto.read(XFile.fromData(Uint8List.fromList([...bytes, 0]))),
        throwsFormatException,
      );
      await expectLater(
        SosPhoto.read(XFile.fromData(Uint8List(20), name: 'foto.png')),
        throwsFormatException,
      );
      expect(requests.length, 1);
    });
  }
  test('nullable/invalid photos dates and unknown status are safe', () {
    final parsed = SosReport.parse({
      ...report(),
      'status_laporan': 'unknown',
      'foto': 'javascript:alert(1)',
    });
    expect(parsed.photo, isNull);
    expect(parsed.createdAt, isNull);
    expect(parsed.status, 'Status belum tersedia');
    expect(
      SosReport.parse({...report(), 'foto': 'https://images.test/a.png'}).photo,
      'https://images.test/a.png',
    );
    expect(
      SosReport.parse({...report(), 'foto': 'a.png'}).photo,
      endsWith('/storage/a.png'),
    );
    expect(SosReport.parse(report()).photo, isNull);
  });
  for (final body in [
    '<html>private</html>',
    '{}',
    '{"success":true,"data":[{}]}',
  ]) {
    test('invalid envelopes and non JSON $body', () async {
      handler = (_) async => http.Response(body, 200);
      expect(
        (await api.sosHistory(expectedSession: owner)).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
      expect(
        (await api.sosDetail(1, expectedSession: owner)).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
      expect(
        (await api.sendSos(
          expectedSession: owner,
          type: sosTypes.first,
          description: 'test',
        )).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
    });
  }
  for (final status in [401, 403, 404, 422, 429, 503]) {
    test('HTTP $status centralized session behavior no retries', () async {
      handler = (_) async => http.Response('private raw body', status);
      final result = await api.sendSos(
        expectedSession: owner,
        type: sosTypes.first,
        description: 'test',
      );
      expect(result.statusCode, status);
      expect(result.isSuccess, false);
      expect(result.failure!.message, isNot(contains('private raw body')));
      expect(session.hasSession, status != 401);
      expect(requests.length, 1);
    });
  }
  for (final method in ['GET', 'POST']) {
    for (final status in [200, 401]) {
      test('late $method $status A after B does not change B', () async {
        final started = Completer<void>();
        final response = Completer<http.Response>();
        handler = (_) {
          started.complete();
          return response.future;
        };
        final future = method == 'POST'
            ? api.sendSos(
                expectedSession: owner,
                type: sosTypes.first,
                description: 'test',
              )
            : api.sosHistory(expectedSession: owner);
        await started.future;
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        response.complete(
          status == 401
              ? http.Response('{}', 401)
              : envelope(
                  method == 'POST' ? report() : [report()],
                  method == 'POST' ? 201 : 200,
                ),
        );
        final result = await future;
        expect(result.failure!.kind, ApiErrorKind.staleSession);
        expect(session.metadata['user_name'], 'B');
        expect(session.hasSession, true);
      });
    }
  }
  sosWidget(
    'submit once success detail and history refresh failure never reposts',
    (tester) async {
      final response = Completer<http.Response>();
      handler = (r) async => r.method == 'POST'
          ? response.future
          : r.url.path.endsWith('/1')
          ? envelope(report())
          : http.Response('{}', 503);
      await show(tester);
      await draft(tester);
      await tap(tester, 'Kirim laporan');
      await tap(tester, 'Kirim laporan');
      expect(requests.length, 1);
      response.complete(envelope(report(), 201));
      await tester.pumpAndSettle();
      expect(find.text('Laporan berhasil dikirim.'), findsOneWidget);
      await tap(tester, 'Lihat detail status');
      await tester.pumpAndSettle();
      expect(find.text('Detail SOS'), findsOneWidget);
      expect(find.text('Status: Pending'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Periksa riwayat saya');
      await tester.pumpAndSettle();
      expect(
        find.text('Layanan sedang tidak tersedia. Silakan coba kembali nanti.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Laporan berhasil dikirim.'), findsOneWidget);
      expect(requests.where((r) => r.method == 'POST').length, 1);
      await close(tester);
    },
  );
  sosWidget('history loading empty manual retry then detail navigation', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    handler = (_) => response.future;
    await tester.pumpWidget(
      MaterialApp(
        home: SosScreen(api: api, page: SosPage.history),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(envelope([]));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada laporan.'), findsOneWidget);
    handler = (r) async =>
        envelope(r.url.path.endsWith('/1') ? report() : [report()]);
    await tap(tester, 'Muat ulang');
    await tester.pumpAndSettle();
    await tap(tester, 'Wabah Penyakit');
    await tester.pumpAndSettle();
    expect(find.text('Tanggal tidak tersedia'), findsOneWidget);
    expect(find.text('Tidak ada foto'), findsOneWidget);
    await close(tester);
  });
  for (final status in [422, 503]) {
    sosWidget('UI $status keeps draft sanitized and manual retry', (
      tester,
    ) async {
      handler = (_) async =>
          http.Response('{"errors":{"deskripsi":["private"]}}', status);
      await show(tester);
      await draft(tester);
      await tap(tester, 'Kirim laporan');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Laporan uji',
      );
      expect(find.textContaining('private'), findsNothing);
      expect(
        find.textContaining(
          status == 503 ? 'laporan tidak dibuat' : 'deskripsi:',
        ),
        findsOneWidget,
      );
      expect(requests.length, 1);
      await close(tester);
    });
  }
  for (final status in [401, 403, 404]) {
    sosWidget('private UI $status centralized guard and Back', (tester) async {
      handler = (_) async => http.Response('{}', status);
      await show(tester, page: SosPage.detail);
      expect(session.hasSession, status != 401);
      expect(requests.length, 1);
      if (status == 401) {
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          false,
        );
      } else {
        expect(find.text('Detail SOS'), findsOneWidget);
        expect(
          find.textContaining(
            status == 403 ? 'Akses ditolak' : 'Data tidak ditemukan',
          ),
          findsOneWidget,
        );
      }
      await close(tester);
    });
  }
  sosWidget('logout discards draft and Back cannot restore it', (tester) async {
    await show(tester);
    await draft(tester);
    await session.clear();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Laporan uji'), findsNothing);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      false,
    );
    expect(requests, isEmpty);
    await close(tester);
  });
  for (final header in [true, false]) {
    for (final page in SosPage.values) {
      sosWidget(
        'cooldown header=$header page=$page resume deadline no auto request',
        (tester) async {
          handler = (_) async => http.Response(
            '{}',
            429,
            headers: header ? {'retry-after': '10'} : {},
          );
          await show(tester, page: page);
          if (page == SosPage.form) {
            await draft(tester);
            await tap(tester, 'Kirim laporan');
            await tester.pumpAndSettle();
          }
          expect(
            find.textContaining(
              header ? 'Tunggu 10 detik' : 'Jeda lokal 60 detik',
            ),
            findsOneWidget,
          );
          final count = requests.length;
          await tap(
            tester,
            page == SosPage.form ? 'Kirim laporan' : 'Muat ulang',
          );
          expect(requests.length, count);
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          now = now.add(const Duration(minutes: 2));
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
          await tester.pump();
          expect(requests.length, count);
          expect(find.textContaining('Jeda lokal'), findsNothing);
          await close(tester);
        },
      );
    }
  }
  for (final failure in ['network', 'timeout', 'malformed']) {
    sosWidget(
      'uncertain $failure requires history check before explicit retry',
      (tester) async {
        handler = (r) async {
          if (r.method == 'GET') return envelope([]);
          if (failure == 'network') throw http.ClientException('private');
          if (failure == 'timeout') throw TimeoutException('private');
          return http.Response('{}', 201);
        };
        await show(tester);
        await draft(tester);
        await tap(tester, 'Kirim laporan');
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Hasil pengiriman belum diketahui.'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byType(FilledButton),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tap(tester, 'Periksa riwayat saya');
        await tester.pumpAndSettle();
        expect(find.text('Belum ada laporan.'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(FilledButton),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(requests.where((r) => r.method == 'POST').length, 1);
        await close(tester);
      },
    );
  }
  for (final page in SosPage.values) {
    sosWidget('guest direct $page rejected without SOS request', (
      tester,
    ) async {
      await session.clear();
      await show(tester, page: page);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(requests, isEmpty);
      await close(tester);
    });
    for (final dark in [true, false]) {
      sosWidget('320px large text keyboard $page dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        handler = (r) async =>
            envelope(r.url.path.endsWith('/1') ? report() : [report()]);
        await show(tester, page: page, dark: dark, small: true);
        final button = find.text(
          page == SosPage.form ? 'Kirim laporan' : 'Muat ulang',
        );
        await tester.scrollUntilVisible(
          button,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  }
  sosWidget('picker double tap late A cannot preview or navigate account B', (
    tester,
  ) async {
    final picker = Completer<XFile?>();
    var picks = 0;
    await show(
      tester,
      picker: (_) {
        picks++;
        return picker.future;
      },
    );
    await draft(tester);
    await tap(tester, 'Pilih foto');
    await tap(tester, 'Pilih foto');
    expect(picks, 1);
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpAndSettle();
    picker.complete(XFile.fromData(Uint8List.fromList([255, 216, 255])));
    await tester.pumpAndSettle();
    expect(find.byType(SosScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(session.metadata['user_name'], 'B');
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
  for (final post in [true, false]) {
    for (final unauthorized in [true, false]) {
      sosWidget(
        'late ${post ? 'POST' : 'GET'} unauthorized=$unauthorized after B no UI restoration',
        (tester) async {
          final pending = Completer<http.Response>();
          handler = (_) => pending.future;
          if (post) {
            await show(tester);
            await draft(tester);
            await tap(tester, 'Kirim laporan');
          } else {
            await tester.pumpWidget(
              MaterialApp(
                home: SosScreen(api: api, page: SosPage.history),
              ),
            );
            await tester.pump();
            await tester.pump();
          }
          expect(requests.length, 1);
          await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
          await tester.pumpAndSettle();
          pending.complete(
            unauthorized
                ? http.Response('{}', 401)
                : envelope(post ? report() : [report()], post ? 201 : 200),
          );
          await tester.pumpAndSettle();
          expect(session.metadata['user_name'], 'B');
          expect(session.hasSession, true);
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(find.text('Laporan uji'), findsNothing);
          expect(
            tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
            false,
          );
          await close(tester);
        },
      );
    }
  }
}
