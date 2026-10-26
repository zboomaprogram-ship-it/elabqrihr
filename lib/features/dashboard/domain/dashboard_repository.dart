import 'package:attend_mobile/features/dashboard/domain/dashboard_models.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getDashboardSummary();
}
