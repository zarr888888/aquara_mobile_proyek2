import 'dart:ui' as ui;

import 'package:aquara_mobile/widgets/home_services.dart';
import 'package:aquara_mobile/widgets/samudera_theme.dart';
import 'package:aquara_mobile/widgets/feature_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('registered hero decodes without network', (tester) async {
    await tester.runAsync(() async {
      final data = await rootBundle.load(
        'assets/images/home/samudera_hero.jpg',
      );
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 600);
      expect(frame.image.height, 399);
      frame.image.dispose();
      codec.dispose();
    });
  });

  for (final brightness in Brightness.values) {
    for (final labels in const [
      ['Ensiklopedia', 'Bursa Stok'],
      ['Info Diskanla', 'Kementerian & Umum'],
    ]) {
      testWidgets('readable feature selection $brightness $labels at 320/2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: samuderaTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: DefaultTabController(
              length: 2,
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    bottom: FeatureTabs(
                      controller: DefaultTabController.of(context),
                      labels: labels,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final tab = tester.widget<TabBar>(find.byType(TabBar));
        expect(tab.labelColor, Colors.black);
        expect((tab.indicator! as BoxDecoration).color, SamuderaColors.blue);
        expect(
          tab.unselectedLabelColor,
          samuderaTheme(brightness).colorScheme.onSurface,
        );
        expect(
          tab.overlayColor!.resolve({WidgetState.focused})!.a,
          greaterThan(0),
        );
        expect(
          tab.overlayColor!.resolve({WidgetState.pressed})!.a,
          lessThan(.2),
        );
        await tester.ensureVisible(find.text(labels.last));
        await tester.tap(find.text(labels.last));
        await tester.pumpAndSettle();
        expect(tab.controller!.index, 1);
        await tester.ensureVisible(find.text(labels.first));
        await tester.tap(find.text(labels.first));
        await tester.pumpAndSettle();
        expect(tab.controller!.index, 0);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('uniform icon boxes and complete labels $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: samuderaTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Info KKP')),
            body: SingleChildScrollView(
              child: ServiceGrid(
                services: [
                  HomeService(
                    id: 'short',
                    label: 'Cuaca',
                    group: ServiceGroup.primary,
                    order: 0,
                    onTap: () => taps++,
                  ),
                  HomeService(
                    id: 'long',
                    label: 'Forum Komunitas',
                    group: ServiceGroup.secondary,
                    order: 1,
                    onTap: () => taps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final id in ['short', 'long']) {
        expect(
          tester.getSize(find.byKey(ValueKey('service-icon-$id'))),
          const Size(64, 64),
        );
      }
      expect(find.text('Forum Komunitas'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('service-short')));
      expect(taps, 1);
      final context = tester.element(find.byType(AppBar));
      final theme = Theme.of(context);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF009FE3));
      expect(theme.colorScheme.error, const Color(0xFFF7941D));
      expect(theme.colorScheme.secondary, const Color(0xFF8CC63F));
      expect(tester.takeException(), isNull);
    });
  }
}
