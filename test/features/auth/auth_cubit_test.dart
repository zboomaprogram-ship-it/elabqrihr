import 'package:test/test.dart';
import 'package:attend_mobile/core/network/background_sync_coordinator.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_state.dart';

class FakeAuthRepository implements AuthRepository {
  AuthSessionEntity? _session;

  @override
  Future<AuthSessionEntity?> getCachedSession() async => _session;

  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async {
    if (password == 'wrong') {
      throw Exception('Invalid credentials');
    }
    _session = const AuthSessionEntity(
      accessToken: 'test-token',
      refreshToken: 'test-refresh',
      tenantId: 'tenant-1',
      userId: 'user-1',
      role: UserRole.employee,
      email: 'employee@attend.app',
      displayName: 'أحمد محمود',
    );
    return _session!;
  }

  @override
  Future<void> logout() async {
    _session = null;
  }

  @override
  Future<AuthSessionEntity> refreshSession() async {
    if (_session == null) throw Exception('No session');
    return _session!;
  }

  @override
  Future<void> requestPasswordReset(
          {required String email, required String tenantSlug}) async =>
      throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset(
          {required String resetToken, required String newPassword}) async =>
      throw UnimplementedError();
}

class FakeBackgroundSyncLifecycle implements BackgroundSyncSessionLifecycle {
  final scheduled = <(String, String)>[];
  final revoked = <(String, String)>[];

  @override
  Future<void> onSessionAuthenticated({
    required String tenantId,
    required String userId,
  }) async {
    scheduled.add((tenantId, userId));
  }

  @override
  Future<void> onSessionRevoked({
    required String tenantId,
    required String userId,
  }) async {
    revoked.add((tenantId, userId));
  }
}

void main() {
  group('AuthCubit', () {
    late FakeAuthRepository authRepository;
    late FakeBackgroundSyncLifecycle backgroundSync;
    late AuthCubit authCubit;

    setUp(() {
      authRepository = FakeAuthRepository();
      backgroundSync = FakeBackgroundSyncLifecycle();
      authCubit = AuthCubit(
        authRepository,
        backgroundSyncCoordinator: backgroundSync,
      );
    });

    tearDown(() {
      authCubit.close();
    });

    test('initial state is AuthInitial', () {
      expect(authCubit.state, equals(const AuthInitial()));
    });

    test('checkSession emits Unauthenticated when no cached session exists',
        () async {
      expectLater(
        authCubit.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Unauthenticated>(),
        ]),
      );
      await authCubit.checkSession();
    });

    test('login with valid credentials emits Authenticated', () async {
      expectLater(
        authCubit.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<Authenticated>(),
        ]),
      );
      await authCubit.login(
        email: 'employee@attend.app',
        password: 'secret',
        tenantSlug: 'alpha',
      );
      expect((authCubit.state as Authenticated).session.displayName,
          equals('أحمد محمود'));
      expect(backgroundSync.scheduled, [('tenant-1', 'user-1')]);
    });

    test('login failure emits AuthError', () async {
      expectLater(
        authCubit.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthError>(),
        ]),
      );
      await authCubit.login(
        email: 'employee@attend.app',
        password: 'wrong',
        tenantSlug: 'alpha',
      );
    });

    test('logout transitions to Unauthenticated', () async {
      await authCubit.login(
        email: 'employee@attend.app',
        password: 'secret',
        tenantSlug: 'alpha',
      );
      expect(authCubit.state, isA<Authenticated>());

      await authCubit.logout();
      expect(authCubit.state, isA<Unauthenticated>());
      expect(backgroundSync.revoked, [('tenant-1', 'user-1')]);
    });

    test('session restore reschedules background work for cached identity',
        () async {
      await authCubit.login(
        email: 'employee@attend.app',
        password: 'secret',
        tenantSlug: 'alpha',
      );
      backgroundSync.scheduled.clear();

      await authCubit.checkSession();

      expect(backgroundSync.scheduled, [('tenant-1', 'user-1')]);
    });
  });
}
