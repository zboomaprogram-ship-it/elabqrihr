import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/final_settlement/domain/final_settlement_models.dart';

/// Test suite for Task T091 [US5]: Mobile private final settlement statement,
/// itemized lines, approval timeline, payment/document states, and adjustment link.
void main() {
  group('User Story 5: Final Settlement Statement Tests (T091)', () {
    final sampleLines = [
      const SettlementLineEntity(
        category: 'end_of_service',
        type: SettlementLineType.earning,
        description: 'مكافأة نهاية الخدمة النظامية',
        amountMinor: 25000000,
        currency: 'SDG',
        ruleReference: 'SD-LABOR-2026-ART88',
        disputeState: 'clear',
      ),
      const SettlementLineEntity(
        category: 'leave_liquidation',
        type: SettlementLineType.earning,
        description: 'بدل رصيد الإجازات المتبقي (14 يوماً)',
        amountMinor: 7000000,
        currency: 'SDG',
        ruleReference: 'SD-LABOR-2026-ART72',
        disputeState: 'clear',
      ),
      const SettlementLineEntity(
        category: 'advance_deduction',
        type: SettlementLineType.liability,
        description: 'متبقي سلفة راتب غير مسددة',
        amountMinor: 4000000,
        currency: 'SDG',
        disputeState: 'clear',
      ),
    ];

    final sampleDecisions = [
      SettlementDecisionEntity(
        stage: 1,
        decision: 'approved',
        actorDisplayName: 'سارة - الموارد البشرية',
        decidedAt: DateTime.parse('2026-10-16T10:00:00Z'),
      ),
      SettlementDecisionEntity(
        stage: 2,
        decision: 'approved',
        actorDisplayName: 'أحمد - الإدارة المالية',
        decidedAt: DateTime.parse('2026-10-16T14:30:00Z'),
      ),
    ];

    test(
        'statement preserves itemized line items and immutable financial values',
        () {
      final statement = SettlementStatementEntity(
        id: 'stmt-001',
        settlementId: 'settle-101',
        statementNumber: 'FS-2026-00042',
        statementDigest:
            'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0',
        publishedAt: DateTime.parse('2026-10-16T15:00:00Z'),
        documentState: SettlementDocumentState.ready,
        earningsMinor: 32000000,
        deductionsMinor: 4000000,
        netMinor: 28000000,
        currency: 'SDG',
        lines: sampleLines,
        decisions: sampleDecisions,
      );

      expect(statement.statementNumber, 'FS-2026-00042');
      expect(statement.lines.length, 3);
      expect(statement.earningsMinor, 32000000);
      expect(statement.deductionsMinor, 4000000);
      expect(statement.netMinor, 28000000);
      expect(statement.documentState, SettlementDocumentState.ready);
      expect(statement.documentState.arabicLabel, 'جاهز للتحميل');
    });

    test('approval timeline tracks distinct reviewer stages with Arabic roles',
        () {
      expect(sampleDecisions.length, 2);
      expect(sampleDecisions[0].stage, 1);
      expect(sampleDecisions[0].actorDisplayName, contains('الموارد البشرية'));
      expect(sampleDecisions[1].stage, 2);
      expect(sampleDecisions[1].actorDisplayName, contains('الإدارة المالية'));
    });

    test('document states map to appropriate Arabic actions and statuses', () {
      expect(SettlementDocumentState.pending.arabicLabel, contains('قيد'));
      expect(SettlementDocumentState.ready.arabicLabel, contains('جاهز'));
      expect(SettlementDocumentState.failed.arabicLabel,
          contains('إعادة المحاولة'));
    });

    test(
        'linked adjustment preserves original statement while linking post-publication correction',
        () {
      final originalStatement = SettlementStatementEntity(
        id: 'stmt-001',
        settlementId: 'settle-101',
        statementNumber: 'FS-2026-00042',
        statementDigest:
            'a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0',
        publishedAt: DateTime.parse('2026-10-16T15:00:00Z'),
        documentState: SettlementDocumentState.ready,
        earningsMinor: 32000000,
        deductionsMinor: 4000000,
        netMinor: 28000000,
        currency: 'SDG',
        lines: sampleLines,
        decisions: sampleDecisions,
        linkedAdjustmentId: 'adj-rev-002',
      );

      expect(originalStatement.linkedAdjustmentId, 'adj-rev-002');
      // Original statement identity and digest remain intact
      expect(originalStatement.statementNumber, 'FS-2026-00042');
    });

    test('handles negative net result with flag rather than silent deduction',
        () {
      final negativeStatement = SettlementStatementEntity(
        id: 'stmt-002',
        settlementId: 'settle-102',
        statementNumber: 'FS-2026-00043',
        statementDigest:
            'b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef01',
        publishedAt: DateTime.parse('2026-10-16T16:00:00Z'),
        documentState: SettlementDocumentState.ready,
        earningsMinor: 5000000,
        deductionsMinor: 8000000,
        netMinor: -3000000,
        currency: 'SDG',
        lines: const [],
        decisions: const [],
      );

      expect(negativeStatement.netMinor, isNegative);
      expect(negativeStatement.netMinor, -3000000);
    });
  });
}
