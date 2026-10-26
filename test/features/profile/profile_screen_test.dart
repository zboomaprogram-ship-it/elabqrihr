import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/auth/token_storage.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/profile/domain/profile_models.dart';
import 'package:attend_mobile/features/profile/domain/profile_repository.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:attend_mobile/features/profile/presentation/cubit/profile_state.dart';
import 'package:attend_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:attend_mobile/core/localization/language_cubit.dart';

class _FakeAuthRepo implements AuthRepository {
  final AuthSessionEntity session;
  bool loggedOut = false;

  _FakeAuthRepo(this.session);

  @override
  Future<AuthSessionEntity?> getCachedSession() async => session;
  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async =>
      session;
  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<AuthSessionEntity> refreshSession() => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class _FakeProfileRepo implements ProfileRepository {
  UserProfile profile;
  Object? loadError;
  Object? updateError;
  int loadCalls = 0;
  UserPreferences? updatedPreferences;

  _FakeProfileRepo(this.profile);

  @override
  Future<UserProfile> getMyProfile() async {
    loadCalls += 1;
    if (loadError != null) throw loadError!;
    return profile;
  }

  @override
  Future<UserProfile> updatePreferences(UserPreferences preferences) async {
    if (updateError != null) throw updateError!;
    updatedPreferences = preferences;
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
    if (updateError != null) throw updateError!;
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

void main() {
  group('ProfileScreen Tests (US3)', () {
    const session = AuthSessionEntity(
      accessToken: 'token',
      tenantId: 'acme-corp',
      userId: 'emp-101',
      role: UserRole.employee,
      email: 'sara@acme.com',
      displayName: 'سارة خالد',
    );

    const profile = UserProfile(
      userId: 'emp-101',
      tenantId: 'acme-corp',
      companyName: 'شركة أكمي',
      displayName: 'سارة خالد',
      email: 'sara@acme.com',
      role: UserRole.employee,
      branchName: 'فرع القاهرة',
      managerName: 'أحمد علي',
      revision: 3,
    );

    Widget buildSubject({required _FakeProfileRepo profileRepo}) {
      final fakeAuthRepo = _FakeAuthRepo(session);
      final authCubit = AuthCubit(fakeAuthRepo)..checkSession();
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ApiClient>.value(
            value: ApiClient(
                baseUrl: 'http://localhost:3000/api/v1',
                tokenStorage: TokenStorage()),
          ),
          RepositoryProvider<TokenStorage>.value(value: TokenStorage()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<ProfileCubit>(
              create: (_) => ProfileCubit(repository: profileRepo),
            ),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
    }

    testWidgets('Renders identity card, work placement, settings, and logout',
        (tester) async {
      final profileRepo = _FakeProfileRepo(profile);
      await tester.pumpWidget(buildSubject(profileRepo: profileRepo));

      await tester.pumpAndSettle();

      // Displays user info
      expect(find.text('سارة خالد'), findsOneWidget);
      expect(find.text('sara@acme.com'), findsOneWidget);
      expect(find.textContaining('موظف'), findsOneWidget);
      expect(find.text('شركة أكمي'), findsOneWidget);
      expect(find.text('فرع القاهرة'), findsOneWidget);
      expect(find.text('أحمد علي'), findsOneWidget);

      // Displays app settings
      expect(find.textContaining('إعدادات الاتصال بالخادم'), findsNothing);
      expect(find.textContaining('USB / Wi-Fi'), findsNothing);
      expect(find.byIcon(Icons.router), findsNothing);
      expect(find.text('دليل الفترة التجريبية (Pilot)'), findsNothing);

      // Displays logout action
      expect(find.text('تسجيل الخروج من الحساب'), findsOneWidget);
    });

    testWidgets(
        'Tapping logout presents confirmation dialog and logs out on confirm',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeAuthRepo = _FakeAuthRepo(session);
      final authCubit = AuthCubit(fakeAuthRepo)..checkSession();
      final profileCubit = ProfileCubit(repository: _FakeProfileRepo(profile));

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ApiClient>.value(
              value: ApiClient(
                  baseUrl: 'http://localhost:3000/api/v1',
                  tokenStorage: TokenStorage()),
            ),
            RepositoryProvider<TokenStorage>.value(value: TokenStorage()),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<ProfileCubit>.value(value: profileCubit),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap logout
      final logoutFinder = find.text('تسجيل الخروج من الحساب');
      await tester.ensureVisible(logoutFinder);
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('تأكيد تسجيل الخروج'), findsOneWidget);
      expect(
          find.widgetWithText(ElevatedButton, 'تسجيل الخروج'), findsOneWidget);

      // Confirm
      await tester.tap(find.widgetWithText(ElevatedButton, 'تسجيل الخروج'));
      await tester.pumpAndSettle();

      expect(fakeAuthRepo.loggedOut, isTrue);
    });

    testWidgets('renders a safe retryable error without session placeholders',
        (tester) async {
      final profileRepo = _FakeProfileRepo(profile)
        ..loadError = Exception('private-stack-value');
      await tester.pumpWidget(buildSubject(profileRepo: profileRepo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_retry_button')), findsOneWidget);
      expect(find.textContaining('private-stack-value'), findsNothing);
      expect(find.text('شركة أكمي'), findsNothing);
      expect(find.text('ACME-CORP'), findsNothing);
    });

    test(
        'ProfileCubit updates server-issued preferences and preserves returned identity',
        () async {
      final profileRepo = _FakeProfileRepo(profile);
      final cubit = ProfileCubit(repository: profileRepo);
      const preferences =
          UserPreferences(reducedMotion: true, notificationsEnabled: false);

      await cubit.loadProfile();
      await cubit.updatePreferences(preferences);

      expect(profileRepo.updatedPreferences, same(preferences));
      final loaded = cubit.state as ProfileLoaded;
      expect(loaded.profile.userId, 'emp-101');
      expect(loaded.profile.tenantId, 'acme-corp');
      expect(loaded.profile.preferences.reducedMotion, isTrue);
      await cubit.close();
    });

    testWidgets(
        'RoleNavigationPolicy gates financial services for Company Admin while rendering them for Employee',
        (tester) async {
      final empProfile = profile.copyWith(role: UserRole.employee);
      await tester.pumpWidget(KeyedSubtree(
        key: const ValueKey('emp'),
        child: buildSubject(
          profileRepo: _FakeProfileRepo(empProfile),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('الخدمات المالية والرواتب'), findsOneWidget);

      final adminProfile = profile.copyWith(role: UserRole.companyAdmin);
      await tester.pumpWidget(KeyedSubtree(
        key: const ValueKey('admin'),
        child: buildSubject(
          profileRepo: _FakeProfileRepo(adminProfile),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('الخدمات المالية والرواتب'), findsNothing);
    });

    testWidgets(
        'Language preference tile communicates Arabic-only release policy',
        (tester) async {
      final storage = TokenStorage();
      final languageCubit = LanguageCubit(tokenStorage: storage);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LanguageCubit>.value(value: languageCubit),
          ],
          child: buildSubject(
            profileRepo: _FakeProfileRepo(profile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final langTileFinder = find.byKey(const Key('language_preference_tile'));
      await tester.ensureVisible(langTileFinder);
      expect(langTileFinder, findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);

      await tester.tap(langTileFinder);
      await tester.pumpAndSettle();

      expect(find.text('الإنجليزية قريباً'), findsOneWidget);
      expect(languageCubit.state.locale, const Locale('ar'));
    });
  });
}
