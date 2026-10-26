import 'package:equatable/equatable.dart';

/// Supported administrative emergency actions (Feature 015)
enum ManualAttendanceActionType {
  checkIn,
  checkOut,
  fullDay,
  excusedAbsence;

  String toApiValue() => switch (this) {
        ManualAttendanceActionType.checkIn => 'check_in',
        ManualAttendanceActionType.checkOut => 'check_out',
        ManualAttendanceActionType.fullDay => 'full_day',
        ManualAttendanceActionType.excusedAbsence => 'excused_absence',
      };

  static ManualAttendanceActionType fromApiValue(String value) =>
      switch (value) {
        'check_in' => ManualAttendanceActionType.checkIn,
        'check_out' => ManualAttendanceActionType.checkOut,
        'full_day' => ManualAttendanceActionType.fullDay,
        'excused_absence' => ManualAttendanceActionType.excusedAbsence,
        _ => throw ArgumentError('Unknown manual attendance action type: $value'),
      };

  String get arabicLabel => switch (this) {
        ManualAttendanceActionType.checkIn => 'تسجيل حضور',
        ManualAttendanceActionType.checkOut => 'تسجيل انصراف',
        ManualAttendanceActionType.fullDay => 'تصحيح يوم كامل',
        ManualAttendanceActionType.excusedAbsence => 'غياب بعذر',
      };
}

/// Searchable employee summary for HR administrative selection
class ManualAttendanceEmployeeOption extends Equatable {
  final String id;
  final String displayName;
  final String employeeNumber;

  const ManualAttendanceEmployeeOption({
    required this.id,
    required this.displayName,
    required this.employeeNumber,
  });

  factory ManualAttendanceEmployeeOption.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceEmployeeOption(
      id: json['id'] as String? ?? json['employeeId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      employeeNumber: json['employeeNumber'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'employeeNumber': employeeNumber,
      };

  @override
  List<Object?> get props => [id, displayName, employeeNumber];
}

/// Administrative attendance action request payload (OpenAPI 3.1)
class ManualAttendanceActionRequest extends Equatable {
  final String commandId;
  final String employeeId;
  final String businessDate; // YYYY-MM-DD
  final ManualAttendanceActionType action;
  final DateTime? occurredAt;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String reason;

  const ManualAttendanceActionRequest({
    required this.commandId,
    required this.employeeId,
    required this.businessDate,
    required this.action,
    this.occurredAt,
    this.checkInAt,
    this.checkOutAt,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'commandId': commandId,
      'employeeId': employeeId,
      'businessDate': businessDate,
      'action': action.toApiValue(),
      'reason': reason.trim(),
    };
    if (occurredAt != null) {
      map['occurredAt'] = occurredAt!.toUtc().toIso8601String();
    }
    if (checkInAt != null) {
      map['checkInAt'] = checkInAt!.toUtc().toIso8601String();
    }
    if (checkOutAt != null) {
      map['checkOutAt'] = checkOutAt!.toUtc().toIso8601String();
    }
    return map;
  }

  @override
  List<Object?> get props => [
        commandId,
        employeeId,
        businessDate,
        action,
        occurredAt,
        checkInAt,
        checkOutAt,
        reason,
      ];
}

/// Append-only administrative attendance action outcome
class ManualAttendanceActionResult extends Equatable {
  final String id;
  final String employeeId;
  final String? shiftInstanceId;
  final String businessDate;
  final ManualAttendanceActionType action;
  final String effectiveState;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String reason;
  final String source;
  final DateTime createdAt;

  const ManualAttendanceActionResult({
    required this.id,
    required this.employeeId,
    this.shiftInstanceId,
    required this.businessDate,
    required this.action,
    required this.effectiveState,
    this.checkedInAt,
    this.checkedOutAt,
    required this.reason,
    required this.source,
    required this.createdAt,
  });

  factory ManualAttendanceActionResult.fromJson(Map<String, dynamic> json) {
    return ManualAttendanceActionResult(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      shiftInstanceId: json['shiftInstanceId'] as String?,
      businessDate: json['businessDate'] as String,
      action: ManualAttendanceActionType.fromApiValue(json['action'] as String),
      effectiveState: json['effectiveState'] as String,
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'] as String)
          : null,
      checkedOutAt: json['checkedOutAt'] != null
          ? DateTime.parse(json['checkedOutAt'] as String)
          : null,
      reason: json['reason'] as String,
      source: json['source'] as String? ?? 'hr_manual_override',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        shiftInstanceId,
        businessDate,
        action,
        effectiveState,
        checkedInAt,
        checkedOutAt,
        reason,
        source,
        createdAt,
      ];
}

/// Money representation in minor units
class MoneyAmount extends Equatable {
  final String currency;
  final String amount;

  const MoneyAmount({
    required this.currency,
    required this.amount,
  });

  factory MoneyAmount.fromJson(Map<String, dynamic> json) {
    return MoneyAmount(
      currency: json['currency'] as String? ?? 'SDG',
      amount: json['amount'] as String? ?? '0.00',
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'amount': amount,
      };

  @override
  List<Object?> get props => [currency, amount];
}

/// Open payroll cycle representation
class OpenPayrollCycle extends Equatable {
  final String id;
  final String cycleKey;
  final String state;
  final int revision;
  final String periodStart;
  final String periodEnd;

