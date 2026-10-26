import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';

class PayslipRepositoryImpl implements PayslipRepository {
  final ApiClient _api;

  PayslipRepositoryImpl({required ApiClient api}) : _api = api;

  @override
  Future<PayslipPageEntity> listMyPayslips({
    String? cursor,
    int limit = 25,
  }) async {
    try {
      final dto = await _api.listMyPayslips(cursor: cursor, limit: limit);
      return PayslipPageEntity(
        items: dto.items.map(PayslipSummaryEntity.fromDto).toList(),
        nextCursor: dto.nextCursor,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) throw const PayslipAccessDeniedException();
      rethrow;
    }
  }

  @override
  Future<PayslipEntity> getPayslip(String payslipId) async {
    try {
      final dto = await _api.getPayslip(payslipId);
      return PayslipEntity.fromDto(dto);
    } on ApiException catch (e) {
      if (e.statusCode == 403) throw const PayslipAccessDeniedException();
      if (e.statusCode == 404) throw PayslipNotFoundException(payslipId);
      rethrow;
    }
  }
}
