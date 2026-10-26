import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import '../domain/final_settlement_models.dart';
import '../domain/final_settlement_repository.dart';

class FinalSettlementRepositoryImpl implements FinalSettlementRepository {
  final ApiClient _api;
  FinalSettlementRepositoryImpl({required ApiClient api}) : _api = api;

  @override
  Future<SettlementStatementEntity?> getLatestStatement() async {
    final response = await _api.dio.get<Map<String, dynamic>>(
      '/final-settlements',
      queryParameters: const {'limit': 1},
    );
    final items = (response.data?['items'] as List<dynamic>? ?? const []);
    if (items.isEmpty) return null;
    final id = (items.first as Map<String, dynamic>)['id'] as String;
    return getStatement(id);
  }

  @override
  Future<SettlementStatementEntity> getStatement(String settlementId) async {
    final response = await _api.dio
        .get<Map<String, dynamic>>('/final-settlements/$settlementId');
    return _fromDetail(response.data ?? const {}, settlementId);
  }

  @override
  Future<String> downloadPrivateDocument(String settlementId) async {
    final response = await _api.dio.get<List<int>>(
      '/final-settlements/$settlementId/document',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) throw StateError('DOCUMENT_EMPTY');
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/final-settlement-$settlementId.html');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

SettlementStatementEntity _fromDetail(
    Map<String, dynamic> json, String settlementId) {
  final publication = json['publication'] as Map<String, dynamic>?;
  if (publication == null) throw StateError('SETTLEMENT_NOT_PUBLISHED');
  final revisions = json['revisions'] as List<dynamic>? ?? const [];
  if (revisions.isEmpty) throw StateError('SETTLEMENT_REVISION_MISSING');
  final revision = revisions.first as Map<String, dynamic>;
  final currency = revision['currency'] as String? ?? '';
  final lines = (revision['lines'] as List<dynamic>? ?? const []).map((raw) {
    final line = raw as Map<String, dynamic>;
    final kind = line['kind'] as String?;
    return SettlementLineEntity(
      category: line['code'] as String? ?? 'settlement_line',
      type: kind == 'earning'
          ? SettlementLineType.earning
          : SettlementLineType.deduction,
      description: _lineLabel(line['code'] as String?),
      amountMinor: (line['amountMinor'] as num?)?.toInt() ?? 0,
      currency: currency,
      ruleReference: line['ruleReference'] as String?,
      disputeState: line['disputeState'] as String? ?? 'clear',
    );
  }).toList(growable: false);
  final decisions =
      (json['decisions'] as List<dynamic>? ?? const []).map((raw) {
    final decision = raw as Map<String, dynamic>;
    return SettlementDecisionEntity(
      stage: (decision['stage'] as num?)?.toInt() ?? 0,
      decision: decision['decision'] as String? ?? '',
      actorDisplayName: 'مراجع معتمد',
      decidedAt: DateTime.parse(decision['decidedAt'] as String),
    );
  }).toList(growable: false);
  final adjustments = json['adjustments'] as List<dynamic>? ?? const [];
  return SettlementStatementEntity(
    id: publication['id'] as String? ?? settlementId,
    settlementId: settlementId,
    statementNumber: publication['statementNumber'] as String? ?? '',
    statementDigest: publication['statementDigest'] as String? ?? '',
    publishedAt: DateTime.parse(publication['publishedAt'] as String),
    documentState: switch (publication['documentState']) {
      'ready' => SettlementDocumentState.ready,
      'failed' => SettlementDocumentState.failed,
      _ => SettlementDocumentState.pending,
    },
    earningsMinor: (revision['earningsMinor'] as num?)?.toInt() ?? 0,
    deductionsMinor: (revision['deductionsMinor'] as num?)?.toInt() ?? 0,
    netMinor: (revision['netMinor'] as num?)?.toInt() ?? 0,
    currency: currency,
    lines: lines,
    decisions: decisions,
    linkedAdjustmentId: adjustments.isEmpty
        ? null
        : (adjustments.last as Map<String, dynamic>)['id'] as String?,
  );
}

String _lineLabel(String? code) => switch (code) {
      'statutory_gratuity' => 'مكافأة نهاية الخدمة',
      'leave_liquidation' => 'المقابل النقدي لرصيد الإجازات',
      'unpaid_earnings' => 'مستحقات غير مصروفة',
      'notice_earning' => 'بدل مهلة الإخطار',
      'notice_deduction' => 'استقطاع مهلة الإخطار',
      'advance_balance' => 'رصيد السلف المتبقي',
      'documented_liability' => 'التزامات موثقة',
      _ => 'بند المخالصة',
    };
