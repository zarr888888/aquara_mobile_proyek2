import 'package:aquara_mobile/widgets/support_banners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester t, {
    ValueChanged<int>? open,
    bool reduced = false,
    bool dark = false,
    double scale = 1,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  child: SupportBanners(onSelected: open ?? (_) {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
  }

  Future<void> advance(WidgetTester t) async {
    await t.pump(SupportBanners.interval);
    await t.pump();
    await t.pump(SupportBanners.transition);
    await t.pump(const Duration(milliseconds: 16));
    await t.pump();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 20));
    expect(t.takeException(), isNull);
  }

  testWidgets('one slide per interval and seamless forward wrap', (t) async {
    await mount(t);
    expect(find.text('1 / 4'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2999));
    expect(find.text('1 / 4'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump();
    await t.pump(SupportBanners.transition);
    await t.pump(const Duration(milliseconds: 16));
    await t.pump();
    expect(find.text('2 / 4'), findsOneWidget);
    for (final page in [3, 4, 1, 2]) {
      await advance(t);
      expect(find.text('$page / 4'), findsOneWidget);
    }
    await close(t);
  });

  testWidgets(
    'pause holds; resume starts fresh interval; controls never navigate',
    (t) async {
      final opened = <int>[];
      await mount(t, open: opened.add);
      await t.pump(const Duration(seconds: 2));
      await t.tap(find.text('Jeda'));
      await t.pump(const Duration(seconds: 30));
      expect(find.text('1 / 4'), findsOneWidget);
      expect(opened, isEmpty);
      await t.tap(find.text('Lanjut'));
      await t.pump(const Duration(seconds: 2));
      expect(find.text('1 / 4'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      await t.pump(SupportBanners.transition);
      await t.pump(const Duration(milliseconds: 16));
      await t.pump();
      expect(find.text('2 / 4'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('support-banner-1')));
      expect(opened, [1]);
      await close(t);
    },
  );

  testWidgets('manual swipe pauses and resume has only one timer', (t) async {
    await mount(t);
    await t.drag(
      find.byKey(const Key('support-banners')),
      const Offset(-650, 0),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Lanjut'), findsOneWidget);
    final controller = t.widget<PageView>(find.byType(PageView)).controller!;
    await t.pump(const Duration(seconds: 1));
    final page = controller.page;
    expect(page, greaterThan(0));
    await t.pump(const Duration(seconds: 30));
    expect(controller.page, page);
    await t.tap(find.text('Lanjut'));
    await t.pump();
    await t.tap(find.text('Jeda'));
    await t.pump();
    await t.tap(find.text('Lanjut'));
    await advance(t);
    expect(controller.page, (page! + 1) % 4);
    await close(t);
  });

  for (final paused in [false, true]) {
    testWidgets('route cover return and background preserve pause=$paused', (
      t,
    ) async {
      await mount(t);
      if (paused) {
        await t.tap(find.text('Jeda'));
        await t.pump();
      }
      final context = t.element(find.byType(SupportBanners));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Target')),
        ),
      );
      await t.pump();
      await t.pump(const Duration(seconds: 20));
      final controller = t
          .widget<PageView>(find.byType(PageView, skipOffstage: false))
          .controller!;
      expect(controller.page, 0);
      Navigator.of(t.element(find.text('Target'))).pop();
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(seconds: 1));
      expect(controller.page, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump(const Duration(seconds: 20));
      expect(controller.page, 0);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await advance(t);
      expect(controller.page, paused ? 0 : 1);
      await close(t);
    });
  }

  testWidgets(
    'background interrupts animation and invalidates its completion',
    (t) async {
      await mount(t);
      await t.pump(SupportBanners.interval);
      await t.pump(const Duration(milliseconds: 200));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final controller = t.widget<PageView>(find.byType(PageView)).controller!;
      await t.pump(const Duration(seconds: 1));
      final page = controller.page;
      await t.pump(const Duration(seconds: 20));
      expect(controller.page, page);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await advance(t);
      expect(controller.page, (page! + 1) % 4);
      await close(t);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      '320 2x dark=$dark reduced motion still permits controls and swipe',
      (t) async {
        t.view.physicalSize = const Size(320, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await mount(t, reduced: true, dark: dark, scale: 2);
        await t.pump(const Duration(seconds: 30));
        expect(find.text('1 / 4'), findsOneWidget);
        expect(
          find.byTooltip('Jeda banner otomatis').hitTestable(),
          findsOneWidget,
        );
        await t.tap(find.text('Jeda'));
        await t.pump();
        await t.tap(find.text('Lanjut'));
        await t.pump(const Duration(seconds: 30));
        expect(find.text('1 / 4'), findsOneWidget);
        await t.drag(find.byType(PageView), const Offset(-280, 0));
        await t.pump(const Duration(seconds: 1));
        expect(find.text('2 / 4'), findsOneWidget);
        expect(find.text('Lanjut'), findsOneWidget);
        expect(t.takeException(), isNull);
        await close(t);
      },
    );
  }

  testWidgets(
    'pause interrupts transition; dispose cancels outstanding animation',
    (t) async {
      await mount(t);
      await t.pump(SupportBanners.interval);
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Jeda'));
      await t.pump();
      final controller = t.widget<PageView>(find.byType(PageView)).controller!;
      final page = controller.page;
      await t.pump(const Duration(seconds: 20));
      expect(controller.page, page);
      await t.tap(find.text('Lanjut'));
      await t.pump(SupportBanners.interval);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      await close(t);
    },
  );
}
