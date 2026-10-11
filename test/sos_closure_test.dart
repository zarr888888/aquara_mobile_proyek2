import 'dart:async';
import 'dart:io';

import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/sos_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/auth_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/fake_token_store.dart';
import 'sos_test.dart' show envelope, report;

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

// Uses the real Flutter NetworkImage loading path up to the HTTP client seam.
// No sockets, DNS, TLS or production API. Unexpected fake calls fail loudly.
class _ImageHeaders extends Fake implements HttpHeaders {
  final values = <String, List<String>>{};
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    values.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name.toLowerCase()] = [value.toString()];
  }
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.statusCode);
  static late List<int> bytes;
  @override
  final int statusCode;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.uri, this.status);
  @override
  final Uri uri;
  final int status;
  bool closed = false;
  @override
  final _ImageHeaders headers = _ImageHeaders();
  @override
  Future<HttpClientResponse> close() async {
    closed = true;
    return _ImageResponse(status);
  }
}

class _ImageClient extends Fake implements HttpClient {
  final requests = <_ImageRequest>[];
  int status = 200;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final request = _ImageRequest(url, status);
    requests.add(request);
    return request;
  }
}

void main() {
  void closureTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final previous = debugNetworkImageHttpClientProvider;
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        debugNetworkImageHttpClientProvider = previous;
      }
    });
  }

  late SessionService session;
  late ApiService api;
  late _Routes routes;
  late _ImageClient images;
  late Future<http.Response> Function(http.Request) handler;
  final requests = <http.Request>[];

  Future<void> initialize(WidgetTester tester, {bool guest = false}) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    routes = _Routes();
    images = _ImageClient();
    _ImageResponse.bytes = (await rootBundle.load(
      'assets/logo2.png',
    )).buffer.asUint8List();
    final previous = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => images;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    session = SessionService(store: FakeTokenStore());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final disposal = session.dispose();
      await tester.pump();
      await disposal;
      debugNetworkImageHttpClientProvider = previous;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    if (!guest) {
      await session.saveIfCurrent('SYNTHETIC-A', user: {'id': 1, 'name': 'A'});
    }
    handler = (r) async {
      if (r.url.path.endsWith('fish-types')) {
        return http.Response('{"status":"success","data":[]}', 200);
      }
      if (r.url.path.endsWith('/lapor-darurat')) return envelope([report()]);
      if (r.url.path.endsWith('/lapor-darurat/1')) return envelope(report());
      throw StateError('Unexpected API request in SOS test');
    };
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

  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(navigatorObservers: [routes], home: screen),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester) async {
    await tester.tap(find.text('SOS Bahari / Lapor Darurat'));
    await tester.pumpAndSettle();
  }

  for (final guest in [false, true]) {
    closureTest('Beranda actual repeated SOS taps guest=$guest single route', (
      tester,
    ) async {
      await initialize(tester, guest: guest);
      await mount(tester, HomeScreen(api: api));
      for (final label in [
        'Analisa Usaha',
        'Harga Pasar',
        'Katalog Ikan',
        'Forum',
        'Konsultasi',
        'Info Dinas',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      final entry = find.text('SOS Bahari / Lapor Darurat');
      final onTap = tester
          .widget<ListTile>(
            find.ancestor(of: entry, matching: find.byType(ListTile)),
          )
          .onTap!;
      await tester.tap(entry);
      // Exercise queued callbacks too: the new route can obscure later pointer taps.
      onTap();
      onTap();
      await tester.pumpAndSettle();
      expect(routes.pushed.length, guest ? 3 : 2); // Home, SOS, optional Login.
      expect(find.byType(guest ? LoginScreen : SosScreen), findsOneWidget);
      expect(
        requests.where((r) => r.url.path.contains('lapor-darurat')),
        isEmpty,
      );
      if (guest) {
        expect(requests, isEmpty);
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          false,
        );
      } else {
        await tester.tap(find.text('Periksa riwayat saya'));
        await tester.pumpAndSettle();
        expect(
          requests.where((r) => r.url.path.endsWith('lapor-darurat')).length,
          1,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        await enter(tester);
        expect(find.text('SOS Bahari'), findsOneWidget);
      }
    });
  }

  for (final replace in [false, true]) {
    closureTest(
      'Beranda SOS draft and history cleared replace=$replace Back safe',
      (tester) async {
        await initialize(tester);
        await mount(tester, HomeScreen(api: api));
        await enter(tester);
        await tester.enterText(find.byType(TextField), 'Draft akun A');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.tap(find.text('Periksa riwayat saya'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Wabah Penyakit'));
        await tester.pumpAndSettle();
        expect(find.text('Laporan uji'), findsOneWidget);
        if (replace) {
          await session.saveIfCurrent(
            'SYNTHETIC-B',
            user: {'id': 2, 'name': 'B'},
          );
        } else {
          await session.clear();
        }
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(SosScreen, skipOffstage: false), findsNothing);
        expect(find.text('Draft akun A', skipOffstage: false), findsNothing);
        expect(find.text('Laporan uji', skipOffstage: false), findsNothing);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        expect(await navigator.maybePop(), false);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(session.hasSession, replace);
        if (replace) expect(session.metadata['user_name'], 'B');
      },
    );
  }

  for (final dark in [false, true]) {
    closureTest('SOS UX inline validation 320 large text keyboard dark=$dark', (
      tester,
    ) async {
      await initialize(tester);
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
              viewInsets: const EdgeInsets.only(bottom: 200),
            ),
            child: child!,
          ),
          home: SosScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.text('Kirim laporan');
      await tester.scrollUntilVisible(
        submit,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.decoration!.errorText,
        'Deskripsi wajib diisi, maksimal 5000 karakter.',
      );
      expect(field.controller!.text, isEmpty);
      expect(requests, isEmpty);
      await tester.scrollUntilVisible(
        find.text('Foto opsional: JPEG/PNG, maksimal 2048 KB.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Foto opsional: JPEG/PNG, maksimal 2048 KB.'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        submit,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  final relative = Uri.parse(
    AuthService.apiBaseUrl,
  ).resolve('/storage/sos/photo.png').toString();
  for (final photo in [
    'https://third-party.test/photo.png?version=1',
    'sos/photo.png',
  ]) {
    for (final status in [200, 404]) {
      closureTest(
        'SOS image actual fake HTTP photo=$photo status=$status no credentials',
        (tester) async {
          await initialize(tester);
          images.status = status;
          handler = (_) async => envelope({...report(), 'foto': photo});
          await mount(tester, SosScreen(api: api, page: SosPage.detail, id: 1));
          // Image codecs may complete outside the fake clock; wait without networking.
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          final image = tester.widget<Image>(find.byType(Image));
          final provider = image.image as NetworkImage;
          final expected = photo.startsWith('https:') ? photo : relative;
          expect(provider.url, expected);
          expect(provider.headers, isNull);
          final request = images.requests.single;
          expect(request.uri.toString(), expected);
          expect(request.closed, true);
          expect(request.headers.values, isEmpty);
          expect(request.headers.values.containsKey('authorization'), false);
          expect(request.uri.toString(), isNot(contains('SYNTHETIC-A')));
          expect(
            requests.single.headers['Authorization'],
            'Bearer SYNTHETIC-A',
          );
          if (status == 404) {
            expect(find.text('Foto tidak tersedia'), findsOneWidget);
          } else {
            expect(find.text('Foto tidak tersedia'), findsNothing);
            expect(
              tester.widget<RawImage>(find.byType(RawImage)).image,
              isNotNull,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final photo in [
    null,
    '',
    'http://unsafe.test/a',
    'javascript:alert(1)',
    '../private',
    42,
  ]) {
    closureTest('SOS nullable invalid image fallback no HTTP $photo', (
      tester,
    ) async {
      await initialize(tester);
      handler = (_) async => envelope({...report(), 'foto': photo});
      await mount(tester, SosScreen(api: api, page: SosPage.detail, id: 1));
      expect(find.text('Tidak ada foto'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(images.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
