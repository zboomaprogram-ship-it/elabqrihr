import 'dart:async';

import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/widgets/auth_gate.dart';
import 'package:attend_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedAuthRepository implements AuthRepository {
  final Completer<AuthSessionEntity?> session = Completer<AuthSessionEntity?>();

  final Completer<AuthSessionEntity> signIn = Completer<AuthSessionEntity>();

  @override
  Future<AuthSessionEntity?> getCachedSession() => session.future;

  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) =>
      signIn.future;

  @override
  Future<void> logout() async {}

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

void main() {
  testWidgets(
      'startup restoration never mounts the login form before the session is known',
      (tester) async {
    final repository = _DelayedAuthRepository();
    final cubit = AuthCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
        home: BlocProvider<AuthCubit>.value(
            value: cubit, child: const AuthGate())));
    unawaited(cubit.checkSession());
    await tester.pump();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('login_email_field')), findsNothing);
    repository.session.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'login never exposes server settings or logo-tap developer unlock',
      (tester) async {
    final repository = _DelayedAuthRepository();
    repository.session.complete(null);
    final cubit = AuthCubit(repository);
    addTearDown(cubit.close);
    await cubit.checkSession();
    await tester.pumpWidget(MaterialApp(
        home: BlocProvider<AuthCubit>.value(
            value: cubit, child: const AuthGate())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server_settings_button')), findsNothing);
    expect(find.textContaining('الخادم'), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byType(Image).first);
      await tester.pump();
    }
    expect(find.byKey(const Key('server_settings_button')), findsNothing);
    expect(find.textContaining('للمطورين'), findsNothing);
  });

  testWidgets('keeps login fields mounted while authentication is loading',
      (tester) async {
    final repository = _DelayedAuthRepository();
    final cubit = AuthCubit(repository);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthCubit>.value(
          value: cubit,
          child: const AuthGate(),
        ),
      ),
    );

    repository.session.complete(null);
    await cubit.checkSession();
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('login_email_field')), 'employee@example.test');
    unawaited(cubit.login(
        email: 'employee@example.test',
        password: 'secret',
        tenantSlug: 'demo'));
    await tester.pump();

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_button')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(find.text('employee@example.test'), findsOneWidget);
    repository.signIn.completeError(Exception('Synthetic rejected login'));
    await tester.pumpAndSettle();
    expect(find.text('employee@example.test'), findsOneWidget);
  });
}
