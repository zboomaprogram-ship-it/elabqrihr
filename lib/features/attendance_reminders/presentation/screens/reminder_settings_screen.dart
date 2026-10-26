import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import '../cubit/reminder_settings_cubit.dart';

class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({super.key});

  static Route<void> route({required ReminderSettingsCubit cubit}) {
    return MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: cubit..loadSettings(),
        child: const ReminderSettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('منبهات وتنبيهات الحضور'),
          centerTitle: true,
        ),
        body: BlocConsumer<ReminderSettingsCubit, ReminderSettingsState>(
          listener: (context, state) {
            if (state is ReminderSettingsLoaded &&
                state.feedbackMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.feedbackMessage!),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          builder: (context, state) {
            return switch (state) {
              ReminderSettingsLoading() =>
                const Center(child: CircularProgressIndicator()),
              ReminderSettingsError(:final message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<ReminderSettingsCubit>()
                              .loadSettings(),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              ReminderSettingsLoaded(:final preferences, :final isSaving) =>
                _buildContent(context, preferences, isSaving),
            };
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    dynamic preferences,
    bool isSaving,
  ) {
    final dateFormat = DateFormat('yyyy/MM/dd · hh:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Non-pressuring informational banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تنبيهات الحضور اختيارية تماماً، وتعمل بنغمات هادئة وفقاً لمواعيد وردياتك وأذوناتك المعتمدة لمساعدتك دون أي إلزام أو تأثير على حضورك الرسمي.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Permission status section if not granted
        if (!preferences.permissionGranted) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.notifications_paused_outlined,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'إذن الإشعارات غير مفعل',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'لتصلك التنبيهات في موعدها، يُرجى تفعيل إذن الإشعارات للتطبيق.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => context
                        .read<ReminderSettingsCubit>()
                        .requestPermission(),
                    icon: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: const Text('تفعيل الإذن'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 1. Shift Start Reminder Card
        AttendCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'تنبيه موعد بداية الوردية',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'تذكيرك قبل بدء وقت العمل الرسمي للاستعداد لتسجيل البصمة.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                value: preferences.shiftStartEnabled,
                onChanged: (val) => context
                    .read<ReminderSettingsCubit>()
                    .toggleShiftStart(val),
              ),
              if (preferences.shiftStartEnabled) ...[
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'وقت التنبيه قبل الوردية:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('قبل 15 دقيقة'),
                      selected: preferences.shiftStartLeadMinutes == 15,
                      onSelected: (_) => context
                          .read<ReminderSettingsCubit>()
                          .setShiftStartLeadMinutes(15),
                    ),
                    ChoiceChip(
                      label: const Text('قبل 30 دقيقة'),
                      selected: preferences.shiftStartLeadMinutes == 30,
                      onSelected: (_) => context
                          .read<ReminderSettingsCubit>()
                          .setShiftStartLeadMinutes(30),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Checkout Reminder Card
        AttendCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'تذكير تسجيل الانصراف',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: const Text(
              'تنبيه عند حلول موعد نهاية الوردية في حال لم تقم بتسجيل الانصراف بعد.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: preferences.checkoutEnabled,
            onChanged: (val) =>
                context.read<ReminderSettingsCubit>().toggleCheckout(val),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Permission Return Reminder Card
        AttendCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'تنبيه العودة من الإذن',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: const Text(
              'تنبيه هادئ قبل انتهاء وقت إذنك المصرح بـ 10 دقائق لتسجيل العودة.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            value: preferences.permissionReturnEnabled,
            onChanged: (val) => context
                .read<ReminderSettingsCubit>()
                .togglePermissionReturn(val),
          ),
        ),
        const SizedBox(height: 16),

        // Test notification button
        AttendCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'صوت التنبيه ونغمات النظام',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'يتم استخدام نغمة الإشعارات القياسية بهاتفك دون إزعاج.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<ReminderSettingsCubit>().testNotification(),
                icon: const Icon(Icons.volume_up_outlined, size: 16),
                label: const Text('تجربة التنبيه'),
              ),
            ],
          ),
        ),

        // Last sync metadata
        if (preferences.lastSyncAt != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              'آخر مزامنة لمواعيد الورديات: ${dateFormat.format(preferences.lastSyncAt!)}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
