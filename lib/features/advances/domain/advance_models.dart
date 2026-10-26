// Domain models for self-service advances (Feature 006, T041-T042).
// These map from DTO types and are presentation-safe. Never calculate
// or round balances on the client — render verbatim server amounts.

import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

enum AdvanceLifecycleState {
  submitted,
  pendingApproval,
  approved,
  rejected,
  disbursed,
  collecting,
  settled,
  cancelled,
  reversed;

  static AdvanceLifecycleState fromDto(AdvanceState dto) => switch (dto) {
        AdvanceState.submitted => AdvanceLifecycleState.submitted,
        AdvanceState.pendingApproval => AdvanceLifecycleState.pendingApproval,
        AdvanceState.approved => AdvanceLifecycleState.approved,
        AdvanceState.rejected => AdvanceLifecycleState.rejected,
        AdvanceState.disbursed => AdvanceLifecycleState.disbursed,
        AdvanceState.collecting => AdvanceLifecycleState.collecting,
        AdvanceState.settled => AdvanceLifecycleState.settled,
        AdvanceState.cancelled => AdvanceLifecycleState.cancelled,
        AdvanceState.reversed => AdvanceLifecycleState.reversed,
      };

  String get arabicLabel => switch (this) {
        AdvanceLifecycleState.submitted => 'تم التقديم',
        AdvanceLifecycleState.pendingApproval => 'قيد الاعتماد',
        AdvanceLifecycleState.approved => 'معتمدة',
        AdvanceLifecycleState.rejected => 'مرفوضة',
        AdvanceLifecycleState.disbursed => 'تم الصرف',
        AdvanceLifecycleState.collecting => 'قيد السداد',
        AdvanceLifecycleState.settled => 'تمت التسوية',
        AdvanceLifecycleState.cancelled => 'ملغاة',
        AdvanceLifecycleState.reversed => 'مسترجعة',
      };
}

class AdvanceEntity {
  final String id;
  final String employeeId;
  final MoneyEntity principal;
  final MoneyEntity postedAmount;
  final MoneyEntity remainingBalance;
  final AdvanceLifecycleState state;
  final String approvalStage;
  final List<AdvanceApprovalStageEntity> approvalRoute;
  final bool hrReviewed;
  final bool financeReviewed;
  final List<AdvanceScheduleItemEntity> installmentSchedule;
  final int revision;

  const AdvanceEntity({
    required this.id,
    required this.employeeId,
    required this.principal,
    required this.postedAmount,
    required this.remainingBalance,
    required this.state,
    this.approvalStage = 'hr_review',
    this.approvalRoute = const [],
    this.hrReviewed = false,
    this.financeReviewed = false,
    this.installmentSchedule = const [],
    required this.revision,
  });

  factory AdvanceEntity.fromDto(AdvanceDto dto) => AdvanceEntity(
        id: dto.id,
        employeeId: dto.employeeId,
        principal: MoneyEntity.fromDto(dto.principal),
        postedAmount: MoneyEntity.fromDto(dto.postedAmount),
        remainingBalance: MoneyEntity.fromDto(dto.remainingBalance),
        state: AdvanceLifecycleState.fromDto(dto.state),
        approvalStage: dto.approvalStage,
        approvalRoute:
            ((dto.approvalRoute['stages'] as List<dynamic>?) ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(AdvanceApprovalStageEntity.fromJson)
                .toList(),
        hrReviewed: dto.hrReviewed,
        financeReviewed: dto.financeReviewed,
        installmentSchedule: dto.installmentSchedule
            .map(AdvanceScheduleItemEntity.fromDto)
            .toList(),
        revision: dto.revision,
      );
}

class AdvanceApprovalStageEntity {
  final int position;
  final String role;

  const AdvanceApprovalStageEntity(
      {required this.position, required this.role});

  factory AdvanceApprovalStageEntity.fromJson(Map<String, dynamic> json) =>
      AdvanceApprovalStageEntity(
        position: json['position'] as int? ?? 0,
        role: json['role'] as String? ?? '',
      );

  String get arabicLabel => switch (role) {
        'hr' => 'مراجعة الموارد البشرية',
        'finance' => 'اعتماد الإدارة المالية',
        _ => 'مرحلة اعتماد',
      };
}

class AdvancePageEntity {
  final List<AdvanceEntity> items;
  final String? nextCursor;

  const AdvancePageEntity({required this.items, this.nextCursor});
}

class AdvanceScheduleItemEntity {
  final int sequence;
  final String dueDate;
  final MoneyEntity amount;

  const AdvanceScheduleItemEntity({
    required this.sequence,
    required this.dueDate,
    required this.amount,
  });

  factory AdvanceScheduleItemEntity.fromDto(AdvanceScheduleItemDto dto) =>
      AdvanceScheduleItemEntity(
        sequence: dto.sequence,
        dueDate: dto.dueDate,
        amount: MoneyEntity.fromDto(dto.amount),
      );
}

class AdvanceEligibilityPreviewEntity {
  final String evaluationId;
  final String policyVersionId;
  final bool eligible;
  final List<String> reasonCodes;
  final DateTime expiresAt;
  final List<AdvanceScheduleItemEntity> provisionalSchedule;

  const AdvanceEligibilityPreviewEntity({
    required this.evaluationId,
    required this.policyVersionId,
    required this.eligible,
    required this.reasonCodes,
    required this.expiresAt,
    required this.provisionalSchedule,
  });

  factory AdvanceEligibilityPreviewEntity.fromDto(
          AdvanceEligibilityPreviewDto dto) =>
      AdvanceEligibilityPreviewEntity(
        evaluationId: dto.evaluationId,
        policyVersionId: dto.policyVersionId,
        eligible: dto.eligible,
        reasonCodes: dto.reasonCodes,
        expiresAt: dto.expiresAt,
        provisionalSchedule: dto.provisionalSchedule
            .map(AdvanceScheduleItemEntity.fromDto)
            .toList(),
      );

  String get localizedReasonText {
    if (eligible) return 'مؤهل لطلب السلفة';
    if (reasonCodes.isEmpty) return 'غير مؤهل لطلب السلفة وفق سياسة الشركة';
    return reasonCodes
        .map((code) => switch (code) {
              'ADVANCE_INACTIVE_POLICY' => 'سياسة السلف غير مفعلة حالياً',
              'ADVANCE_SERVICE_DAYS_INSUFFICIENT' =>
                'فترة الخدمة أقل من الحد الأدنى المطلوب لطلب سلفة',
              'ADVANCE_ACTIVE_EXISTS' =>
                'لديك سلفة نشطة حالية لم يكتمل سدادها بعد',
              'ADVANCE_AMOUNT_EXCEEDS_CEILING' =>
                'المبلغ المطلوب يتجاوز الحد الأقصى المسموح به',
              'ADVANCE_INSTALLMENT_COUNT_INVALID' =>
                'عدد الأقساط غير مطابق للسياسة المعتمدة',
              _ => code,
            })
        .join('\n');
  }
}
