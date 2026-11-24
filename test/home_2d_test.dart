import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/screens/asisten_samudera_screen.dart';
import 'package:aquara_mobile/screens/icon_credits_screen.dart';
import 'package:aquara_mobile/screens/analysis_screen.dart';
import 'package:aquara_mobile/screens/pasar_screen.dart';
import 'package:aquara_mobile/screens/catalog_screen.dart';
import 'package:aquara_mobile/screens/forum_screen.dart';
import 'package:aquara_mobile/screens/external_info_screen.dart';
import 'package:aquara_mobile/screens/pre_order_screen.dart';
import 'package:aquara_mobile/screens/ai_fisho_screen.dart';
import 'package:aquara_mobile/screens/berita_screen.dart';
import 'package:aquara_mobile/screens/info_dinas_screen.dart';
import 'package:aquara_mobile/screens/market_price_screen.dart';
import 'package:aquara_mobile/screens/consultation_screen.dart';
import 'package:aquara_mobile/screens/semua_komoditas_screen.dart';
import 'package:aquara_mobile/screens/notifikasi_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/sos_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/home_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/fake_token_store.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aquara_mobile/services/sos_api.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionService session;
  late ApiService api;
  late _Routes routes;
  final requests = <http.Request>[];

  Future<void> mount(
    WidgetTester tester, {
    bool login = true,
    bool dark = false,
    double scale = 1,
    Future<XFile?> Function(ImageSource)? picker,
  }) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    session = SessionService(store: FakeTokenStore());
    await session.snapshot();
    if (login) {
      await session.saveIfCurrent(
        'synthetic',
        user: {'id': 1, 'name': 'Nelayan'},
      );
    }
    requests.clear();
    api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({'status': 'success', 'data': []}),
            200,
          );
        }),
      ),
    );
    routes = _Routes();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [routes],
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            padding: const EdgeInsets.only(top: 24, bottom: 24),
          ),
          child: child!,
        ),
        home: HomeScreen(api: api, pickSosPhoto: picker),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final closing = session.dispose();
      await tester.pump();
      await closing;
    });
  }

  Future<void> catalog(WidgetTester tester) async {
    tester.widget<InkWell>(find.byKey(const ValueKey('service-all'))).onTap!();
    await tester.pumpAndSettle();
  }

  for (final login in [false, true]) {
    testWidgets(
      'single Asisten entry guarded login=$login; back preserves home',
      (tester) async {
        await mount(tester, login: login);
        final entry = find.byKey(const Key('home-asisten'));
        expect(entry, findsOneWidget);
        final rect = tester.getRect(entry);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(
          rect.bottom,
          lessThanOrEqualTo(
            tester.getRect(find.byType(BottomNavigationBar)).top,
          ),
        );
        expect(
          rect.overlaps(tester.getRect(find.byKey(const Key('sos-camera')))),
          isFalse,
        );
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        await tester.tap(entry);
        await tester.pumpAndSettle();
        if (login) {
          expect(find.byType(AsistenSamuderaScreen), findsOneWidget);
          expect(find.text(asistenSimulationLabel), findsOneWidget);
          expect(
            requests.where((r) => r.url.path == '/api/asisten/chat').length,
            1,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.byType(BottomNavigationBar), findsOneWidget);
          expect(find.byKey(const Key('support-playback')), findsOneWidget);
        } else {
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(
            requests.where((r) => r.url.path.contains('asisten')),
            isEmpty,
          );
        }
      },
    );
  }

  testWidgets('support pause survives tab removal and return', (tester) async {
    await mount(tester);
    await tester.ensureVisible(find.byKey(const Key('support-playback')));
    await tester.pump();
    await tester.tap(find.text('Jeda'));
    await tester.pump();
    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      3,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    expect(find.byKey(const Key('home-asisten')), findsNothing);
    expect(find.byKey(const Key('support-banners')), findsNothing);
    tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).onTap!(
      0,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('home-asisten')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('support-playback')));
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Lanjut'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1 / 4'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 516));
    await tester.pump();
    expect(find.text('2 / 4'), findsOneWidget);
  });

  for (final login in [false, true]) {
    for (var index = 0; index < 4; index++) {
      testWidgets('restored support banner $index login=$login physical tap', (
        tester,
      ) async {
        await mount(tester, login: login);
        await tester.ensureVisible(find.byKey(const Key('support-banners')));
        await tester.pumpAndSettle();
        final target = find.byKey(ValueKey('support-banner-$index'));
        await tester.scrollUntilVisible(
          target,
          350,
          scrollable: find.descendant(
            of: find.byKey(const Key('support-banners')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        final position = tester.getCenter(target);
        await tester.tapAt(position);
        await tester.tapAt(position);
        await tester.pumpAndSettle();
        final type = !login && index != 3
            ? LoginScreen
            : [
                AnalysisScreen,
                PasarScreen,
                ForumScreen,
                ConsultationScreen,
              ][index];
        expect(find.byType(type), findsOneWidget);
        expect(requests.every((r) => r.method == 'GET'), true);
        if (login || index == 3) {
          if (index == 0 || index == 3) {
            await tester.tap(find.byIcon(Icons.arrow_back));
          } else {
            await tester.pageBack();
          }
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(find.text('Mendukung Pembudidaya'), findsOneWidget);
        }
      });
    }
  }

  for (final source in ImageSource.values) {
    testWidgets(
      'SOS $source prefill no POST, double tap, validation and removal',
      (tester) async {
        var picks = 0;
        ImageSource? pickedSource;
        final data = await rootBundle.load('assets/icons/whatsapp.png');
        final file = XFile.fromData(
          Uint8List.sublistView(data),
          name: 'photo.png',
        );
        await SosPhoto.read(file);
        await mount(
          tester,
          picker: (actual) async {
            picks++;
            pickedSource = actual;
            return file;
          },
        );
        final nav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        nav.onTap!(2);
        nav.onTap!(2);
        await tester.pumpAndSettle();
        expect(find.text('Ambil Foto'), findsOneWidget);
        await tester.tap(
          find.text(
            source == ImageSource.camera ? 'Ambil Foto' : 'Pilih dari Galeri',
          ),
        );
        await tester.pumpAndSettle();
        expect(picks, 1);
        expect(pickedSource, source);
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(SosScreen), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) => w is Image && w.semanticLabel == 'Preview foto laporan SOS',
          ),
          findsOneWidget,
        );
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
        await tester.scrollUntilVisible(
          find.text('Kirim laporan'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Kirim laporan'));
        await tester.pumpAndSettle();
        expect(requests.where((r) => r.method == 'POST'), isEmpty);
        await tester.scrollUntilVisible(
          find.text('Hapus foto'),
          -150,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Hapus foto'));
        await tester.pumpAndSettle();
        expect(find.text('Hapus foto'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final outcome in ['cancel', 'denied', 'error', 'invalid']) {
    testWidgets('SOS picker $outcome creates no form or upload', (
      tester,
    ) async {
      await mount(
        tester,
        picker: (_) async {
          if (outcome == 'cancel') return null;
          if (outcome == 'invalid') {
            return XFile.fromData(Uint8List.fromList([1, 2, 3]));
          }
          throw PlatformException(code: outcome);
        },
      );
      await tester.tap(find.byKey(const Key('sos-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ambil Foto'));
      await tester.pumpAndSettle();
      expect(find.byType(SosScreen), findsNothing);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      if (outcome != 'cancel') {
        expect(
          find.textContaining('Foto tidak dapat dipilih.'),
          findsOneWidget,
        );
      }
    });
  }

  testWidgets('SOS guest never opens picker', (tester) async {
    var picks = 0;
    await mount(
      tester,
      login: false,
      picker: (_) async {
        picks++;
        return null;
      },
    );
    await tester.tap(find.byKey(const Key('sos-camera')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(picks, 0);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('SOS old account picker result discarded after account change', (
    tester,
  ) async {
    final pending = Completer<XFile?>();
    await mount(tester, picker: (_) => pending.future);
    await tester.tap(find.byKey(const Key('sos-camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ambil Foto'));
    await tester.pumpAndSettle();
    await session.saveIfCurrent('B', user: {'id': 2, 'name': 'B'});
    await tester.pumpAndSettle();
    final bytes = await rootBundle.load('assets/icons/whatsapp.png');
    pending.complete(XFile.fromData(bytes.buffer.asUint8List()));
    await tester.pumpAndSettle();
    expect(find.byType(SosScreen), findsNothing);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets(
    'ten local PNGs decode, have alpha, credits map to official sources',
    (tester) async {
      expect(iconCredits.length, 10);
      await tester.runAsync(() async {
        for (final credit in iconCredits) {
          final data = await rootBundle.load(credit.asset);
          expect(data.buffer.asUint8List().take(8), [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ]);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 512);
          expect(frame.image.height, 512);
          final rgba = await frame.image.toByteData();
          expect(
            [
              for (var i = 3; i < rgba!.lengthInBytes; i += 4) rgba.getUint8(i),
            ].any((a) => a < 255),
            isTrue,
          );
          expect(Uri.parse(credit.url).host, 'www.flaticon.com');
          expect(credit.author, isNotEmpty);
          frame.image.dispose();
          codec.dispose();
        }
      });
    },
  );

  for (final dark in [false, true]) {
    for (final login in [false, true]) {
      testWidgets(
        '320px text 2x keyboard scroll catalog dark=$dark login=$login',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await mount(tester, login: login, dark: dark, scale: 2);
          expect(find.text('SAMUDERA'), findsOneWidget);
          expect(
            find.text(login ? 'Hallo, Nelayan ' : 'Selamat datang'),
            findsOneWidget,
          );
          expect(find.text('Simulasi'), findsNothing);
          expect(find.text('Tanya\nGombyang'), findsOneWidget);
          await tester.ensureVisible(find.text('SOS Bahari / Lapor Darurat'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Kredit ilustrasi'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byKey(const Key('home-search')));
          await tester.tap(find.byKey(const Key('home-search')));
          await tester.pumpAndSettle();
          expect(find.byType(ServiceCatalogScreen), findsOneWidget);
          final all = tester
              .widget<ServiceCatalogScreen>(find.byType(ServiceCatalogScreen))
              .services;
          expect(all.map((s) => s.id).toSet().length, 17);
          expect(all.where((s) => s.badge == 'Simulasi'), isEmpty);
          expect(
            all
                .where((s) => s.group == ServiceGroup.primary)
                .map((s) => s.label),
            ['Analisa Usaha', 'Pasar Ikan', 'Katalog Ikan', 'Forum Komunitas'],
          );
          final before = requests.length;
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.enterText(
            find.byKey(const Key('catalog-search')),
            '  DINAS  ',
          );
          await tester.pumpAndSettle();
          expect(find.text('Info Dinas'), findsOneWidget);
          // Category tags are searched too: Berita and Info Dinas share this category.
          expect(find.byType(ServiceTile), findsNWidgets(2));
          await tester.ensureVisible(find.text('Info Dinas'));
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.byKey(const Key('catalog-search')),
            'tidak ada layanan ini',
          );
          await tester.pumpAndSettle();
          expect(find.text('Layanan tidak ditemukan.'), findsOneWidget);
          expect(requests.length, before);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  final destinations = <String, Type>{
    'analysis': AnalysisScreen,
    'market': PasarScreen,
    'fish': CatalogScreen,
    'forum': ForumScreen,
    'external-info-kkp': ExternalInfoScreen,
    'external-info-cuaca': ExternalInfoScreen,
    'external-info-tpi': ExternalInfoScreen,
    'orders': PreOrderScreen,
    'photo': AiFishoScreen,
    'my-forum': ForumScreen,
    'news': BeritaScreen,
    'department': InfoDinasScreen,
    'prices': MarketPriceScreen,
    'consultation': ConsultationScreen,
    'commodities': SemuaKomoditasScreen,
    'sos': SosScreen,
  };
  for (final entry in destinations.entries) {
    testWidgets(
      'registry ${entry.key} preserves destination and rejects queued duplicate',
      (tester) async {
        await mount(tester);
        await catalog(tester);
        final service = tester
            .widget<ServiceCatalogScreen>(find.byType(ServiceCatalogScreen))
            .services
            .singleWhere((s) => s.id == entry.key);
        final before = routes.pushed.length;
        service.onTap();
        service.onTap();
        service.onTap();
        expect(routes.pushed.length, before + 1);
        final route = routes.pushed.last as MaterialPageRoute<void>;
        final page = route.builder(
          tester.element(find.byType(ServiceCatalogScreen)),
        );
        expect(page.runtimeType, entry.value);
        if (page is ForumScreen) expect(page.mine, entry.key == 'my-forum');
        if (page is PreOrderScreen) expect(page.view, PreOrderView.history);
        // Route wiring test; destination services/guards are covered separately.
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final login in [false, true]) {
    testWidgets('notification action uses existing destination login=$login', (
      tester,
    ) async {
      await mount(tester, login: login);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.tooltip == (login ? 'Notifikasi' : 'Login'),
        ),
      );
      button.onPressed!();
      button.onPressed!();
      expect(routes.pushed.length, 2);
      final route = routes.pushed.last as MaterialPageRoute<void>;
      expect(
        route.builder(tester.element(find.byType(HomeScreen))).runtimeType,
        login ? NotifikasiScreen : LoginScreen,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'both catalog entries share registry and guard; empty market retains history',
    (tester) async {
      await mount(tester);
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Lihat semua'),
      );
      final tile = tester.widget<InkWell>(
        find.byKey(const ValueKey('service-all')),
      );
      button.onPressed!();
      tile.onTap!();
      button.onPressed!();
      expect(routes.pushed.length, 2);
      await tester.pumpAndSettle();
      expect(find.byType(ServiceCatalogScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      tester
          .widget<InkWell>(find.byKey(const ValueKey('service-market')))
          .onTap!();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Riwayat pre-order'), findsOneWidget);
      await tester.tap(find.byTooltip('Riwayat pre-order'));
      await tester.pumpAndSettle();
      expect(find.byType(PreOrderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
