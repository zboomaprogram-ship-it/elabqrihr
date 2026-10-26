import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';

void main() {
  test('notification consent defaults to disabled until explicitly granted',
      () {
    expect(const UserPreferences().notificationsEnabled, isFalse);
    expect(UserPreferences.fromJson(const {}).notificationsEnabled, isFalse);
    expect(
      UserPreferences.fromJson(const {'notificationsEnabled': true})
          .notificationsEnabled,
      isTrue,
    );
  });
}
