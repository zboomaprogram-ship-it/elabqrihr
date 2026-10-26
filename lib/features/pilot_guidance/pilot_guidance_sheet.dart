import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

class PilotGuidanceSheet extends StatelessWidget {
  const PilotGuidanceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PilotGuidanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        AppStringsAr.pilotGuidanceTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkInk,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'إغلاق',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGuidanceCard(
                  icon: Icons.location_on_outlined,
                  title: 'استخدام الموقع الجغرافي',
                  content: AppStringsAr.pilotLocationNotice,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 12),
                _buildGuidanceCard(
                  icon: Icons.wifi_off_outlined,
                  title: 'المزامنة ووضع عدم الاتصال',
                  content: AppStringsAr.pilotOfflineNotice,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(height: 12),
                _buildGuidanceCard(
                  icon: Icons.security_outlined,
                  title: 'سياسة الخصوصية وحماية البيانات',
                  content: AppStringsAr.pilotPrivacyNotice,
                  color: AppTheme.mint,
                ),
                const SizedBox(height: 12),
                _buildGuidanceCard(
                  icon: Icons.support_agent_outlined,
                  title: 'قناة الدعم والمساعدة',
                  content: AppStringsAr.pilotSupportRoute,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 12),
                _buildGuidanceCard(
                  icon: Icons.emergency_outlined,
                  title: 'إجراء الطوارئ البديل',
                  content: AppStringsAr.pilotEmergencyWorkaround,
                  color: AppTheme.coral,
                ),
                const SizedBox(height: 12),
                _buildGuidanceCard(
                  icon: Icons.info_outline,
                  title: 'ملاحظات وضوابط التجربة',
                  content: AppStringsAr.pilotLimitationsNotice,
                  color: Colors.blueGrey,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGuidanceCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.darkInk,
            ),
          ),
        ],
      ),
    );
  }
}
