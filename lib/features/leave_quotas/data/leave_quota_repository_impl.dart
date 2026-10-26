import 'package:attend_mobile/core/api/api_client.dart';
import '../domain/leave_quota_models.dart';
import '../domain/leave_quota_repository.dart';

class LeaveQuotaRepositoryImpl implements LeaveQuotaRepository {
  final ApiClient _apiClient;

  LeaveQuotaRepositoryImpl({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  @override
  Future<List<QuotaBalanceEntity>> getMyBalances() async {
    final rawList = await _apiClient.getMyQuotaBalances();
    return rawList.map((json) => QuotaBalanceEntity.fromJson(json)).toList();
  }
}
