import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository repository;

  ProfileCubit({required this.repository}) : super(const ProfileInitial());

  Future<void> loadProfile() async {
    if (isClosed) return;
    emit(const ProfileLoading());
    try {
      final profile = await repository.getMyProfile();
      if (isClosed) return;
      emit(ProfileLoaded(profile));
    } catch (e) {
      if (isClosed) return;
      emit(ProfileError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> updatePreferences(UserPreferences preferences) async {
    try {
      final updated = await repository.updatePreferences(preferences);
      if (isClosed) return;
      emit(ProfileLoaded(updated));
    } catch (e) {
      if (isClosed) return;
      emit(ProfileError(AppFailureMapper.fromGeneric(e).message));
    }
  }
}
