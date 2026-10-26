import 'package:equatable/equatable.dart';
import 'package:attend_mobile/features/auth/domain/auth_models.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Initial or background session restoration, distinct from interactive sign-in.
class AuthRestoringSession extends AuthLoading {
  const AuthRestoringSession();
}

class Authenticated extends AuthState {
  final AuthSessionEntity session;

  const Authenticated(this.session);

  @override
  List<Object?> get props => [session];
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
