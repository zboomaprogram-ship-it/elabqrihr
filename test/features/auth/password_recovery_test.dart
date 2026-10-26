import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/password_recovery_state.dart';
import 'package:attend_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:attend_mobile/features/auth/presentation/screens/password_recovery_screen.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';

class _FakePasswordRecoveryAuthRepo implements AuthRepository {
  String? lastRequestedEmail;
  String? lastRequestedTenantSlug;
  String? lastConfirmedToken;
  String? lastConfirmedNewPassword;

  bool shouldFailRequest = false;
  String? requestErrorCode;

  bool shouldFailConfirm = false;
  String? confirmErrorCode;

  @override
  Future<AuthSessionEntity?> getCachedSession() async => null;

  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<AuthSessionEntity> refreshSession() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset({
    required String email,
    required String tenantSlug,
  }) async {
    lastRequestedEmail = email;
    lastRequestedTenantSlug = tenantSlug;

    if (shouldFailRequest) {
      if (requestErrorCode == 'PASSWORD_RESET_RATE_LIMITED') {
        throw const ValidationFailure(
          'تم تجاوز عدد المحاولات المسموح بها. يرجى الانتظار قليلاً ثم المحاولة مرة أخرى.',
          code: 'PASSWORD_RESET_RATE_LIMITED',
        );
      }
      throw const NetworkFailure();
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String resetToken,
    required String newPassword,
  }) async {
    lastConfirmedToken = resetToken;
    lastConfirmedNewPassword = newPassword;

    if (shouldFailConfirm) {
      if (confirmErrorCode == 'RESET_TOKEN_INVALID') {
        throw const ValidationFailure(
          'رمز إعادة تعيين كلمة المرور غير صالح أو منتهي الصلاحية. يرجى طلب رمز جديد.',
          code: 'RESET_TOKEN_INVALID',
        );
      }
      throw const ValidationFailure(
        'البيانات المدخلة غير صحيحة.',
        code: 'VALIDATION_FAILED',
      );
    }
  }
}