  const OpenPayrollCycle({
    required this.id,
    required this.cycleKey,
    required this.state,
    required this.revision,
    required this.periodStart,
    required this.periodEnd,
  });

  factory OpenPayrollCycle.fromJson(Map<String, dynamic> json) {
    return OpenPayrollCycle(
      id: json['id'] as String,
      cycleKey: json['cycleKey'] as String,
      state: json['state'] as String,
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      periodStart: json['periodStart'] as String,
      periodEnd: json['periodEnd'] as String,
    );
  }

  @override
  List<Object?> get props =>
      [id, cycleKey, state, revision, periodStart, periodEnd];
}

/// Server-suggested deduction proposal for attendance exceptions (e.g. late arrival)
class SuggestedDeduction extends Equatable {
  final AdministrativeAdjustmentMode mode;
  final String units;
  final bool requiresApproval;

  const SuggestedDeduction({
    required this.mode,
    required this.units,
    required this.requiresApproval,
  });

  factory SuggestedDeduction.fromJson(Map<String, dynamic> json) {
    return SuggestedDeduction(
      mode: AdministrativeAdjustmentMode.fromApiValue(
        json['mode'] as String? ?? 'custom_hours',
      ),
      units: json['units'] as String? ?? '0.0',
      requiresApproval: json['requiresApproval'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.toApiValue(),
        'units': units,
        'requiresApproval': requiresApproval,
      };

  @override
  List<Object?> get props => [mode, units, requiresApproval];
}

/// Detailed reconciliation item for attendance exceptions
class DetailedReconciliationItem extends Equatable {
  final String id;
  final String employeeId;
  final String shiftInstanceId;
  final String causeType;
  final String state;
  final int attempts;
  final String? reasonCode;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final String employeeName;
  final String businessDate;
  final int? lateMinutes;
  final SuggestedDeduction? suggestedDeduction;

  const DetailedReconciliationItem({
    required this.id,
    required this.employeeId,
    required this.shiftInstanceId,
    required this.causeType,
    required this.state,
    required this.attempts,
    this.reasonCode,
    required this.createdAt,
    this.finishedAt,
    required this.employeeName,
    required this.businessDate,
    this.lateMinutes,
    this.suggestedDeduction,
  });

  bool get isLateArrivalProposal => causeType == 'late_arrival';

  String get friendlyReasonDescription {
    if (reasonCode == 'LATE_ARRIVAL_REVIEW_REQUIRED' || isLateArrivalProposal) {
      if (lateMinutes != null) {
        return 'تجاوز فترة السماح بمقدار $lateMinutes دقيقة ويحتاج قراراً بشرياً قبل أي خصم.';
      }
      return 'تجاوز تسجيل الوصول وقت السماح ويحتاج قراراً بشرياً قبل أي خصم.';
    }
    return switch (reasonCode) {
      'NO_ATTENDANCE_EVENTS' => 'لم تسجل أحداث حضور ضمن النافذة المحددة.',
      'CHECK_OUT_MISSING' => 'لم يسجل الموظف الانصراف.',
      'APPROVED_LEAVE' => 'تم تطبيق إجازة معتمدة.',
      'APPROVED_PERMISSION' => 'تم تطبيق إذن معتمد.',
      'APPROVED_CORRECTION' => 'تم تطبيق تصحيح حضور معتمد.',
      'RECONCILIATION_FAILED' => 'تعذر إكمال المعالجة الآلية.',
      'MANUAL_REPLAY' => 'أعيدت المهمة للمعالجة يدوياً.',
      _ => 'استثناء حضور معلق بانتظار المراجعة.',
    };
  }

  factory DetailedReconciliationItem.fromJson(Map<String, dynamic> json) {
    return DetailedReconciliationItem(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      shiftInstanceId: json['shiftInstanceId'] as String? ?? '',
      causeType: json['causeType'] as String? ?? '',
      state: json['state'] as String,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      reasonCode: json['reasonCode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      employeeName: json['employeeName'] as String? ?? '',
      businessDate: json['businessDate'] as String? ?? '',
      lateMinutes: (json['lateMinutes'] as num?)?.toInt(),
      suggestedDeduction: json['suggestedDeduction'] != null
          ? SuggestedDeduction.fromJson(
              json['suggestedDeduction'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeId,
        shiftInstanceId,
        causeType,
        state,
        attempts,
        reasonCode,
        createdAt,
        finishedAt,
        employeeName,
        businessDate,
        lateMinutes,
        suggestedDeduction,
      ];
}

/// Decision mode for resolving attendance exceptions
enum AdministrativeAdjustmentMode {
  waived,
  dayFraction,
  customHours,
  fixed;

  String toApiValue() => switch (this) {
        AdministrativeAdjustmentMode.waived => 'waived',
        AdministrativeAdjustmentMode.dayFraction => 'day_fraction',
        AdministrativeAdjustmentMode.customHours => 'custom_hours',
        AdministrativeAdjustmentMode.fixed => 'fixed',
      };

  static AdministrativeAdjustmentMode fromApiValue(String value) =>
      switch (value) {
        'waived' => AdministrativeAdjustmentMode.waived,
        'day_fraction' => AdministrativeAdjustmentMode.dayFraction,
        'custom_hours' => AdministrativeAdjustmentMode.customHours,
        'fixed' => AdministrativeAdjustmentMode.fixed,
        _ => throw ArgumentError('Unknown adjustment mode: $value'),
      };

  String get arabicLabel => switch (this) {
        AdministrativeAdjustmentMode.waived => 'إعفاء كامل',
        AdministrativeAdjustmentMode.dayFraction => 'جزء من يوم',
        AdministrativeAdjustmentMode.customHours => 'ساعات محددة',
        AdministrativeAdjustmentMode.fixed => 'مبلغ مخصص',
      };
}

/// Server calculated adjustment preview
class AdministrativeAdjustmentPreview extends Equatable {
  final MoneyAmount amount;
  final MoneyAmount? dailyRate;
  final MoneyAmount? hourlyRate;
  final String units;
  final String? shiftInstanceId;
  final Map<String, dynamic>? calculationSnapshot;

  const AdministrativeAdjustmentPreview({
    required this.amount,
    this.dailyRate,
    this.hourlyRate,
    required this.units,
    this.shiftInstanceId,
    this.calculationSnapshot,
  });

  factory AdministrativeAdjustmentPreview.fromJson(Map<String, dynamic> json) {
    return AdministrativeAdjustmentPreview(
      amount: MoneyAmount.fromJson(json['amount'] as Map<String, dynamic>),
      dailyRate: json['dailyRate'] != null
          ? MoneyAmount.fromJson(json['dailyRate'] as Map<String, dynamic>)
          : null,
      hourlyRate: json['hourlyRate'] != null
          ? MoneyAmount.fromJson(json['hourlyRate'] as Map<String, dynamic>)
          : null,
      units: json['units'] as String? ?? '0',
      shiftInstanceId: json['shiftInstanceId'] as String?,
      calculationSnapshot: json['calculationSnapshot'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        amount,
        dailyRate,
        hourlyRate,
        units,
        shiftInstanceId,
        calculationSnapshot,
      ];
}

/// Request to preview or create an administrative adjustment
class AdministrativeAdjustmentRequest extends Equatable {
  final String commandId;
  final String employeeId;
  final String targetCycleId;
  final String businessDate;
  final String kind; // deduction
  final AdministrativeAdjustmentMode mode;
  final String? units;
  final MoneyAmount? fixedAmount;
  final String reasonCode;
  final String reason;
  final String? reconciliationItemId;

  const AdministrativeAdjustmentRequest({
    required this.commandId,
    required this.employeeId,
    required this.targetCycleId,
    required this.businessDate,
    this.kind = 'deduction',
    required this.mode,
    this.units,
    this.fixedAmount,
    required this.reasonCode,
    required this.reason,
    this.reconciliationItemId,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'commandId': commandId,
      'employeeId': employeeId,
      'targetCycleId': targetCycleId,
      'businessDate': businessDate,
      'kind': kind,
      'mode': mode.toApiValue(),
      'reasonCode': reasonCode,
      'reason': reason.trim(),
    };
    if (units != null) {
      map['units'] = units;
    }
    if (fixedAmount != null) {
      map['fixedAmount'] = fixedAmount!.toJson();
    }
    if (reconciliationItemId != null) {
      map['reconciliationItemId'] = reconciliationItemId;
    }
    return map;
  }

  @override
  List<Object?> get props => [
        commandId,
        employeeId,
        targetCycleId,
        businessDate,
        kind,
        mode,
        units,
        fixedAmount,
        reasonCode,
        reason,
        reconciliationItemId,
      ];
}

/// Result of creating an administrative adjustment
class AdministrativeAdjustmentResult extends Equatable {
  final String id;
  final String? financialAdjustmentId;
  final String employeeId;
  final String businessDate;
  final String kind;
  final AdministrativeAdjustmentMode mode;
  final MoneyAmount amount;
  final String state;
  final DateTime createdAt;

  const AdministrativeAdjustmentResult({
    required this.id,
    this.financialAdjustmentId,
    required this.employeeId,
    required this.businessDate,
    required this.kind,
    required this.mode,
    required this.amount,
    required this.state,
    required this.createdAt,
  });

  factory AdministrativeAdjustmentResult.fromJson(Map<String, dynamic> json) {
    return AdministrativeAdjustmentResult(
      id: json['id'] as String,
      financialAdjustmentId: json['financialAdjustmentId'] as String?,
      employeeId: json['employeeId'] as String,
      businessDate: json['businessDate'] as String,
      kind: json['kind'] as String,
      mode: AdministrativeAdjustmentMode.fromApiValue(json['mode'] as String),
      amount: MoneyAmount.fromJson(json['amount'] as Map<String, dynamic>),
      state: json['state'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        financialAdjustmentId,
        employeeId,
        businessDate,
        kind,
        mode,
        amount,
        state,
        createdAt,
      ];
}
