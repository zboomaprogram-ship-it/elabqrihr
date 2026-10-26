import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:attend_mobile/features/dashboard/presentation/cubit/dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository repository;

  DashboardCubit({required this.repository}) : super(const DashboardInitial());

  Future<void> loadDashboard({bool refresh = false}) async {
    if (!refresh && state is DashboardLoaded) return;

    if (isClosed) return;
    emit(const DashboardLoading());
    try {
      final summary = await repository.getDashboardSummary();
      if (isClosed) return;
      emit(DashboardLoaded(summary));
    } catch (e) {
      if (isClosed) return;
      emit(DashboardError(AppFailureMapper.fromGeneric(e).message));
    }
  }
}
