import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:aquara_mobile/screens/berita_detail_screen.dart';
import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/screens/icon_credits_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/home_news_preview.dart';
import 'package:aquara_mobile/widgets/commodity_card.dart';
import 'package:aquara_mobile/widgets/home_services.dart';
import 'package:aquara_mobile/widgets/service_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  final services = [
    for (final id in serviceCategories.keys)
      HomeService(
        id: id,
        label: id,
        group: ServiceGroup.primary,
        order: 0,
        onTap: () {},
      ),
  ];
  test(
    'all categories, empty query, aliases, no duplicate or empty groups',
    () {
      final groups = groupedServices([...services, services.first], '');
      expect(groups.length, 6);
      expect(groups.values.expand((s) => s).length, 17);
      expect(
        groupedServices(services, 'preorder').values.single.single.id,
        'orders',
      );
      expect(groupedServices(services, 'tidak-ada'), isEmpty);
      expect(groupedServices(services, '  NELAYAN ').values.single.length, 4);
      for (final persona in servicePersonas) {
        expect(persona.services.toSet().length, persona.services.length);
        expect(persona.services.every(serviceCategories.containsKey), isTrue);
      }
      expect(servicePersonas[1].services, isNot(contains('analysis')));
    },
  );

  Future<(ApiService, SessionService)> apiFor(
    Future<http.Response> Function(http.Request) handler, {
    bool login = true,
  }) async {
    final session = SessionService(store: FakeTokenStore());
    await session.snapshot();
    if (login) {
      await session.saveIfCurrent('synthetic', user: {'id': 1, 'name': 'Test'});
    }
    return (
      ApiService(
        session: session,
        client: ApiClient(
          baseUrl: Uri.parse('https://example.test/api'),
          session: session,
          clientFactory: () => MockClient(handler),
        ),
      ),
      session,
    );
  }

  Map<String, dynamic> post(int id) => {
    'id': id,
    'title': 'Artikel $id',
    'content': 'Isi $id',
    'author': 'Dinas',
    'created_at': id == 1 ? null : '2026-10-24T10:00:00Z',
  };
  http.Response response(Object data) =>
      http.Response(jsonEncode({'success': true, 'data': data}), 200);

  for (final count in [0, 1, 2, 3, 5]) {
    testWidgets(
      'news $count real entries, deduplicated, exact detail and nullable date',
      (tester) async {
        var calls = 0;
        final (api, _) = await apiFor((r) async {
          calls++;
          expect(r.url.path, '/api/posts');
          return response([
            for (var i = 1; i <= count; i++) post(i),
            if (count > 0) post(1),
          ]);
        });
        Widget? opened;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeNewsPreview(
                api: api,
                openPage: (page) => opened = page,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls, 1);
        if (count == 0) {
          expect(find.text('Belum ada berita Info Diskanla.'), findsOneWidget);
        }
        for (var i = 1; i <= count.clamp(0, 3); i++) {
          await tester.tap(find.byKey(ValueKey('news-preview-$i')));
          final detail = opened as BeritaDetailScreen;
          expect(detail.title, 'Artikel $i');
          expect(detail.content, 'Isi $i');
          expect(detail.date, i == 1 ? '-' : '24 Oct 2026');
        }
        expect(find.text('Artikel 4'), findsNothing);
      },
    );
  }
  testWidgets('guest news makes no private request', (tester) async {
    var calls = 0;
    final (api, _) = await apiFor((r) async {
      calls++;
      return response([]);
    }, login: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeNewsPreview(api: api, openPage: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.textContaining('Masuk untuk membaca berita'), findsOneWidget);
  });
  for (final malformed in [false, true]) {
    testWidgets('news failure malformed=$malformed only retries manually', (
      tester,
    ) async {
      var calls = 0;
      final (api, _) = await apiFor((r) async {
        calls++;
        if (calls == 1) {
          return malformed
              ? response([
                  {'id': 'bad'},
                ])
              : http.Response('{}', 500);
        }
        return response([post(1)]);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeNewsPreview(api: api, openPage: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coba lagi'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 1);
      await tester.tap(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Artikel 1'), findsOneWidget);
    });
  }
  testWidgets('late news discarded on session switch', (tester) async {
    final pending = Completer<http.Response>();
    final (api, session) = await apiFor((r) => pending.future);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeNewsPreview(api: api, openPage: (_) {}),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await session.saveIfCurrent('other', user: {'id': 2, 'name': 'Other'});
    await tester.pump();
    pending.complete(response([post(1)]));
    await tester.pumpAndSettle();
    expect(find.text('Artikel 1'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'discovery 320px text 2x dark=$dark, category search keyboard, guide content',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget wrap(Widget child) => MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 280),
            ),
            child: child!,
          ),
          home: child,
        );
        await tester.pumpWidget(wrap(ServiceCatalogScreen(services: services)));
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'preorder',
        );
        await tester.pumpAndSettle();
        expect(find.text('Pasar & Perdagangan'), findsOneWidget);
        expect(find.text('Budidaya & Analisa Usaha'), findsNothing);
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'missing',
        );
        await tester.pumpAndSettle();
        expect(find.text('Layanan tidak ditemukan.'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('catalog-search')), '');
        await tester.pumpAndSettle();
        expect(find.text('Budidaya & Analisa Usaha'), findsOneWidget);
        for (final persona in servicePersonas) {
          await tester.pumpWidget(
            wrap(PersonaDetailScreen(persona: persona, services: services)),
          );
          await tester.pumpAndSettle();
          expect(find.text(persona.title), findsOneWidget);
          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -900),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        for (final guide in appGuides) {
          await tester.pumpWidget(wrap(AppGuideScreen(guide: guide)));
          await tester.pumpAndSettle();
          expect(find.text(guide.title), findsOneWidget);
          expect(find.text(guide.paragraphs.last), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(wrap(const IconCreditsScreen()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Pengolah — Woman Working in Fishing Industry (Vietnam)'),
          250,
          maxScrolls: 100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Quang Nguyen Vinh'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'actual registry category coverage and unique assets without exceptions',
    (tester) async {
      final (api, _) = await apiFor(
        (r) async => http.Response(
          jsonEncode({'status': 'success', 'success': true, 'data': []}),
          200,
        ),
      );
      await tester.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
      await tester.pumpAndSettle();
      tester
          .widget<InkWell>(find.byKey(const ValueKey('service-all')))
          .onTap!();
      await tester.pumpAndSettle();
      final actual = tester
          .widget<ServiceCatalogScreen>(find.byType(ServiceCatalogScreen))
          .services;
      expect(actual.map((s) => s.id).toSet(), serviceCategories.keys.toSet());
      final byBytes = <String, List<String>>{};
      for (final s in actual) {
        if (s.id == 'perizinan') {
          expect(s.asset, 'assets/icons/services/perizinan.png');
        }
        final bytes = File(s.asset!).readAsBytesSync();
        byBytes.putIfAbsent(base64Encode(bytes), () => []).add(s.id);
      }
      expect(
        byBytes.values.where((ids) => ids.length > 1).map((ids) => ids.toSet()),
        isEmpty,
      );
      expect(
        actual.singleWhere((s) => s.id == 'my-forum').asset,
        'assets/icons/services/forum_saya.png',
      );
      expect(
        actual.singleWhere((s) => s.id == 'commodities').asset,
        'assets/icons/services/semua_komoditas.png',
      );
      for (final query in ['Forum Saya', 'Semua Komoditas']) {
        final matched = groupedServices(actual, query).values.single.single;
        expect(
          identical(matched, actual.singleWhere((s) => s.id == matched.id)),
          true,
        );
      }
    },
  );
  testWidgets('new supplied assets decode and credits available', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final asset in [
        ...additionalIconCredits.map((c) => c.asset),
        ...discoveryPhotoCredits.map((c) => c.asset),
        'assets/icons/services/info_dinas.png',
      ]) {
        final bytes = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
          targetWidth: 320,
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });

  testWidgets(
    'processor choice/detail use same real photo with preserved ratio',
    (tester) async {
      final persona = servicePersonas.singleWhere((p) => p.id == 'pengolah');
      expect(persona.photo, 'pengolah');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PersonaChoices(onSelected: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      final photos = tester.widgetList<DiscoveryPhoto>(
        find.byType(DiscoveryPhoto),
      );
      expect(photos.singleWhere((p) => p.photo == 'pengolah').round, true);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonaDetailScreen(persona: persona, services: services),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image).first);
      expect(image.fit, BoxFit.contain);
      expect(find.textContaining('Vietnam'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        additionalIconCredits
            .singleWhere((c) => c.asset.endsWith('forum_saya.png'))
            .author,
        'mikan933',
      );
      expect(
        additionalIconCredits
            .singleWhere((c) => c.asset.endsWith('semua_komoditas.png'))
            .author,
        'Magnific',
      );
      expect(
        discoveryPhotoCredits
            .singleWhere((c) => c.asset.endsWith('pengolah.jpg'))
            .licenseUrl,
        'https://www.pexels.com/license/',
      );
    },
  );

  testWidgets(
    'persona route double-open guarded, recommendation keeps guest guard',
    (tester) async {
      var calls = 0;
      final (api, _) = await apiFor((r) async {
        calls++;
        return response([]);
      }, login: false);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
      await tester.pumpAndSettle();
      final choice = tester.widget<InkWell>(
        find.byKey(const ValueKey('persona-tawar')),
      );
      choice.onTap!();
      choice.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(PersonaDetailScreen), findsOneWidget);
      final recommendation = tester.widget<InkWell>(
        find.byKey(const ValueKey('persona-service-analysis')),
      );
      recommendation.onTap!();
      recommendation.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(calls, 0);
    },
  );

  testWidgets(
    'all three banner taps open matching public guide; back restores home',
    (tester) async {
      final (api, _) = await apiFor((r) async => response([]), login: false);
      await tester.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
      await tester.pumpAndSettle();
      for (var i = 0; i < appGuides.length; i++) {
        final guide = appGuides[i];
        await tester.ensureVisible(find.byType(PageView).last);
        await tester.pumpAndSettle();
        final banner = tester.widget<InkWell>(
          find.byKey(ValueKey('guide-${guide.id}')),
        );
        banner.onTap!();
        banner.onTap!();
        await tester.pumpAndSettle();
        expect(
          tester.widget<AppGuideScreen>(find.byType(AppGuideScreen)).guide.id,
          guide.id,
        );
        expect(find.text(guide.title), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        if (i < appGuides.length - 1) {
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Banner berikutnya',
                ),
              )
              .onPressed!();
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blue cards exact and logo enlarged without changing fish values',
    (tester) async {
      final (api, _) = await apiFor(
        (r) async => r.url.path.endsWith('fish-types')
            ? http.Response(
                jsonEncode({
                  'status': 'success',
                  'data': [
                    {
                      'id': 1,
                      'name': 'Lele',
                      'fcr_ratio': 1,
                      'harvest_duration_days': 60,
                      'market_price_per_kg': 18000,
                      'standard_density_per_m2': 100,
                      'survival_rate': 90,
                      'feed_price_per_kg': 12000,
                    },
                  ],
                }),
                200,
              )
            : response([]),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: HomeScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in [
        'SOS Bahari / Lapor Darurat',
        'Info Diskanla & Umum Terkini',
      ]) {
        final card = tester.widget<Card>(
          find.ancestor(of: find.text(text), matching: find.byType(Card)).first,
        );
        expect(card.color, const Color(0xFF009FE3));
        expect(card.surfaceTintColor, Colors.transparent);
      }
      final commodity = tester.widget<Material>(
        find.descendant(
          of: find.byType(CommodityCard),
          matching: find.byType(Material),
        ),
      );
      expect(commodity.color, const Color(0xFF009FE3));
      expect(commodity.surfaceTintColor, Colors.transparent);
      expect(find.text('Lele'), findsOneWidget);
      final logo = tester.widget<Image>(
        find.byWidgetPredicate(
          (w) => w is Image && w.semanticLabel == 'Logo SAMUDERA',
        ),
      );
      expect(logo.width, 94);
      expect(logo.fit, BoxFit.contain);
      expect(find.textContaining('FCR 1 • Panen 60 Hari'), findsOneWidget);
    },
  );
}
