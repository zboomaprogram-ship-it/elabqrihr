import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_motion.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/widgets/wolf_card.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';
import 'package:attend_mobile/core/design_system/widgets/checkin_radar_button.dart';
import 'package:attend_mobile/core/design_system/widgets/motion_feedback_sheets.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/presentation/branch_time_formatter.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_integrity_state.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_cubit.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_state.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/widgets/mobile_controls_views.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/month_activity_section.dart';
import 'package:attend_mobile/features/notifications/presentation/widgets/notification_badge_icon.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/hr_attendance_controls_card.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_range_status_card.dart';

/// Dedicated Operational Attendance Workspace Screen.
///
/// Attendance owns:
/// - Current shift schedule & details
/// - Authoritative branch, geofence, and location quality
/// - Check-in/out control ([CheckInRadarButton]) and state transitions
/// - Offline, pending-sync, pending-review, rejection, and conflict states
/// - Attendance event history and month attendance calendar ([MonthActivitySection])
///
/// Attendance strictly excludes:
/// - DashboardHeader & executive greeting
/// - EmployeePriorityStrip
/// - EmployeeQuickActionsGrid
/// - EmployeeSummaryCards & TeamSummaryCard
/// - RecentRequestsPreview
class AttendanceScreen extends StatelessWidget {
  final UserRole? userRole;

  const AttendanceScreen({super.key, this.userRole});

  static String resolveErrorText(String raw) =>
      _AttendanceScreenBody._resolveErrorText(raw);

  @override
  Widget build(BuildContext context) {
    return _AttendanceScreenBody(userRole: userRole);
  }
}

class _AttendanceScreenBody extends StatelessWidget {
  final UserRole? userRole;

  const _AttendanceScreenBody({this.userRole});

