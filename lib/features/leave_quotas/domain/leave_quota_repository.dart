import 'leave_quota_models.dart';

abstract class LeaveQuotaRepository {
  Future<List<QuotaBalanceEntity>> getMyBalances();
}
