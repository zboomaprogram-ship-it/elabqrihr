import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';

/// Self-service advance repository. Scoped to the authenticated employee.
/// Never approves, disburses, or calculates balances client-side.
abstract class AdvanceRepository {
  /// Returns a cursor-paginated page of the authenticated employee's advances.
  /// Throws [AdvanceAccessDeniedException] on 403.
  Future<AdvancePageEntity> listMyAdvances({
    String? cursor,
    int limit = 25,
    String? state,
  });
}

/// Port for checking employee advance eligibility and submitting advance requests.
abstract class AdvanceEligibilityRepository {
  /// Previews advance eligibility and provisional installment schedule without side effects.
  Future<AdvanceEligibilityPreviewEntity> previewEligibility({
    required MoneyEntity amount,
    required int installmentCount,
  });

  /// Submits an employee advance request.
  Future<AdvanceEntity> submitAdvanceRequest({
    required String commandId,
    required MoneyEntity principal,
    required MoneyEntity installmentAmount,
    required String reason,
    List<String> attachmentIds = const [],
    String? eligibilityEvaluationId,
    int? installmentCount,
  });
}

class AdvanceAccessDeniedException implements Exception {
  const AdvanceAccessDeniedException();
  @override
  String toString() => 'AdvanceAccessDeniedException';
}
