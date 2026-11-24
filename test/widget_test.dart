import 'dart:async';
import 'package:aquara_mobile/screens/auth_form_screen.dart';
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
  for (final mode in AuthFormMode.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '$mode $brightness 320px text 2x keyboard: reachable controls without overflow',
        (tester) async {
          tester.view.physicalSize = const Size(320, 800);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final api = FakeAuthApi();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: AuthFormScreen(mode: mode, api: api),
            ),
          );
          await tester.pumpAndSettle();
          final reset = mode == AuthFormMode.reset;
          expect(
            find.text('Metode login lainnya'),
            reset ? findsNothing : findsOneWidget,
          );
          if (reset) {
            expect(find.text('Reset kata sandi'), findsOneWidget);
            expect(find.byType(Image), findsNothing);
            final input = tester.widget<TextField>(
              find.byType(TextField).first,
            );
            expect(input.decoration!.prefixIcon, isNull);
            expect(find.byType(LayoutBuilder), findsNothing);
          } else {
            final fieldContext = tester.element(
              find.byType(TextFormField).first,
            );
            final border =
                Theme.of(fieldContext).inputDecorationTheme.border
                    as OutlineInputBorder;
            expect(border.borderRadius, BorderRadius.circular(16));
            expect(
              Theme.of(
                fieldContext,
              ).filledButtonTheme.style!.backgroundColor!.resolve({}),
              mode == AuthFormMode.register
                  ? const Color(0xFF8CC63F)
                  : const Color(0xFF009FE3),
            );
          }
          final submit = find.byType(FilledButton);
          await tester.ensureVisible(submit);
          await tester.pumpAndSettle();
          expect(submit.hitTestable(), findsOneWidget);
          if (!reset) {
            expect(tester.getSize(submit).height, greaterThanOrEqualTo(55));
          }
          await tester.tap(submit);
          await tester.pumpAndSettle();
          expect(api.loginCalls + api.registerCalls, 0);
          for (final control
              in tester
                  .widgetList(
                    find.byWidgetPredicate(
                      (w) => w is OutlinedButton || w is TextButton,
                    ),
                  )
                  .toList()) {
            final finder = find.byWidget(control);
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            expect(finder.hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          if (reset) {
            final dropdown = find.byType(DropdownButtonFormField<String>);
            expect(tester.state<FormFieldState<String>>(dropdown).value, 'wa');
            for (final channel in ['Email', 'WhatsApp']) {
              await tester.ensureVisible(dropdown);
              await tester.pumpAndSettle();
              expect(dropdown.hitTestable(), findsOneWidget);
              await tester.tap(dropdown);
              await tester.pumpAndSettle();
              final option = find.text(channel).last;
              expect(option.hitTestable(), findsOneWidget);
              await tester.tap(option);
              await tester.pumpAndSettle();
              expect(
                tester.state<FormFieldState<String>>(dropdown).value,
                channel == 'Email' ? 'email' : 'wa',
              );
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

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
  testWidgets('403 still opens registration OTP and clears password', (
    tester,
  ) async {
    final api = FakeAuthApi()
      ..response = ApiResult.failure(
        ApiFailure(
          kind: ApiErrorKind.unauthorized,
          message: 'Verifikasi diperlukan.',
        ),
        statusCode: 403,
      );
    await tester.pumpWidget(MaterialApp(home: LoginScreen(api: api)));
    await tester.enterText(find.byType(TextFormField).first, 'budi@test.id');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    final password = tester
        .widget<TextField>(find.byType(TextField).last)
        .controller!;
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(api.loginCalls, 1);
    expect(
      tester.widget<OtpScreen>(find.byType(OtpScreen)).purpose,
      OtpPurpose.register,
    );
    expect(password.text, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('successful login keeps callback and clears password', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(api: FakeAuthApi(), onAuthenticated: () => calls++),
      ),
    );
    await tester.enterText(find.byType(TextFormField).first, 'budi@test.id');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    final password = tester
        .widget<TextField>(find.byType(TextField).last)
        .controller!;
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(password.text, isEmpty);
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
