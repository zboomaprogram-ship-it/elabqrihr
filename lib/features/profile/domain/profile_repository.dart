import 'package:attend_mobile/features/profile/domain/profile_models.dart';

abstract class ProfileRepository {
  Future<UserProfile> getMyProfile();
  Future<UserProfile> updatePreferences(UserPreferences preferences);
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<List<AccountSession>> getActiveSessions();
  Future<void> revokeSession(String sessionId);
}
