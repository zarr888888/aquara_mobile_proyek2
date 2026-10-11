import 'dart:async';
import 'package:aquara_mobile/screens/login_screen.dart';
import 'package:aquara_mobile/screens/register_screen.dart';
import 'package:aquara_mobile/screens/otp_screen.dart';
import 'package:aquara_mobile/services/api_result.dart';
import 'package:aquara_mobile/services/api_service.dart';
import 'package:aquara_mobile/services/auth_cooldown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthApi extends ApiService {
  int loginCalls = 0;
  int registerCalls = 0;
  int sendCalls = 0;
  int verifyCalls = 0;
  String? verifiedOtp;
  Completer<ApiResult<Object?>>? pending;
  ApiResult<Object?> response = const ApiResult.success(
    data: {},
    statusCode: 200,
  );
  @override
  Future<ApiResult<Object?>> loginUser(String id, String password) async {
    loginCalls++;
    return pending?.future ?? response;
  }

  @override
  Future<ApiResult<Object?>> registerUser(
    String n,
    String e,
    String p,
    String pw,
  ) async {
    registerCalls++;
    return response;
  }

  @override
  Future<ApiResult<Object?>> sendOtpWa(String phone) async {
    sendCalls++;
    return response;
  }

  @override
  Future<ApiResult<Object?>> verifyOtpWa(String phone, String otp) async {
    verifyCalls++;
    verifiedOtp = otp;
    return response;
  }
}

void main() {
  testWidgets(
    'login validates input, prevents duplicate submission, shows 401',
    (tester) async {
      final api = FakeAuthApi()..pending = Completer<ApiResult<Object?>>();
      await tester.pumpWidget(MaterialApp(home: LoginScreen(api: api)));
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump();
      expect(api.loginCalls, 0);
      await tester.enterText(find.byType(TextFormField).at(0), 'budi@test.id');
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump();
      expect(api.loginCalls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      api.pending!.complete(
        ApiResult.failure(
          ApiFailure(kind: ApiErrorKind.unauthorized, message: 'Wrong'),
          statusCode: 401,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Email/nomor HP atau kata sandi salah.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('registration navigates to unsent challenge, not home/login', (
    tester,
  ) async {
    final api = FakeAuthApi();
    await tester.pumpWidget(MaterialApp(home: RegisterScreen(api: api)));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Budi');
    await tester.enterText(fields.at(1), 'budi@test.id');
    await tester.enterText(fields.at(2), '081234567890');
    await tester.enterText(fields.at(3), 'secret123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await tester.pumpAndSettle();
    expect(api.registerCalls, 1);
    expect(api.loginCalls, 0);
    expect(find.byType(OtpScreen), findsOneWidget);
    expect(find.text('Kirim OTP'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('OTP 320px validates six digits and retains leading zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeAuthApi();
    var authenticated = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OtpScreen(
          identifier: '081234567890',
          purpose: OtpPurpose.login,
          method: 'wa',
          api: api,
          onAuthenticated: () => authenticated = true,
        ),
      ),
    );
    await tester.tap(find.text('Kirim OTP'));
    await tester.pumpAndSettle();
    expect(api.sendCalls, 1);
    expect(find.textContaining('Kirim ulang tersedia'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Verifikasi'));
    await tester.pump();
    expect(api.verifyCalls, 0);
    expect(find.text('OTP wajib tepat 6 digit.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '012345');
    await tester.tap(find.widgetWithText(FilledButton, 'Verifikasi'));
    await tester.pump();
    expect(api.verifiedOtp, '012345');
    expect(authenticated, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('429 disables login and displays wait', (tester) async {
    final api = FakeAuthApi()
      ..response = ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.rateLimited,
          message: 'Terlalu banyak permintaan.',
          retryAfter: const Duration(seconds: 60),
        ),
        statusCode: 429,
      );
    await tester.pumpWidget(MaterialApp(home: LoginScreen(api: api)));
    await tester.enterText(find.byType(TextFormField).at(0), 'budi@test.id');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(AuthCooldown.instance.remaining('auth'), greaterThan(0));
    expect(find.textContaining('Tunggu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
