import 'dart:ui' as ui;
import 'dart:io';
import 'package:aquara_mobile/screens/splash_screen.dart';
import 'package:aquara_mobile/screens/onboarding_screen.dart';
import 'package:aquara_mobile/screens/tentang_aquara_screen.dart';
import 'package:aquara_mobile/widgets/samudera_branding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('registered PNG decodes with transparent and visible pixels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(samuderaLogoAsset, 'assets/images/branding/SAMUDERA_FIX_LOGO.png');
      expect(
        Directory(
          'assets/images/branding',
        ).listSync().map((f) => f.uri.pathSegments.last),
        contains('SAMUDERA_FIX_LOGO.png'),
      );
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('    - $samuderaLogoAsset'),
      );
      final data = await rootBundle.load(samuderaLogoAsset);
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
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 500);
      expect(frame.image.height, 500);
      final pixels = (await frame.image.toByteData())!;
      var transparent = false;
      var visible = false;
      for (var i = 3; i < pixels.lengthInBytes; i += 4) {
        transparent |= pixels.getUint8(i) == 0;
        visible |= pixels.getUint8(i) > 0;
      }
      expect(transparent && visible, isTrue);
      frame.image.dispose();
      codec.dispose();
    });
  });
  for (final dark in [false, true]) {
    for (final splash in [false, true]) {
      testWidgets('logo renders uncropped 320px 2x dark=$dark splash=$splash', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: splash ? const SplashScreen() : const TentangAquaraScreen(),
          ),
        );
        await tester.pump();
        final images = tester
            .widgetList<Image>(find.byType(Image))
            .where(
              (image) =>
                  image.image is AssetImage &&
                  (image.image as AssetImage).assetName == samuderaLogoAsset,
            );
        expect(images, hasLength(1));
        expect(images.single.fit, BoxFit.contain);
        expect(find.text('SAMUDERA'), findsOneWidget);
        expect(find.textContaining('AQUARA'), findsNothing);
        expect(tester.takeException(), isNull);
        // Dispose before the existing splash timer can invoke navigation/services.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      });
    }
  }
  testWidgets('onboarding consultation uses SAMUDERA without changing paging', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Konsultasi AI'), findsOneWidget);
    expect(find.textContaining('AI SAMUDERA.'), findsOneWidget);
    expect(find.textContaining('AQUARA'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
