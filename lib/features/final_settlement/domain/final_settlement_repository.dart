import 'final_settlement_models.dart';

abstract class FinalSettlementRepository {
  Future<SettlementStatementEntity?> getLatestStatement();
  Future<SettlementStatementEntity> getStatement(String settlementId);
  Future<String> downloadPrivateDocument(String settlementId);
}
