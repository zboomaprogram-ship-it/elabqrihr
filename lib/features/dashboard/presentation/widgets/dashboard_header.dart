import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';

class DashboardHeader extends StatefulWidget {
  final String userName;
  final String? branchName;
  final bool? isWithinGeofence;
  final VoidCallback? onRefreshLocation;
  final String? roleName;

  const DashboardHeader({
    super.key,
    required this.userName,
    this.branchName,
    this.isWithinGeofence,
    this.onRefreshLocation,
    this.roleName,
  });

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = intl.DateFormat('hh:mm:ss a').format(_now);
    final dateStr = intl.DateFormat('EEEE، d MMMM yyyy', 'ar').format(_now);

    return AttendCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Logo & User Greeting
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppTheme.logoAsset,
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.business,
                      size: 32,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، ${widget.userName}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Live Digital Clock Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface02,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.surface03),
                ),
                child: Text(
                  timeStr,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          if (widget.isWithinGeofence != null && widget.branchName != null) ...[
            const SizedBox(height: 14),
            // Location & Geofence Status Chip
            Row(
              children: [
                InkWell(
                  onTap: widget.onRefreshLocation,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.isWithinGeofence!
                          ? AppTheme.successColor.withValues(alpha: 0.12)
                          : AppTheme.warningColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isWithinGeofence!
                            ? AppTheme.successColor.withValues(alpha: 0.3)
                            : AppTheme.warningColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isWithinGeofence! ? Icons.check_circle : Icons.location_on,
                          size: 15,
                          color: widget.isWithinGeofence!
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isWithinGeofence!
                              ? 'داخل نطاق العمل (${widget.branchName})'
                              : 'خارج النطاق (${widget.branchName})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isWithinGeofence!
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
