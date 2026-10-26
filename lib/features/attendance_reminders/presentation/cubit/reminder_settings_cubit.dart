import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/reminder_coordinator.dart';
import '../../domain/reminder_models.dart';
import '../../domain/reminder_repository.dart';
import '../../domain/reminder_scheduler.dart';

sealed class ReminderSettingsState extends Equatable {
  const ReminderSettingsState();

  @override
  List<Object?> get props => [];
}

final class ReminderSettingsLoading extends ReminderSettingsState {
  const ReminderSettingsLoading();
}

final class ReminderSettingsLoaded extends ReminderSettingsState {
  final ReminderPreferences preferences;
  final bool isSaving;
  final String? feedbackMessage;

  const ReminderSettingsLoaded({
    required this.preferences,
    this.isSaving = false,
    this.feedbackMessage,
  });

  ReminderSettingsLoaded copyWith({
    ReminderPreferences? preferences,
    bool? isSaving,
    String? feedbackMessage,
  }) {
    return ReminderSettingsLoaded(
      preferences: preferences ?? this.preferences,
      isSaving: isSaving ?? this.isSaving,
      feedbackMessage: feedbackMessage,
    );
  }

  @override
  List<Object?> get props => [preferences, isSaving, feedbackMessage];
}

final class ReminderSettingsError extends ReminderSettingsState {
  final String message;

  const ReminderSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReminderSettingsCubit extends Cubit<ReminderSettingsState> {
  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;
  final ReminderCoordinator _coordinator;

  ReminderSettingsCubit({
    required ReminderRepository repository,
    required ReminderScheduler scheduler,
    required ReminderCoordinator coordinator,
  })  : _repository = repository,
        _scheduler = scheduler,
        _coordinator = coordinator,
        super(const ReminderSettingsLoading());

  Future<void> loadSettings() async {
    try {
      emit(const ReminderSettingsLoading());
      final hasPermission = await _scheduler.hasPermission();
      var prefs = await _repository.getPreferences();
      prefs = prefs.copyWith(permissionGranted: hasPermission);
      emit(ReminderSettingsLoaded(preferences: prefs));
    } catch (e) {
      emit(const ReminderSettingsError('تعذر تحميل إعدادات التنبيهات'));
    }
  }

  Future<void> requestPermission() async {
    final state = this.state;
    if (state is! ReminderSettingsLoaded) return;

    try {
      final granted = await _scheduler.requestPermission();
      final updated = state.preferences.copyWith(permissionGranted: granted);
      await _repository.savePreferences(updated);
      emit(state.copyWith(
        preferences: updated,
        feedbackMessage: granted
            ? 'تم تفعيل إذن الإشعارات بنجاح'
            : 'لم يتم منح إذن الإشعارات. يمكنك تفعيله لاحقاً من إعدادات الهاتف.',
      ));
      if (granted) {
        await _coordinator.reconcile();
      }
    } catch (_) {
      emit(state.copyWith(feedbackMessage: 'تعذر طلب إذن الإشعارات'));
    }
  }

  Future<void> toggleShiftStart(bool enabled) async {
    await _updatePreferences((p) => p.copyWith(shiftStartEnabled: enabled));
  }

  Future<void> setShiftStartLeadMinutes(int minutes) async {
    await _updatePreferences((p) => p.copyWith(shiftStartLeadMinutes: minutes));
  }

  Future<void> toggleCheckout(bool enabled) async {
    await _updatePreferences((p) => p.copyWith(checkoutEnabled: enabled));
  }

  Future<void> togglePermissionReturn(bool enabled) async {
    await _updatePreferences(
        (p) => p.copyWith(permissionReturnEnabled: enabled));
  }

  Future<void> testNotification() async {
    final state = this.state;
    if (state is! ReminderSettingsLoaded) return;

    try {
      await _scheduler.showTestNotification(
        titleAr: 'تجربة تنبيهات الحضور',
        bodyAr: 'صوت التنبيه يعمل بنجاح وبشكل هادئ وفق إعدادات هاتفك.',
      );
      emit(state.copyWith(feedbackMessage: 'تم إرسال إشعار تجريبي هادئ'));
    } catch (_) {
      emit(state.copyWith(feedbackMessage: 'تعذر إرسال الإشعار التجريبي'));
    }
  }

  Future<void> _updatePreferences(
      ReminderPreferences Function(ReminderPreferences) update) async {
    final state = this.state;
    if (state is! ReminderSettingsLoaded) return;

    final updated = update(state.preferences);
    emit(state.copyWith(preferences: updated, isSaving: true));

    try {
      await _repository.savePreferences(updated);
      emit(state.copyWith(preferences: updated, isSaving: false));
      await _coordinator.reconcile();
    } catch (_) {
      emit(state.copyWith(
        isSaving: false,
        feedbackMessage: 'تعذر حفظ التغييرات محلياً',
      ));
    }
  }
}
