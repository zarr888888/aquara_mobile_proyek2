import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aquara_mobile/screens/profil_screen.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late SessionService session;
  late ApiService api;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  http.Response user(String name) =>
      http.Response(jsonEncode({'id': 1, 'name': name}), 200);
  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    handler = (_) async => user('A');
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

  test('own user direct object, headers, no query or body', () async {
    expect((await api.currentUser()).isSuccess, true);
    final r = requests.single;
    expect(r.url.path, '/api/user');
    expect(r.url.query, isEmpty);
    expect(r.body, isEmpty);
    expect(r.headers['Authorization'], 'Bearer A');
    expect(r.headers['Accept'], 'application/json');
  });
  test(
    'profile binary upload exact 2048 KB and optional focus allowlist',
    () async {
      final dir = await Directory.systemTemp.createTemp('profile-test-');
      try {
        final file = File('${dir.path}/private-name.png');
        final bytes = List<int>.filled(2048 * 1024, 0);
        bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
        await file.writeAsBytes(bytes);
        handler = (r) async {
          expect(
            r.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = latin1.decode(r.bodyBytes);
          expect(body, contains('name="name"'));
          expect(body, contains('name="foto_profil"; filename="profil.png"'));
          expect(body, isNot(contains('private-name')));
          expect(body, isNot(contains('name="fokus_budidaya"')));
          expect(body, isNot(contains('name="user_id"')));
          return http.Response(
            '{"success":true,"data":{"id":1,"name":"A"}}',
            200,
          );
        };
        expect((await api.updateProfile('A', '', file)).isSuccess, true);
        await file.writeAsBytes([...bytes, 0]);
        expect(
          (await api.updateProfile('A', '', file)).failure?.kind,
          ApiErrorKind.validation,
        );
        expect(requests.length, 1);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  for (final body in [
    '{}',
    '{"success":true,"data":{"id":1,"name":"A"}}',
    '{"id":2,"name":"wrong"}',
    '{"id":1,"name":42}',
  ]) {
    test('invalid or wrong-owner refresh rejected: $body', () async {
      handler = (_) async => http.Response(body, 200);
      expect((await api.currentUser()).isSuccess, false);
      expect(session.metadata['user_name'], 'A');
    });
  }
  test('old GET cannot undo successful update in same revision', () async {
    final sent = Completer<void>();
    final response = Completer<http.Response>();
    handler = (r) async {
      if (r.method == 'GET') {
        sent.complete();
        return response.future;
      }
      expect(jsonDecode(r.body), {'name': 'new'});
      return http.Response(
        '{"success":true,"data":{"id":1,"name":"new"}}',
        200,
      );
    };
    final revision = session.revision;
    final pending = api.currentUser();
    await sent.future;
    expect((await api.updateProfile('new', '', null)).isSuccess, true);
    response.complete(user('old'));
    expect((await pending).failure?.kind, ApiErrorKind.staleSession);
    expect(session.metadata['user_name'], 'new');
    expect(session.revision, revision);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
  for (final status in [200, 401]) {
    test('late GET A $status cannot change B', () async {
      final sent = Completer<void>();
      final response = Completer<http.Response>();
      handler = (_) {
        sent.complete();
        return response.future;
      };
      final pending = api.currentUser();
      await sent.future;
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      response.complete(
        status == 200 ? user('old') : http.Response('{}', status),
      );
      expect((await pending).isSuccess, false);
      expect(session.metadata['user_name'], 'B');
      expect(session.hasSession, true);
    });
  }
  for (final status in [403, 404, 422, 429, 503]) {
    test('update $status typed, no retry or logout', () async {
      handler = (_) async => http.Response('{}', status);
      final result = await api.updateProfile('A', '', null);
      expect(result.statusCode, status);
      expect(result.isSuccess, false);
      expect(requests.length, 1);
      expect(session.hasSession, true);
    });
  }
  testWidgets('foreign profile refused without any profile or market request', (
    tester,
  ) async {
    await initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(api: api, publicUserId: '2'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profil pengguna lain tidak tersedia.'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
  });
  testWidgets('profile metadata update does not reload market or reset route', (
    tester,
  ) async {
    await initialize();
    handler = (r) async => r.url.path.endsWith('pasars')
        ? http.Response('{"success":true,"data":[]}', 200)
        : user('A');
    await tester.pumpWidget(MaterialApp(home: ProfilScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada stok ikan.'), findsOneWidget);
    final owner = await session.snapshot();
    await session.updateMetadata(owner, {'id': 1, 'name': 'Updated'});
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('pasars')).length, 1);
    expect(find.text('Profil Saya'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await session.dispose();
  });
}
