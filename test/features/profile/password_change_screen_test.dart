import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/screens/password_change_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _MockProfileRepo implements ProfileRepository {
  String? lastCurrentPassword;
  String? lastNewPassword;
  bool shouldThrowError = false;

  @override
  Future<UserProfile> getMyProfile() => throw UnimplementedError();

  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) =>
      throw UnimplementedError();

  @override
  Future<UserProfile> updateProfile({
    required int expectedRevision,
    String? phone,
    String? secondaryEmail,
    UserPreferences? preferences,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    if (shouldThrowError) {
      throw Exception('كلمة المرور الحالية غير صحيحة');
    }
  }

  @override
  Future<List<AccountSession>> getActiveSessions() async => [];

  @override
  Future<void> revokeSession(String sessionId) async {}
}

void main() {
  late _MockProfileRepo mockRepo;

  setUp(() {
    mockRepo = _MockProfileRepo();
  });

  Widget buildScreen() {
    return MaterialApp(
      home: RepositoryProvider<ProfileRepository>.value(
        value: mockRepo,
        child: const PasswordChangeScreen(),
      ),
    );
  }

  testWidgets('renders all fields, security notice, and submit button',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('تغيير كلمة المرور'), findsOneWidget);
    expect(find.text('إجراء أمني معتمد'), findsOneWidget);
    expect(find.byKey(const Key('current_password_input')), findsOneWidget);
    expect(find.byKey(const Key('new_password_input')), findsOneWidget);
    expect(find.byKey(const Key('confirm_password_input')), findsOneWidget);
    expect(
        find.byKey(const Key('submit_password_change_button')), findsOneWidget);
  });

  testWidgets('validates required fields and minimum 12 characters',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Tap submit with empty inputs
    await tester
        .ensureVisible(find.byKey(const Key('submit_password_change_button')));
    await tester.tap(find.byKey(const Key('submit_password_change_button')));
    await tester.pumpAndSettle();

    expect(find.text('يرجى إدخال كلمة المرور الحالية'), findsOneWidget);
    expect(find.text('يرجى إدخال كلمة المرور الجديدة'), findsOneWidget);

    // Enter short new password (< 12 characters)
    await tester.enterText(
        find.byKey(const Key('current_password_input')), 'CurrentPass123!');
    await tester.enterText(
        find.byKey(const Key('new_password_input')), 'Short123');
    await tester.enterText(
        find.byKey(const Key('confirm_password_input')), 'Short123');

    await tester
        .ensureVisible(find.byKey(const Key('submit_password_change_button')));
    await tester.tap(find.byKey(const Key('submit_password_change_button')));
    await tester.pumpAndSettle();

    expect(find.text('يجب ألا تقل كلمة المرور الجديدة عن 12 خانة'),
        findsOneWidget);
  });

  testWidgets('validates password mismatch and identical to current',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Identical to current password
    await tester.enterText(
        find.byKey(const Key('current_password_input')), 'SamePassword123!');
    await tester.enterText(
        find.byKey(const Key('new_password_input')), 'SamePassword123!');
    await tester.enterText(
        find.byKey(const Key('confirm_password_input')), 'SamePassword123!');

    await tester
        .ensureVisible(find.byKey(const Key('submit_password_change_button')));
    await tester.tap(find.byKey(const Key('submit_password_change_button')));
    await tester.pumpAndSettle();

    expect(find.text('يجب أن تختلف كلمة المرور الجديدة عن الحالية'),
        findsOneWidget);

    // Mismatched confirmation
    await tester.enterText(
        find.byKey(const Key('new_password_input')), 'BrandNewPassword123!');
    await tester.enterText(find.byKey(const Key('confirm_password_input')),
        'DifferentPassword123!');

    await tester
        .ensureVisible(find.byKey(const Key('submit_password_change_button')));
    await tester.tap(find.byKey(const Key('submit_password_change_button')));
    await tester.pumpAndSettle();

    expect(find.text('كلمة المرور غير متطابقة'), findsOneWidget);
  });

  testWidgets('submits valid password change and pops with success',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('current_password_input')), 'OldPassword123!');
    await tester.enterText(find.byKey(const Key('new_password_input')),
        'BrandNewSecurePassword123!');
    await tester.enterText(find.byKey(const Key('confirm_password_input')),
        'BrandNewSecurePassword123!');

    await tester
        .ensureVisible(find.byKey(const Key('submit_password_change_button')));
    await tester.tap(find.byKey(const Key('submit_password_change_button')));
    await tester.pumpAndSettle();

    expect(mockRepo.lastCurrentPassword, equals('OldPassword123!'));
    expect(mockRepo.lastNewPassword, equals('BrandNewSecurePassword123!'));
  });
}
