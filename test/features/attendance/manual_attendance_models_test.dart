import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/domain/manual_attendance_models.dart';

void main() {
  group('ManualAttendanceActionType', () {
    test('maps toApiValue and fromApiValue symmetrically', () {
      expect(ManualAttendanceActionType.checkIn.toApiValue(), 'check_in');
      expect(ManualAttendanceActionType.checkOut.toApiValue(), 'check_out');
      expect(ManualAttendanceActionType.fullDay.toApiValue(), 'full_day');
      expect(ManualAttendanceActionType.excusedAbsence.toApiValue(),
          'excused_absence');

      expect(ManualAttendanceActionType.fromApiValue('check_in'),
          ManualAttendanceActionType.checkIn);
      expect(ManualAttendanceActionType.fromApiValue('check_out'),
          ManualAttendanceActionType.checkOut);
      expect(ManualAttendanceActionType.fromApiValue('full_day'),
          ManualAttendanceActionType.fullDay);
      expect(ManualAttendanceActionType.fromApiValue('excused_absence'),
          ManualAttendanceActionType.excusedAbsence);
    });

    test('provides clean Arabic labels', () {
      expect(ManualAttendanceActionType.checkIn.arabicLabel, 'تسجيل حضور');
      expect(ManualAttendanceActionType.checkOut.arabicLabel, 'تسجيل انصراف');
      expect(ManualAttendanceActionType.fullDay.arabicLabel, 'تصحيح يوم كامل');
      expect(
          ManualAttendanceActionType.excusedAbsence.arabicLabel, 'غياب بعذر');
    });
  });

  group('ManualAttendanceActionRequest', () {
    test('serializes cleanly without extraneous null fields', () {
      final req = ManualAttendanceActionRequest(
        commandId: 'cmd-1',
        employeeId: 'emp-1',
        businessDate: '2026-10-17',
        action: ManualAttendanceActionType.checkIn,
        occurredAt: DateTime.utc(2026, 10, 17, 8, 30),
        reason: 'عطل في البصمة',
      );

      final json = req.toJson();
      expect(json['commandId'], 'cmd-1');
      expect(json['employeeId'], 'emp-1');
      expect(json['businessDate'], '2026-10-17');
      expect(json['action'], 'check_in');
      expect(json['occurredAt'], '2026-10-17T08:30:00.000Z');
      expect(json['reason'], 'عطل في البصمة');
      expect(json.containsKey('checkInAt'), isFalse);
      expect(json.containsKey('checkOutAt'), isFalse);
    });

    test('serializes full day with checkInAt and checkOutAt', () {
      final req = ManualAttendanceActionRequest(
        commandId: 'cmd-2',
        employeeId: 'emp-2',
        businessDate: '2026-10-17',
        action: ManualAttendanceActionType.fullDay,
        checkInAt: DateTime.utc(2026, 10, 17, 8, 0),
        checkOutAt: DateTime.utc(2026, 10, 17, 16, 0),
        reason: 'نسيان تسجيل الخروج بسبب اجتماع طارئ',
      );

      final json = req.toJson();
      expect(json['action'], 'full_day');
      expect(json['checkInAt'], '2026-10-17T08:00:00.000Z');
      expect(json['checkOutAt'], '2026-10-17T16:00:00.000Z');
      expect(json.containsKey('occurredAt'), isFalse);
    });
  });

  group('ManualAttendanceActionResult', () {
    test('deserializes OpenAPI 3.1 manual-actions response', () {
      final json = {
        'id': 'res-123',
        'employeeId': 'emp-123',
        'shiftInstanceId': 'shift-123',
        'businessDate': '2026-10-17',
        'action': 'full_day',
        'effectiveState': 'completed',
        'checkedInAt': '2026-10-17T08:00:00.000Z',
        'checkedOutAt': '2026-10-17T16:00:00.000Z',
        'reason': 'تعديل إداري معتمد',
        'source': 'hr_manual_override',
        'createdAt': '2026-10-17T16:05:00.000Z',
      };

      final res = ManualAttendanceActionResult.fromJson(json);
      expect(res.id, 'res-123');
      expect(res.employeeId, 'emp-123');
      expect(res.action, ManualAttendanceActionType.fullDay);
      expect(res.effectiveState, 'completed');
      expect(res.source, 'hr_manual_override');
      expect(res.checkedInAt, DateTime.utc(2026, 10, 17, 8, 0));
    });
  });

  group('DetailedReconciliationItem', () {
    test('deserializes detailed items with safe employee display name', () {
      final json = {
        'id': 'rec-1',
        'employeeId': 'emp-1',
        'shiftInstanceId': 'shift-1',
        'causeType': 'absence_scan',
        'state': 'failed',
        'attempts': 3,
        'reasonCode': 'NO_ATTENDANCE_EVENTS',
        'createdAt': '2026-10-17T10:00:00.000Z',
        'finishedAt': null,
        'employeeName': 'أحمد محمد علي',
        'businessDate': '2026-10-17',
      };

      final item = DetailedReconciliationItem.fromJson(json);
      expect(item.id, 'rec-1');
      expect(item.employeeName, 'أحمد محمد علي');
      expect(item.state, 'failed');
      expect(item.attempts, 3);
      expect(item.reasonCode, 'NO_ATTENDANCE_EVENTS');
      expect(item.isLateArrivalProposal, isFalse);
    });

    test(
        'deserializes late arrival proposal with excess minutes and suggested deduction',
        () {
      final json = {
        'id': 'rec-late-1',
        'employeeId': 'emp-1',
        'shiftInstanceId': 'shift-1',
        'causeType': 'late_arrival',
        'state': 'queued',
        'attempts': 1,
        'reasonCode': 'LATE_ARRIVAL_REVIEW_REQUIRED',
        'createdAt': '2026-10-17T10:00:00.000Z',
        'finishedAt': null,
        'employeeName': 'سارة عبد الرحمن',
        'businessDate': '2026-10-17',
        'lateMinutes': 45,
        'suggestedDeduction': {
          'mode': 'custom_hours',
          'units': '0.75',
          'requiresApproval': true,
        },
      };

      final item = DetailedReconciliationItem.fromJson(json);
      expect(item.isLateArrivalProposal, isTrue);
      expect(item.lateMinutes, 45);
      expect(item.suggestedDeduction?.mode,
          AdministrativeAdjustmentMode.customHours);
      expect(item.suggestedDeduction?.units, '0.75');
      expect(item.suggestedDeduction?.requiresApproval, isTrue);
      expect(item.friendlyReasonDescription, contains('45 دقيقة'));
    });
  });

  group('AdministrativeAdjustmentPreview & Request', () {
    test('deserializes server preview calculations', () {
      final json = {
        'amount': {'currency': 'SDG', 'amount': '25.00'},
        'dailyRate': {'currency': 'SDG', 'amount': '100.00'},
        'hourlyRate': {'currency': 'SDG', 'amount': '12.50'},
        'units': '0.25',
        'shiftInstanceId': 'shift-1',
        'calculationSnapshot': {
          'baseMonthlyMinor': '300000',
          'payrollDays': 30,
        },
      };

      final preview = AdministrativeAdjustmentPreview.fromJson(json);
      expect(preview.amount.amount, '25.00');
      expect(preview.amount.currency, 'SDG');
      expect(preview.units, '0.25');
      expect(preview.dailyRate?.amount, '100.00');
    });

    test('serializes adjustment request with reason and units', () {
      final req = AdministrativeAdjustmentRequest(
        commandId: 'cmd-adj-1',
        employeeId: 'emp-1',
        targetCycleId: 'cycle-1',
        businessDate: '2026-10-17',
        mode: AdministrativeAdjustmentMode.dayFraction,
        units: '0.25',
        reasonCode: 'ATTENDANCE_PENALTY_ADJUSTED',
        reason: 'تأخير غير مبرر عن الوردية',
        reconciliationItemId: 'rec-1',
      );

      final json = req.toJson();
      expect(json['commandId'], 'cmd-adj-1');
      expect(json['targetCycleId'], 'cycle-1');
      expect(json['mode'], 'day_fraction');
      expect(json['units'], '0.25');
      expect(json['reconciliationItemId'], 'rec-1');
      expect(json['reasonCode'], 'ATTENDANCE_PENALTY_ADJUSTED');
    });
  });
}
