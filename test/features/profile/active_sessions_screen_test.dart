import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/screens/active_sessions_screen.dart';

class _MockSessionsRepo implements ProfileRepository {
  List<AccountSession> sessions;
  String? revokedSessionId;

  _MockSessionsRepo({required this.sessions});

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
  }) =>
      throw UnimplementedError();

  @override
  Future<List<AccountSession>> getActiveSessions() async => sessions;

  @override
  Future<void> revokeSession(String sessionId) async {
    revokedSessionId = sessionId;
    sessions.removeWhere((s) => s.id == sessionId);
  }
}

void main() {
  final now = DateTime.now();
  final sampleSessions = [
    AccountSession(
      id: 'session-current',
      clientType: 'mobile',
      deviceInstallationId: 'inst-1234567890',
      createdAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.add(const Duration(days: 30)),
      current: true,
    ),
    AccountSession(
      id: 'session-remote-web',
      clientType: 'web',
      deviceInstallationId: null,
      createdAt: now.subtract(const Duration(days: 1)),
      expiresAt: now.add(const Duration(days: 7)),
      current: false,
    ),
  ];

  testWidgets('renders active sessions with current session badge',
      (tester) async {
    final repo = _MockSessionsRepo(sessions: List.from(sampleSessions));

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ProfileRepository>.value(
          value: repo,
          child: const ActiveSessionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الجلسات والأجهزة النشطة'), findsOneWidget);
    expect(find.byKey(const Key('current_session_badge')), findsOneWidget);
    expect(find.text('الجلسة الحالية'), findsOneWidget);
    expect(find.textContaining('هاتف محمول'), findsOneWidget);
    expect(find.textContaining('متصفح ويب'), findsOneWidget);
    expect(find.byKey(const Key('revoke_session_session-remote-web')),
        findsOneWidget);
    expect(
        find.byKey(const Key('revoke_session_session-current')), findsNothing);
  });

  testWidgets('revoking remote session shows dialog and revokes on confirm',
      (tester) async {
    final repo = _MockSessionsRepo(sessions: List.from(sampleSessions));

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ProfileRepository>.value(
          value: repo,
          child: const ActiveSessionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap revoke on remote session
    await tester
        .tap(find.byKey(const Key('revoke_session_session-remote-web')));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('إنهاء الجلسة'), findsNWidgets(2)); // Title & button
    expect(find.text('إلغاء'), findsOneWidget);

    // Confirm revocation
    await tester.tap(find.widgetWithText(ElevatedButton, 'إنهاء الجلسة'));
    await tester.pumpAndSettle();

    expect(repo.revokedSessionId, equals('session-remote-web'));
    expect(find.text('تم إنهاء الجلسة المحددة بنجاح.'), findsOneWidget);
  });
}