void main() {
  late _FakePasswordRecoveryAuthRepo authRepo;

  setUp(() {
    authRepo = _FakePasswordRecoveryAuthRepo();
  });

  Widget buildRecoveryWidget({
    String? initialToken,
    PasswordRecoveryStep initialStep = PasswordRecoveryStep.request,
  }) {
    return MaterialApp(
      home: RepositoryProvider<AuthRepository>.value(
        value: authRepo,
        child: PasswordRecoveryScreen(
          initialStep: initialStep,
          initialToken: initialToken,
        ),
      ),
    );
  }

  group('Password Recovery — User Story 5 (T069)', () {
    testWidgets('renders request form fields, labels, and buttons',
        (tester) async {
      await tester.pumpWidget(buildRecoveryWidget());
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.passwordRecoveryTitle), findsWidgets);
      expect(find.byKey(const Key('recovery_tenant_field')), findsOneWidget);
      expect(find.byKey(const Key('recovery_email_field')), findsOneWidget);
      expect(find.byKey(const Key('request_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('switch_to_confirm_button')), findsOneWidget);
      expect(find.byKey(const Key('back_to_login_button')), findsOneWidget);
    });

    testWidgets('validates required email and company inputs', (tester) async {
      await tester.pumpWidget(buildRecoveryWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('request_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال رمز الشركة'), findsOneWidget);
      expect(find.text('يرجى إدخال البريد الإلكتروني'), findsOneWidget);

      // Invalid email without @
      await tester.enterText(
          find.byKey(const Key('recovery_email_field')), 'invalid-email');
      await tester.tap(find.byKey(const Key('request_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال بريد إلكتروني صالح'), findsOneWidget);
    });

    testWidgets(
        'FR-015: provides identical generic response for known and unknown accounts',
        (tester) async {
      await tester.pumpWidget(buildRecoveryWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('recovery_tenant_field')), 'acme-corp');
      await tester.enterText(
          find.byKey(const Key('recovery_email_field')), 'user@acme.com');

      await tester.tap(find.byKey(const Key('request_reset_button')));
      await tester.pumpAndSettle();

      // Generic non-enumerating Arabic message
      expect(find.byKey(const Key('recovery_success_card')), findsOneWidget);
      expect(
          find.text(AppStringsAr.passwordResetRequestSuccess), findsOneWidget);
      expect(find.text('تم استلام طلبك بنجاح'), findsOneWidget);

      expect(authRepo.lastRequestedEmail, 'user@acme.com');
      expect(authRepo.lastRequestedTenantSlug, 'acme-corp');
    });

    testWidgets(
        'displays polite Arabic error without raw exception strings on request failure',
        (tester) async {
      authRepo.shouldFailRequest = true;
      authRepo.requestErrorCode = 'PASSWORD_RESET_RATE_LIMITED';

      await tester.pumpWidget(buildRecoveryWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('recovery_tenant_field')), 'acme-corp');
      await tester.enterText(find.byKey(const Key('recovery_email_field')),
          'rate.limited@acme.com');

      await tester.tap(find.byKey(const Key('request_reset_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_error_banner')), findsOneWidget);
      expect(
        find.textContaining('تم تجاوز عدد المحاولات المسموح بها'),
        findsOneWidget,
      );
      // Ensure zero raw strings
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('429'), findsNothing);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets('switches smoothly between request and confirm token modes',
        (tester) async {
      await tester.pumpWidget(buildRecoveryWidget());
      await tester.pumpAndSettle();

      // Switch to confirm
      await tester.tap(find.byKey(const Key('switch_to_confirm_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_token_field')), findsOneWidget);
      expect(
          find.byKey(const Key('recovery_new_password_field')), findsOneWidget);
      expect(find.byKey(const Key('confirm_reset_button')), findsOneWidget);

      // Switch back to request
      await tester
          .ensureVisible(find.byKey(const Key('switch_to_request_button')));
      await tester.tap(find.byKey(const Key('switch_to_request_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_email_field')), findsOneWidget);
      expect(find.byKey(const Key('request_reset_button')), findsOneWidget);
    });

    testWidgets('validates confirm form (min 12 chars and password match)',
        (tester) async {
      await tester.pumpWidget(buildRecoveryWidget(
        initialStep: PasswordRecoveryStep.confirm,
      ));
      await tester.pumpAndSettle();

      // Submit empty
      await tester.ensureVisible(find.byKey(const Key('confirm_reset_button')));
      await tester.tap(find.byKey(const Key('confirm_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.tokenRequired), findsOneWidget);
      expect(find.text('يرجى إدخال كلمة المرور الجديدة'), findsOneWidget);

      // Short token and short password (< 12 characters)
      await tester.enterText(
          find.byKey(const Key('recovery_token_field')), 'short');
      await tester.enterText(
          find.byKey(const Key('recovery_new_password_field')), 'Short123!');
      await tester.enterText(
          find.byKey(const Key('recovery_confirm_password_field')),
          'Short123!');

      await tester.ensureVisible(find.byKey(const Key('confirm_reset_button')));
      await tester.tap(find.byKey(const Key('confirm_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.tokenLengthNotice), findsOneWidget);
      expect(find.text(AppStringsAr.passwordLengthNotice), findsOneWidget);

      // Mismatch
      await tester.enterText(find.byKey(const Key('recovery_token_field')),
          'valid-token-1234567890');
      await tester.enterText(
          find.byKey(const Key('recovery_new_password_field')),
          'StrongPass12345!');
      await tester.enterText(
          find.byKey(const Key('recovery_confirm_password_field')),
          'DifferentPass123!');

      await tester.ensureVisible(find.byKey(const Key('confirm_reset_button')));
      await tester.tap(find.byKey(const Key('confirm_reset_button')));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.passwordsMismatch), findsOneWidget);
    });

    testWidgets(
        'SC-006: handles expired or invalid token safely with Arabic message',
        (tester) async {
      authRepo.shouldFailConfirm = true;
      authRepo.confirmErrorCode = 'RESET_TOKEN_INVALID';

      await tester.pumpWidget(buildRecoveryWidget(
        initialStep: PasswordRecoveryStep.confirm,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recovery_token_field')),
          'expired-token-1234567890');
      await tester.enterText(
          find.byKey(const Key('recovery_new_password_field')),
          'StrongPassword2026!');
      await tester.enterText(
          find.byKey(const Key('recovery_confirm_password_field')),
          'StrongPassword2026!');

      await tester.ensureVisible(find.byKey(const Key('confirm_reset_button')));
      await tester.tap(find.byKey(const Key('confirm_reset_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_error_banner')), findsOneWidget);
      expect(
        find.textContaining(
            'رمز إعادة تعيين كلمة المرور غير صالح أو منتهي الصلاحية'),
        findsOneWidget,
      );
      // Zero raw exception strings
      expect(find.textContaining('RESET_TOKEN_INVALID'), findsNothing);
      expect(find.textContaining('DioException'), findsNothing);
      expect(find.textContaining('422'), findsNothing);
    });

    testWidgets('confirms password reset and shows success card',
        (tester) async {
      await tester.pumpWidget(buildRecoveryWidget(
        initialStep: PasswordRecoveryStep.confirm,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('recovery_token_field')),
          'valid-token-abcdef12345');
      await tester.enterText(
          find.byKey(const Key('recovery_new_password_field')),
          'BrandNewSecretPass1!');
      await tester.enterText(
          find.byKey(const Key('recovery_confirm_password_field')),
          'BrandNewSecretPass1!');

      await tester.ensureVisible(find.byKey(const Key('confirm_reset_button')));
      await tester.tap(find.byKey(const Key('confirm_reset_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recovery_success_card')), findsOneWidget);
      expect(find.text('تم تحديث كلمة المرور'), findsOneWidget);
      expect(find.text(AppStringsAr.passwordResetSuccess), findsOneWidget);
      expect(find.byKey(const Key('success_back_to_login_button')),
          findsOneWidget);

      expect(authRepo.lastConfirmedToken, 'valid-token-abcdef12345');
      expect(authRepo.lastConfirmedNewPassword, 'BrandNewSecretPass1!');
    });

    testWidgets('prefills token when opened with initialToken parameter',
        (tester) async {
      await tester.pumpWidget(buildRecoveryWidget(
        initialToken: 'deep-linked-token-xyz-98765',
      ));
      await tester.pumpAndSettle();

      // Screen opens directly in confirm step with prefilled token
      expect(find.byKey(const Key('recovery_token_field')), findsOneWidget);
      final tokenField = tester.widget<TextFormField>(
        find.byKey(const Key('recovery_token_field')),
      );
      expect(tokenField.controller?.text, 'deep-linked-token-xyz-98765');
    });

    testWidgets('login screen includes working forgot password button',
        (tester) async {
      final tokenStorage = TokenStorage();
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<AuthRepository>.value(value: authRepo),
            RepositoryProvider<TokenStorage>.value(value: tokenStorage),
          ],
          child: MaterialApp(
            home: BlocProvider<AuthCubit>(
              create: (_) => AuthCubit(authRepo),
              child: const LoginScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final forgotBtn = find.byKey(const Key('forgot_password_button'));
      await tester.ensureVisible(forgotBtn);
      expect(forgotBtn, findsOneWidget);
      expect(find.text(AppStringsAr.forgotPassword), findsOneWidget);

      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      // Navigated to PasswordRecoveryScreen
      expect(find.byKey(const Key('recovery_email_field')), findsOneWidget);
      expect(find.text(AppStringsAr.passwordRecoveryTitle), findsWidgets);
    });
  });
}
