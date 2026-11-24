import 'dart:convert';
import 'package:aquara_mobile/screens/analysis_screen.dart';
import 'package:aquara_mobile/services/api_client.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/fake_token_store.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    Map<String, dynamic>? overrides,
    bool compact = false,
    Brightness brightness = Brightness.light,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final session = SessionService(store: FakeTokenStore());
    await session.saveIfCurrent('test', user: {'id': 1, 'name': 'Test'});
    final api = ApiService(
      session: session,
      client: ApiClient(
        baseUrl: Uri.parse('https://example.test/api'),
        session: session,
        clientFactory: () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 'success',
              'data': [
                {
                  'id': 1,
                  'name': 'Lele',
                  'fcr_ratio': '1.20',
                  'harvest_duration_days': 90,
                  'market_price_per_kg': '25000.00',
                  'standard_density_per_m2': 100,
                  'survival_rate': '90.00',
                  'feed_price_per_kg': '12000.00',
                  ...?overrides,
                },
              ],
            }),
            200,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(compact ? 1.5 : 1),
            viewInsets: EdgeInsets.only(bottom: compact ? 200 : 0),
          ),
          child: child!,
        ),
        home: AnalysisScreen(api: api, autoFishName: 'Lele'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, List<String> values) async {
    for (var i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextField).at(i), values[i]);
    }
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('HITUNG ANALISA'));
    await tester.tap(find.text('HITUNG ANALISA'));
    await tester.pumpAndSettle();
  }

  for (final value in ['0', '-1', '1.5', '1.000', 'NaN', 'Infinity']) {
    testWidgets('reject invalid area $value', (tester) async {
      await mount(tester);
      await submit(tester, [value, '1000', '200', '0']);
      expect(find.text('Hasil Analisa'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  }
  testWidgets('valid legacy calculation remains unchanged', (tester) async {
    await mount(tester);
    await submit(tester, ['100', '1000', '200', '0']);
    expect(find.text('Hasil Analisa'), findsOneWidget);
    for (final text in [
      '90.0 Kg',
      '108.0 Kg',
      'Rp 1.496.000',
      'Rp 2.250.000',
      'Rp 754.000',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
  });

  for (var field = 0; field < 4; field++) {
    for (final value in [
      '',
      ' ',
      '-5',
      'abc',
      '1.000,50',
      '1,000.50',
      '1 000',
      '1e3',
      '9' * 400,
    ]) {
      testWidgets('field $field rejects $value', (tester) async {
        await mount(tester);
        final values = ['100', '1000', '200', '0']..[field] = value;
        await submit(tester, values);
        expect(find.text('Hasil Analisa'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final value in ['1,5', '1.5', '1,0', '9007199254740993']) {
    testWidgets('seed count rejects fraction or unsafe integer $value', (
      tester,
    ) async {
      await mount(tester);
      await submit(tester, ['100', value, '200', '0']);
      expect(find.text('Hasil Analisa'), findsNothing);
      expect(find.textContaining('Jumlah bibit'), findsWidgets);
    });
  }
  for (final values in [
    ['12,5', '1000', '200,5', '0,5'],
    ['100', '0', '0', '0'],
    ['100', '1000', '0', '0'],
  ]) {
    testWidgets('accept explicit numbers $values', (tester) async {
      await mount(tester);
      await submit(tester, values);
      expect(find.text('Hasil Analisa'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  final badParameters = <String, List<Object>>{
    'survival_rate': [-1, 101],
    'fcr_ratio': [-1],
    'standard_density_per_m2': [0, -1],
    'feed_price_per_kg': [-1],
    'market_price_per_kg': [-1],
  };
  for (final entry in badParameters.entries) {
    for (final value in entry.value) {
      testWidgets('reject backend ${entry.key}=$value', (tester) async {
        await mount(tester, overrides: {entry.key: value});
        await submit(tester, ['100', '1000', '200', '0']);
        expect(find.text('Hasil Analisa'), findsNothing);
        expect(find.textContaining('dari server tidak valid'), findsOneWidget);
      });
    }
  }
  for (final sr in [0, 100]) {
    testWidgets('accept SR boundary $sr and zero costs/FCR', (tester) async {
      await mount(
        tester,
        overrides: {
          'survival_rate': sr,
          'fcr_ratio': 0,
          'feed_price_per_kg': 0,
          'market_price_per_kg': 0,
        },
      );
      await submit(tester, ['100', '1000', '0', '0']);
      expect(find.text('Hasil Analisa'), findsOneWidget);
    });
  }
  testWidgets('finite inputs with overflowing result rejected', (tester) async {
    await mount(tester);
    await submit(tester, ['100', '1000', '1${'0' * 308}', '0']);
    expect(find.text('Hasil Analisa'), findsNothing);
    expect(find.textContaining('Nilai terlalu besar'), findsOneWidget);
  });
  testWidgets('invalid resubmit hides previous result', (tester) async {
    await mount(tester);
    await submit(tester, ['100', '1000', '200', '0']);
    expect(find.text('Hasil Analisa'), findsOneWidget);
    await submit(tester, ['0', '1000', '200', '0']);
    expect(find.text('Hasil Analisa'), findsNothing);
    expect(find.text('Luas kolam harus lebih dari nol.'), findsOneWidget);
  });
  for (final brightness in Brightness.values) {
    testWidgets('validation at 320px large text keyboard $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await mount(tester, compact: true, brightness: brightness);
      await submit(tester, ['0', '1000', '200', '0']);
      expect(find.text('Luas kolam harus lebih dari nol.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
