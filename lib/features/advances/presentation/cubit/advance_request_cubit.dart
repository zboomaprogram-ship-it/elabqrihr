import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'advance_request_state.dart';

class AdvanceRequestCubit extends Cubit<AdvanceRequestState> {
  final AdvanceEligibilityRepository _repository;
  final Uuid _uuid = const Uuid();

  AdvanceRequestCubit({required AdvanceEligibilityRepository repository})
      : _repository = repository,
        super(const AdvanceRequestInitial());

  Future<void> previewEligibility({
    required String amount,
    required int installmentCount,
  }) async {
    if (isClosed) return;
    emit(const AdvanceRequestPreviewing());

    try {
      final money = MoneyEntity(currency: 'SDG', amount: amount);
      final preview = await _repository.previewEligibility(
        amount: money,
        installmentCount: installmentCount,
      );

      if (isClosed) return;
      emit(AdvanceRequestPreviewLoaded(
        preview: preview,
        requestedAmount: amount,
        installmentCount: installmentCount,
      ));
    } on AdvanceAccessDeniedException {
      if (isClosed) return;
      emit(const AdvanceRequestError(
        message: 'ليس لديك صلاحية الوصول إلى طلبات السلف المالية.',
        isDenied: true,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      emit(AdvanceRequestError(message: failure.message));
    }
  }

  Future<void> submitAdvance({
    required String reason,
    String? clientCommandId,
  }) async {
    final current = state;
    if (current is! AdvanceRequestPreviewLoaded) {
      emit(const AdvanceRequestError(
        message: 'يرجى إجراء معاينة الأهلية أولاً قبل تقديم الطلب.',
      ));
      return;
    }

    if (!current.preview.eligible) {
      emit(AdvanceRequestError(
        message: current.preview.localizedReasonText,
      ));
      return;
    }

    if (current.preview.provisionalSchedule.isEmpty) {
      emit(const AdvanceRequestError(
        message: 'لا يوجد جدول أقساط مؤقت متاح لهذا الطلب.',
      ));
      return;
    }

    emit(const AdvanceRequestSubmitting());

    final commandId = clientCommandId ?? _uuid.v4();
    final principal =
        MoneyEntity(currency: 'SDG', amount: current.requestedAmount);
    final installmentAmount = current.preview.provisionalSchedule.first.amount;

    try {
      final advance = await _repository.submitAdvanceRequest(
        commandId: commandId,
        principal: principal,
        installmentAmount: installmentAmount,
        reason: reason,
        eligibilityEvaluationId: current.preview.evaluationId,
        installmentCount: current.installmentCount,
      );

      if (isClosed) return;
      emit(AdvanceRequestSuccess(advance: advance));
    } on AdvanceAccessDeniedException {
      if (isClosed) return;
      emit(const AdvanceRequestError(
        message: 'تم رفض طلب السلفة: غير مصرح لهذا الموظف.',
        isDenied: true,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailureMapper.fromGeneric(e);
      final isConflict = failure is ConflictFailure;
      emit(AdvanceRequestError(
        message: failure.message,
        isConflict: isConflict,
      ));
    }
  }

  void reset() {
    emit(const AdvanceRequestInitial());
  }
}
