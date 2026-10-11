import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aquara_mobile/screens/edit_profil_screen.dart';
import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/profil_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';
import 'pasar_test.dart' show product, listResponse;

void main() {
  late SessionService session;
  late ApiService api;
  late DateTime now;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  final nav = GlobalKey<NavigatorState>();
  Future<void> initialize(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 10, 8);
    requests.clear();
    session = SessionService(store: FakeTokenStore());
    final ownedSession = session;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final disposal = ownedSession.dispose();
      await tester.pump();
      await disposal;
      final lifecycle = tester.binding.lifecycleState;
      if (lifecycle == AppLifecycleState.paused) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      }
      if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    handler = (r) async => r.url.path.endsWith('user')
        ? http.Response('{"id":1,"name":"A","fokus_budidaya":"Lele"}', 200)
        : r.url.path.endsWith('fish-types')
        ? http.Response('{"status":"success","data":[]}', 200)
        : listResponse([]);
    api = ApiService(
      session: session,
      client: ApiClient(
        session: session,
        baseUrl: Uri.parse('https://example.test/api'),
        clock: () => now,
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  Widget edit({Future<XFile?> Function()? picker}) => EditProfilScreen(
    api: api,
    clock: () => now,
    pickImage: picker,
    currentName: 'A',
    currentFokus: 'Lele',
  );
  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    await tester.pump();
  }

  for (final header in [true, false]) {
    for (final editing in [true, false]) {
      testWidgets(
        'profile ${editing ? "update" : "GET"} 429 header=$header deadline resume no retry',
        (tester) async {
          await initialize(tester);
          handler = (r) async => r.url.path.endsWith('pasars')
              ? listResponse([])
              : http.Response(
                  '{}',
                  429,
                  headers: header ? {'retry-after': '17'} : {},
                );
          await mount(
            tester,
            editing ? edit() : ProfilScreen(api: api, clock: () => now),
          );
          if (editing) {
            await submit(tester);
            await tester.pumpAndSettle();
          }
          expect(
            find.textContaining(header ? 'Tunggu 17' : 'Jeda lokal 60'),
            findsOneWidget,
          );
          final button = find.widgetWithText(
            editing ? ElevatedButton : TextButton,
            editing ? 'SIMPAN PERUBAHAN' : 'Muat ulang',
          );
          expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
          final count = requests.length;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          now = now.add(const Duration(seconds: 70));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(tester.widget<ButtonStyleButton>(button).onPressed, isNotNull);
          expect(requests.length, count);
          await close(tester);
          await tester.pump(const Duration(seconds: 100));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final status in [401, 403, 404, 422, 503]) {
    testWidgets('edit UI $status draft isolation and centralized 401', (
      tester,
    ) async {
      await initialize(tester);
      handler = (_) async => http.Response(
        '{"message":"raw secret","errors":{"name":["raw secret"]}}',
        status,
      );
      await mount(tester, edit());
      await tester.enterText(find.byType(TextFormField).first, 'Draft A');
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('raw secret'), findsNothing);
      expect(session.hasSession, status != 401);
      if (status == 401) {
        expect(find.text('Draft A'), findsNothing);
        expect(find.text('Edit Profil'), findsNothing);
      } else {
        expect(find.text('Draft A'), findsOneWidget);
        if (status == 422) expect(find.textContaining('name:'), findsOneWidget);
        expect(find.text('Edit Profil'), findsOneWidget);
      }
      expect(requests.length, 1);
      await close(tester);
    });
  }
  testWidgets(
    'double submit one mutation, replacement clears draft and late update',
    (tester) async {
      await initialize(tester);
      final pending = Completer<http.Response>();
      handler = (_) => pending.future;
      await mount(tester, edit());
      await tester.enterText(find.byType(TextFormField).first, 'Draft A');
      await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
      await tester.tap(find.text('SIMPAN PERUBAHAN'));
      await tester.tap(find.text('SIMPAN PERUBAHAN'));
      await tester.pump();
      expect(requests.length, 1);
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      await tester.pumpAndSettle();
      pending.complete(
        http.Response('{"success":true,"data":{"id":1,"name":"Draft A"}}', 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft A'), findsNothing);
      expect(session.metadata['user_name'], 'B');
      expect(find.text('Profil Berhasil Diperbarui!'), findsNothing);
      await close(tester);
    },
  );
  testWidgets('picker A completion after B is discarded without upload', (
    tester,
  ) async {
    await initialize(tester);
    final pending = Completer<XFile?>();
    await mount(tester, edit(picker: () => pending.future));
    await tester.enterText(
      find.byType(TextFormField).first,
      'Private picker draft A',
    );
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpAndSettle();
    pending.complete(XFile('never-read-private-A.png'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(EditProfilScreen), findsNothing);
    expect(find.text('Private picker draft A'), findsNothing);
    expect(find.text('SIMPAN PERUBAHAN'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.image is FileImage),
      findsNothing,
    );
    expect(session.metadata['user_name'], 'B');
    await close(tester);
  });
  for (final timeout in [true, false]) {
    testWidgets(
      'uncertain ${timeout ? "timeout" : "network"} requires GET, not automatic resubmit',
      (tester) async {
        await initialize(tester);
        handler = (r) async {
          if (r.method == 'POST') {
            if (timeout) throw TimeoutException('private');
            throw const SocketException('private');
          }
          return http.Response(
            '{"id":1,"name":"Confirmed","fokus_budidaya":"Nila"}',
            200,
          );
        };
        await mount(tester, edit());
        await submit(tester);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Hasil pengiriman belum diketahui'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'SIMPAN PERUBAHAN'),
              )
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(find.text('Muat ulang profil'));
        await tester.tap(find.text('Muat ulang profil'));
        await tester.pumpAndSettle();
        expect(requests.map((r) => r.method), ['POST', 'GET']);
        expect(find.text('Confirmed'), findsOneWidget);
        expect(
          find.textContaining('Hasil pengiriman belum diketahui'),
          findsNothing,
        );
        await close(tester);
      },
    );
  }
  for (final mutation in ['add', 'edit', 'delete']) {
    testWidgets('profile market $mutation real navigation refresh on return', (
      tester,
    ) async {
      await initialize(tester);
      var items = [product(), product(id: 99, owner: 2)];
      handler = (r) async {
        if (r.url.path.endsWith('user')) {
          return http.Response('{"id":1,"name":"A"}', 200);
        }
        if (r.method == 'GET') return listResponse(items);
        if (r.method == 'DELETE') {
          items.removeWhere((p) => p['id'] == 10);
          return http.Response('{"message":"deleted"}', 200);
        }
        final body = jsonDecode(r.body) as Map;
        final changed = {
          ...product(id: mutation == 'add' ? 11 : 10),
          'nama_ikan': body['nama_ikan'],
        };
        if (mutation == 'add') {
          items.add(changed);
        } else {
          items[0] = changed;
        }
        return http.Response(
          jsonEncode({'success': true, 'data': changed}),
          mutation == 'add' ? 201 : 200,
        );
      };
      await mount(tester, ProfilScreen(api: api));
      expect(find.text('Lele 99'), findsNothing);
      await tester.ensureVisible(find.text('Lele 10'));
      await tester.tap(find.text('Lele 10'));
      await tester.pumpAndSettle();
      expect(find.text('Pasar Ikan Indramayu'), findsOneWidget);
      if (mutation == 'add') {
        await tester.tap(find.text('Jual Hasil Tambak'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        // Labels are part of the existing form, not a fake mutation route.
        for (final field in tester.widgetList<TextField>(fields)) {
          final label =
              field.decoration?.labelText ?? field.decoration?.hintText ?? '';
          field.controller!.text =
              label.contains('35000') || label.toLowerCase().contains('harga')
              ? '100'
              : label.toLowerCase().contains('stok')
              ? '1'
              : label.toLowerCase().contains('whatsapp')
              ? '08123456789'
              : 'Added';
        }
        await tester.ensureVisible(find.text('POSTING JUALAN SEKARANG'));
        await tester.tap(find.text('POSTING JUALAN SEKARANG'));
      } else {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(mutation == 'edit' ? 'Edit Jualan' : 'Hapus Jualan'),
        );
        await tester.pumpAndSettle();
        if (mutation == 'edit') {
          await tester.enterText(find.byType(TextFormField).first, 'Edited');
          await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
          await tester.tap(find.text('SIMPAN PERUBAHAN'));
        } else {
          await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
        }
      }
      await tester.pumpAndSettle();
      expect(find.text('Pasar Ikan Indramayu'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.text('Lele 99'), findsNothing);
      expect(
        find.text(
          mutation == 'add'
              ? 'Added'
              : mutation == 'edit'
              ? 'Edited'
              : 'Belum ada stok ikan.',
        ),
        findsOneWidget,
      );
      expect(requests.where((r) => r.method != 'GET').length, 1);
      expect(
        requests
            .where((r) => r.method == 'GET' && r.url.path.endsWith('pasars'))
            .length,
        4,
      );
      final reads = requests.length;
      await session.updateMetadata(await session.snapshot(), {
        'id': 1,
        'name': 'Changed',
      });
      await tester.pumpAndSettle();
      expect(find.text('Changed'), findsOneWidget);
      expect(requests.length, reads);
      await close(tester);
    });
  }

  for (final status in [503, 429]) {
    testWidgets(
      'profile market loading failure $status retry deduplicated then empty',
      (tester) async {
        await initialize(tester);
        final pending = Completer<http.Response>();
        var reads = 0;
        handler = (r) async => r.url.path.endsWith('user')
            ? http.Response('{"id":1,"name":"A"}', 200)
            : ++reads == 1
            ? pending.future
            : listResponse([]);
        await tester.pumpWidget(
          MaterialApp(
            home: ProfilScreen(api: api, clock: () => now),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(reads, 1);
        pending.complete(http.Response('{}', status));
        await tester.pumpAndSettle();
        expect(find.text('Belum ada stok ikan.'), findsNothing);
        final retry = find.widgetWithText(TextButton, 'Coba lagi');
        await tester.ensureVisible(retry);
        if (status == 429) {
          expect(find.textContaining('Jeda lokal'), findsOneWidget);
          expect(tester.widget<TextButton>(retry).onPressed, isNull);
          now = now.add(const Duration(seconds: 61));
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.tap(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.text('Belum ada stok ikan.'), findsOneWidget);
        expect(reads, 2);
        await close(tester);
      },
    );
  }

  testWidgets('profile pending A list cannot render on new B profile', (
    tester,
  ) async {
    await initialize(tester);
    final pending = Completer<http.Response>();
    handler = (r) async => r.url.path.endsWith('user')
        ? http.Response('{"id":1,"name":"A"}', 200)
        : pending.future;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: ProfilScreen(api: api),
      ),
    );
    await tester.pump();
    await tester.pump();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpAndSettle();
    handler = (r) async => r.url.path.endsWith('user')
        ? http.Response('{"id":2,"name":"B"}', 200)
        : listResponse([product(id: 20, owner: 2)]);
    nav.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => ProfilScreen(api: api)),
    );
    await tester.pumpAndSettle();
    pending.complete(listResponse([product()]));
    await tester.pumpAndSettle();
    expect(find.text('Lele 10'), findsNothing);
    expect(find.text('Lele 20'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await close(tester);
  });

  testWidgets(
    'home metadata name photo route preserved then logout clears private data',
    (tester) async {
      await initialize(tester);
      await mount(tester, HomeScreen(api: api));
      expect(find.text('Hallo, A '), findsOneWidget);
      final revision = session.revision;
      final route = nav.currentState;
      await session.updateMetadata(await session.snapshot(), {
        'id': 1,
        'name': 'Updated',
        'foto_profil': 'https://images.example.test/avatar.png',
      });
      await tester.pumpAndSettle();
      expect(find.text('Hallo, Updated '), findsOneWidget);
      final image = tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.image)
          .whereType<NetworkImage>()
          .single;
      expect(image.url, 'https://images.example.test/avatar.png');
      expect(image.headers, isNull);
      expect(nav.currentState, same(route));
      expect(session.revision, revision);
      expect(requests.where((r) => r.url.path.endsWith('user')), isEmpty);
      await session.clear();
      await tester.pumpAndSettle();
      expect(find.textContaining('Updated'), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(session.metadata, isEmpty);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(nav.currentState!.canPop(), false);
      await close(tester);
    },
  );

  testWidgets(
    'guest home and direct profile edit never request private profile',
    (tester) async {
      await initialize(tester);
      await session.clear();
      for (final screen in [
        HomeScreen(api: api),
        ProfilScreen(api: api),
        edit(),
      ]) {
        await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: screen));
        await tester.pumpAndSettle();
        expect(find.text('SIMPAN PERUBAHAN'), findsNothing);
      }
      expect(requests, isEmpty);
      await close(tester);
    },
  );

  testWidgets(
    'old profile GET after edit success preserves UI metadata and route',
    (tester) async {
      await initialize(tester);
      final pending = Completer<http.Response>();
      handler = (r) async => r.url.path.endsWith('user')
          ? pending.future
          : r.method == 'POST'
          ? http.Response('{"success":true,"data":{"id":1,"name":"New"}}', 200)
          : listResponse([]);
      await mount(tester, ProfilScreen(api: api));
      await tester.ensureVisible(find.text('EDIT PROFIL LENGKAP'));
      await tester.tap(find.text('EDIT PROFIL LENGKAP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'New');
      await submit(tester);
      await tester.pumpAndSettle();
      pending.complete(http.Response('{"id":1,"name":"Old"}', 200));
      await tester.pumpAndSettle();
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(session.metadata['user_name'], 'New');
      await close(tester);
    },
  );

  testWidgets(
    'profile metadata photo updates without reads and logout clears route',
    (tester) async {
      await initialize(tester);
      await mount(tester, ProfilScreen(api: api));
      final count = requests.length;
      await session.updateMetadata(await session.snapshot(), {
        'id': 1,
        'name': 'Photo owner',
        'foto_profil': 'avatars/updated.png',
      });
      await tester.pumpAndSettle();
      expect(find.text('Photo owner'), findsOneWidget);
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image)
          .whereType<NetworkImage>();
      expect(images.single.url, endsWith('/storage/avatars/updated.png'));
      expect(images.single.headers, isNull);
      expect(requests.length, count);
      await session.updateMetadata(await session.snapshot(), {
        'id': 1,
        'name': 'Photo owner',
        'foto_profil': 'http://invalid.test/a',
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .where((w) => w.image is NetworkImage),
        isEmpty,
      );
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      expect(find.text('Keluar Akun'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      await tester.pumpAndSettle();
      expect(session.hasSession, false);
      expect(find.text('Photo owner'), findsNothing);
      expect(find.byType(ProfilScreen), findsNothing);
      await close(tester);
    },
  );

  for (final status in [200, 401]) {
    testWidgets('home B unaffected by late profile A $status', (tester) async {
      await initialize(tester);
      final pending = Completer<http.Response>();
      handler = (r) async => r.url.path.endsWith('user')
          ? pending.future
          : http.Response('{"status":"success","data":[]}', 200);
      await mount(tester, HomeScreen(api: api));
      final read = api.currentUser(expectedSession: await session.snapshot());
      await tester.pump();
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'Account B'});
      await tester.pumpAndSettle();
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => HomeScreen(api: api)),
      );
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(
          status == 200 ? '{"id":1,"name":"Late A"}' : '{}',
          status,
        ),
      );
      await tester.pumpAndSettle();
      expect((await read).isSuccess, false);
      expect(find.text('Hallo, Account B '), findsOneWidget);
      expect(find.textContaining('Late A'), findsNothing);
      expect(session.hasSession, true);
      await close(tester);
    });
  }

  testWidgets('profile GET repeated retry taps share one in-flight request', (
    tester,
  ) async {
    await initialize(tester);
    final pending = Completer<http.Response>();
    var reads = 0;
    handler = (r) async => r.url.path.endsWith('pasars')
        ? listResponse([])
        : ++reads == 1
        ? http.Response('{}', 503)
        : pending.future;
    await mount(tester, ProfilScreen(api: api));
    await tester.tap(find.text('Muat ulang'));
    await tester.tap(find.text('Muat ulang'));
    await tester.pump();
    expect(reads, 2);
    pending.complete(http.Response('{"id":1,"name":"Refreshed"}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Refreshed'), findsOneWidget);
    expect(find.textContaining('Pembaruan profil gagal'), findsNothing);
    await close(tester);
  });

  testWidgets(
    'uncertain recovery GET 429 blocks repeated refresh until deadline',
    (tester) async {
      await initialize(tester);
      handler = (r) async {
        if (r.method == 'POST') throw const SocketException('private');
        return http.Response('{}', 429);
      };
      await mount(tester, edit());
      await submit(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Muat ulang profil'));
      await tester.tap(find.text('Muat ulang profil'));
      await tester.tap(find.text('Muat ulang profil'));
      await tester.pumpAndSettle();
      expect(requests.map((r) => r.method), ['POST', 'GET']);
      expect(find.textContaining('Jeda lokal 60'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Muat ulang profil'),
            )
            .onPressed,
        isNull,
      );
      await close(tester);
      await tester.pump(const Duration(seconds: 70));
      expect(requests.length, 2);
    },
  );

  for (final screen in ['home', 'profile', 'edit']) {
    for (final dark in [false, true]) {
      testWidgets('$screen 320 text 1.8 keyboard dark=$dark', (tester) async {
        await initialize(tester);
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(1.8),
                viewInsets: EdgeInsets.only(bottom: 240),
              ),
              child: screen == 'home'
                  ? HomeScreen(api: api)
                  : screen == 'profile'
                  ? ProfilScreen(api: api)
                  : edit(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen == 'edit') {
          await tester.enterText(
            find.byType(TextFormField).first,
            'Nama panjang untuk profil',
          );
          await tester.ensureVisible(find.text('SIMPAN PERUBAHAN'));
          expect(find.text('SIMPAN PERUBAHAN').hitTestable(), findsOneWidget);
        } else if (screen == 'profile') {
          await tester.ensureVisible(find.text('EDIT PROFIL LENGKAP'));
          expect(
            find.text('EDIT PROFIL LENGKAP').hitTestable(),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Belum ada stok ikan.'));
        } else {
          await tester.ensureVisible(
            find.text('Info penyuluhan & berita perikanan'),
          );
          expect(
            find.text('Info penyuluhan & berita perikanan').hitTestable(),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }
  }
}
