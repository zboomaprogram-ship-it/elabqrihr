import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/rtl_navigation.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/password_recovery_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/password_recovery_state.dart';

class PasswordRecoveryScreen extends StatelessWidget {
  final PasswordRecoveryStep initialStep;
  final String? initialToken;

  const PasswordRecoveryScreen({
    super.key,
    this.initialStep = PasswordRecoveryStep.request,
    this.initialToken,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PasswordRecoveryCubit>(
      create: (context) => PasswordRecoveryCubit(
        authRepository: context.read<AuthRepository>(),
        initialStep:
            initialToken != null ? PasswordRecoveryStep.confirm : initialStep,
      ),
      child: _PasswordRecoveryView(initialToken: initialToken),
    );
  }
}

class _PasswordRecoveryView extends StatefulWidget {
  final String? initialToken;

  const _PasswordRecoveryView({this.initialToken});

  @override
  State<_PasswordRecoveryView> createState() => _PasswordRecoveryViewState();
}

class _PasswordRecoveryViewState extends State<_PasswordRecoveryView> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();

  final _tenantController = TextEditingController();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _tokenController.text = widget.initialToken!;
    }
    _restoreRememberedCompany();
  }

  Future<void> _restoreRememberedCompany() async {
    try {
      final tokenStorage = context.read<TokenStorage>();
      final lastTenant = await tokenStorage.getLastTenantSlug();
      if (mounted && lastTenant != null && lastTenant.isNotEmpty) {
        setState(() {
          _tenantController.text = lastTenant;
        });
      }
    } catch (_) {
      // Non-blocking in test harnesses or fresh installs
    }
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitRequest() {
    if (!_requestFormKey.currentState!.validate()) return;
    context.read<PasswordRecoveryCubit>().requestReset(
          email: _emailController.text,
          tenantSlug: _tenantController.text,
        );
  }

  void _submitConfirm() {
    if (!_confirmFormKey.currentState!.validate()) return;
    context.read<PasswordRecoveryCubit>().confirmReset(
          resetToken: _tokenController.text,
          newPassword: _newPasswordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            key: const Key('back_to_login_button'),
            icon: Icon(RtlNavigation.backIcon(context),
                size: 20, color: AppTheme.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            AppStringsAr.passwordRecoveryTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: BlocConsumer<PasswordRecoveryCubit, PasswordRecoveryState>(
            listener: (context, state) {
              // Can show snackbars or handle navigation if needed
            },
            builder: (context, state) {
              final isSubmitting = state is PasswordRecoverySubmitting;
              final isRequestStep = state.step == PasswordRecoveryStep.request;

              return Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Icon & Subtitle
                        Center(
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              isRequestStep
                                  ? Icons.mark_email_read_outlined
                                  : Icons.lock_reset_rounded,
                              size: 32,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isRequestStep
                              ? AppStringsAr.passwordRecoveryTitle
                              : AppStringsAr.passwordResetTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isRequestStep
                              ? AppStringsAr.passwordRecoverySubtitle
                              : AppStringsAr.passwordResetSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Error Banner if in failure state
                        if (state is PasswordRecoveryFailure) ...[
                          Container(
                            key: const Key('recovery_error_banner'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.errorColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.message,
                                    style: const TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Success Cards
                        if (state is PasswordRecoveryRequestSuccess) ...[
                          _buildRequestSuccessCard(context, state.message),
                        ] else if (state is PasswordRecoveryConfirmSuccess) ...[
                          _buildConfirmSuccessCard(context, state.message),
                        ] else if (isRequestStep) ...[
                          _buildRequestForm(context, isSubmitting),
                        ] else ...[
                          _buildConfirmForm(context, isSubmitting),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequestSuccessCard(BuildContext context, String message) {
    return AttendCard(
      key: const Key('recovery_success_card'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppTheme.successColor,
            size: 48,
          ),
          const SizedBox(height: 14),
          const Text(
            'تم استلام طلبك بنجاح',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('switch_to_confirm_button'),
            onPressed: () {
              context
                  .read<PasswordRecoveryCubit>()
                  .setStep(PasswordRecoveryStep.confirm);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              AppStringsAr.enterResetTokenAction,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text(
              AppStringsAr.backToLogin,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmSuccessCard(BuildContext context, String message) {
    return AttendCard(
      key: const Key('recovery_success_card'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppTheme.successColor,
            size: 48,
          ),
          const SizedBox(height: 14),
          const Text(
            'تم تحديث كلمة المرور',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('success_back_to_login_button'),
            onPressed: () => Navigator.of(context).maybePop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              AppStringsAr.backToLogin,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(BuildContext context, bool isSubmitting) {
    return AttendCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _requestFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Company / Tenant Field
            TextFormField(
              key: const Key('recovery_tenant_field'),
              controller: _tenantController,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'رمز جهة العمل (الشركة)',
                prefixIcon: Icon(Icons.business, color: AppTheme.textSecondary),
                hintText: 'company-slug',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'يرجى إدخال رمز الشركة'
                  : null,
            ),
            const SizedBox(height: 14),

            // Email Field
            TextFormField(
              key: const Key('recovery_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: AppStringsAr.emailLabel,
                prefixIcon:
                    Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                hintText: 'name@company.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'يرجى إدخال البريد الإلكتروني';
                }
                if (!v.contains('@')) {
                  return 'يرجى إدخال بريد إلكتروني صالح';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Request Reset Button
            ElevatedButton(
              key: const Key('request_reset_button'),
              onPressed: isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      AppStringsAr.requestResetButton,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Switch to Confirm Token Step
            TextButton(
              key: const Key('switch_to_confirm_button'),
              onPressed: () {
                context
                    .read<PasswordRecoveryCubit>()
                    .setStep(PasswordRecoveryStep.confirm);
              },
              child: const Text(
                AppStringsAr.haveResetTokenPrompt,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmForm(BuildContext context, bool isSubmitting) {
    return AttendCard(
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _confirmFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reset Token
            TextFormField(
              key: const Key('recovery_token_field'),
              controller: _tokenController,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: AppStringsAr.resetTokenLabel,
                prefixIcon:
                    Icon(Icons.vpn_key_outlined, color: AppTheme.textSecondary),
                hintText: 'أدخل الرمز المستلم بالبريد',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStringsAr.tokenRequired;
                }
                if (v.trim().length < 10) {
                  return AppStringsAr.tokenLengthNotice;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // New Password
            TextFormField(
              key: const Key('recovery_new_password_field'),
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: AppStringsAr.newPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline,
                    color: AppTheme.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'يرجى إدخال كلمة المرور الجديدة';
                }
                if (v.length < 12) {
                  return AppStringsAr.passwordLengthNotice;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Confirm Password
            TextFormField(
              key: const Key('recovery_confirm_password_field'),
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                labelText: AppStringsAr.confirmNewPasswordLabel,
                prefixIcon: const Icon(Icons.lock_reset_outlined,
                    color: AppTheme.textSecondary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'يرجى تأكيد كلمة المرور الجديدة';
                }
                if (v != _newPasswordController.text) {
                  return AppStringsAr.passwordsMismatch;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Submit Confirm Button
            ElevatedButton(
              key: const Key('confirm_reset_button'),
              onPressed: isSubmitting ? null : _submitConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      AppStringsAr.confirmResetButton,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Switch to Request Step
            TextButton(
              key: const Key('switch_to_request_button'),
              onPressed: () {
                context
                    .read<PasswordRecoveryCubit>()
                    .setStep(PasswordRecoveryStep.request);
              },
              child: const Text(
                AppStringsAr.requestNewTokenPrompt,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
