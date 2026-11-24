import 'dart:async';
import 'dart:ui' as ui;
import 'package:aquara_mobile/screens/consultation_screen.dart';
import 'package:aquara_mobile/screens/tentang_aquara_screen.dart';
import 'package:aquara_mobile/widgets/app_version_label.dart';
import 'package:aquara_mobile/widgets/samudera_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/package_info');
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  // Failure first: package_info_plus caches only successful platform results.
  testWidgets('platform failure is sanitized without hardcoded version', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(
            code: 'test',
            message: 'private native detail',
          ),
        );
    await tester.pumpWidget(const MaterialApp(home: TentangAquaraScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Versi build belum tersedia'), findsOneWidget);
    expect(find.textContaining('private native detail'), findsNothing);
    expect(find.textContaining('1.1.0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading then platform metadata different from pubspec', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) {
          calls++;
          return pending.future;
        });
    await tester.pumpWidget(const MaterialApp(home: TentangAquaraScreen()));
    expect(find.text('Memuat versi aplikasi…'), findsOneWidget);
    pending.complete({
      'appName': 'Test',
      'packageName': 'test.app',
      'version': '7.8.9',
      'buildNumber': '321',
      'buildSignature': '',
    });
    await tester.pumpAndSettle();
    expect(find.text('Versi 7.8.9 (321)'), findsOneWidget);
    expect(calls, 1);
    expect(find.textContaining('1.1.0'), findsNothing);
  });

  testWidgets('empty metadata has no numeric fallback', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Test',
      packageName: 'test',
      version: '',
      buildNumber: '',
      buildSignature: '',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppVersionLabel())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Versi build belum tersedia'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final about in [true, false]) {
      testWidgets('about=$about $brightness 320px 2x scroll and local logos', (
        tester,
      ) async {
        PackageInfo.setMockInitialValues(
          appName: 'Test',
          packageName: 'test',
          version: '9.8.7',
          buildNumber: '654',
          buildSignature: '',
        );
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: samuderaTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24),
              ),
              child: child!,
            ),
            home: about
                ? const TentangAquaraScreen()
                : const ConsultationScreen(),
          ),
        );
        await tester.pumpAndSettle();
        if (about) {
          await tester.ensureVisible(find.text('Versi 9.8.7 (654)'));
          expect(find.text('Versi 9.8.7 (654)'), findsOneWidget);
        } else {
          for (final title in ['WhatsApp Penyuluh', 'Instagram Dinas']) {
            await tester.ensureVisible(find.text(title));
            final image = tester.widget<Image>(
              find.byWidgetPredicate(
                (w) => w is Image && w.semanticLabel == title,
              ),
            );
            expect(image.fit, BoxFit.contain);
            expect(image.color, isNull);
            expect(image.width, 30);
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final name in ['whatsapp', 'instagram']) {
    testWidgets('$name official PNG decodes locally', (tester) async {
      await tester.runAsync(() async {
        final bytes = await rootBundle.load(
          'assets/icons/${name}_official.png',
        );
        final codec = await ui.instantiateImageCodec(
          Uint8List.sublistView(bytes),
          targetWidth: 120,
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 120);
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      });
    });
  }
}
