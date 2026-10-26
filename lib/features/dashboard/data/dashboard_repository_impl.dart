import 'package:dio/dio.dart' show DioException;
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  DashboardRepositoryImpl({
    required this.apiClient,
    required this.tokenStorage,
  });

  @override
  Future<DashboardSummary> getDashboardSummary() async {
    final session = await tokenStorage.getSession();
    if (session == null) {
      throw const AuthFailure('لا توجد جلسة نشطة لعرض لوحة المعلومات');
    }

    try {
      final response = await apiClient.dio.get('/me/dashboard');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return DashboardSummary.fromJson(response.data as Map<String, dynamic>);
      }
      throw const ServerFailure('استجاب الخادم برمز غير متوقع أثناء استرجاع لوحة المعلومات');
    } on DioException catch (e) {
      throw AppFailureMapper.fromDio(e);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }
}
