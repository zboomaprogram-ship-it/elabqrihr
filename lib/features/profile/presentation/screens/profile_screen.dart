import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_list_screen.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/cubit/financial_request_cubit.dart';
import 'package:attend_mobile/features/dynamic_requests/presentation/screens/financial_request_screen.dart';
import 'package:attend_mobile/features/navigation/domain/role_navigation_policy.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_list_screen.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_state.dart';
import 'package:attend_mobile/features/profile/presentation/screens/active_sessions_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/password_change_screen.dart';
import 'package:attend_mobile/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:attend_mobile/core/localization/language_cubit.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/auth/presentation/screens/password_recovery_screen.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:attend_mobile/features/leave_quotas/domain/leave_quota_repository.dart';
import 'package:attend_mobile/features/leave_quotas/presentation/cubit/leave_quota_cubit.dart';
import 'package:attend_mobile/features/leave_quotas/presentation/screens/leave_quotas_screen.dart';
import 'package:attend_mobile/features/final_settlement/domain/final_settlement_repository.dart';
import 'package:attend_mobile/features/final_settlement/presentation/cubit/final_settlement_cubit.dart';
import 'package:attend_mobile/features/final_settlement/presentation/screens/final_settlement_statement_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProfileCubit>();
    if (cubit.state is ProfileInitial) {
      cubit.loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _ProfileScreenContent();
  }
}

