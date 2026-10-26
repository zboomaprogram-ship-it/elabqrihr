import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/auth/presentation/screens/password_recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoadingRememberedCompany = true;
  bool _isChangingCompany = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _restoreRememberedCompany();
  }

  Future<void> _restoreRememberedCompany() async {
    try {
      final tenantSlug = await context.read<TokenStorage>().getLastTenantSlug();
      if (!mounted) return;
      setState(() {
        if (tenantSlug != null) {
          _tenantController.text = tenantSlug;
        }
        _isLoadingRememberedCompany = false;
      });
    } catch (_) {
      // Secure storage can be unavailable in a test harness. The normal
      // company field remains available, so sign-in is never blocked.
      if (mounted) {
        setState(() => _isLoadingRememberedCompany = false);
      }
    }
  }

  @override
  void dispose() {
    _tenantController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;

    final tenant = _tenantController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    context.read<AuthCubit>().login(
          email: email,
          password: password,
          tenantSlug: tenant,
        );
  }

  Widget _companyField() {
    return TextFormField(
      key: const Key('login_tenant_field'),
      controller: _tenantController,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'رمز الشركة',
        prefixIcon: Icon(Icons.business, color: AppTheme.textSecondary),
        hintText: 'مثال: acme',
      ),
      validator: (v) => v == null || v.trim().isEmpty
          ? 'يرجى اختيار الشركة أو إدخال رمزها'
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: BlocConsumer<AuthCubit, AuthState>(
                  listener: (context, state) {
                    if (state is AuthError) {
                      setState(() => _localError = state.message);
                    }
                  },
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;

                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Official Attend Logo
                          Image.asset(
                            AppTheme.logoAsset,
                            width: 88,
                            height: 88,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.secondaryColor
                                    .withValues(alpha: 0.3),
                              ),
                              child: const Icon(Icons.business,
                                  size: 40, color: AppTheme.primaryColor),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // App Name
                          Text(
                            AppStringsAr.appName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'نظام إدارة الحضور والطلبات الذكي',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Error Banner
                          if (_localError != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.4),
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
                                      _localError!,
                                      style: const TextStyle(
                                        color: AppTheme.errorColor,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 16, color: AppTheme.errorColor),
                                    onPressed: () =>
                                        setState(() => _localError = null),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Credentials AttendCard
                          AttendCard(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'تسجيل الدخول للنظام',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // A remembered company keeps the normal login
                                // form focused on email and password. First
                                // time users, or users changing company, see
                                // the same explicit field.
                                if (_isLoadingRememberedCompany)
                                  const SizedBox(height: 36)
                                else if (_tenantController.text.isNotEmpty &&
                                    !_isChangingCompany) ...[
                                  Container(
                                    key: const Key('remembered_company'),
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            12, 10, 8, 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppTheme.secondaryColor),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.business_outlined,
                                            size: 19,
                                            color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'الشركة: ${_tenantController.text}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          key: const Key(
                                              'change_company_button'),
                                          onPressed: () => setState(
                                              () => _isChangingCompany = true),
                                          child: const Text('تغيير'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else
                                  _companyField(),
                                const SizedBox(height: 14),

                                // Email
                                TextFormField(
                                  key: const Key('login_email_field'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14),
                                  decoration: const InputDecoration(
                                    labelText: AppStringsAr.emailLabel,
                                    prefixIcon: Icon(Icons.email_outlined,
                                        color: AppTheme.textSecondary),
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
                                const SizedBox(height: 14),

                                // Password
                                TextFormField(
                                  key: const Key('login_password_field'),
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: AppStringsAr.passwordLabel,
                                    prefixIcon: const Icon(Icons.lock_outline,
                                        color: AppTheme.textSecondary),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'يرجى إدخال كلمة المرور'
                                      : null,
                                ),
                                const SizedBox(height: 24),

                                // Login Button
                                ElevatedButton(
                                  key: const Key('login_button'),
                                  onPressed: isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          AppStringsAr.loginButton,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  key: const Key('forgot_password_button'),
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const PasswordRecoveryScreen(),
                                            ),
                                          );
                                        },
                                  child: const Text(
                                    AppStringsAr.forgotPassword,
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
