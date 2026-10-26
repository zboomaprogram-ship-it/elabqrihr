import 'package:equatable/equatable.dart';

enum SettlementDocumentState {
  pending,
  ready,
  failed;

  String get arabicLabel => switch (this) {
        SettlementDocumentState.pending => 'قيد المعالجة',
        SettlementDocumentState.ready => 'جاهز للتحميل',
        SettlementDocumentState.failed => 'فشل التوليد (يمكن إعادة المحاولة)',
      };
}

enum SettlementState {
  draft,
  underReview,
  approved,
  published,
  adjusted,
  cancelled;

  String get arabicLabel => switch (this) {
        SettlementState.draft => 'مسودة أولية',
        SettlementState.underReview => 'قيد المراجعة',
        SettlementState.approved => 'معتمدة',
        SettlementState.published => 'منشورة',
        SettlementState.adjusted => 'تمت تسوية لاحقة',
        SettlementState.cancelled => 'ملغاة',
      };
}

enum SettlementLineType {
  earning,
  deduction,
  liability;

  String get arabicLabel => switch (this) {
        SettlementLineType.earning => 'مستحقات',
        SettlementLineType.deduction => 'استقطاعات',
        SettlementLineType.liability => 'التزامات ومتبقيات',
      };
}

class SettlementLineEntity extends Equatable {
  final String category;
  final SettlementLineType type;
  final String description;
  final int amountMinor;
  final String currency;
  final String? ruleReference;
  final String disputeState; // clear, disputed, exception_approved

  const SettlementLineEntity({
    required this.category,
    required this.type,
    required this.description,
    required this.amountMinor,
    required this.currency,
    this.ruleReference,
    required this.disputeState,
  });

  @override
  List<Object?> get props => [
        category,
        type,
        description,
        amountMinor,
        currency,
        ruleReference,
        disputeState,
      ];
}

class SettlementDecisionEntity extends Equatable {
  final int stage;
  final String decision;
  final String actorDisplayName;
  final DateTime decidedAt;

  const SettlementDecisionEntity({
    required this.stage,
    required this.decision,
    required this.actorDisplayName,
    required this.decidedAt,
  });

  @override
  List<Object?> get props => [stage, decision, actorDisplayName, decidedAt];
}

class SettlementStatementEntity extends Equatable {
  final String id;
  final String settlementId;
  final String statementNumber;
  final String statementDigest;
  final DateTime publishedAt;
  final SettlementDocumentState documentState;
  final int earningsMinor;
  final int deductionsMinor;
  final int netMinor;
  final String currency;
  final List<SettlementLineEntity> lines;
  final List<SettlementDecisionEntity> decisions;
  final String? linkedAdjustmentId;

  const SettlementStatementEntity({
    required this.id,
    required this.settlementId,
    required this.statementNumber,
    required this.statementDigest,
    required this.publishedAt,
    required this.documentState,
    required this.earningsMinor,
    required this.deductionsMinor,
    required this.netMinor,
    required this.currency,
    required this.lines,
    required this.decisions,
    this.linkedAdjustmentId,
  });

  @override
  List<Object?> get props => [
        id,
        settlementId,
        statementNumber,
        statementDigest,
        publishedAt,
        documentState,
        earningsMinor,
        deductionsMinor,
        netMinor,
        currency,
        lines,
        decisions,
        linkedAdjustmentId,
      ];
}