  @override
  Widget build(BuildContext context) {
    UserRole? effectiveRole = userRole;
    if (effectiveRole == null) {
      try {
        final authState = context.read<AuthCubit>().state;
        if (authState is Authenticated) {
          effectiveRole = authState.session.role;
        }
      } catch (_) {}
    }
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Semantics(
            label: AppStringsAr.appNameSpoken,
            excludeSemantics: true,
            child: const Text(
              AppStringsAr.attendanceTab,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          actions: [
            const NotificationBadgeIcon(),
          ],
        ),
        body: BlocConsumer<AttendanceCubit, AttendanceState>(
          listener: (context, state) {
            if (state is AttendanceSuccess) {
              final isCheckIn =
                  state.event.eventType == AttendanceEventType.checkIn;
              final isOffline =
                  state.event.status == AttendanceValidationStatus.pendingSync;
              final isConflict =
                  state.event.status == AttendanceValidationStatus.conflict;

              if (state.event.status == AttendanceValidationStatus.accepted) {
                MotionFeedbackSheets.showCheckInSuccess(
                  context,
                  title: isCheckIn
                      ? 'تم تسجيل الحضور بنجاح'
                      : 'تم تسجيل الانصراف بنجاح',
                  subtitle: 'تم اعتماد الحركة وتسجيلها بنجاح في النظام',
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isConflict
                          ? AppStringsAr.statusConflict
                          : isOffline
                              ? AppStringsAr.offlineSaved
                              : AppFailureMapper.attendanceReasonMessage(
                                  state.event.reasonCode,
                                ),
                    ),
                    backgroundColor: isConflict ||
                            state.event.status ==
                                AttendanceValidationStatus.rejected
                        ? AppTheme.errorColor
                        : AppTheme.warningColor,
                  ),
                );
              }
            }
          },
          builder: (context, state) {
            if (effectiveRole == UserRole.companyAdmin) {
              return _buildRoleForbiddenState(context);
            }

            if (state is AttendanceLoading || state is AttendanceInitial) {
              return const AttendanceSkeleton();
            }

            if (state is AttendanceFailure) {
              if (_isRoleForbidden(state, effectiveRole)) {
                return _buildRoleForbiddenState(context);
              }
              if (_isMissingShift(state)) {
                return _buildMissingShiftState(
                  context,
                  isHrOrAdmin: effectiveRole == UserRole.hr ||
                      effectiveRole == UserRole.companyAdmin,
                );
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(
                        _resolveErrorText(state.message),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<AttendanceCubit>().loadShiftContext(),
                        child: const Text(AppStringsAr.retrySync),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is AttendanceReady) {
              final shift = state.shiftContext;
              final isCheckedIn = shift.isCheckedIn;
              final isCompleted = shift.isCompleted ||
                  (shift.lastEvent != null &&
                      shift.lastEvent!.status ==
                          AttendanceValidationStatus.accepted &&
                      shift.lastEvent!.eventType ==
                          AttendanceEventType.checkOut);

              return RefreshIndicator(
                onRefresh: () =>
                    context.read<AttendanceCubit>().loadShiftContext(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 14.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (effectiveRole == UserRole.hr ||
                          effectiveRole == UserRole.companyAdmin)
                        HrAttendanceControlsCard(
                          onEmergencySaved: () => context
                              .read<AttendanceCubit>()
                              .loadShiftContext(),
                        ),
                      // ── Shift Info & Operational Location Card ──
                      AttendCard(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Text(
                                  shift.shiftName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                _buildStatusBadge(shift),
                              ],
                            ),
                            const Divider(
                                height: 20, color: AppTheme.surface03),
                            _buildInfoRow(
                              Icons.business,
                              AppStringsAr.branch,
                              shift.branchName,
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow(
                              Icons.access_time,
                              AppStringsAr.shiftTime,
                              '${BranchTimeFormatter.formatRange(startsAt: shift.scheduledStart, endsAt: shift.scheduledEnd, timezone: shift.branchTimezone)}${shift.branchTimezone == null ? '' : ' (${shift.branchTimezone})'}',
                            ),
                            const SizedBox(height: 10),
                            const SizedBox(height: 12),
                            AttendanceRangeStatusCard(
                              shift: shift,
                              currentLocation: state.currentLocation,
                              isLocating: state.isLocating,
                              locationError: state.locationError,
                              onRefresh: () => context
                                  .read<AttendanceCubit>()
                                  .refreshLocation(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Error banner ──
                      if (state.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.errorColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _resolveErrorText(state.errorMessage!),
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Terminal reason / rejection banner ──
                      if (shift.lastEvent != null &&
                          shift.lastEvent!.reasonCode != null) ...[
                        _buildTerminalReasonBanner(shift.lastEvent!),
                        const SizedBox(height: 12),
                        if (shift.lastEvent!.status ==
                            AttendanceValidationStatus.pendingReview) ...[
                          AttendanceIntegrityState(
                            reasonCode: shift.lastEvent!.reasonCode,
                            onRefresh: () => context
                                .read<AttendanceCubit>()
                                .loadShiftContext(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],

                      // ── Offline outbox indicator ──
                      if (state.pendingEvents.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const AppMotion(
                                asset: AppMotionAsset.offlineSync,
                                semanticLabel:
                                    'جاري مزامنة العمليات غير المتصلة',
                                size: 28,
                                repeat: true,
                                fallbackIcon: Icons.cloud_upload_outlined,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${AppStringsAr.statusPendingSync} (${state.pendingEvents.length})',
                                  style: const TextStyle(
                                    color: AppTheme.warningColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── CheckIn Radar Button (central operational CTA) ──
                      CheckInRadarButton(
                        title: isCompleted
                            ? 'اكتملت الوردية'
                            : isCheckedIn
                                ? AppStringsAr.checkOut
                                : AppStringsAr.checkIn,
                        subtitle: isCompleted
                            ? 'تم انتهاء دوام اليوم بنجاح'
                            : isCheckedIn
                                ? 'اضغط لتسجيل الانصراف'
                                : 'اضغط لتسجيل الحضور',
                        icon: isCompleted
                            ? Icons.task_alt_rounded
                            : isCheckedIn
                                ? Icons.logout
                                : Icons.fingerprint,
                        isCheckOut: isCheckedIn,
                        isCompleted: isCompleted,
                        disabled: state.isSubmitting || isCompleted,
                        loading: state.isSubmitting,
                        onTap: () {
                          if (isCompleted) return;
                          MobileActionGuardDecision? decision;
                          try {
                            decision = context
                                .read<MobileControlsCubit>()
                                .evaluateAction(
                                  MobileControlKey.attendanceSubmit,
                                );
                          } catch (_) {}
                          if (decision != null && !decision.isPermitted) {
                            MobileActionGuardDialog.show(
                              context,
                              decision: decision,
                            );
                            return;
                          }
                          context.read<AttendanceCubit>().recordEvent(
                                eventType: isCheckedIn
                                    ? AttendanceEventType.checkOut
                                    : AttendanceEventType.checkIn,
                              );
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Month Activity Calendar ──
                      const _SectionLabel('سجل حضور الشهر'),
                      const SizedBox(height: 10),
                      MonthActivitySection(
                        presentDates: (shift.lastEvent != null &&
                                shift.lastEvent!.status ==
                                    AttendanceValidationStatus.accepted)
                            ? [shift.lastEvent!.capturedAt]
                            : [],
                        absentDates: const [],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ShiftContextEntity shift) {
    String text = AppStringsAr.statusNotStarted;
    Color color = Colors.grey;

    final isCompleted = shift.isCompleted ||
        (shift.lastEvent != null &&
            shift.lastEvent!.status == AttendanceValidationStatus.accepted &&
            shift.lastEvent!.eventType == AttendanceEventType.checkOut);

    if (isCompleted) {
      text = AppStringsAr.statusCompleted;
      color = AppTheme.successColor;
    } else if (shift.isCheckedIn) {
      text = AppStringsAr.statusPresent;
      color = AppTheme.successColor;
    } else if (shift.lastEvent != null) {
      switch (shift.lastEvent!.status) {
        case AttendanceValidationStatus.pendingReview:
          text = AppStringsAr.statusPendingReview;
          color = AppTheme.warningColor;
          break;
        case AttendanceValidationStatus.rejected:
          text = AppStringsAr.statusRejected;
          color = AppTheme.errorColor;
          break;
        case AttendanceValidationStatus.conflict:
          text = AppStringsAr.statusConflict;
          color = AppTheme.errorColor;
          break;
        case AttendanceValidationStatus.pendingSync:
          text = AppStringsAr.statusPendingSync;
          color = AppTheme.warningColor;
          break;
        case AttendanceValidationStatus.accepted:
          text = AppStringsAr.statusCompleted;
          color = AppTheme.secondaryColor;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTerminalReasonBanner(AttendanceEventEntity event) {
    final isGeofence = _isGeofenceReason(event.reasonCode);
    final String message;
    if (event.reasonCode == 'LOCATION_OUT_OF_RADIUS') {
      message = AppStringsAr.reasonOutOfRadius;
    } else if (isGeofence) {
      message =
          'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.';
    } else {
      message = AppFailureMapper.attendanceReasonMessage(event.reasonCode);
    }

    final isRejected = event.status == AttendanceValidationStatus.rejected ||
        event.status == AttendanceValidationStatus.conflict;
    final color = isRejected ? AppTheme.errorColor : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isGeofence
                ? Icons.location_off_outlined
                : (isRejected ? Icons.highlight_off : Icons.info_outline),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (isGeofence &&
                    message !=
                        'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.') ...[
                  const SizedBox(height: 4),
                  Text(
                    'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingShiftState(BuildContext context,
      {bool isHrOrAdmin = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (isHrOrAdmin) const HrAttendanceControlsCard(),
            AttendCard(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today_outlined,
                      size: 36,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'لا توجد وردية عمل حالياً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'لا توجد وردية عمل مجدولة مسندة إليك في الوقت الحالي. يمكنك مراجعة مشرفك المباشر أو إدارة الموارد البشرية لجدولة وردية العمل الخاصة بك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    key: const Key('attendance_refresh_shift_btn'),
                    onPressed: () =>
                        context.read<AttendanceCubit>().loadShiftContext(),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(AppStringsAr.retrySync),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleForbiddenState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const HrAttendanceControlsCard(),
            AttendCard(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 36,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'حساب إدارة المنشأة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تسجيل الحضور الذاتي مخصص للموظفين التشغيليين. أدوات الإشراف والاعتماد متاحة في التبويبات الأخرى.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface02,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.steel),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'لا يمكن تجاوز الوردية أو نطاق الموقع من هذا الإعداد',
                            style:
                                TextStyle(fontSize: 12, color: AppTheme.steel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isMissingShift(AttendanceFailure failure) {
    final code = failure.code?.toUpperCase() ?? '';
    final msg = failure.message.toUpperCase();
    return code == 'SHIFT_NOT_FOUND' ||
        code == 'NO_ACTIVE_SHIFT' ||
        code == 'NO_CURRENT_SHIFT' ||
        code == 'SHIFT_ASSIGNMENT_NOT_FOUND' ||
        code == 'NOT_FOUND' ||
        code == '404' ||
        msg.contains('SHIFT_NOT_FOUND') ||
        msg.contains('NO_ACTIVE_SHIFT') ||
        msg.contains('NO_CURRENT_SHIFT') ||
        msg.contains('SHIFT_ASSIGNMENT_NOT_FOUND') ||
        msg.contains('404') ||
        msg.contains('لا توجد وردية');
  }

  static bool _isRoleForbidden(AttendanceFailure failure, UserRole? _) {
    final code = failure.code?.toUpperCase() ?? '';
    final msg = failure.message.toUpperCase();
    return code == 'SELF_ATTENDANCE_DISABLED' ||
        code == 'FORBIDDEN' ||
        code == 'ROLE_FORBIDDEN' ||
        code == '403' ||
        msg.contains('FORBIDDEN') ||
        msg.contains('ROLE_FORBIDDEN') ||
        msg.contains('403') ||
        msg.contains('غير مصرح') ||
        msg.contains('صلاحية');
  }

  static bool _isGeofenceReason(String? code) {
    if (code == null) return false;
    final upper = code.toUpperCase();
    return upper == 'LOCATION_OUT_OF_RADIUS' ||
        upper == 'OUTSIDE_GEOFENCE' ||
        upper == 'GEOFENCE_REJECTED' ||
        upper.contains('GEOFENCE') ||
        upper.contains('RADIUS');
  }

  static String _resolveErrorText(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('401') ||
        lower.contains('authentication_required') ||
        lower.contains('unauthorized')) {
      return 'انتهت صلاحية الجلسة أو يلزم تسجيل الدخول مرة أخرى.';
    }
    if (lower.contains('permanently') || lower.contains('deniedforever')) {
      return AppStringsAr.locationPermissionPermanentlyDenied;
    }
    if (lower.contains('locationservicedisabled') ||
        lower.contains('disabled') ||
        lower.contains('gps')) {
      return AppStringsAr.locationServiceDisabled;
    }
    if (lower.contains('permissiondenied') ||
        lower.contains('denied') ||
        raw == 'location_required') {
      return AppStringsAr.locationPermissionRequired;
    }
    if (lower.contains('timeoutexception') || lower.contains('timeout')) {
      return AppStringsAr.locationTimeout;
    }
    if (lower.contains('mocklocationdetected')) {
      return AppStringsAr.locationIntegrityFailed;
    }
    if (lower.contains('outside_geofence') ||
        lower.contains('geofence_rejected') ||
        lower.contains('location_out_of_radius') ||
        lower.contains('outside_allowed_radius') ||
        lower.contains('geofence')) {
      return 'يتطلب تسجيل الحضور التواجد الفعلي داخل النطاق الجغرافي المحدد لفرع العمل.';
    }
    if (lower.contains('shift_not_found') ||
        lower.contains('no_active_shift') ||
        lower.contains('shift_assignment_not_found') ||
        lower.contains('404')) {
      return 'لا توجد وردية عمل حالياً مسندة إليك.';
    }
    if (lower.contains('forbidden') ||
        lower.contains('403') ||
        lower.contains('role_forbidden')) {
      return 'تسجيل الحضور الذاتي مخصص للموظفين التشغيليين.';
    }
    if (lower.contains('apiexception') ||
        lower.contains('500') ||
        lower.contains('internal server error')) {
      return 'حدث خطأ في خدمة الخادم. يرجى المحاولة لاحقاً.';
    }
    if (lower.contains('dio') ||
        lower.contains('socket') ||
        lower.contains('connect') ||
        lower.contains('failed host lookup') ||
        lower.contains('network')) {
      return 'تعذر الاتصال بالخادم. يرجى التأكد من تشغيل الخادم وإعدادات الاتصال.';
    }
    // Sanitized fallback: preserve polite Arabic strings without technical markers,
    // otherwise map through AppFailureMapper to guarantee zero technical leaks.
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(raw);
    final hasTechnicalMarkers = raw.contains('Exception') ||
        raw.contains('Error') ||
        raw.contains('{') ||
        raw.contains('HTTP') ||
        raw.contains('http') ||
        raw.contains('Dio') ||
        raw.contains('Socket') ||
        raw.contains('at ') ||
        raw.contains('/');
    if (hasArabic && !hasTechnicalMarkers) {
      return raw;
    }
    return AppFailureMapper.fromGeneric(raw).message;
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: AppTheme.steel),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              Text(
                '$label: ',
                style: const TextStyle(color: AppTheme.steel, fontSize: 14),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
