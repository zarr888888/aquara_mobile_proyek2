import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:aquara_mobile/screens/ai_fisho_screen.dart';
import 'package:aquara_mobile/services/ai_analysis_api.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_result.dart';
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

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a/a0AAAAASUVORK5CYII=',
);
XFile photo() => XFile.fromData(png, path: 'fish.png');
http.Response success() => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'image_path': 'https://images.example.test/fish.png',
      'disease_detected': 'Hasil ikan',
      'water_quality_status': 'Hasil air',
      'solution': '<script>navigate("https://evil.test")</script>',
      'raw_ai_response': 'RAW_DO_NOT_RENDER',
    },
  }),
  200,
);

class BrokenFile extends XFile {
  BrokenFile() : super('private-local-path.png');
  @override
  Future<int> length() async => throw StateError('private-local-path');
}

class DelayedFile extends XFile {
  DelayedFile(this.gate) : super('fish.png');
  final Completer<Uint8List> gate;
  @override
  Future<int> length() async => png.length;
  @override
  Future<Uint8List> readAsBytes() => gate.future;
}

class StreamClient extends http.BaseClient {
  StreamClient(this.sendFake);
  final Future<http.StreamedResponse> Function(http.BaseRequest) sendFake;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      sendFake(request);
}

class ShortTimeoutApi extends ApiService {
  ShortTimeoutApi({required super.session, required super.client});
  @override
  Future<ApiResult<AiAnalysis>> analyzeImage({
    required AiImage image,
    required SessionSnapshot expectedSession,
    Duration requestTimeout = aiRequestTimeout,
  }) => super.analyzeImage(
    image: image,
    expectedSession: expectedSession,
    requestTimeout: const Duration(milliseconds: 20),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  late ApiService api;
  late ApiClient client;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];
  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('A', user: {'id': 1, 'name': 'A'});
    requests.clear();
    handler = (_) async => success();
    client = ApiClient(
      session: session,
      baseUrl: Uri.parse('https://backend.test/api'),
      clientFactory: () => MockClient((r) {
        requests.add(r);
        return handler(r);
      }),
    );
    api = ApiService(session: session, client: client);
  }

  setUp(initialize);
  Future<ApiResult<AiAnalysis>> analyze({
    Duration timeout = aiRequestTimeout,
    SessionSnapshot? owner,
  }) async => api.analyzeImage(
    image: (await AiImage.read(photo())).data!,
    expectedSession: owner ?? await session.snapshot(),
    requestTimeout: timeout,
  );

  test(
    'POST relative path Bearer Accept binary boundary and only image',
    () async {
      expect((await analyze()).isSuccess, isTrue);
      final r = requests.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://backend.test/api/ai-analyze');
      expect(r.headers['Authorization'], 'Bearer A');
      expect(r.headers['Accept'], 'application/json');
      expect(
        r.headers['content-type'],
        contains('multipart/form-data; boundary='),
      );
      final body = latin1.decode(r.bodyBytes);
      expect(
        RegExp(
          'content-disposition:',
          caseSensitive: false,
        ).allMatches(body).length,
        1,
      );
      expect(body, contains('name="image"; filename="image.png"'));
      expect(body, contains(latin1.decode(png)));
      for (final field in ['user_id', 'prompt', 'base64', 'https://']) {
        expect(body, isNot(contains(field)));
      }
    },
  );

  for (final extension in ['jpg', 'jpeg', 'JPG', 'png']) {
    test('accept $extension and exact AI limit', () async {
      final bytes = Uint8List(aiImageMaxBytes);
      bytes.setAll(0, extension == 'png' ? png : [255, 216, 255]);
      expect(
        (await AiImage.read(
          XFile.fromData(bytes, path: 'fish.$extension'),
        )).isSuccess,
        isTrue,
      );
    });
  }
  test(
    'reject above limit invalid signature extension empty and read failure safely',
    () async {
      for (final file in [
        XFile.fromData(Uint8List(aiImageMaxBytes + 1), path: 'fish.png'),
        XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'fish.jpg'),
        XFile.fromData(png, path: 'fish.gif'),
        XFile.fromData(Uint8List(0), path: 'fish.png'),
        BrokenFile(),
      ]) {
        final result = await AiImage.read(file);
        expect(result.failure?.kind, ApiErrorKind.validation);
        expect(result.failure!.message, isNot(contains('private-local-path')));
      }
      expect(requests, isEmpty);
    },
  );
  for (final body in [
    'not-json',
    '{}',
    '{"success":true,"data":{}}',
    '{"success":false,"data":{}}',
    '{"success":true,"data":{"solution":42}}',
  ]) {
    test('malformed response is not a diagnosis: $body', () async {
      handler = (_) async => http.Response(body, 200);
      final result = await analyze();
      expect(result.failure?.kind, ApiErrorKind.invalidResponse);
      expect(result.data, isNull);
    });
  }
  for (final status in [401, 403, 404, 422, 429, 500, 503]) {
    test(
      'safe error $status without envelope and contextual session',
      () async {
        handler = (_) async =>
            http.Response('secret stack provider path', status);
        final result = await analyze();
        expect(result.isSuccess, isFalse);
        expect(result.statusCode, status);
        expect(result.failure!.message, isNot(contains('secret')));
        expect(session.hasSession, status != 401);
        expect(requests.length, 1);
      },
    );
  }
  for (final header in [null, '3', 'Wed, 07 Oct 2026 00:00:03 GMT']) {
    test('429 retry header $header', () async {
      handler = (_) async =>
          http.Response('{}', 429, headers: {'retry-after': ?header});
      final r = await analyze();
      expect(r.failure!.kind, ApiErrorKind.rateLimited);
      expect(r.failure!.retryAt == null, header == null);
    });
  }
  test(
    'AI policy is 180s default stays 30s and timeout never retries',
    () async {
      expect(aiRequestTimeout, const Duration(seconds: 180));
      expect(client.timeout, const Duration(seconds: 30));
      final gate = Completer<http.Response>();
      handler = (_) => gate.future;
      final r = await analyze(timeout: const Duration(milliseconds: 10));
      expect(r.failure!.kind, ApiErrorKind.timeout);
      expect(requests.length, 1);
      gate.complete(success());
    },
  );
  test('timeout covers response stream as well as send', () async {
    final body = StreamController<List<int>>();
    client = ApiClient(
      session: session,
      baseUrl: Uri.parse('https://backend.test/api'),
      clientFactory: () =>
          StreamClient((_) async => http.StreamedResponse(body.stream, 200)),
    );
    api = ApiService(client: client, session: session);
    expect(
      (await analyze(timeout: const Duration(milliseconds: 10))).failure!.kind,
      ApiErrorKind.timeout,
    );
    await body.close();
  });
  test(
    'AI override extends send deadline without changing other requests',
    () async {
      client = ApiClient(
        session: session,
        baseUrl: Uri.parse('https://backend.test/api'),
        timeout: const Duration(milliseconds: 10),
        clientFactory: () => MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return success();
        }),
      );
      api = ApiService(client: client, session: session);
      expect(
        (await analyze(timeout: const Duration(milliseconds: 200))).isSuccess,
        isTrue,
      );
      expect((await client.get('user')).failure!.kind, ApiErrorKind.timeout);
    },
  );
  for (final status in [200, 401, 500]) {
    test('late A $status cannot change or invalidate B', () async {
      final gate = Completer<http.Response>();
      handler = (_) => gate.future;
      final pending = analyze();
      while (requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      gate.complete(status == 200 ? success() : http.Response('{}', status));
      expect((await pending).failure!.kind, ApiErrorKind.staleSession);
      expect(await session.readToken(), 'B');
      expect(requests.single.headers['Authorization'], 'Bearer A');
    });
  }
  test('guest and stale owner cannot dispatch', () async {
    final owner = await session.snapshot();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    expect(
      (await analyze(owner: owner)).failure!.kind,
      ApiErrorKind.staleSession,
    );
    await session.invalidate(await session.snapshot());
    expect((await analyze()).failure!.kind, ApiErrorKind.unauthenticated);
    expect(requests, isEmpty);
  });

  Future<void> open(
    WidgetTester tester, {
    Future<XFile?> Function(ImageSource)? picker,
    bool dark = false,
    bool small = false,
    DateTime Function()? clock,
  }) async {
    if (small) {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(small ? 1.8 : 1)),
          child: child!,
        ),
        home: AiFishoScreen(
          api: api,
          clock: clock,
          pickImage: picker ?? (_) async => photo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester) async {
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final f = find.text('ANALISA SEKARANG');
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump();
  }

  testWidgets(
    'double tap locks picker and submit, plain text result, new photo clears result',
    (tester) async {
      await initialize();
      final gate = Completer<http.Response>();
      handler = (_) => gate.future;
      var picks = 0;
      await open(
        tester,
        picker: (_) async {
          picks++;
          return photo();
        },
      );
      await pick(tester);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'ANALISA SEKARANG'),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.tap(find.text('Galeri'));
      await tester.pump();
      expect(requests.length, 1);
      expect(picks, 1);
      gate.complete(success());
      await tester.pumpAndSettle();
      expect(find.text('Hasil ikan'), findsOneWidget);
      expect(
        find.text('<script>navigate("https://evil.test")</script>'),
        findsOneWidget,
      );
      expect(find.text('RAW_DO_NOT_RENDER'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(
        tester.widget<Image>(find.byType(Image)).image,
        isA<MemoryImage>(),
      );
      await pick(tester);
      expect(find.text('Hasil ikan'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final delayRead in [false, true]) {
    testWidgets(
      'pending ${delayRead ? "file" : "picker"} A is discarded after B',
      (tester) async {
        await initialize();
        final pickerGate = Completer<XFile?>();
        final readGate = Completer<Uint8List>();
        await open(
          tester,
          picker: (_) => delayRead
              ? Future.value(DelayedFile(readGate))
              : pickerGate.future,
        );
        await tester.tap(find.text('Galeri'));
        await tester.pump();
        await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
        if (delayRead) {
          readGate.complete(png);
        } else {
          pickerGate.complete(photo());
        }
        await tester.pumpAndSettle();
        expect(find.byType(AiFishoScreen), findsNothing);
        expect(requests, isEmpty);
        expect(await session.readToken(), 'B');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('guest direct entry does not open picker or send', (
    tester,
  ) async {
    await initialize();
    await session.invalidate(await session.snapshot());
    var picked = false;
    await open(
      tester,
      picker: (_) async {
        picked = true;
        return photo();
      },
    );
    expect(find.text('Galeri'), findsNothing);
    expect(picked, isFalse);
    expect(requests, isEmpty);
  });
  testWidgets('logout removes selected image and success result', (
    tester,
  ) async {
    await initialize();
    await open(tester);
    await pick(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Hasil ikan'), findsOneWidget);
    await session.invalidate(await session.snapshot());
    await tester.pumpAndSettle();
    expect(find.text('Hasil ikan'), findsNothing);
    expect(find.byType(AiFishoScreen), findsNothing);
  });
  testWidgets('timeout exits loading with uncertain result and no retry', (
    tester,
  ) async {
    await initialize();
    api = ShortTimeoutApi(session: session, client: client);
    final gate = Completer<http.Response>();
    handler = (_) => gate.future;
    await open(tester);
    await pick(tester);
    await submit(tester);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.textContaining('Analisis mungkin sudah diproses'),
      findsOneWidget,
    );
    await tester.pump(const Duration(minutes: 4));
    expect(requests.length, 1);
    gate.complete(success());
    await tester.pumpAndSettle();
    expect(find.text('Hasil ikan'), findsNothing);
  });
  for (final header in [null, '2']) {
    testWidgets(
      'cooldown $header blocks repeated submit uses deadline after resume',
      (tester) async {
        await initialize();
        var now = DateTime.now();
        handler = (_) async =>
            http.Response('{}', 429, headers: {'retry-after': ?header});
        await open(tester, clock: () => now);
        await pick(tester);
        await submit(tester);
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          ElevatedButton,
          'KIRIM ANALISIS BARU',
        );
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        if (header == null) {
          expect(find.textContaining('Ini jeda lokal'), findsOneWidget);
        }
        now = now.add(const Duration(seconds: 65));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
        expect(requests.length, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final dark in [false, true]) {
    testWidgets(
      '320 large text ${dark ? "dark" : "light"} success loading cooldown error',
      (tester) async {
        await initialize();
        await open(tester, small: true, dark: dark);
        await pick(tester);
        final gate = Completer<http.Response>();
        handler = (_) => gate.future;
        await submit(tester);
        expect(tester.takeException(), isNull);
        gate.complete(success());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Galeri'));
        await pick(tester);
        handler = (_) async => http.Response('{}', 429);
        await submit(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final status in [200, 401, 500]) {
    testWidgets('caller ignores late A $status after B login', (tester) async {
      await initialize();
      final gate = Completer<http.Response>();
      handler = (_) => gate.future;
      await open(tester);
      await pick(tester);
      await submit(tester);
      expect(requests.length, 1);
      await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
      await tester.pumpAndSettle();
      gate.complete(
        status == 200 ? success() : http.Response('private', status),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hasil ikan'), findsNothing);
      expect(find.byKey(const ValueKey('ai-error')), findsNothing);
      expect(await session.readToken(), 'B');
      expect(requests.single.headers['Authorization'], 'Bearer A');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('422 retains image and allows only explicit new analysis', (
    tester,
  ) async {
    await initialize();
    handler = (_) async => http.Response('private provider stack', 422);
    await open(tester);
    await pick(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-error')), findsOneWidget);
    expect(find.textContaining('private provider'), findsNothing);
    expect(find.text('Hasil Diagnosa AI'), findsNothing);
    expect(requests.length, 1);
    final button = find.widgetWithText(ElevatedButton, 'KIRIM ANALISIS BARU');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    handler = (_) async => success();
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(find.text('Hasil ikan'), findsOneWidget);
  });
}
