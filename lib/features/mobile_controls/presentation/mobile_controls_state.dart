import 'package:equatable/equatable.dart';
import 'package:attend_mobile/features/mobile_controls/domain/mobile_controls_models.dart';

sealed class MobileControlsState extends Equatable {
  final MobileOperationalConfiguration configuration;
  final bool isUpdateRequired;
  final bool isUpdateRecommended;

  const MobileControlsState({
    required this.configuration,
    this.isUpdateRequired = false,
    this.isUpdateRecommended = false,
  });

  @override
  List<Object?> get props => [
        configuration,
        isUpdateRequired,
        isUpdateRecommended,
      ];
}

final class MobileControlsInitial extends MobileControlsState {
  MobileControlsInitial()
      : super(
          configuration: MobileOperationalConfiguration.defaultRestrictive(),
        );
}

final class MobileControlsLoading extends MobileControlsState {
  const MobileControlsLoading({
    required super.configuration,
    super.isUpdateRequired,
    super.isUpdateRecommended,
  });
}

final class MobileControlsLoaded extends MobileControlsState {
  const MobileControlsLoaded({
    required super.configuration,
    super.isUpdateRequired,
    super.isUpdateRecommended,
  });
}

final class MobileControlsError extends MobileControlsState {
  final String messageAr;

  const MobileControlsError({
    required super.configuration,
    required this.messageAr,
    super.isUpdateRequired,
    super.isUpdateRecommended,
  });

  @override
  List<Object?> get props => [...super.props, messageAr];
}

sealed class MobileActionGuardDecision extends Equatable {
  const MobileActionGuardDecision();

  bool get isPermitted => this is ActionAllowed;

  @override
  List<Object?> get props => [];
}

final class ActionAllowed extends MobileActionGuardDecision {
  const ActionAllowed();
}

final class ActionRestricted extends MobileActionGuardDecision {
  final MobileControlKey controlKey;
  final String messageAr;

  const ActionRestricted({
    required this.controlKey,
    required this.messageAr,
  });

  @override
  List<Object?> get props => [controlKey, messageAr];
}

final class ActionMaintenance extends MobileActionGuardDecision {
  final MobileControlKey controlKey;
  final String messageAr;

  const ActionMaintenance({
    required this.controlKey,
    required this.messageAr,
  });

  @override
  List<Object?> get props => [controlKey, messageAr];
}

final class UpdateRequired extends MobileActionGuardDecision {
  final int minimumBuild;
  final int currentBuild;
  final String messageAr;

  const UpdateRequired({
    required this.minimumBuild,
    required this.currentBuild,
    this.messageAr =
        'يتطلب التطبيق تحديثاً للمتابعة. يرجى تثبيت أحدث إصدار من Google Play.',
  });

  @override
  List<Object?> get props => [minimumBuild, currentBuild, messageAr];
}
