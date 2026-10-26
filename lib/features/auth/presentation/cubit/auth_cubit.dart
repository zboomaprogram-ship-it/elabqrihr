import 'package:bloc/bloc.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final InstallationIdentityPort? _installationIdentity;

  AuthCubit(this._authRepository,
      {InstallationIdentityPort? installationIdentity})
      : _installationIdentity = installationIdentity,
        super(const AuthInitial());

  Future<void> checkSession() async {
    if (isClosed) return;
    emit(const AuthLoading());
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
    } catch (e) {
      if (isClosed) return;
      emit(AuthError(AppFailureMapper.fromGeneric(e).message));
    }
  }

  Future<void> logout() async {
    if (isClosed) return;
    emit(const AuthLoading());
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
