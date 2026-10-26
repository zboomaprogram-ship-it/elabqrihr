import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';

/// Privacy-safe range-status card displayed on the Attendance Screen.
///
/// Indicates whether the employee's foreground location fix is currently
/// inside or outside the assigned branch geofence, or if locating/error.
///
/// Invariant: Client geofence guidance is advisory only. The server remains
/// the sole attendance authority for all decisions.
class AttendanceRangeStatusCard extends StatelessWidget {
  final ShiftContextEntity shift;
  final GeoPoint? currentLocation;
  final bool isLocating;
  final String? locationError;
  final VoidCallback onRefresh;

  const AttendanceRangeStatusCard({
    super.key,
    required this.shift,
    this.currentLocation,
    this.isLocating = false,
    this.locationError,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return WolfCard(
      key: const Key('attendance_range_status_card'),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildLeadingIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTitleAndSubtitle(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('attendance_refresh_location_btn'),
                  icon: isLocating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      : const Icon(
                          Icons.refresh,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                  tooltip: 'تحديث الموقع والنطاق',
                  onPressed: isLocating ? null : onRefresh,
                ),
              ],
            ),
            _buildCalloutMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIndicator() {
    if (isLocating) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      );
    }

    if (locationError != null) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.location_off_outlined,
          color: AppTheme.warningColor,
          size: 20,
        ),
      );
    }

    if (currentLocation == null) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.steel.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.my_location_outlined,
          color: AppTheme.steel,
          size: 20,
        ),
      );
    }

    final distanceMeters = currentLocation!.distanceTo(shift.branchLocation);
    // Boundary equality with small indoor GPS tolerance (capped at 25m)
    final accuracyTolerance = (currentLocation!.accuracyMeters ?? 0.0).clamp(0.0, 25.0).toDouble();
    final effectiveRadius = shift.allowedRadiusMeters + accuracyTolerance;
    final isInside = distanceMeters <= effectiveRadius;

    final color = isInside ? AppTheme.successColor : AppTheme.warningColor;
    final icon = isInside
        ? Icons.check_circle_outline
        : Icons.wrong_location_outlined;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildTitleAndSubtitle() {
    if (isLocating) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'جارٍ التحقق من موقعك…',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'يتم فحص إحداثيات الموقع الدقيق عبر GPS.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    if (locationError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'تعذر تحديد الموقع بدقة',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            locationError!,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      );
    }

    if (currentLocation == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'اضغط على زر التحديث لفحص الموقع',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'نطاق العمل: ${shift.allowedRadiusMeters.toInt()} متر',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    final distanceMeters = currentLocation!.distanceTo(shift.branchLocation);
    final accuracyTolerance = (currentLocation!.accuracyMeters ?? 0.0).clamp(0.0, 25.0).toDouble();
    final effectiveRadius = shift.allowedRadiusMeters + accuracyTolerance;
    final isInside = distanceMeters <= effectiveRadius;
    final formattedDistance = distanceMeters < 1000
        ? '~${distanceMeters.round()} متر'
        : '~${(distanceMeters / 1000).toStringAsFixed(1)} كم';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isInside ? 'أنت داخل نطاق العمل' : 'أنت خارج نطاق العمل',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isInside ? AppTheme.successColor : AppTheme.warningColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${shift.branchName} • المسافة: $formattedDistance (النطاق: ${shift.allowedRadiusMeters.toInt()} م)',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCalloutMessage() {
    if (isLocating) {
      return const SizedBox.shrink();
    }

    if (locationError != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface02,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.warningColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تأكد من تفعيل خدمة GPS ومنح إذن الموقع الدقيق، أو انتقل إلى مكان مكشوف لتحسين الإشارة.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  if (!kIsWeb) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () async {
                        try {
                          await Geolocator.openLocationSettings();
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.primaryColor),
                      label: const Text('إعدادات GPS', style: TextStyle(fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () async {
                        try {
                          await Geolocator.openAppSettings();
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.settings_outlined, size: 16, color: AppTheme.primaryColor),
                      label: const Text('أذونات التطبيق', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: isLocating ? null : onRefresh,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('إعادة المحاولة', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (currentLocation == null) {
      return const SizedBox.shrink();
    }

    final distanceMeters = currentLocation!.distanceTo(shift.branchLocation);
    final accuracyTolerance = (currentLocation!.accuracyMeters ?? 0.0).clamp(0.0, 25.0).toDouble();
    final effectiveRadius = shift.allowedRadiusMeters + accuracyTolerance;
    final isInside = distanceMeters <= effectiveRadius;

    final isLowAccuracy = currentLocation!.accuracyMeters != null &&
        currentLocation!.accuracyMeters! > 100;

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isInside
              ? AppTheme.successColor.withValues(alpha: 0.08)
              : AppTheme.warningColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isInside
                  ? 'يمكنك تسجيل الحضور الآن'
                  : 'يرجى الاقتراب من موقع العمل المصرح به لتسجيل الحضور.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isInside ? AppTheme.successColor : AppTheme.warningColor,
              ),
            ),
            if (isLowAccuracy) ...[
              const SizedBox(height: 3),
              Text(
                'دقة إشارة GPS منخفضة (${currentLocation!.accuracyMeters!.round()} م). قد يؤثر ذلك على دقة التحقق.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
