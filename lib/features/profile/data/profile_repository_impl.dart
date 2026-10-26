import 'dart:convert';
import 'package:dio/dio.dart' show DioException;
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/core/database/drift_attendance_database.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final AppDriftDatabase? database;

  UserProfile? _cachedProfile;

  ProfileRepositoryImpl({
    required this.apiClient,
    required this.tokenStorage,
    this.database,
  });

  @override
  Future<UserProfile> getMyProfile() async {
    final session = await tokenStorage.getSession();
    if (session == null) {
      throw const AuthFailure('لا توجد جلسة نشطة لعرض الملف الشخصي');
    }

    try {
      final response = await apiClient.dio.get('/me');
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        _cachedProfile = UserProfile.fromJson(response.data as Map<String, dynamic>);
        if (database != null) {
          try {
            await database!.saveProfile(
              tenantId: session.tenantId,
              userId: session.userId,
              profileJson: jsonEncode(response.data),
            );
          } catch (_) {}
        }
        return _cachedProfile!;
      }
      throw const ServerFailure('استجاب الخادم برمز غير متوقع أثناء استرجاع الملف الشخصي');
    } on DioException catch (e) {
      if (database != null) {
        try {
          final cached = await database!.getCachedProfile(
            tenantId: session.tenantId,
            userId: session.userId,
          );
          if (cached != null) {
            _cachedProfile = UserProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
            return _cachedProfile!;
          }
        } catch (_) {}
      }
      throw AppFailureMapper.fromDio(e);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }

  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) async {
    return updateProfile(
      expectedRevision: _cachedProfile?.revision ?? 1,
      preferences: preferences,
    );
  }

  @override
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  }) async {
    final session = await tokenStorage.getSession();
    if (session == null) {
      throw const AuthFailure('لا توجد جلسة نشطة لتحديث البيانات الشخصية');
    }

    try {
      final response = await apiClient.updateMyProfile(
        expectedRevision: expectedRevision,
        phone: phone,
        secondaryEmail: secondaryEmail,
        preferences: preferences?.toJson(),
      );
      _cachedProfile = UserProfile.fromJson(response);
      if (database != null) {
        try {
          await database!.saveProfile(
            tenantId: session.tenantId,
            userId: session.userId,
            profileJson: jsonEncode(response),
          );
        } catch (_) {}
      }
      return _cachedProfile!;
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await apiClient.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }

  @override
  Future<List<AccountSession>> getActiveSessions() async {
    try {
      final page = await apiClient.listAccountSessions();
      return page.items
          .map((dto) => AccountSession(
                id: dto.id,
                clientType: dto.clientType,
                deviceInstallationId: dto.deviceInstallationId,
                createdAt: dto.createdAt,
                expiresAt: dto.expiresAt,
                current: dto.current,
              ))
          .toList();
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    try {
      await apiClient.revokeAccountSession(sessionId);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AppFailureMapper.fromGeneric(e);
    }
  }
}
