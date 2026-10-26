import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';

/// Notification Settings Screen for Feature 012 Task T064.
///
/// Provides:
/// - Explicit OS push permission toggle with consent-first behavior.
/// - Non-pressuring denied permission guidance (respects user choice without nagging).
/// - Category-specific notification preference toggles (attendance, approvals, requests, payroll, service).
/// - Optimistic UI updates with rollback on network failure.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    this.pushRegistrationPort,
    this.pushNotificationPort,
    this.apiClient,
  });

  final PushRegistrationPort? pushRegistrationPort;
  final PushNotificationPort? pushNotificationPort;
  final ApiClient? apiClient;

  static Route<void> route({
    PushRegistrationPort? pushRegistrationPort,
    PushNotificationPort? pushNotificationPort,
    ApiClient? apiClient,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => NotificationSettingsScreen(
        pushRegistrationPort: pushRegistrationPort,
        pushNotificationPort: pushNotificationPort,
        apiClient: apiClient,
      ),
    );
  }

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSavingPreferences = false;
  PushPermissionState _permissionState = PushPermissionState.unknown;
  bool _pushMasterEnabled = false;

  int _preferenceRevision = 1;
  final Map<String, bool> _categoryPreferences = {
    'attendance': true,
    'approvals': true,
    'requests': true,
    'payroll': true,
    'service': true,
    'company_announcements': true,
  };

  static const Map<String, String> _categoryTitles = {
    'attendance': 'تنبيهات الحضور والانصراف',
    'approvals': 'قرارات الاعتماد والطلبات',
    'requests': 'تحديثات الطلبات الشخصية',
    'payroll': 'إشعارات مسيرات الرواتب والسلف',
    'service': 'تنبيهات النظام والخدمة',
    'company_announcements': 'إعلانات الشركة والتعاميم',
  };

  static const Map<String, String> _categorySubtitles = {
    'attendance': 'تأكيد تسجيل الحضور وتنبيهات الوردية',
    'approvals': 'إشعارات الموافقة أو الرفض للمرؤوسين',
    'requests': 'تحديثات حالة الإجازات والمهام',
    'payroll': 'جاهزية قسائم الرواتب والسلف المالية',
    'service': 'إعلانات الصيانة وتحديثات النظام',
    'company_announcements':
        'الرسائل والتعاميم الإدارية الموجهة من إدارة الشركة',
  };

  PushRegistrationPort? _getRegistrationPort() {
    if (widget.pushRegistrationPort != null) return widget.pushRegistrationPort;
    try {
      return context.read<PushRegistrationPort>();
    } catch (_) {
      return null;
    }
  }

  PushNotificationPort? _getNotificationPort() {
    if (widget.pushNotificationPort != null) return widget.pushNotificationPort;
    try {
      return context.read<PushNotificationPort>();
    } catch (_) {
      return null;
    }
  }

  ApiClient? _getApiClient() {
    if (widget.apiClient != null) return widget.apiClient;
    try {
      return context.read<ApiClient>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadState();
    });
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    final notifPort = _getNotificationPort();
    final client = _getApiClient();
    final perm = notifPort != null
        ? await notifPort.currentPermission()
        : PushPermissionState.unavailable;
    // Preference delivery must not hide a granted Android permission.  The
    // two calls use different services and can fail independently.
    List<NotificationPreferenceDto> prefs = const [];
    if (client != null) {
      try {
        prefs = await client.getNotificationPreferences();
      } catch (_) {
        // Keep the default category choices until the next refresh.
      }
    }
    if (!mounted) return;
    setState(() {
      _permissionState = perm;
      _pushMasterEnabled = perm == PushPermissionState.granted;
      for (final p in prefs) {
        _categoryPreferences[p.category] = p.pushEnabled;
        if (p.revision > _preferenceRevision) {
          _preferenceRevision = p.revision;
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _togglePushMaster(bool value) async {
    final regPort = _getRegistrationPort();
    final notifPort = _getNotificationPort();

    if (value) {
      if (regPort == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خدمة الإشعارات غير متوفرة على هذا الجهاز حالياً.'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
        return;
      }
      final outcome = await regPort.enable(locale: 'ar');
      final newPerm = notifPort != null
          ? await notifPort.currentPermission()
          : PushPermissionState.unknown;
      if (!mounted) return;
      setState(() {
        _permissionState = newPerm;
        _pushMasterEnabled = outcome == PushRegistrationOutcome.enabled;
      });
      if (outcome == PushRegistrationOutcome.permissionUnavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'إشعارات الجهاز معطلة. يمكنك تفعيلها من إعدادات النظام متى رغبت.'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
      }
      if (outcome == PushRegistrationOutcome.tokenUnavailable ||
          outcome == PushRegistrationOutcome.registrationUnavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'تعذر تفعيل إشعارات الجهاز الآن. لم يُحفظ أي جهاز؛ أعد المحاولة لاحقاً.'),
            backgroundColor: AppTheme.textSecondary,
          ),
        );
      }
    } else {
      if (regPort != null) {
        await regPort.disable();
      }
      if (!mounted) return;
      setState(() {
        _pushMasterEnabled = false;
      });
    }
  }

  Future<void> _toggleCategory(String category, bool value) async {
    final client = _getApiClient();
    if (client == null) return;

    final oldVal = _categoryPreferences[category] ?? true;
    setState(() {
      _categoryPreferences[category] = value;
      _isSavingPreferences = true;
    });

    try {
      final items = [
        NotificationPreferenceInputDto(
          category: category,
          pushEnabled: value,
        ),
      ];

      final updated = await client.replaceNotificationPreferences(
        expectedRevision: _preferenceRevision,
        items: items,
      );

      if (mounted) {
        setState(() {
          for (final p in updated) {
            _categoryPreferences[p.category] = p.pushEnabled;
            if (p.revision > _preferenceRevision) {
              _preferenceRevision = p.revision;
            }
          }
          _isSavingPreferences = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _categoryPreferences[category] = oldVal;
          _isSavingPreferences = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر حفظ التفضيلات. حاول مرة أخرى.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text(
            'إعدادات الإشعارات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Master Device Push Permission Card
                  WolfCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'إشعارات الجهاز (Push)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                key: const Key('push_master_switch'),
                                value: _pushMasterEnabled,
                                onChanged: _togglePushMaster,
                                activeTrackColor: AppTheme.primaryColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'استلام تنبيهات فورية عند اعتماد الطلبات أو تحديثات الحضور حتى أثناء إغلاق التطبيق. لا يتضمن محتوى الإشعار أي بيانات مالية أو حساسة.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (_permissionState ==
                              PushPermissionState.denied) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 20, color: AppTheme.textSecondary),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'إشعارات النظام متوقفة حالياً. يمكنك تفعيلها في أي وقت من إعدادات جهازك إذا أردت استلام التنبيهات.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'تفضيلات فئات الإشعارات',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Toggles
                  WolfCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: _categoryPreferences.keys.map((cat) {
                          final isEnabled = _categoryPreferences[cat] ?? true;
                          final title = _categoryTitles[cat] ?? cat;
                          final subtitle = _categorySubtitles[cat] ?? '';

                          return Column(
                            children: [
                              SwitchListTile.adaptive(
                                key: Key('category_pref_$cat'),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                value: isEnabled,
                                activeTrackColor: AppTheme.primaryColor,
                                onChanged: _isSavingPreferences
                                    ? null
                                    : (val) => _toggleCategory(cat, val),
                              ),
                              if (cat != _categoryPreferences.keys.last)
                                const Divider(height: 1),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
