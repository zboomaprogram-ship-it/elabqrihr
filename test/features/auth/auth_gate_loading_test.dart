import 'dart:async';

import 'package:attend_mobile/features/auth/domain/auth_models.dart';
import 'package:attend_mobile/features/auth/domain/auth_repository.dart';
import 'package:attend_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:attend_mobile/features/auth/presentation/widgets/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedAuthRepository implements AuthRepository {
  final Completer<AuthSessionEntity?> session = Completer<AuthSessionEntity?>();

  @override
  Future<AuthSessionEntity?> getCachedSession() => session.future;

  @override
  Future<AuthSessionEntity> login({
    required String email,
    required String password,
    required String tenantSlug,
    String? deviceInstallationId,
  }) =>
      throw UnimplementedError();

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

    unawaited(cubit.checkSession());
    await tester.pump();

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_button')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.session.complete(null);
    await tester.pumpAndSettle();
  });
}
