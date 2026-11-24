import 'dart:convert';

import 'package:aquara_mobile/screens/analysis_screen.dart';
import 'package:aquara_mobile/screens/berita_detail_screen.dart';
import 'package:aquara_mobile/screens/home_screen.dart';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/semua_komoditas_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:aquara_mobile/widgets/commodity_card.dart';
import 'package:aquara_mobile/widgets/home_news_preview.dart';
import 'package:aquara_mobile/widgets/samudera_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reference_data_test.dart' show fish;
import 'services/fake_token_store.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<ApiService> apiFor(
    List<Map<String, dynamic>> posts,
    List<String> calls,
  ) async {
    final session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('fake', user: {'id': 1, 'name': 'Test'});
    return ApiService(
      session: session,
      client: ApiClient(
        session: session,
        baseUrl: Uri.parse('https://example.test/api'),
        clientFactory: () => MockClient((r) async {
          expect(r.url.origin, 'https://example.test');
          expect(r.headers['Authorization'], 'Bearer fake');
          final path = r.url.pathSegments.last;
          calls.add(path);
          return http.Response(
            jsonEncode({
              if (path == 'fish-types')
                'status': 'success'
              else
                'success': true,
              'data': path == 'posts'
                  ? posts
                  : path == 'fish-types'
                  ? [
                      fish(),
                      {...fish(), 'id': 2},
                      {...fish(), 'id': 3},
                    ]
                  : [],
            }),
            200,
          );
        }),
      ),
    );
  }

  Widget wrap(Widget child, Brightness brightness, double scale) => MaterialApp(
    theme: samuderaTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared commodity geometry $brightness $scale at 320', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final sizes = <Size>[];
        final positions = <List<Offset>>[];
        for (final home in [false, true]) {
          await tester.pumpWidget(
            wrap(
              Padding(
                padding: const EdgeInsets.all(16),
                child: CommodityCard(
                  home: home,
                  name: 'Gurame unggulan budidaya',
                  specs: 'FCR 1.00 • Panen 80 Hari',
                  price: 'Rp 15.985',
                ),
              ),
              brightness,
              scale,
            ),
          );
          await tester.pumpAndSettle();
          sizes.add(tester.getSize(find.byType(CommodityCard)));
          positions.add([
            for (final text in [
              'Gurame unggulan budidaya',
              'FCR 1.00 • Panen 80 Hari',
              'Harga Pasar',
              'Rp 15.985',
            ])
              tester.getTopLeft(find.text(text)),
          ]);
          final material = tester.widget<Material>(
            find.descendant(
              of: find.byType(CommodityCard),
              matching: find.byType(Material),
            ),
          );
          expect(material.surfaceTintColor, Colors.transparent);
          if (home) {
            expect(material.color, const Color(0xFF009FE3));
            expect(
              tester.widget<Text>(find.text('Rp 15.985')).style!.color,
              Colors.black87,
            );
          }
          await tester.ensureVisible(find.text('Rp 15.985'));
          expect(tester.takeException(), isNull);
        }
        expect(sizes[0], sizes[1]);
        expect(positions[0], positions[1]);
      });

      testWidgets(
        'news horizontal grows with text null and failed image $brightness $scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final calls = <String>[];
          final api = await apiFor([
            for (var id = 1; id <= 3; id++)
              {
                'id': id,
                'title':
                    'Judul berita panjang tentang pembudidayaan ikan SAMUDERA $id',
                'content': 'Isi $id',
                'author': 'Penulis asli',
                'created_at': id == 1
                    ? null
                    : id == 2
                    ? 'rusak'
                    : '2026-10-25T08:00:00Z',
                'image': id == 3 ? 'https://example.test/broken.png' : null,
              },
          ], calls);
          Widget? opened;
          await tester.pumpWidget(
            wrap(
              HomeNewsPreview(api: api, openPage: (page) => opened = page),
              brightness,
              scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Penulis asli'), findsNothing);
          expect(find.text('-'), findsNWidgets(2));
          expect(find.text('25 Oct 2026'), findsOneWidget);
          for (var id = 1; id <= 3; id++) {
            final card = find.byKey(ValueKey('news-preview-$id'));
            final thumbnail = find.descendant(
              of: card,
              matching: find.byType(ClipRRect),
            );
            expect(tester.getSize(thumbnail), const Size(80, 80));
            final title = find.descendant(
              of: card,
              matching: find.byWidgetPredicate(
                (w) => w is Text && w.data!.startsWith('Judul'),
              ),
            );
            expect(tester.widget<Text>(title).maxLines, 2);
            expect(tester.widget<Text>(title).overflow, TextOverflow.ellipsis);
            expect(
              tester.getTopLeft(title).dx,
              greaterThan(tester.getTopRight(thumbnail).dx),
            );
            if (scale == 2) {
              expect(tester.getSize(card).height, greaterThan(112));
            }
            await tester.ensureVisible(card);
            await tester.tap(card);
            expect(opened!.key, ValueKey('news-detail-$id'));
            expect((opened as BeritaDetailScreen).content, 'Isi $id');
          }
          expect(find.byIcon(Icons.newspaper), findsNWidgets(3));
          expect(calls, ['posts']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final home in [true, false]) {
    testWidgets(
      'actual route shares cards and preserves analysis values home=$home',
      (tester) async {
        final calls = <String>[];
        final api = await apiFor([], calls);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: home ? HomeScreen(api: api) : SemuaKomoditasScreen(api: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CommodityCard), findsNWidgets(home ? 2 : 3));
        final card = tester.widget<CommodityCard>(
          find.byType(CommodityCard).first,
        );
        expect(card.home, home);
        expect(card.name, 'Lele');
        expect(card.specs, 'FCR 1.20 • Panen 90 Hari');
        expect(card.price, 'Rp 25.000');
        final tap = tester.widget<GestureDetector>(
          find
              .ancestor(
                of: find.byType(CommodityCard).first,
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        final context = tester.element(find.byType(CommodityCard).first);
        tap.onTap!();
        // Verify wiring before mounting: a missing injection must not use a real client.
        final navigator = Navigator.of(context);
        final routes = <Route<dynamic>>[];
        navigator.popUntil((route) {
          routes.add(route);
          return true;
        });
        final analysis =
            (routes.single as MaterialPageRoute).builder(context)
                as AnalysisScreen;
        expect(analysis.autoFishName, 'Lele');
        expect(analysis.autoPrice, '25000.00');
        expect(analysis.autoFcr, '1.20');
        expect(analysis.autoPeriod, '90');
        expect(analysis.api, same(api));
        expect(analysis.api!.session, same(api.session));
        expect(analysis.api!.authClient, same(api.authClient));
        expect(calls.where((p) => p == 'fish-types'), hasLength(1));
        await tester.pumpAndSettle();
        expect(find.byType(AnalysisScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(calls.where((p) => p == 'fish-types'), hasLength(2));
        await api.session.invalidate(await api.session.snapshot());
        await tester.pumpAndSettle();
        expect(find.byType(AnalysisScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
