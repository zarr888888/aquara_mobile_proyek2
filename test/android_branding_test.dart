import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generator targets Android and preserves the original logo canvas', () {
    final config = File('pubspec.yaml').readAsStringSync();
    final branding = config
        .split('flutter_launcher_icons:\n')
        .last
        .split('\nflutter:')
        .first;
    expect(branding, contains('android: true'));
    expect(branding, contains('ios: false'));
    expect(branding, isNot(contains('generate: true')));
    expect(branding, contains('adaptive_icon_foreground_inset: 0'));
    expect(branding, isNot(contains('assets/logo2.png')));
    expect(branding, contains('assets/images/branding/SAMUDERA_FIX_LOGO.png'));
    final adaptive = File(
      '$_res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive, contains('@color/ic_launcher_background'));
    expect(adaptive, contains('@drawable/ic_launcher_foreground'));
    expect(adaptive, contains('android:inset="0%"'));
    expect(
      File('$_res/values/colors.xml').readAsStringSync(),
      contains('#FFFFFF'),
    );
  });

  test('pre-31 and API 31 light/dark resolve to the branded splash', () {
    for (final qualifier in ['drawable', 'drawable-v21']) {
      final xml = File(
        '$_res/$qualifier/launch_background.xml',
      ).readAsStringSync();
      expect(xml, contains('@drawable/samudera_splash'));
      expect(xml, contains('@android:color/white'));
      expect(xml, contains('android:gravity="center"'));
    }
    for (final qualifier in ['values-v31', 'values-night-v31']) {
      final xml = File('$_res/$qualifier/styles.xml').readAsStringSync();
      expect(xml, contains('name="LaunchTheme"'));
      expect(xml, contains('name="android:windowSplashScreenBackground"'));
      expect(xml, contains('name="android:windowSplashScreenAnimatedIcon"'));
      expect(xml, contains('@drawable/samudera_splash'));
      expect(xml, isNot(contains('NormalTheme')));
    }
  });

  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };
  for (final entry in densities.entries) {
    test('PNG dimensions, alpha and safe zones ${entry.key}', () async {
      for (final spec in [
        ('mipmap', 'ic_launcher', 48, 0.5),
        ('drawable', 'ic_launcher_foreground', 108, 33 / 108),
        ('drawable', 'samudera_splash', 288, 96 / 288),
      ]) {
        final file = File('$_res/${spec.$1}-${entry.key}/${spec.$2}.png');
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        final image = (await codec.getNextFrame()).image;
        try {
          final size = (spec.$3 * entry.value).round();
          expect(image.width, size);
          expect(image.height, size);
          final pixels = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!;
          var visible = 0;
          var transparent = 0;
          var blue = false;
          var gold = false;
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              final offset = (y * size + x) * 4;
              final alpha = pixels.getUint8(offset + 3);
              if (alpha == 0) {
                transparent++;
                continue;
              }
              visible++;
              final radius = math.sqrt(
                math.pow(x + 0.5 - size / 2, 2) +
                    math.pow(y + 0.5 - size / 2, 2),
              );
              expect(
                radius,
                lessThanOrEqualTo(size * spec.$4),
                reason: '${file.path}: visible pixel outside safe circle',
              );
              final r = pixels.getUint8(offset);
              final g = pixels.getUint8(offset + 1);
              final b = pixels.getUint8(offset + 2);
              blue |= alpha > 200 && b > r && g > r;
              gold |= alpha > 200 && r > b && g > b;
            }
          }
          expect(visible, greaterThan(0));
          expect(transparent, greaterThan(visible));
          expect(blue && gold, isTrue);
        } finally {
          image.dispose();
          codec.dispose();
        }
      }
    });
  }
}
