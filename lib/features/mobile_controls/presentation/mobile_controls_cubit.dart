import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_repository.dart';
import 'package:attend_mobile/features/mobile_controls/presentation/mobile_controls_state.dart';

class MobileControlsCubit extends Cubit<MobileControlsState> {
  final MobileControlsRepository _repository;
  final int currentBuildNumber;

  MobileControlsCubit({
    required MobileControlsRepository repository,
    this.currentBuildNumber = 19,
  })  : _repository = repository,
        super(MobileControlsInitial());

  static const Map<MobileControlKey, String> defaultActionMessagesAr = {
    MobileControlKey.requestsSubmit:
        'إرسال الطلبات متوقف مؤقتاً للصيانة. حاول مرة أخرى قريباً.',
    MobileControlKey.attendanceSubmit:
        'تسجيل الحضور متوقف مؤقتاً للصيانة. لم يُرسل أي حضور. حاول مرة أخرى قريباً.',
    MobileControlKey.advancesSubmit:
        'طلب السلفة متوقف مؤقتاً للصيانة. حاول مرة أخرى قريباً.',
    MobileControlKey.passwordRecovery:
        'استعادة كلمة المرور متوقفة مؤقتاً للصيانة. حاول مرة أخرى قريباً.',
    MobileControlKey.notificationsRegistration:
        'تفعيل الإشعارات متوقف مؤقتاً للصيانة. حاول مرة أخرى قريباً.',
  };

  Future<void> loadConfiguration({bool forceRefresh = false}) async {
    emit(MobileControlsLoading(
      configuration: state.configuration,
      isUpdateRequired: state.isUpdateRequired,
      isUpdateRecommended: state.isUpdateRecommended,
    ));

    try {
      final config = await _repository.getConfiguration(
        forceRefresh: forceRefresh,
      );
      final updateReq = config.buildPolicy.isUpdateRequired(currentBuildNumber);
      final updateRec =
          config.buildPolicy.isUpdateRecommended(currentBuildNumber);

      emit(MobileControlsLoaded(
        configuration: config,
        isUpdateRequired: updateReq,
        isUpdateRecommended: updateRec,
      ));
    } catch (_) {
      // Safe fallback to current configuration with informative state
      emit(MobileControlsLoaded(
        configuration: state.configuration,
        isUpdateRequired: state.isUpdateRequired,
        isUpdateRecommended: state.isUpdateRecommended,
      ));
    }
  }

  /// Synchronously evaluates whether a protected mobile command is allowed
  /// according to the current operational configuration and build policy.
  MobileActionGuardDecision evaluateAction(MobileControlKey key) {
    if (state.isUpdateRequired) {
      return UpdateRequired(
        minimumBuild: state.configuration.buildPolicy.minimumBuild,
        currentBuild: currentBuildNumber,
      );
    }

    final entry = state.configuration.getControl(key);
    if (entry == null) {
      return const ActionAllowed();
    }

    final fallbackMessage = defaultActionMessagesAr[key] ??
        'هذه الخدمة متوقفة مؤقتاً للصيانة. حاول مرة أخرى قريباً.';
    final effectiveMessage =
        (entry.messageAr != null && entry.messageAr!.trim().isNotEmpty)
            ? entry.messageAr!.trim()
            : fallbackMessage;

    return switch (entry.state) {
      MobileControlState.normal => const ActionAllowed(),
      MobileControlState.maintenance => ActionMaintenance(
          controlKey: key,
          messageAr: effectiveMessage,
        ),
      MobileControlState.restricted => ActionRestricted(
          controlKey: key,
          messageAr: effectiveMessage,
        ),
    };
  }

  /// Verifies if a notification destination is allowed before navigation.
  bool isDestinationAllowed(MobileAllowedDestination destination) {
    return state.configuration.destinations.contains(destination);
  }
}
