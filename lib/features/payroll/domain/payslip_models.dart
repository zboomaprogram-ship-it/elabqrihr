// Domain models for self-service payslips (Feature 006, T032-T033).
// These map from DTO types and are the only payroll types visible in
// presentation and domain layers. Never expose raw amounts as numbers;
// always carry them as the server-formatted string.

import 'package:attend_mobile/core/api/generated/contract_types.dart';

enum PayslipState {
  queued,
  ready,
  failed,
  expired;

  static PayslipState fromDto(PayslipDocumentState dto) => switch (dto) {
        PayslipDocumentState.ready => PayslipState.ready,
        PayslipDocumentState.failed => PayslipState.failed,
        PayslipDocumentState.expired => PayslipState.expired,
        _ => PayslipState.queued,
      };

  bool get isDocumentAvailable => this == PayslipState.ready;
}

enum PayslipLineKind {
  earning,
  deduction,
  adjustment,
  installment,
  rounding;

  static PayslipLineKind fromDto(PayrollLineKind dto) => switch (dto) {
        PayrollLineKind.earning => PayslipLineKind.earning,
        PayrollLineKind.deduction => PayslipLineKind.deduction,
        PayrollLineKind.adjustment => PayslipLineKind.adjustment,
        PayrollLineKind.installment => PayslipLineKind.installment,
        PayrollLineKind.rounding => PayslipLineKind.rounding,
      };
}

/// Server-formatted money. The [amount] string comes from the server verbatim.
/// Never parse, round, or compute with this value.
class MoneyEntity {
  final String currency;
  final String amount;

  const MoneyEntity({required this.currency, required this.amount});

  factory MoneyEntity.fromDto(MoneyDto dto) =>
      MoneyEntity(currency: dto.currency, amount: dto.amount);

  String get display => '$amount $currency';
}

class PayslipLineEntity {
  final String id;
  final PayslipLineKind kind;
  final String code;
  final MoneyEntity amount;

  const PayslipLineEntity({
    required this.id,
    required this.kind,
    required this.code,
    required this.amount,
  });

  factory PayslipLineEntity.fromDto(PayrollLineDto dto) => PayslipLineEntity(
        id: dto.id,
        kind: PayslipLineKind.fromDto(dto.kind),
        code: dto.code,
        amount: MoneyEntity.fromDto(dto.amount),
      );
}

/// Summary shown in the payslip list. Contains no download URL or lines.
class PayslipSummaryEntity {
  final String id;
  final String cycleKey;
  final MoneyEntity gross;
  final MoneyEntity deductions;
  final MoneyEntity net;
  final DateTime issuedAt;
  final PayslipState documentState;

  const PayslipSummaryEntity({
    required this.id,
    required this.cycleKey,
    required this.gross,
    required this.deductions,
    required this.net,
    required this.issuedAt,
    required this.documentState,
  });

  factory PayslipSummaryEntity.fromDto(PayslipSummaryDto dto) =>
      PayslipSummaryEntity(
        id: dto.id,
        cycleKey: dto.cycleKey,
        gross: MoneyEntity.fromDto(dto.gross),
        deductions: MoneyEntity.fromDto(dto.deductions),
        net: MoneyEntity.fromDto(dto.net),
        issuedAt: dto.issuedAt,
        documentState: PayslipState.fromDto(dto.documentState),
      );
}

/// Full payslip detail including period, lines, and conditional download URL.
/// [downloadUrl] is only non-null when [documentState] is [PayslipState.ready]
/// and must not be retained after a 403/404 response or logout.
class PayslipEntity extends PayslipSummaryEntity {
  final String periodStart;
  final String periodEnd;
  final List<PayslipLineEntity> lines;
  final String? downloadUrl;
  final DateTime? downloadExpiresAt;

  const PayslipEntity({
    required super.id,
    required super.cycleKey,
    required super.gross,
    required super.deductions,
    required super.net,
    required super.issuedAt,
    required super.documentState,
    required this.periodStart,
    required this.periodEnd,
    required this.lines,
    this.downloadUrl,
    this.downloadExpiresAt,
  });

  factory PayslipEntity.fromDto(PayslipDto dto) => PayslipEntity(
        id: dto.id,
        cycleKey: dto.cycleKey,
        gross: MoneyEntity.fromDto(dto.gross),
        deductions: MoneyEntity.fromDto(dto.deductions),
        net: MoneyEntity.fromDto(dto.net),
        issuedAt: dto.issuedAt,
        documentState: PayslipState.fromDto(dto.documentState),
        periodStart: dto.periodStart,
        periodEnd: dto.periodEnd,
        lines: dto.lines.map(PayslipLineEntity.fromDto).toList(),
        downloadUrl: dto.downloadUrl,
        downloadExpiresAt: dto.downloadExpiresAt,
      );
}

class PayslipPageEntity {
  final List<PayslipSummaryEntity> items;
  final String? nextCursor;

  const PayslipPageEntity({required this.items, this.nextCursor});
}