class _ProfileScreenContent extends StatelessWidget {
  const _ProfileScreenContent();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'الملف الشخصي',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, profileState) {
            if (profileState is ProfileInitial ||
                profileState is ProfileLoading) {
              return const ProfileSkeleton(
                  key: Key('profile_loading_indicator'));
            }
            if (profileState is ProfileError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorColor, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        profileState.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        key: const Key('profile_retry_button'),
                        onPressed: context.read<ProfileCubit>().loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final profile = (profileState as ProfileLoaded).profile;
            final displayName = profile.displayName;
            final email = profile.email;
            final role = profile.role;
            final rolePolicy = RoleNavigationPolicy(role);
            final roleName = _roleLabel(role);
            final tenantName = profile.companyName;
            final branchName =
                profile.branchName ?? 'غير متوفر في بيانات الحساب';
            final managerName =
                profile.managerName ?? 'غير متوفر في بيانات الحساب';

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Identity Card
                  AttendCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                AppTheme.secondaryColor.withValues(alpha: 0.35),
                            border: Border.all(
                                color: AppTheme.primaryColor, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              displayName.isNotEmpty ? displayName[0] : 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryColor
                                      .withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  roleName,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Company & Work Placement Card
                  AttendCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'معلومات العمل والتنظيم',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Divider(height: 24, color: AppTheme.surface03),
                        _buildProfileRow(Icons.business, 'الشركة', tenantName),
                        const SizedBox(height: 12),
                        _buildProfileRow(
                            Icons.domain, 'الفرع المعتمد', branchName),
                        const SizedBox(height: 12),
                        _buildProfileRow(Icons.supervisor_account,
                            'المدير المباشر', managerName),
                      ],
                    ),
                  ),
                  // Security & Account Management Card
                  AttendCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الأمان وإدارة الحساب',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Divider(height: 24, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('edit_profile_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_outline,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'تعديل البيانات الشخصية',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: Text(
                            profile.phone != null && profile.phone!.isNotEmpty
                                ? 'الهاتف: ${profile.phone}'
                                : 'تحديث رقم الهاتف والبريد الإضافي',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<ProfileCubit>(),
                                  child: ProfileEditScreen(profile: profile),
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('final_settlement_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_outlined,
                              color: AppTheme.primaryColor),
                          title: const Text('كشف المخالصة النهائية',
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14)),
                          subtitle: const Text(
                              'المستحقات والاستقطاعات ومسار الاعتماد والمستند الخاص',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            final repository =
                                context.read<FinalSettlementRepository>();
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => BlocProvider(
                                create: (_) => FinalSettlementCubit(
                                    repository: repository),
                                child: const FinalSettlementStatementScreen(),
                              ),
                            ));
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('change_password_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_outline,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'تغيير كلمة المرور',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'تحديث كلمة مرور الدخول لحسابك',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            final repo = context.read<ProfileRepository>();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RepositoryProvider.value(
                                  value: repo,
                                  child: const PasswordChangeScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('active_sessions_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.devices_outlined,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'الجلسات والأجهزة النشطة',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'مراجعة الأجهزة المسجلة وتسجيل الخروج منها',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            final repo = context.read<ProfileRepository>();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RepositoryProvider.value(
                                  value: repo,
                                  child: const ActiveSessionsScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('leave_quotas_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.pie_chart_outline,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'أرصدة الإجازات والاستئذان',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'استعراض رصيد الإجازات والأذونات ودورات التجديد',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            final quotaRepo =
                                context.read<LeaveQuotaRepository>();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BlocProvider(
                                  create: (_) => LeaveQuotaCubit(
                                    repository: quotaRepo,
                                  )..loadBalances(),
                                  child: const LeaveQuotasScreen(),
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('notification_settings_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.notifications_outlined,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'إعدادات الإشعارات والتنبيهات',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'تخصيص فئات الإشعارات وتنبيهات الشركة والإعلانات',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationSettingsScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('password_reset_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lock_reset,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'استعادة كلمة المرور',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'إرسال رابط أو رمز استعادة كلمة المرور للبريد الإلكتروني',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PasswordRecoveryScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Financial & Payroll Services Card
                  if (rolePolicy.canAccessFinanceSection) ...[
                    AttendCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الخدمات المالية والرواتب',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (rolePolicy.canAccessFinancialRequests) ...[
                            const Divider(
                                height: 24, color: AppTheme.surface03),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.request_quote_outlined,
                                  color: AppTheme.primaryColor),
                              title: const Text(
                                'طلب مالي',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14),
                              ),
                              subtitle: const Text(
                                'الطلبات التي نشرتها شركتك، مثل السلفة أو المصروفات',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppTheme.steel),
                              onTap: () {
                                final repository =
                                    context.read<DynamicRequestRepository>();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider(
                                      create: (_) => FinancialRequestCubit(
                                          repository: repository),
                                      child: const FinancialRequestScreen(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          if (rolePolicy.canViewPayslips) ...[
                            const Divider(
                                height: 12, color: AppTheme.surface03),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.receipt_long,
                                  color: AppTheme.primaryColor),
                              title: const Text(
                                'كشوف الرواتب',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14),
                              ),
                              subtitle: const Text(
                                'استعراض ومراجعة تفاصيل الرواتب الشهرية والبدلات',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppTheme.steel),
                              onTap: () {
                                try {
                                  final repo =
                                      context.read<PayslipRepository>();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider(
                                        create: (_) => PayslipListCubit(
                                          repository: repo,
                                        ),
                                        child: const PayslipListScreen(),
                                      ),
                                    ),
                                  );
                                } catch (_) {}
                              },
                            ),
                          ],
                          if (rolePolicy.canRequestAdvance) ...[
                            const Divider(
                                height: 12, color: AppTheme.surface03),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.account_balance_wallet,
                                  color: AppTheme.mint),
                              title: const Text(
                                'السلف والأقساط المالية',
                                style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14),
                              ),
                              subtitle: const Text(
                                'متابعة السلف المعتمدة وجدول الأقساط والمبالغ المتبقية',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppTheme.steel),
                              onTap: () {
                                try {
                                  final repo =
                                      context.read<AdvanceRepository>();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider(
                                        create: (_) => AdvanceListCubit(
                                          repository: repo,
                                        ),
                                        child: const AdvanceListScreen(),
                                      ),
                                    ),
                                  );
                                } catch (_) {}
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // App Settings Card
                  AttendCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إعدادات التطبيق والدعم',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Divider(height: 24, color: AppTheme.surface03),
                        ListTile(
                          key: const Key('language_preference_tile'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.language,
                              color: AppTheme.primaryColor),
                          title: const Text(
                            'لغة التطبيق',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'العربية',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppTheme.steel),
                          onTap: () =>
                              _showLanguageSelectionSheet(context, profile),
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: profile.preferences.notificationsEnabled,
                          title: const Text('تنبيهات التطبيق',
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14)),
                          subtitle: const Text(
                              'استلام التحديثات المتعلقة بحسابك',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          onChanged: (value) async {
                            PushRegistrationPort? push;
                            try {
                              push = context.read<PushRegistrationPort>();
                            } catch (_) {
                              // Widget-only and offline test hosts do not install FCM.
                            }
                            if (push != null) {
                              try {
                                if (value) {
                                  final outcome =
                                      await push.enable(locale: 'ar');
                                  if (outcome !=
                                      PushRegistrationOutcome.enabled) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'لم يتم تفعيل إذن الإشعارات. يمكنك المحاولة من إعدادات الجهاز لاحقاً.'),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                } else {
                                  await push.disable();
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'تعذر تحديث إعداد الإشعارات الآن. لم يتم تغيير تفضيلك.'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            if (context.mounted) {
                              await context
                                  .read<ProfileCubit>()
                                  .updatePreferences(
                                    profile.preferences
                                        .copyWith(notificationsEnabled: value),
                                  );
                            }
                          },
                        ),
                        const Divider(height: 12, color: AppTheme.surface03),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: profile.preferences.reducedMotion,
                          title: const Text('تقليل الحركة',
                              style: TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 14)),
                          subtitle: const Text('إيقاف الحركات غير الضرورية',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                          onChanged: (value) => context
                              .read<ProfileCubit>()
                              .updatePreferences(profile.preferences
                                  .copyWith(reducedMotion: value)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppTheme.surface03),
                          ),
                          title: const Text(
                            'تأكيد تسجيل الخروج',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold),
                            textDirection: TextDirection.rtl,
                          ),
                          content: const Text(
                            'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
                            style: TextStyle(color: AppTheme.textSecondary),
                            textDirection: TextDirection.rtl,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('إلغاء',
                                  style: TextStyle(color: AppTheme.steel)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                context.read<AuthCubit>().logout();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.errorColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text('تسجيل الخروج'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text(
                      'تسجيل الخروج من الحساب',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.errorColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.errorColor),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.steel),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: AppTheme.steel, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  static String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.companyAdmin:
        return 'مسؤول الشركة';
      case UserRole.hr:
        return 'الموارد البشرية';
      case UserRole.manager:
        return 'مدير مباشر';
      case UserRole.employee:
        return 'موظف';
    }
  }

  void _showLanguageSelectionSheet(BuildContext context, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'لغة التطبيق',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('lang_arabic_tile'),
                  leading: const Text('🇸🇦', style: TextStyle(fontSize: 24)),
                  title: const Text('العربية'),
                  onTap: () {
                    try {
                      context
                          .read<LanguageCubit>()
                          .setLanguage(const Locale('ar'));
                    } catch (_) {}
                    try {
                      context.read<ProfileCubit>().updatePreferences(
                            profile.preferences.copyWith(locale: 'ar'),
                          );
                    } catch (_) {}
                    Navigator.of(bottomSheetCtx).pop();
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.translate, color: AppTheme.steel),
                  title: Text('الإنجليزية قريباً'),
                  subtitle: Text(
                    'ستتاح عند اكتمال ترجمة جميع شاشات التطبيق.',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
