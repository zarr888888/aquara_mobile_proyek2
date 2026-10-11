import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

Map<String, dynamic> post({int id = 1, int? owner = 1}) => {
  'id': id,
  'user_id': owner,
  'content': 'Diskusi $id',
  'author_name': 'Sama',
  'user': null,
  'comments': [
    {'id': 10, 'user_id': 1, 'author_name': 'Sama', 'content': 'Komentar saya'},
    {'id': 11, 'user_id': 2, 'author_name': 'Sama', 'content': 'Komentar lain'},
  ],
  'image': null,
  'likes_count': '0',
  'comments_count': 2,
  'is_liked_by_me': false,
  'created_at': 'broken',
};
http.Response listing(List<Object?> rows) =>
    http.Response(jsonEncode({'success': true, 'data': rows}), 200);

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
        ? listing([post()])
        : http.Response('{"success":true}', 200);
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
  testWidgets(
    'timeout mutation requires list check and never automatically retries',
    (tester) async {
      await initialize();
      api = ApiService(
        session: session,
        client: ApiClient(
          session: session,
          baseUrl: Uri.parse('https://example.test/api'),
          timeout: const Duration(seconds: 2),
          clientFactory: () => MockClient((r) {
            requests.add(r);
            if (r.method == 'POST') return Completer<http.Response>().future;
            return Future.value(listing([post()]));
          }),
        ),
      );
      await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Suka'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Hasil aksi belum dapat dipastikan'),
        findsOneWidget,
      );
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Suka',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Periksa ulang daftar'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(requests.where((r) => r.method == 'GET'), hasLength(2));
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Suka',
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'external image uses intact HTTPS URL and no authorization headers',
    (tester) async {
      await initialize();
      handler = (_) async => listing([
        {
          ...post(),
          'image': 'https://res.cloudinary.com/example/image.png',
          'content': '<script>navigate()</script>',
        },
      ]);
      await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
      await tester.pumpAndSettle();
      final image =
          tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(image.url, 'https://res.cloudinary.com/example/image.png');
      expect(image.headers, isNull);
      expect(find.text('<script>navigate()</script>'), findsOneWidget);
      expect(requests, hasLength(1));
    },
  );
  testWidgets(
    'cooldown deadline expires in background without ticks or auto request',
    (tester) async {
      await initialize();
      var now = DateTime(2026, 10, 7);
      handler = (_) async => http.Response('{}', 429);
      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(api: api, clock: () => now),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 61));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Muat ulang',
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final dark in [false, true]) {
    testWidgets('320px large text keyboard and theme $dark', (tester) async {
      await initialize();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: ForumScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField), 'Draft kecil');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('pending A submission cannot alter B route or draft', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'A private draft');
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.tap(find.text('Posting'));
    await tester.pump();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpAndSettle();
    expect(find.text('A private draft'), findsNothing);
    pending.complete(http.Response('{}', 401));
    await tester.pumpAndSettle();
    expect(await session.readToken(), 'B');
    expect(find.text('A private draft'), findsNothing);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('loading and deduplicated read before response', (tester) async {
    await initialize();
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    final s = await session.snapshot();
    final duplicate = api.fetchForumPosts(expectedSession: s);
    pending.complete(listing([]));
    await duplicate;
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.text('Belum ada diskusi.'), findsOneWidget);
  });
  test('seven endpoint contracts and mine; no client identity', () async {
    final s = await session.snapshot();
    await api.fetchForumPosts(expectedSession: s);
    await api.fetchForumPosts(expectedSession: s, mine: true);
    expect(
      (await api.postForum('create', null, expectedSession: s)).data,
      isNull,
    );
    await api.updateForumPost(3, 'update', null, expectedSession: s);
    await api.deleteForumPost(3, expectedSession: s);
    handler = (_) async =>
        http.Response('{"success":true,"status":"liked"}', 200);
    expect((await api.toggleLikePost(3, expectedSession: s)).data, 'liked');
    await api.storeComment(3, 'comment', expectedSession: s);
    await api.deleteComment(10, expectedSession: s);
    expect(
      requests.map(
        (r) =>
            '${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}',
      ),
      [
        'GET /api/forum',
        'GET /api/forum?mine=1',
        'POST /api/forum',
        'POST /api/forum/3/update',
        'DELETE /api/forum/3',
        'POST /api/forum/3/toggle-like',
        'POST /api/forum/3/comment',
        'DELETE /api/forum/comment/10',
      ],
    );
    for (final r in requests) {
      expect(r.headers['authorization'], 'Bearer A');
      expect(r.body, isNot(contains('user_id')));
      expect(r.body, isNot(contains('author_name')));
    }
    for (final i in [0, 1, 4, 5, 7]) {
      expect(requests[i].body, isEmpty);
    }
    expect(jsonDecode(requests[3].body), {'content': 'update'});
    expect(jsonDecode(requests[6].body), {'content': 'comment'});
  });
  test(
    'nullable relations, invalid date, order, external image and minimization',
    () async {
      handler = (_) async => listing([
        {
          ...post(id: 2),
          'comments': null,
          'image': 'https://res.cloudinary.com/a.jpg',
          'user': {'id': 1, 'name': 'Name', 'email': 'private'},
        },
        post(),
      ]);
      final result = await api.fetchForumPosts(
        expectedSession: await session.snapshot(),
      );
      expect(result.data!.map((p) => p['id']), [2, 1]);
      expect(result.data!.first['created_at'], isNull);
      expect(result.data!.first['comments'], isEmpty);
      expect(result.data!.first['image'], 'https://res.cloudinary.com/a.jpg');
      expect(result.data!.first.toString(), isNot(contains('private')));
    },
  );
  for (final body in [
    'not json',
    '{}',
    '{"success":false}',
    '{"success":true,"data":[{}]}',
  ]) {
    test('invalid list is failure: $body', () async {
      await initialize();
      handler = (_) async => http.Response(body, 200);
      expect(
        (await api.fetchForumPosts(
          expectedSession: await session.snapshot(),
        )).failure!.kind,
        ApiErrorKind.invalidResponse,
      );
    });
  }
  test('empty list and unliked status', () async {
    final s = await session.snapshot();
    handler = (_) async => listing([]);
    expect((await api.fetchForumPosts(expectedSession: s)).data, isEmpty);
    handler = (_) async =>
        http.Response('{"success":true,"status":"unliked"}', 200);
    expect((await api.toggleLikePost(1, expectedSession: s)).data, 'unliked');
    handler = (_) async => http.Response('{"success":true}', 200);
    expect((await api.toggleLikePost(1, expectedSession: s)).isSuccess, false);
    handler = (_) async => http.Response('{"success":true}', 201);
    expect(
      (await api.postForum('x', null, expectedSession: s)).isSuccess,
      false,
    );
  });
  test(
    'multipart boundary, binary, separate limits and no update text limit',
    () async {
      final dir = await Directory.systemTemp.createTemp('forum-test');
      addTearDown(() => dir.delete(recursive: true));
      final image = File('${dir.path}/image.png');
      await image.writeAsBytes([137, 80, 78, 71, 0, 255]);
      final s = await session.snapshot();
      expect(
        (await api.postForum('x', image, expectedSession: s)).isSuccess,
        true,
      );
      expect(
        requests.last.headers['content-type'],
        contains('multipart/form-data; boundary='),
      );
      expect(
        requests.last.bodyBytes,
        containsAllInOrder([137, 80, 78, 71, 0, 255]),
      );
      expect(
        latin1.decode(requests.last.bodyBytes),
        contains('name="image"; filename="image.png"'),
      );
      await image.writeAsBytes(List.filled(5120 * 1024 + 1, 0));
      expect(
        (await api.postForum('x', image, expectedSession: s)).failure!.kind,
        ApiErrorKind.validation,
      );
      expect(
        (await api.updateForumPost(
          1,
          'x' * 5001,
          image,
          expectedSession: s,
        )).isSuccess,
        true,
      );
      await image.writeAsBytes(List.filled(10240 * 1024 + 1, 0));
      expect(
        (await api.updateForumPost(
          1,
          'x',
          image,
          expectedSession: s,
        )).failure!.kind,
        ApiErrorKind.validation,
      );
      expect(
        (await api.storeComment(
          1,
          'x' * 5001,
          expectedSession: s,
        )).failure!.kind,
        ApiErrorKind.validation,
      );
    },
  );
  for (final status in [403, 404, 422, 429]) {
    test('$status stays authenticated and safe', () async {
      handler = (_) async =>
          http.Response('{"message":"PRIVATE SECRET"}', status);
      final result = await api.deleteComment(
        10,
        expectedSession: await session.snapshot(),
      );
      expect(result.isSuccess, false);
      expect(result.failure!.message, isNot(contains('PRIVATE SECRET')));
      expect(session.hasSession, true);
      expect(requests, hasLength(1));
    });
  }
  test('private 401 centralized invalidation', () async {
    handler = (_) async => http.Response('{}', 401);
    await api.fetchForumPosts(expectedSession: await session.snapshot());
    expect(session.hasSession, false);
  });
  for (final status in [200, 401]) {
    test(
      'late A $status cannot invalidate B; old snapshot never sends B',
      () async {
        final pending = Completer<http.Response>();
        final started = Completer<void>();
        handler = (_) {
          started.complete();
          return pending.future;
        };
        final s = await session.snapshot();
        final work = api.toggleLikePost(1, expectedSession: s);
        await started.future;
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        pending.complete(
          http.Response('{"success":true,"status":"liked"}', status),
        );
        expect((await work).failure!.kind, ApiErrorKind.staleSession);
        expect(await session.readToken(), 'B');
        expect(
          (await api.deleteForumPost(1, expectedSession: s)).failure!.kind,
          ApiErrorKind.staleSession,
        );
        expect(requests, hasLength(1));
      },
    );
  }
  testWidgets('mine, post/comment owner-only controls; no profile fetch', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => listing([post(), post(id: 2, owner: 2)]);
    await tester.pumpWidget(
      MaterialApp(home: ForumScreen(api: api, mine: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Forum Saya'), findsOneWidget);
    expect(requests.single.url.query, 'mine=1');
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    await tester.tap(find.byTooltip('Komentar').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hapus komentar'), findsOneWidget);
    expect(find.text('Komentar lain'), findsOneWidget);
    expect(requests, hasLength(1));
  });
  testWidgets(
    'duplicate like blocked; success then refresh failure is not mutation failure',
    (tester) async {
      await initialize();
      await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
      await tester.pumpAndSettle();
      final pending = Completer<http.Response>();
      handler = (r) async =>
          r.method == 'POST' ? pending.future : http.Response('{}', 503);
      await tester.tap(find.byTooltip('Suka'));
      await tester.tap(find.byTooltip('Suka'));
      await tester.pump();
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      pending.complete(http.Response('{"success":true,"status":"liked"}', 200));
      await tester.pumpAndSettle();
      expect(find.textContaining('Aksi sudah berhasil'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Suka',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );
  for (final header in [true, false]) {
    testWidgets('429 cooldown $header prevents repeats', (tester) async {
      await initialize();
      handler = (_) async => http.Response(
        '{}',
        429,
        headers: header ? {'retry-after': '120'} : {},
      );
      await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(header ? 'Coba kembali dalam' : 'Jeda lokal'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Muat ulang',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('422 retains draft; double submit blocked', (tester) async {
    await initialize();
    await tester.pumpWidget(MaterialApp(home: ForumScreen(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'draft');
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await tester.tap(find.text('Posting'));
    await tester.tap(find.text('Posting'));
    await tester.pump();
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    pending.complete(http.Response('{}', 422));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'draft',
    );
    expect(session.hasSession, true);
  });
}
