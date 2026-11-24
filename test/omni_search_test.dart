import 'dart:async';
import 'dart:convert';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/home_services.dart';
import 'package:aquara_mobile/widgets/session_boundary.dart';
import 'package:aquara_mobile/screens/perizinan_screen.dart';
import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/widgets/omni_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

const kinds = ['pasar', 'forum', 'berita'];
http.Response ok(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);
http.Response groups({int page = 1, String suffix = ''}) => ok({
  for (final k in kinds)
    k: {
      'data': [
        {
          'type': k,
          'id': k == 'forum' ? page : 1,
          'title': k == 'forum' ? null : '$k$suffix',
          'summary': 'cuplikan $k $page',
          'thumbnail': null,
        },
      ],
      'meta': {
        'total': 2,
        'current_page': k == 'forum' ? page : 1,
        'last_page': 2,
        'per_page': 1,
        'has_more_pages': k == 'forum' && page == 1,
      },
    },
});
Future<ApiService> mount(
  WidgetTester t,
  Future<http.Response> Function(http.Request) send, {
  bool login = true,
}) async {
  final s = SessionService(store: FakeTokenStore());
  await s.snapshot();
  if (login) {
    await s.saveIfCurrent('synthetic', user: {'id': 1, 'name': 'Test'});
  }
  final api = ApiService(
    session: s,
    client: ApiClient(
      session: s,
      baseUrl: Uri.parse('https://example.test/api'),
      clientFactory: () => MockClient(send),
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      home: SessionBoundary(
        private: false,
        api: api,
        builder: (context) => ServiceCatalogScreen(
          api: api,
          services: [
            HomeService(
              id: 'perizinan',
              label: 'Perizinan',
              order: 1,
              group: ServiceGroup.additional,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PerizinanScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return api;
}

final field = find.byKey(const Key('catalog-search'));
Future<void> submit(WidgetTester t, String text) async {
  await t.enterText(field, text);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pump();
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final afterLogout in [false, true]) {
    testWidgets(
      'public guide and Back from ${afterLogout ? "buyer logout" : "Login"}',
      (t) async {
        final session = SessionService(store: FakeTokenStore());
        const buyer = {'id': 1, 'name': 'Pembeli uji'};
        if (afterLogout) await session.saveIfCurrent('buyer', user: buyer);
        final requests = <String>[];
        MockClient transport() => MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          return switch (r.url.path) {
            '/api/search' => groups(suffix: '-pembeli'),
            '/api/logout' => ok({}),
            '/api/user' => http.Response(jsonEncode(buyer), 200),
            '/api/login' => http.Response(
              jsonEncode({
                'success': true,
                'token': 'new-session',
                'data': buyer,
              }),
              200,
            ),
            '/api/fish-types' => http.Response(
              '{"status":"success","data":[]}',
              200,
            ),
            _ => http.Response('{}', 404),
          };
        });
        final api = ApiService(
          session: session,
          client: ApiClient(
            session: session,
            baseUrl: Uri.parse('https://example.test/api'),
            clientFactory: transport,
          ),
        );
        var authenticated = false;
        await http.runWithClient(() async {
          await t.pumpWidget(
            MaterialApp(
              home: afterLogout
                  ? HomeScreen(api: api)
                  : LoginScreen(
                      api: api,
                      onAuthenticated: () => authenticated = true,
                    ),
            ),
          );
          await t.pumpAndSettle();
          if (afterLogout) {
            await tap(t, find.byKey(const Key('home-search')));
            await submit(t, 'pembeli');
            await t.pumpAndSettle();
            expect(find.text('pasar-pembeli'), findsOneWidget);
            await t.pageBack();
            await t.pumpAndSettle();
            await tap(t, find.text('Profil'));
            await tap(t, find.byIcon(Icons.logout));
            await tap(t, find.widgetWithText(TextButton, 'Keluar'));
            expect(requests, contains('POST /api/logout'));
            expect(session.hasSession, isFalse);
          }
          final before = List.of(requests);
          expect(find.byType(LoginScreen), findsOneWidget);
          await tap(t, find.text('Jelajahi layanan publik'));
          expect(find.text('Semua Layanan'), findsOneWidget);
          expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
          await submit(t, 'pembeli');
          await t.pumpAndSettle();
          expect(
            find.text('Login untuk mencari konten Pasar, Forum, dan Berita.'),
            findsOneWidget,
          );
          expect(find.text('pasar-pembeli', skipOffstage: false), findsNothing);
          expect(find.byType(OmniResults, skipOffstage: false), findsNothing);
          await submit(t, 'Perizinan');
          await t.pumpAndSettle();
          await tap(t, find.byKey(const ValueKey('service-perizinan')));
          await tap(t, find.byKey(const ValueKey('guide-topic-kusuka')));
          expect(find.byType(PerizinanDetailScreen), findsOneWidget);
          for (final screen in [
            PerizinanScreen,
            ServiceCatalogScreen,
            LoginScreen,
          ]) {
            await t.pageBack();
            await t.pumpAndSettle();
            expect(find.byType(screen), findsOneWidget);
          }
          expect(
            Navigator.of(t.element(find.byType(LoginScreen))).canPop(),
            isFalse,
          );
          expect(requests, before);
          expect(session.hasSession, isFalse);
          if (!afterLogout) {
            await t.enterText(
              find.byType(TextFormField).first,
              'buyer@example.test',
            );
            await t.enterText(find.byType(TextFormField).last, 'test-password');
            await t.testTextInput.receiveAction(TextInputAction.done);
            await t.pumpAndSettle();
            await tap(t, find.widgetWithText(FilledButton, 'Masuk'));
            expect(authenticated, isTrue);
            expect(session.hasSession, isTrue);
            expect(requests, ['POST /api/login']);
          }
          await t.pumpWidget(const SizedBox());
        }, transport);
      },
    );
  }
  testWidgets('guest: layanan publik dengan keyboard kecil tanpa HTTP', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 720);
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearTextScaleFactorTestValue();
    });
    var calls = 0;
    await mount(t, (r) async {
      calls++;
      return groups();
    }, login: false);
    await submit(t, 'Perizinan');
    expect(find.textContaining('Login untuk mencari'), findsOneWidget);
    await tap(t, find.widgetWithText(ServiceTile, 'Perizinan'));
    expect(find.byType(PerizinanScreen), findsOneWidget);
    expect(calls, 0);
  });
  testWidgets(
    'same ID opens three full objects; pagination, back and double tap',
    (t) async {
      final paths = <String>[];
      await mount(t, (r) async {
        paths.add(r.url.path);
        expect(r.method, 'GET');
        switch (r.url.path) {
          case '/api/search':
            expect(r.url.queryParameters['q'], 'ikan & %');
            return groups(
              page: r.url.queryParameters.containsKey('forum_page') ? 2 : 1,
              suffix: r.url.queryParameters.containsKey('forum_page')
                  ? 'ignored'
                  : '',
            );
          case '/api/pasars/1':
            return ok({
              'id': 1,
              'user_id': 2,
              'nama_ikan': 'Produk lengkap',
              'harga': 15,
              'lokasi': 'TPI',
              'deskripsi': 'Produk isi',
              'nomor_wa': '',
              'stok': 1,
            });
          case '/api/forum/1':
            return ok({
              'id': 1,
              'user_id': '2',
              'content': 'Posting lengkap',
              'likes_count': 1,
              'comments_count': 4,
              'root_comments_count': 2,
              'is_liked_by_me': false,
              'comments': [],
            });
          case '/api/posts/1':
            return ok({
              'id': 1,
              'title': 'Berita lengkap',
              'content': 'Artikel lengkap',
              'created_at': '2026-11-01',
            });
          default:
            throw StateError('Unexpected path');
        }
      });
      await submit(t, '\u3000');
      expect(paths, isEmpty);
      await submit(t, '\u3000ikan & %\u00a0');
      await t.pumpAndSettle();
      await tap(t, find.text('Muat lagi Forum'));
      expect(find.text('cuplikan forum 2'), findsOneWidget);
      expect(find.textContaining('ignored'), findsNothing);
      for (final kind in kinds) {
        final tile = find.byKey(ValueKey('$kind-1'));
        await t.ensureVisible(tile);
        await t.tap(tile);
        await t.tap(tile, warnIfMissed: false);
        await t.pumpAndSettle();
        expect(
          find.text(
            {
              'pasar': 'Produk lengkap',
              'forum': 'Posting lengkap',
              'berita': 'Artikel lengkap',
            }[kind]!,
          ),
          findsOneWidget,
        );
        if (kind == 'forum') expect(find.text('4 komentar'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        expect(tile, findsOneWidget);
        expect(find.text('cuplikan forum 2'), findsOneWidget);
      }
      expect(paths, [
        '/api/search',
        '/api/search',
        '/api/pasars/1',
        '/api/forum/1',
        '/api/posts/1',
      ]);
    },
  );
  testWidgets('old query and old account ignored', (t) async {
    final old = Completer<http.Response>(),
        pending = Completer<http.Response>();
    final api = await mount(
      t,
      (r) async => switch (r.url.queryParameters['q']) {
        'old' => old.future,
        'pending' => pending.future,
        _ => groups(),
      },
    );
    await submit(t, 'old');
    await submit(t, 'new');
    await t.pumpAndSettle();
    old.complete(groups(suffix: 'OLD'));
    await t.pumpAndSettle();
    expect(find.text('pasarOLD'), findsNothing);
    expect(find.text('pasar'), findsOneWidget);
    await submit(t, 'pending');
    await api.session.saveIfCurrent(
      'second',
      user: {'id': 2, 'name': 'Second'},
    );
    pending.complete(groups(suffix: 'PRIVATE'));
    await t.pumpAndSettle();
    expect(find.text('pasarPRIVATE'), findsNothing);
    expect(field, findsNothing);
  });
  testWidgets(
    '422, empty groups, mismatched ID and search cooldown leave local discovery available',
    (t) async {
      var searches = 0;
      await mount(t, (r) async {
        if (r.url.path == '/api/posts/1') {
          return ok({'id': 2, 'title': 'Wrong', 'content': 'Wrong'});
        }
        searches++;
        return switch (searches) {
          1 => http.Response('{}', 422),
          2 => ok({
            for (final k in kinds)
              k: {
                'data': [],
                'meta': {
                  'current_page': 1,
                  'total': 0,
                  'last_page': 1,
                  'per_page': 10,
                  'has_more_pages': false,
                },
              },
          }),
          3 => groups(),
          _ => http.Response('{}', 429, headers: {'retry-after': '30'}),
        };
      });
      await submit(t, '🐟' * 101);
      await t.pumpAndSettle();
      expect(searches, 0);
      await submit(t, 'periksa');
      await t.pumpAndSettle();
      expect(find.textContaining('Periksa kata'), findsOneWidget);
      await submit(t, 'kosong');
      await t.pumpAndSettle();
      expect(find.text('Tidak ada hasil.'), findsNWidgets(3));
      await submit(t, '🐟' * 100);
      await t.pumpAndSettle();
      await tap(t, find.byKey(const ValueKey('berita-1')));
      expect(find.text('Format respons tidak sesuai.'), findsOneWidget);
      await submit(t, 'lagi');
      await t.pumpAndSettle();
      await submit(t, 'Perizinan');
      await t.pumpAndSettle();
      expect(find.textContaining('Cari kembali dalam'), findsOneWidget);
      await tap(t, find.widgetWithText(ServiceTile, 'Perizinan'));
      expect(find.byType(PerizinanScreen), findsOneWidget);
      expect(searches, 4);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('404, failed next page and separate detail cooldown', (t) async {
    final paths = <String>[];
    await mount(t, (r) async {
      paths.add(r.url.path);
      if (r.url.queryParameters.containsKey('forum_page')) return ok({});
      if (r.url.path.endsWith('/search')) return groups();
      if (r.url.path.contains('/forum/')) return http.Response('{}', 404);
      return http.Response('{}', 429, headers: {'retry-after': '30'});
    });
    await submit(t, 'ikan');
    await t.pumpAndSettle();
    await tap(t, find.text('Muat lagi Forum'));
    expect(find.text('Format respons tidak sesuai.'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('forum-1')));
    expect(find.text('Konten tidak tersedia.'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('pasar-1')));
    expect(find.textContaining('Buka konten dalam'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('berita-1')));
    await submit(t, 'lain');
    await t.pumpAndSettle();
    expect(paths, [
      '/api/search',
      '/api/search',
      '/api/forum/1',
      '/api/pasars/1',
      '/api/search',
    ]);
    await t.pumpWidget(const SizedBox());
  });
}
