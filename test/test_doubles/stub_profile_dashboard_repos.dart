import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_models.dart';
import 'package:attend_mobile/features/dashboard/domain/dashboard_repository.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';

class StubProfileRepository implements ProfileRepository {
  UserProfile profile;

  StubProfileRepository({UserRole role = UserRole.employee})
      : profile = UserProfile(
          userId: 'test-user',
          tenantId: 'test-tenant',
          companyName: 'شركة الاختبار',
          displayName: 'مستخدم الاختبار',
          email: 'test@example.com',
          role: role,
        );

  @override
  Future<UserProfile> getMyProfile() async => profile;

  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) async {
    profile = profile.copyWith(
        preferences: preferences, revision: profile.revision + 1);
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  }) async {
    profile = profile.copyWith(
      phone: phone ?? profile.phone,
      secondaryEmail: secondaryEmail ?? profile.secondaryEmail,
      preferences: preferences ?? profile.preferences,
      revision: profile.revision + 1,
    );
    return profile;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<List<AccountSession>> getActiveSessions() async => [];

  @override
  Future<void> revokeSession(String sessionId) async {}
}

class StubDashboardRepository implements DashboardRepository {
  final StubProfileRepository profileRepository;

  StubDashboardRepository({UserRole role = UserRole.employee})
      : profileRepository = StubProfileRepository(role: role);

  @override
  Future<DashboardSummary> getDashboardSummary() async => DashboardSummary(
        profile: profileRepository.profile,
      );
}
