import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:aquara_mobile/screens/icon_credits_screen.dart';
import 'package:aquara_mobile/models/perizinan_guide.dart';
import 'package:aquara_mobile/screens/perizinan_screen.dart';
import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/home_services.dart';
import 'package:aquara_mobile/widgets/samudera_theme.dart';
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

  test(
    'exact HTTPS catalog; rejects credentials, paths, schemes and impostors',
    () {
      final sources = [
        diskanlaAssistance,
        ...perizinanTopics.expand((t) => t.sources),
      ];
      expect(sources.length, 7);
      expect(sources.map((s) => s.id).toSet().length, 7);
      for (final source in sources) {
        expect(isApprovedGuideUrl(source.url), isTrue);
        expect(source.checked, '27 Oktober 2026');
        for (final bad in [
          source.url.replaceFirst('https:', 'http:'),
          '${source.url}?token=private',
          '${source.url}#secret',
          '${source.url}/other',
          source.url.replaceFirst('https://', 'https://user@'),
          source.url.replaceFirst('.go.id', '.go.id.evil.test'),
        ]) {
          expect(isApprovedGuideUrl(bad), isFalse, reason: bad);
        }
      }
      for (final bad in [
        'javascript:alert(1)',
        'file:///tmp/x',
        'data:text/html,x',
        'https://perizinan.kkp.go.id:443/',
        'https://perizinan.kkp.go.id./',
        'https://evil.test/',
        '//perizinan.kkp.go.id/',
      ]) {
        expect(isApprovedGuideUrl(bad), isFalse);
      }
    },
  );

  for (final brightness in Brightness.values) {
    for (final size in [const Size(400, 1200), const Size(320, 640)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('choice top spacing $size scale=$scale $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var launches = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: samuderaTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: child!,
              ),
              home: PerizinanScreen(
                launcher: (_) async {
                  launches++;
                  return true;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final gap =
              tester.getTopLeft(find.text('Pilih panduan yang dibutuhkan')).dy -
              tester.getRect(find.byType(AppBar)).bottom;
          expect(gap, closeTo(16, .01));
          for (final topic in perizinanTopics) {
            expect(
              find.byKey(ValueKey('guide-topic-${topic.id}')),
              findsOneWidget,
            );
          }
          await tester.ensureVisible(find.byKey(const ValueKey('guide-help')));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(const ValueKey('guide-help'))).bottom,
            lessThanOrEqualTo(size.height - 24),
          );
          expect(launches, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
    testWidgets(
      '320px 2x $brightness: all content, safe scroll, no inputs or automatic launches',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final launched = <Uri>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: samuderaTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: child!,
            ),
            home: PerizinanScreen(
              launcher: (uri) async {
                launched.add(uri);
                return true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(launched, isEmpty);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(Form), findsNothing);
        expect(find.byType(SafeArea), findsWidgets);
        expect(find.text('Pilih panduan yang dibutuhkan'), findsOneWidget);
        expect(find.textContaining('Diperiksa:'), findsNothing);
        for (final topic in perizinanTopics) {
          final card = find.byKey(ValueKey('guide-topic-${topic.id}'));
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels;
          final tap = tester.widget<InkWell>(card).onTap!;
          tap();
          tap();
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<PerizinanDetailScreen>(
                  find.byType(PerizinanDetailScreen),
                )
                .topic,
            same(topic),
          );
          expect(find.text(topic.title), findsOneWidget);
          expect(find.text(topic.summary), findsOneWidget);
          expect(find.text(topic.caution), findsOneWidget);
          for (var i = 0; i < topic.steps.length; i++) {
            expect(find.text('${i + 1}. ${topic.steps[i]}'), findsOneWidget);
          }
          expect(find.textContaining('NIK, KTP'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(find.byType(Form), findsNothing);
          expect(find.textContaining('Diperiksa:'), findsNothing);
          final primary = find.byKey(ValueKey('guide-primary-${topic.id}'));
          await tester.ensureVisible(primary);
          await tester.tap(primary);
          await tester.pumpAndSettle();
          expect(
            launched.last.toString(),
            topic.sources
                .firstWhere(
                  (s) =>
                      s.id ==
                      switch (topic.id) {
                        'kusuka' => 'stelina',
                        'kapal' => 'portal',
                        _ => 'bpjs',
                      },
                )
                .url,
          );
          await tester.ensureVisible(find.text('Sumber & pembaruan'));
          await tester.tap(find.text('Sumber & pembaruan'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('belum ditinjau oleh dinas'),
            findsOneWidget,
          );
          for (final source in [...topic.sources, diskanlaAssistance]) {
            final button = find.byKey(
              ValueKey('guide-link-${topic.id}-${source.id}'),
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            expect(tester.getRect(button).bottom, lessThanOrEqualTo(616));
            expect(
              find.text('${source.action}\n${Uri.parse(source.url).host}'),
              findsWidgets,
            );
            expect(find.text(source.url), findsNothing);
            expect(find.text('Diperiksa: ${source.checked}'), findsWidgets);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(launched.last.toString(), source.url);
            expect(launched.last.hasQuery, false);
            expect(tester.takeException(), isNull);
          }
          if (topic.id == 'perlindungan') {
            expect(find.text('Publikasi: 10 Februari 2026'), findsOneWidget);
          }
          await tester.ensureVisible(find.text('Sumber & pembaruan'));
          await tester.tap(find.text('Sumber & pembaruan'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Diperiksa:'), findsNothing);
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(PerizinanDetailScreen), findsNothing);
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .pixels,
            position,
          );
        }
        expect(launched.length, 12);
      },
    );
  }

  for (final outcome in ['success', 'false', 'exception']) {
    testWidgets(
      'launch $outcome: double tap guarded, safe outcome, manual retry only',
      (tester) async {
        final pending = Completer<bool>();
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: PerizinanDetailScreen(
              topic: perizinanTopics.first,
              launcher: (_) {
                calls++;
                return pending.future;
              },
            ),
          ),
        );
        final button = find.byKey(const ValueKey('guide-help'));
        await tester.ensureVisible(button);
        final callback = tester.widget<OutlinedButton>(button).onPressed!;
        callback();
        callback();
        await tester.pump();
        expect(calls, 1);
        expect(
          tester
              .widgetList<OutlinedButton>(find.byType(OutlinedButton))
              .every((b) => b.onPressed == null),
          true,
        );
        if (outcome == 'exception') {
          pending.completeError(StateError('PRIVATE RAW ERROR'));
        } else {
          pending.complete(outcome == 'success');
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(SnackBar),
          outcome == 'success' ? findsNothing : findsOneWidget,
        );
        expect(find.textContaining('PRIVATE RAW ERROR'), findsNothing);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        await tester.pump(const Duration(seconds: 10));
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('dispose while launching does not show error or setState', (
    tester,
  ) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: PerizinanDetailScreen(
          topic: perizinanTopics.first,
          launcher: (_) => pending.future,
        ),
      ),
    );
    tester
        .widget<OutlinedButton>(find.byKey(const ValueKey('guide-help')))
        .onPressed!();
    await tester.pumpWidget(const SizedBox());
    pending.completeError(StateError('hidden'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('default launcher uses external browser without headers', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(const MaterialApp(home: PerizinanScreen()));
    expect(calls, isEmpty);
    tester
        .widget<OutlinedButton>(find.byKey(const ValueKey('guide-help')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(calls.length, 1);
    expect(calls.single.arguments['url'], diskanlaAssistance.url);
    expect(calls.single.arguments['useWebView'], false);
    expect(calls.single.arguments['headers'], isEmpty);
  });

  testWidgets(
    'Perizinan asset decodes with alpha and matches existing credits',
    (tester) async {
      final credit = additionalIconCredits.singleWhere(
        (c) => c.asset.endsWith('/perizinan.png'),
      );
      expect(credit.author, 'Magnific');
      expect(
        credit.url,
        'https://www.flaticon.com/free-icon/certificate_9095982',
      );
      final bytes = await rootBundle.load(credit.asset);
      expect(bytes.buffer.asUint8List().take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 512);
        expect(image.height, 512);
        final rgba = await image.toByteData();
        expect(rgba!.getUint8(3), 0);
        image.dispose();
        codec.dispose();
      });
      await tester.pumpWidget(const MaterialApp(home: IconCreditsScreen()));
      await tester.scrollUntilVisible(
        find.text(credit.label),
        400,
        maxScrolls: 50,
      );
      expect(find.text(credit.label), findsOneWidget);
    },
  );

  for (final login in [false, true]) {
    testWidgets(
      'registry/search/catalog public navigation login=$login; double open/back no API',
      (tester) async {
        final session = SessionService(store: FakeTokenStore());
        await session.snapshot();
        if (login) {
          await session.saveIfCurrent(
            'synthetic',
            user: {'id': 1, 'name': 'Test'},
          );
        }
        var requests = 0;
        final api = ApiService(
          session: session,
          client: ApiClient(
            baseUrl: Uri.parse('https://example.test/api'),
            session: session,
            clientFactory: () => MockClient((r) async {
              requests++;
              return http.Response(
                jsonEncode({'status': 'success', 'success': true, 'data': []}),
                200,
              );
            }),
          ),
        );
        await tester.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
        await tester.pumpAndSettle();
        final baseline = requests;
        tester
            .widget<InkWell>(find.byKey(const ValueKey('service-all')))
            .onTap!();
        await tester.pumpAndSettle();
        final services = tester
            .widget<ServiceCatalogScreen>(find.byType(ServiceCatalogScreen))
            .services;
        final entry = services.singleWhere((s) => s.id == 'perizinan');
        expect(entry.requiresSession, false);
        expect(entry.asset, 'assets/icons/services/perizinan.png');
        expect(serviceCategories[entry.id], ServiceCategory.marine);
        for (final query in [
          'Perizinan',
          'KUSUKA',
          'SIPI',
          'SIKPI',
          'asuransi',
          'BPJS',
        ]) {
          expect(
            groupedServices(services, query).values.single.single,
            same(entry),
          );
        }
        await tester.enterText(
          find.byKey(const Key('catalog-search')),
          'KUSUKA',
        );
        await tester.pumpAndSettle();
        expect(find.text('Perizinan'), findsOneWidget);
        entry.onTap();
        entry.onTap();
        await tester.pumpAndSettle();
        expect(find.byType(PerizinanScreen), findsOneWidget);
        expect(requests, baseline);
        expect(session.hasSession, login);
        tester
            .widget<InkWell>(find.byKey(const ValueKey('guide-topic-kusuka')))
            .onTap!();
        await tester.pumpAndSettle();
        expect(find.byType(PerizinanDetailScreen), findsOneWidget);
        expect(requests, baseline);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ServiceCatalogScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(requests, baseline);
        await tester.pumpWidget(const SizedBox());
        await session.dispose();
      },
    );
  }
}
