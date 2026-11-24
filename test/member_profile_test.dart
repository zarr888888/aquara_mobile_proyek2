import 'dart:async';
import 'dart:convert';
import 'package:aquara_mobile/models/forum_post.dart';
import 'package:aquara_mobile/models/pasar_item.dart';
import 'package:aquara_mobile/models/profile_summary.dart';
import 'package:aquara_mobile/screens/forum_screen.dart';
import 'package:aquara_mobile/screens/forum_comments_screen.dart';
import 'package:aquara_mobile/screens/pasar_screen.dart';
import 'package:aquara_mobile/screens/profil_screen.dart';
import 'package:aquara_mobile/screens/member_profile_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/profile_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as testing;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';
import 'forum_test.dart' as forum;
import 'pasar_test.dart' as pasar;

void main() {
  late SessionService session;
  late ApiService api;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  Map<String, dynamic> user(int id) => {
    'id': id,
    'name': 'Anggota $id',
    'foto_profil': null,
  };
  http.Response profile(int id) =>
      http.Response(jsonEncode({'success': true, 'data': user(id)}), 200);
  http.Response products({
    int page = 1,
    int last = 1,
    List<Object?> rows = const [],
  }) => forum.listing(rows, page: page, last: last);
  Future<void> initialize() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: user(1));
    requests.clear();
    handler = (r) async =>
        r.url.path.endsWith('/pasars') ? products() : profile(2);
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
  // Initialize serialized fake session inside the widget test's async zone.
  void testWidgets(String description, WidgetTesterCallback body) {
    testing.testWidgets(description, (tester) async {
      await initialize();
      await body(tester);
    });
  }

  Future<void> show(WidgetTester t, Widget child) async {
    await t.pumpWidget(MaterialApp(home: child));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  for (final focus in [null, '', 'Lele', 'Nelayan dan pengolahan']) {
    test('profile focus preserves $focus independently of author', () {
      expect(
        ProfileSummary.parse({...user(2), 'fokus_budidaya': focus}, 2).focus,
        focus,
      );
      expect(profileRelation(user(2), '2')!['id'], 2);
    });
  }

  for (final reply in [false, true]) {
    for (final avatar in [false, true]) {
      testWidgets('physical Forum -> comments $reply avatar=$avatar', (
        t,
      ) async {
        handler = (r) async {
          if (r.url.path == '/api/forum') return forum.listing([forum.post()]);
          if (r.url.path == '/api/profiles/2') return profile(2);
          if (r.url.path.endsWith('/pasars')) return products();
          if (r.url.path.endsWith('/replies')) {
            return forum.commentsListing([
              {
                ...forum.comment(id: 11, owner: '2', parent: 10),
                'user': user(2),
              },
            ]);
          }
          return forum.commentsListing([
            {
              ...forum.comment(
                owner: reply ? '1' : '2',
                replies: reply ? 1 : 0,
              ),
              'user': user(reply ? 1 : 2),
            },
          ]);
        };
        await show(t, ForumScreen(api: api));
        await tap(t, find.byTooltip('Komentar'));
        expect(find.byType(ForumCommentsScreen), findsOneWidget);
        await t.enterText(find.byType(TextField), 'draft dipertahankan');
        if (reply) await tap(t, find.text('Lihat balasan (1)'));
        final identity = find.ancestor(
          of: find.text('Anggota 2'),
          matching: find.byType(ProfileIdentity),
        );
        final target = avatar
            ? find.descendant(
                of: identity,
                matching: find.byType(ProfileAvatar),
              )
            : find.text('Anggota 2');
        await tap(t, target);
        expect(find.byType(MemberProfileScreen), findsOneWidget);
        expect(
          requests.where((r) => r.url.path == '/api/profiles/2').length,
          1,
        );
        await t.pageBack();
        await t.pumpAndSettle();
        expect(find.text('draft dipertahankan'), findsOneWidget);
      });
    }
  }

  testWidgets('owner categories across pages route exact Pasar ID and owner', (
    t,
  ) async {
    handler = (r) async {
      if (r.url.path == '/api/profiles/2') return profile(2);
      if (r.url.path == '/api/pasars') {
        return pasar.listResponse([
          pasar.product(id: 71, owner: 2),
          pasar.product(id: 72, owner: 3),
        ]);
      }
      final page = int.parse(r.url.queryParameters['page']!);
      expect(r.url.queryParameters.keys.toSet(), {'page', 'per_page'});
      return products(
        page: page,
        last: 3,
        rows: [
          {
            ...pasar.product(id: 70 + page, owner: 2),
            'kategori': ['olahan', 'laut', 'tawar'][page - 1],
            'stok': 999,
          },
        ],
      );
    };
    await show(t, MemberProfileScreen(api: api, userId: 2));
    expect(find.text('Belum ada pada halaman yang dimuat.'), findsOneWidget);
    await tap(t, find.text('Muat produk berikutnya'));
    await tap(t, find.text('Muat produk berikutnya'));
    for (final id in [71, 72, 73]) {
      expect(find.text('Lele $id'), findsOneWidget);
    }
    await tap(t, find.byKey(const ValueKey('profile-product-71')));
    final screen = t.widget<PasarScreen>(find.byType(PasarScreen));
    expect(screen.targetItemId, 71);
    expect(screen.targetOwnerId, 2);
    expect(find.text('Lele 72'), findsNothing);
    expect(find.text('Edit Jualan'), findsNothing);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byType(MemberProfileScreen), findsOneWidget);
    for (final id in [71, 72, 73]) {
      expect(find.text('Lele $id'), findsOneWidget);
    }
  });

  testWidgets('missing or transferred target does not show another product', (
    t,
  ) async {
    handler = (_) async =>
        pasar.listResponse([pasar.product(id: 71, owner: 3)]);
    await show(t, PasarScreen(api: api, targetItemId: 71, targetOwnerId: 2));
    expect(
      find.text('Produk tidak tersedia atau sudah dihapus.'),
      findsOneWidget,
    );
    expect(find.text('Lele 71'), findsNothing);
  });

  testWidgets('actual Forum null author root/reply never links legacy name', (
    t,
  ) async {
    handler = (r) async {
      if (r.url.path == '/api/forum') return forum.listing([forum.post()]);
      return forum.commentsListing([
        forum.comment(owner: 'legacy-name', content: 'Tanpa akun'),
      ]);
    };
    await show(t, ForumScreen(api: api));
    await tap(t, find.byTooltip('Komentar'));
    await tap(t, find.text('Sama'));
    expect(find.byType(MemberProfileScreen), findsNothing);
    expect(requests.any((r) => r.url.path.contains('/profiles/')), false);
    expect(find.byTooltip('Profil penulis tidak tersedia'), findsOneWidget);
  });
  test(
    'allowlist and canonical relation: legacy/deleted/invalid never navigate',
    () {
      for (final owner in ['nama-lama', '01', '0', '-2', '1.0']) {
        final parsed = parseForumItem({
          ...forum.comment(owner: owner),
          'user': null,
        }, comment: true);
        expect(parsed['profile'], isNull);
      }
      for (final raw in [
        null,
        {'id': 0, 'name': 'x'},
        {'id': '2', 'name': 'x'},
        user(3),
      ]) {
        expect(profileRelation(raw, 2), isNull);
      }
      final relation = {...user(2), 'email': 'secret', 'phone': 'secret'};
      expect(
        parseForumItem({...forum.post(owner: 2), 'user': relation})['profile'],
        user(2),
      );
      expect(
        parsePasarItem({
          ...pasar.product(owner: 2),
          'user': relation,
        })['profile'],
        user(2),
      );
      expect(profileRelation(user(2), '02'), isNull);
    },
  );

  test(
    'profile paths, bearer, strict envelopes, pagination URL ignored',
    () async {
      handler = (r) async => r.url.path.endsWith('/pasars')
          ? products(page: 2, last: 2, rows: [pasar.product(owner: 2)])
          : profile(2);
      final owner = await session.snapshot();
      expect((await api.fetchProfile(2, expectedSession: owner)).data!.id, 2);
      expect(
        (await api.fetchProfileProducts(
          2,
          expectedSession: owner,
          page: 2,
        )).data!.page,
        2,
      );
      expect(requests.map((r) => r.url.path), [
        '/api/profiles/2',
        '/api/profiles/2/pasars',
      ]);
      expect(requests.last.url.queryParameters, {
        'page': '2',
        'per_page': '20',
      });
      expect(
        requests.every((r) => r.headers['authorization'] == 'Bearer A'),
        true,
      );
      for (final body in [
        {
          'success': true,
          'data': {'data': []},
        },
        {
          'success': true,
          'data': [pasar.product(owner: 3)],
          'meta': forum.meta(),
        },
        {
          'success': true,
          'data': [],
          'meta': {...forum.meta(), 'current_page': 2},
        },
      ]) {
        handler = (_) async => http.Response(jsonEncode(body), 200);
        expect(
          (await api.fetchProfileProducts(
            2,
            expectedSession: owner,
          )).failure!.kind,
          ApiErrorKind.invalidResponse,
        );
      }
      handler = (_) async => profile(3);
      expect(
        (await api.fetchProfile(2, expectedSession: owner)).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
      final count = requests.length;
      expect(
        (await api.fetchProfile(0, expectedSession: owner)).isSuccess,
        false,
      );
      expect(requests.length, count);
    },
  );

  for (final status in [401, 403, 404, 422, 429]) {
    testWidgets('HTTP $status central session and manual retry', (t) async {
      handler = (_) async =>
          http.Response('{}', status, headers: {'retry-after': '2'});
      await show(t, MemberProfileScreen(api: api, userId: 2));
      expect((await session.snapshot()).isAuthenticated, status != 401);
      expect(requests.length, 1);
      if (status == 429) {
        expect(find.textContaining('Tunggu 2 detik'), findsOneWidget);
        await t.pump(const Duration(seconds: 3));
        expect(requests.length, 1);
      }
      await t.pumpWidget(const SizedBox());
    });
  }

  for (final source in ['post', 'comment', 'reply', 'seller']) {
    for (final avatar in [false, true]) {
      testWidgets(
        '$source ${avatar ? 'avatar' : 'name'} opens other once and Back preserves source',
        (t) async {
          handler = (r) async {
            if (r.url.path.startsWith('/api/profiles/')) {
              return r.url.path.endsWith('/pasars') ? products() : profile(2);
            }
            if (source == 'post') {
              return forum.listing([
                {...forum.post(owner: 2), 'user': user(2)},
              ]);
            }
            if (source == 'seller') {
              return pasar.listResponse([
                {...pasar.product(owner: 2), 'user': user(2)},
              ]);
            }
            if (r.url.path.endsWith('/replies')) {
              return forum.commentsListing([
                {
                  ...forum.comment(id: 11, owner: '2', parent: 10),
                  'user': user(2),
                },
              ]);
            }
            return forum.commentsListing([
              {
                ...forum.comment(
                  owner: source == 'reply' ? '1' : '2',
                  replies: source == 'reply' ? 1 : 0,
                ),
                'user': user(source == 'reply' ? 1 : 2),
              },
            ]);
          };
          await show(
            t,
            source == 'post'
                ? ForumScreen(api: api)
                : source == 'seller'
                ? PasarScreen(api: api)
                : ForumCommentsScreen(api: api, postId: 1),
          );
          if (source == 'reply') {
            await tap(t, find.textContaining('Lihat balasan'));
          }
          final identity = find.ancestor(
            of: find.text('Anggota 2'),
            matching: find.byType(ProfileIdentity),
          );
          final target = avatar
              ? find.descendant(
                  of: identity,
                  matching: find.byType(ProfileAvatar),
                )
              : find.text('Anggota 2');
          await t.ensureVisible(target);
          await t.pumpAndSettle();
          final position = t.getCenter(target);
          await t.tapAt(position);
          await t.tapAt(position);
          await t.pumpAndSettle();
          expect(find.byType(MemberProfileScreen), findsOneWidget);
          expect(
            requests.where((r) => r.url.path == '/api/profiles/2').length,
            1,
          );
          expect(find.byIcon(Icons.settings), findsNothing);
          expect(find.byIcon(Icons.logout), findsNothing);
          expect(find.text('Edit Jualan'), findsNothing);
          await t.pageBack();
          await t.pumpAndSettle();
          expect(find.text('Anggota 2'), findsOneWidget);
          expect(find.byType(MemberProfileScreen), findsNothing);
        },
      );
    }
  }

  testWidgets('self goes to existing profile; invalid relation stays put', (
    t,
  ) async {
    handler = (r) async => r.url.path.endsWith('/user')
        ? http.Response(jsonEncode(user(1)), 200)
        : pasar.listResponse([]);
    await show(
      t,
      Scaffold(
        body: Column(
          children: [
            ProfileIdentity(api: api, profile: user(1), fallbackName: 'Self'),
            ProfileIdentity(api: api, profile: null, fallbackName: 'Deleted'),
          ],
        ),
      ),
    );
    await tap(t, find.text('Deleted'));
    expect(requests, isEmpty);
    await tap(t, find.text('Anggota 1'));
    expect(find.byType(ProfilScreen), findsOneWidget);
    expect(requests.any((r) => r.url.path == '/api/profiles/1/pasars'), true);
  });

  testWidgets('pagination keeps rows on error then deduplicates retry', (
    t,
  ) async {
    var fail = true;
    handler = (r) async {
      if (!r.url.path.endsWith('/pasars')) return profile(2);
      if (r.url.queryParameters['page'] == '1') {
        return products(last: 2, rows: [pasar.product(owner: 2)]);
      }
      if (fail) return http.Response('{}', 500);
      return products(
        page: 2,
        last: 2,
        rows: [pasar.product(owner: 2), pasar.product(id: 11, owner: 2)],
      );
    };
    await show(t, MemberProfileScreen(api: api, userId: 2));
    await tap(t, find.text('Muat produk berikutnya'));
    expect(find.text('Lele 10'), findsOneWidget);
    fail = false;
    await tap(t, find.text('Coba lagi'));
    expect(find.text('Lele 10'), findsOneWidget);
    expect(find.text('Lele 11'), findsOneWidget);
  });

  for (final switchAccount in [false, true]) {
    testWidgets(
      'pending response cleared on ${switchAccount ? 'switch' : 'logout'} and Back',
      (t) async {
        final pending = Completer<http.Response>();
        handler = (_) => pending.future;
        await t.pumpWidget(
          MaterialApp(home: MemberProfileScreen(api: api, userId: 2)),
        );
        await t.pump();
        await t.pump();
        if (switchAccount) {
          await session.saveIfCurrent('B', user: user(3));
        } else {
          await session.clear();
        }
        pending.complete(profile(2));
        await t.pumpAndSettle();
        expect(find.text('Anggota 2'), findsNothing);
        expect(find.byType(MemberProfileScreen), findsNothing);
        expect(requests.length, 1);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('guest direct profile sends no requests', (t) async {
    await session.clear();
    await show(t, MemberProfileScreen(api: api, userId: 2));
    expect(requests, isEmpty);
    expect(find.byType(MemberProfileScreen), findsNothing);
  });

  testWidgets(
    'loaded products disappear on switch; no private actions or contacts',
    (t) async {
      handler = (r) async => r.url.path.endsWith('/pasars')
          ? products(rows: [pasar.product(owner: 2)])
          : http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  ...user(2),
                  'email': 'private@example.test',
                  'phone': 'private-phone',
                },
              }),
              200,
            );
      await show(t, MemberProfileScreen(api: api, userId: 2));
      expect(find.text('Lele 10'), findsOneWidget);
      for (final text in [
        'private@example.test',
        'private-phone',
        'Edit Profil',
        'Edit Jualan',
        'Hapus Jualan',
        'Pesanan',
        'Logout',
      ]) {
        expect(find.text(text), findsNothing);
      }
      await session.saveIfCurrent('B', user: user(3));
      await t.pumpAndSettle();
      expect(find.text('Lele 10'), findsNothing);
      expect(find.text('Anggota 2'), findsNothing);
      expect(find.byType(MemberProfileScreen), findsNothing);
    },
  );

  testWidgets('target changes ignore late old profile; dispose pending safe', (
    t,
  ) async {
    final pending = Completer<http.Response>();
    handler = (r) => r.url.path == '/api/profiles/2'
        ? pending.future
        : Future.value(
            r.url.path.endsWith('/pasars') ? products() : profile(3),
          );
    await t.pumpWidget(
      MaterialApp(home: MemberProfileScreen(api: api, userId: 2)),
    );
    await t.pump();
    await t.pump();
    await show(t, MemberProfileScreen(api: api, userId: 3));
    pending.complete(profile(2));
    await t.pumpAndSettle();
    expect(find.text('Anggota 3'), findsOneWidget);
    expect(find.text('Anggota 2'), findsNothing);
    expect(requests.any((r) => r.url.path == '/api/profiles/2/pasars'), false);
    expect(t.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('320px 2x keyboard profile light/dark=$dark', (t) async {
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: MemberProfileScreen(api: api, userId: 2),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Belum ada stok panen.'), findsOneWidget);
      await t.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
      await t.pumpAndSettle();
      final count = requests.length;
      await tap(t, find.text('Muat ulang profil'));
      expect(requests.length, count + 2);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('avatar null/error fallback and no authorization headers', (
    t,
  ) async {
    await show(t, const Scaffold(body: ProfileAvatar()));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    await show(
      t,
      const Scaffold(
        body: ProfileAvatar(photo: 'https://images.example.test/photo.png'),
      ),
    );
    final image = t.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;
    expect(provider.url, 'https://images.example.test/photo.png');
    expect(provider.headers ?? {}, isEmpty);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(requests, isEmpty);
  });
}
