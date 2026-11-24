import 'dart:async';
import 'dart:convert';
import 'package:aquara_mobile/screens/forum_comments_screen.dart';
import 'package:aquara_mobile/screens/forum_screen.dart';
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
import 'forum_test.dart' as fixture;

void main() {
  late SessionService session;
  late ApiService api;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  http.Response success(Object data) =>
      http.Response(jsonEncode({'success': true, 'data': data}), 200);
  Future<void> initialize() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    requests.clear();
    handler = (r) async =>
        fixture.commentsListing([fixture.comment(replies: 1)]);
    api = ApiService(
      session: session,
      client: ApiClient(
        session: session,
        baseUrl: Uri.parse('https://example.test/api'),
        timeout: const Duration(seconds: 2),
        clientFactory: () => MockClient((r) {
          requests.add(r);
          return handler(r);
        }),
      ),
    );
  }

  setUp(initialize);
  Future<void> screen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ForumCommentsScreen(api: api, postId: 1)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  test(
    'comment endpoints payload, identities, counts and untrusted paginator URL',
    () async {
      final owner = await session.snapshot();
      handler = (r) async {
        if (r.method == 'GET') {
          return success({
            ...fixture.meta(),
            'data': [
              fixture.comment(
                parent: r.url.path.endsWith('replies') ? 9 : null,
              ),
            ],
            'next_page_url': 'https://attacker.test/api/forum?page=2',
          });
        }
        if (r.url.path.endsWith('like')) {
          return success({
            'id': 10,
            'likes_count': 7,
            'is_liked_by_me': r.method == 'PUT',
          });
        }
        return success(
          fixture.comment(postId: 1, parent: r.method == 'POST' ? 9 : null),
        );
      };
      expect(
        (await api.fetchForumPage(
          expectedSession: owner,
          postId: 1,
        )).data!.items.single['user_id'],
        1,
      );
      expect(
        (await api.fetchForumPage(
          expectedSession: owner,
          postId: 1,
          parentId: 9,
        )).isSuccess,
        true,
      );
      expect(
        (await api.storeComment(
          1,
          'new',
          parentId: 9,
          expectedSession: owner,
        )).isSuccess,
        true,
      );
      expect(
        (await api.editComment(10, 'edit', expectedSession: owner)).isSuccess,
        true,
      );
      for (final liked in [true, true, false, false]) {
        expect(
          (await api.setCommentLike(10, liked, expectedSession: owner)).data,
          {'id': 10, 'likes_count': 7, 'is_liked_by_me': liked},
        );
      }
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/forum/1/comments',
        'GET /api/forum/comment/9/replies',
        'POST /api/forum/1/comment',
        'PATCH /api/forum/comment/10',
        'PUT /api/forum/comment/10/like',
        'PUT /api/forum/comment/10/like',
        'DELETE /api/forum/comment/10/like',
        'DELETE /api/forum/comment/10/like',
      ]);
      expect(jsonDecode(requests[2].body), {'content': 'new', 'parent_id': 9});
      expect(jsonDecode(requests[3].body), {'content': 'edit'});
      for (final r in requests) {
        expect(r.url.host, 'example.test');
        expect(r.headers['authorization'], 'Bearer A');
        expect(r.headers['accept'], 'application/json');
        if (r.method == 'GET') {
          expect(r.url.queryParameters, {'page': '1', 'per_page': '20'});
        }
        if (r.url.path.endsWith('like')) expect(r.body, isEmpty);
      }
    },
  );
  for (final field in [
    'id',
    'user_id',
    'community_post_id',
    'parent_id',
    'likes_count',
    'replies_count',
    'is_liked_by_me',
    'created_at',
    'updated_at',
    'user',
  ]) {
    test('reject malformed comment $field rather than fallback', () async {
      handler = (_) async => fixture.commentsListing([
        {...fixture.comment(), field: field == 'user_id' ? 1 : 'broken'},
      ]);
      expect(
        (await api.fetchForumPage(
          expectedSession: await session.snapshot(),
          postId: 1,
        )).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
    });
  }
  test(
    'empty valid; wrong parent/post, absent meta, malformed mutation and 201 rejected',
    () async {
      final s = await session.snapshot();
      handler = (_) async => fixture.commentsListing([]);
      expect(
        (await api.fetchForumPage(expectedSession: s, postId: 1)).data!.items,
        isEmpty,
      );
      for (final row in [
        fixture.comment(parent: 9),
        fixture.comment(postId: 2),
      ]) {
        handler = (_) async => fixture.commentsListing([row]);
        expect(
          (await api.fetchForumPage(expectedSession: s, postId: 1)).isSuccess,
          false,
        );
      }
      handler = (_) async => success([]);
      expect((await api.fetchForumPage(expectedSession: s)).isSuccess, false);
      for (final status in [200, 201]) {
        handler = (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': status == 200 ? {} : fixture.comment(),
          }),
          status,
        );
        expect(
          (await api.storeComment(1, 'new', expectedSession: s)).isSuccess,
          false,
        );
      }
      final count = requests.length;
      for (final content in ['', '  ', 'x' * 5001]) {
        expect(
          (await api.editComment(
            10,
            content,
            expectedSession: s,
          )).failure!.kind,
          ApiErrorKind.validation,
        );
      }
      expect(
        (await api.fetchForumPage(expectedSession: s, perPage: 51)).isSuccess,
        false,
      );
      expect(requests.length, count);
    },
  );
  for (final status in [401, 403, 404, 422, 429]) {
    test(
      'comment error $status is typed and session context preserved',
      () async {
        handler = (_) async => http.Response(
          jsonEncode({
            'success': false,
            'errors': {
              'content': ['PRIVATE'],
              'parent_id': ['PRIVATE'],
            },
          }),
          status,
          headers: {'retry-after': '12'},
        );
        final result = await api.editComment(
          10,
          'edit',
          expectedSession: await session.snapshot(),
        );
        expect(result.isSuccess, false);
        expect(session.hasSession, status != 401);
        expect(result.failure!.message, isNot(contains('PRIVATE')));
        if (status == 422) {
          expect(
            result.failure!.fieldErrors.keys,
            containsAll(['content', 'parent_id']),
          );
        }
        if (status == 429) {
          expect(result.failure!.retryAfter, const Duration(seconds: 12));
        }
      },
    );
  }

  testWidgets(
    'edit owner only, prefilled, 422 draft survives, server response replaces item',
    (tester) async {
      await initialize();
      handler = (_) async => fixture.commentsListing([
        fixture.comment(),
        fixture.comment(id: 11, owner: '2', content: 'Other'),
      ]);
      await screen(tester);
      expect(find.byTooltip('Edit komentar'), findsOneWidget);
      await tap(tester, find.byTooltip('Edit komentar'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Komentar saya',
      );
      await tester.enterText(find.byType(TextField), 'draft edit');
      handler = (_) async =>
          http.Response('{"errors":{"content":["private"]}}', 422);
      await tap(tester, find.text('Simpan komentar'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'draft edit',
      );
      expect(find.textContaining('Nilai tidak valid'), findsOneWidget);
      handler = (_) async =>
          success(fixture.comment(content: 'server edited', likes: 5));
      await tap(tester, find.text('Simpan komentar'));
      expect(find.text('server edited'), findsOneWidget);
      expect(find.text('5 suka'), findsOneWidget);
      expect(jsonDecode(requests.last.body), {'content': 'draft edit'});
    },
  );

  testWidgets(
    'double like blocked and authoritative server count; unlike explicit',
    (tester) async {
      await initialize();
      await screen(tester);
      final pending = Completer<http.Response>();
      handler = (_) => pending.future;
      await tester.ensureVisible(find.byTooltip('Suka komentar'));
      await tester.tap(find.byTooltip('Suka komentar'));
      await tester.tap(find.byTooltip('Suka komentar'));
      await tester.pump();
      expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
      pending.complete(
        success({'id': 10, 'likes_count': 12, 'is_liked_by_me': true}),
      );
      await tester.pumpAndSettle();
      expect(find.text('12 suka'), findsOneWidget);
      handler = (_) async =>
          success({'id': 10, 'likes_count': 8, 'is_liked_by_me': false});
      await tap(tester, find.byTooltip('Batal suka komentar'));
      expect(requests.last.method, 'DELETE');
      expect(find.text('8 suka'), findsOneWidget);
    },
  );

  testWidgets(
    'reply-to-reply uses root; independent paginated replies deduplicate',
    (tester) async {
      await initialize();
      handler = (r) async {
        if (r.method == 'POST') {
          return success(fixture.comment(id: 15, parent: 10));
        }
        if (r.url.path.endsWith('replies')) {
          final page = int.parse(r.url.queryParameters['page']!);
          return fixture.commentsListing(
            [
              fixture.comment(id: 12, parent: 10, content: 'Reply'),
              if (page == 2)
                fixture.comment(id: 13, parent: 10, content: 'Next reply'),
            ],
            page: page,
            last: 2,
          );
        }
        return fixture.commentsListing([
          fixture.comment(replies: 3),
          fixture.comment(id: 11, content: 'Root 2'),
        ]);
      };
      await screen(tester);
      await tap(tester, find.text('Lihat balasan (3)'));
      await tap(tester, find.text('Muat balasan berikutnya'));
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Next reply'), findsOneWidget);
      await tap(tester, find.text('Balas').at(1));
      await tester.enterText(find.byType(TextField), 'reply to reply');
      await tap(tester, find.text('Kirim'));
      expect(jsonDecode(requests.singleWhere((r) => r.method == 'POST').body), {
        'content': 'reply to reply',
        'parent_id': 10,
      });
      expect(
        requests.where((r) => r.url.path == '/api/forum/comment/12/replies'),
        isEmpty,
      );
    },
  );

  for (final reply in [false, true]) {
    testWidgets(
      'delete confirmation cascade=$reply and reload appropriate collection',
      (tester) async {
        await initialize();
        var deleted = false;
        handler = (r) async {
          if (r.method == 'DELETE') {
            deleted = true;
            return http.Response('{"success":true}', 200);
          }
          if (r.url.path.endsWith('replies')) {
            return fixture.commentsListing(
              deleted ? [] : [fixture.comment(id: 12, parent: 10)],
            );
          }
          return fixture.commentsListing(
            deleted && !reply
                ? []
                : [fixture.comment(replies: 1, owner: reply ? '2' : '1')],
          );
        };
        await screen(tester);
        if (reply) await tap(tester, find.text('Lihat balasan (1)'));
        await tap(tester, find.byTooltip('Hapus komentar'));
        expect(
          find.textContaining(
            reply ? 'Komentar induk tetap' : 'termasuk balasan pengguna lain',
          ),
          findsOneWidget,
        );
        await tap(tester, find.text('Hapus'));
        expect(
          requests.singleWhere((r) => r.method == 'DELETE').url.path,
          '/api/forum/comment/${reply ? 12 : 10}',
        );
        expect(
          find.text('Komentar saya'),
          reply ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets('timeout retains draft and requires reload; never retries POST', (
    tester,
  ) async {
    await initialize();
    await screen(tester);
    handler = (_) => Completer<http.Response>().future;
    await tester.enterText(find.byType(TextField), 'uncertain draft');
    await tester.tap(find.text('Kirim'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Hasil aksi belum dapat dipastikan'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'uncertain draft',
    );
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    handler = (_) async => fixture.commentsListing([]);
    await tap(tester, find.text('Muat ulang komentar'));
    expect(find.textContaining('Hasil aksi belum'), findsNothing);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  for (final status in [200, 401]) {
    testWidgets(
      'account replacement clears draft and ignores late comment $status',
      (tester) async {
        await initialize();
        await screen(tester);
        final pending = Completer<http.Response>();
        handler = (_) => pending.future;
        await tester.enterText(find.byType(TextField), 'private A');
        await tester.tap(find.text('Kirim'));
        await tester.pump();
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        await tester.pumpAndSettle();
        pending.complete(
          http.Response(
            jsonEncode({
              'success': true,
              'data': fixture.comment(content: 'old A'),
            }),
            status,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('private A'), findsNothing);
        expect(find.text('old A'), findsNothing);
        expect(await session.readToken(), 'B');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('feed mine pagination preserves rows on error and deduplicates', (
    tester,
  ) async {
    await initialize();
    var fail = true;
    handler = (r) async {
      final page = int.parse(r.url.queryParameters['page']!);
      if (page == 2 && fail) return http.Response('{}', 503);
      return fixture.listing(
        [fixture.post(), if (page == 2) fixture.post(id: 2)],
        page: page,
        last: 2,
      );
    };
    await tester.pumpWidget(
      MaterialApp(home: ForumScreen(api: api, mine: true)),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Muat posting berikutnya'));
    expect(find.text('Diskusi 1'), findsOneWidget);
    fail = false;
    await tap(tester, find.text('Muat posting berikutnya'));
    expect(find.byKey(const ValueKey('forum-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('forum-2')), findsOneWidget);
    expect(requests.every((r) => r.url.queryParameters['mine'] == '1'), true);
  });

  testWidgets('refresh supersedes late root response', (tester) async {
    await initialize();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.pumpWidget(
      MaterialApp(home: ForumCommentsScreen(api: api, postId: 1)),
    );
    await tester.pump();
    await tester.pump();
    handler = (_) async =>
        fixture.commentsListing([fixture.comment(content: 'fresh')]);
    await tester.tap(find.text('Muat ulang komentar'));
    await tester.pumpAndSettle();
    pending.complete(
      fixture.commentsListing([fixture.comment(content: 'stale')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('stale'), findsNothing);
  });

  testWidgets('separate root reply requests cannot overwrite another thread', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => fixture.commentsListing([
      fixture.comment(replies: 1),
      fixture.comment(id: 11, replies: 2, content: 'Second root'),
    ]);
    await screen(tester);
    final first = Completer<http.Response>();
    handler = (r) async => r.url.path.contains('/10/')
        ? first.future
        : fixture.commentsListing([
            fixture.comment(id: 13, parent: 11, content: 'Second reply'),
          ]);
    await tester.ensureVisible(find.text('Lihat balasan (1)'));
    await tester.tap(find.text('Lihat balasan (1)'));
    await tester.pump();
    await tester.ensureVisible(find.text('Lihat balasan (2)'));
    await tester.tap(find.text('Lihat balasan (2)'));
    await tester.pump();
    await tester.pump();
    first.complete(
      fixture.commentsListing([
        fixture.comment(id: 12, parent: 10, content: 'First reply'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('First reply'), findsOneWidget);
    expect(find.text('Second reply'), findsOneWidget);
  });

  testWidgets('late reply response cannot undo a completed like mutation', (
    tester,
  ) async {
    await initialize();
    await screen(tester);
    final pending = Completer<http.Response>();
    handler = (r) async => r.method == 'GET'
        ? pending.future
        : success({'id': 10, 'likes_count': 9, 'is_liked_by_me': true});
    await tester.ensureVisible(find.text('Lihat balasan (1)'));
    await tester.tap(find.text('Lihat balasan (1)'));
    await tester.pump();
    await tester.tap(find.byTooltip('Suka komentar'));
    await tester.pumpAndSettle();
    pending.complete(
      fixture.commentsListing([
        fixture.comment(id: 12, parent: 10, content: 'stale reply'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('9 suka'), findsOneWidget);
    expect(find.text('stale reply'), findsNothing);
  });

  for (final header in [true, false]) {
    testWidgets(
      'comment 429 cooldown blocks duplicate submission header=$header',
      (tester) async {
        await initialize();
        await screen(tester);
        handler = (_) async => http.Response(
          '{}',
          429,
          headers: header ? {'retry-after': '10'} : {},
        );
        await tester.enterText(find.byType(TextField), 'draft');
        await tap(tester, find.text('Kirim'));
        expect(
          find.textContaining(header ? 'Tunggu 10 detik' : 'Jeda lokal'),
          findsOneWidget,
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
        expect(requests.where((r) => r.method == 'POST'), hasLength(1));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('guest direct entry sends no requests', (tester) async {
    await initialize();
    await session.invalidate(await session.snapshot());
    await screen(tester);
    expect(find.widgetWithText(TextField, 'Tulis komentar'), findsNothing);
    expect(find.text('Email / nomor HP'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('deleted remote parent safely removes stale thread on 404', (
    tester,
  ) async {
    await initialize();
    await screen(tester);
    handler = (_) async => http.Response('{"message":"Not Found"}', 404);
    await tap(tester, find.text('Lihat balasan (1)'));
    expect(find.text('Komentar saya'), findsNothing);
    expect(find.textContaining('sudah tidak tersedia'), findsWidgets);
    expect(session.hasSession, true);
  });

  testWidgets(
    'root pagination deduplicates and retains rows on next-page failure',
    (tester) async {
      await initialize();
      var fail = true;
      handler = (r) async {
        final page = int.parse(r.url.queryParameters['page']!);
        if (page == 2 && fail) return http.Response('{}', 503);
        return fixture.commentsListing(
          [
            fixture.comment(),
            if (page == 2) fixture.comment(id: 11, content: 'next root'),
          ],
          page: page,
          last: 2,
        );
      };
      await screen(tester);
      await tap(tester, find.text('Muat komentar berikutnya'));
      expect(find.text('Komentar saya'), findsOneWidget);
      fail = false;
      await tap(tester, find.text('Muat komentar berikutnya'));
      expect(find.text('Komentar saya'), findsOneWidget);
      expect(find.text('next root'), findsOneWidget);
    },
  );

  testWidgets('invalid mutation response retains draft until explicit reload', (
    tester,
  ) async {
    await initialize();
    await screen(tester);
    handler = (_) async => success({});
    await tester.enterText(find.byType(TextField), 'preserved');
    await tap(tester, find.text('Kirim'));
    expect(
      find.textContaining('Hasil aksi belum dapat dipastikan'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'preserved',
    );
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  for (final dark in [false, true]) {
    testWidgets('320px 2x keyboard accessible comments dark=$dark', (
      tester,
    ) async {
      await initialize();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ForumCommentsScreen(api: api, postId: 1),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'small screen draft');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kirim'));
      await tester.pumpAndSettle();
      expect(find.text('Kirim').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
