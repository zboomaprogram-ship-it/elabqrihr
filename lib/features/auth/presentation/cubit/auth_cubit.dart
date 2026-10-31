import 'package:bloc/bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/core/network/background_sync_coordinator.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final InstallationIdentityPort? _installationIdentity;
  final BackgroundSyncSessionLifecycle? _backgroundSyncCoordinator;

  AuthCubit(this._authRepository,
      {InstallationIdentityPort? installationIdentity,
      BackgroundSyncSessionLifecycle? backgroundSyncCoordinator})
      : _installationIdentity = installationIdentity,
        _backgroundSyncCoordinator = backgroundSyncCoordinator,
        super(const AuthInitial());

  Future<void> _scheduleBackgroundSync(AuthSessionEntity session) async {
    final coordinator = _backgroundSyncCoordinator;
    if (coordinator == null) return;
    try {
      await coordinator.onSessionAuthenticated(
        tenantId: session.tenantId,
        userId: session.userId,
      );
    } catch (_) {}
  }

  Future<void> checkSession() async {
    if (isClosed) return;
    emit(const AuthRestoringSession());
    try {
      final session = await _authRepository.getCachedSession();
      if (isClosed) return;
      if (session != null) {
        // Attempt to refresh session with server if refresh token exists
        if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
          try {
            final refreshed = await _authRepository.refreshSession();
            if (isClosed) return;
            emit(Authenticated(refreshed));
            await _scheduleBackgroundSync(refreshed);
            return;
          } catch (e) {
            final failure = AppFailureMapper.fromGeneric(e);
            if (failure is AuthFailure) {
              // Server rejected the session; clear local stale cache
              await _authRepository.logout();
              if (isClosed) return;
              emit(const Unauthenticated());
              return;
            }
            // Network offline or temporary error: continue with cached session for offline work
          }
        }
        emit(Authenticated(session));
        await _scheduleBackgroundSync(session);
      } else {
        emit(const Unauthenticated());
      }
    } catch (e) {
      if (isClosed) return;
      emit(AuthError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) async {
    if (isClosed) return;
    emit(const AuthLoading());
    try {
      String? protectedInstallationId = deviceInstallationId;
      if (protectedInstallationId == null && _installationIdentity != null) {
        try {
          protectedInstallationId =
              (await _installationIdentity.ensureInstallation()).id;
        } on AttendanceTrustUnavailableException {
          // Login stays available. Attendance remains policy-gated until its
          // protected installation evidence can be collected.
        }
      }
      final session = await _authRepository.login(
        email: email,
        password: password,
        tenantSlug: tenantSlug,
        deviceInstallationId: protectedInstallationId,
      );
      if (isClosed) return;
      emit(Authenticated(session));
      await _scheduleBackgroundSync(session);
    } catch (e) {
      if (isClosed) return;
      emit(AuthError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> logout() async {
    if (isClosed) return;
    emit(const AuthLoading());
    AuthSessionEntity? currentSession;
    try {
      currentSession = await _authRepository.getCachedSession();
    } catch (_) {}
    if (currentSession != null) {
      try {
        await _backgroundSyncCoordinator?.onSessionRevoked(
          tenantId: currentSession.tenantId,
          userId: currentSession.userId,
        );
      } catch (_) {}
    }
    try {
      await _authRepository.logout();
    } catch (_) {}
    if (isClosed) return;
    emit(const Unauthenticated());
  }

  void expireSession() {
    if (isClosed) return;
    emit(const Unauthenticated());
  }
}
