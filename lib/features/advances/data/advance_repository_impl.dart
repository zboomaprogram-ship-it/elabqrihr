import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

class AdvanceRepositoryImpl
    implements AdvanceRepository, AdvanceEligibilityRepository {
  final ApiClient _api;

  AdvanceRepositoryImpl({required ApiClient api}) : _api = api;

  @override
  Future<AdvancePageEntity> listMyAdvances({
    String? cursor,
    int limit = 25,
    String? state,
  }) async {
    try {
      final dto = await _api.listMyAdvances(
        cursor: cursor,
        limit: limit,
        state: state,
      );
      return AdvancePageEntity(
        items: dto.items.map(AdvanceEntity.fromDto).toList(),
        nextCursor: dto.nextCursor,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 403) throw const AdvanceAccessDeniedException();
      rethrow;
    }
  }

  @override
  Future<AdvanceEligibilityPreviewEntity> previewEligibility({
    required MoneyEntity amount,
    required int installmentCount,
  }) async {
    try {
      final dto = await _api.previewAdvanceEligibility(
        amount: MoneyDto(currency: amount.currency, amount: amount.amount),
        installmentCount: installmentCount,
      );
      return AdvanceEligibilityPreviewEntity.fromDto(dto);
    } on ApiException catch (e) {
      if (e.statusCode == 403) throw const AdvanceAccessDeniedException();
      rethrow;
    }
  }

  @override
  Future<AdvanceEntity> submitAdvanceRequest({
    required String commandId,
    required MoneyEntity principal,
    required MoneyEntity installmentAmount,
    required String reason,
    List<String> attachmentIds = const [],
    String? eligibilityEvaluationId,
    int? installmentCount,
  }) async {
    try {
      final reqDto = CreateAdvanceRequestDto(
        commandId: commandId,
        principal:
            MoneyDto(currency: principal.currency, amount: principal.amount),
        installmentAmount: MoneyDto(
            currency: installmentAmount.currency,
            amount: installmentAmount.amount),
        reason: reason,
        attachmentIds: attachmentIds.isEmpty ? null : attachmentIds,
        eligibilityEvaluationId: eligibilityEvaluationId,
        installmentCount: installmentCount,
      );
      final dto = await _api.submitAdvanceRequest(reqDto);
      return AdvanceEntity.fromDto(dto);
    } on ApiException catch (e) {
      if (e.statusCode == 403) throw const AdvanceAccessDeniedException();
      rethrow;
    }
  }
}
