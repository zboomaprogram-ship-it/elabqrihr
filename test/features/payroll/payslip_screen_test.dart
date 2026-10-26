// Tests for Feature 006 self-service payslip screens (T032).
// Covers: identity isolation, loading, empty, denied/not-found,
// expired document, queued state, network error, retry, and 200% text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_state.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_state.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_list_screen.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_detail_screen.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _AlwaysDeniedRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips({String? cursor, int limit = 25}) =>
      throw const PayslipAccessDeniedException();
  @override
  Future<PayslipEntity> getPayslip(String id) =>
      throw const PayslipAccessDeniedException();
}

class _NotFoundRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips({String? cursor, int limit = 25}) =>
      throw const PayslipAccessDeniedException();
  @override
  Future<PayslipEntity> getPayslip(String id) =>
      throw PayslipNotFoundException(id);
}

class _NetworkErrorRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips({String? cursor, int limit = 25}) =>
      throw Exception('connection timeout');
  @override
  Future<PayslipEntity> getPayslip(String id) =>
      throw Exception('connection timeout');
}

class _EmptyRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips(
          {String? cursor, int limit = 25}) async =>
      const PayslipPageEntity(items: [], nextCursor: null);
  @override
  Future<PayslipEntity> getPayslip(String id) =>
      throw const PayslipAccessDeniedException();
}

// Produces a fixed list of payslips belonging to employeeId 'emp-A'.
// Used to verify that no other employee's data is shown.
class _EmployeeARepo implements PayslipRepository {
  final String employeeId = 'emp-A';
  _EmployeeARepo();

  static MoneyDto _money(String amt) => MoneyDto(currency: 'SDG', amount: amt);

  PayslipSummaryDto _summary(
          String id, String cycleKey, String net, PayslipDocumentState state) =>
      PayslipSummaryDto(
        id: id,
        cycleKey: cycleKey,
        gross: _money('5000.00'),
        deductions: _money('500.00'),
        net: _money(net),
        issuedAt: DateTime(2026, 9, 1),
        documentState: state,
      );

  @override
  Future<PayslipPageEntity> listMyPayslips(
          {String? cursor, int limit = 25}) async =>
      PayslipPageEntity(
        items: [
          PayslipSummaryEntity.fromDto(_summary(
              'ps-1', '2026-09', '4500.00', PayslipDocumentState.ready)),
          PayslipSummaryEntity.fromDto(_summary(
              'ps-2', '2026-08', '4480.00', PayslipDocumentState.expired)),
          PayslipSummaryEntity.fromDto(_summary(
              'ps-3', '2026-07', '4300.00', PayslipDocumentState.queued)),
        ],
        nextCursor: null,
      );

  @override
  Future<PayslipEntity> getPayslip(String id) async {
    final lineDto = PayrollLineDto(
      id: 'line-1',
      kind: PayrollLineKind.earning,
      code: 'BASIC',
      amount: MoneyDto(currency: 'SDG', amount: '5000.00'),
      sourceType: 'compensation',
      sourceId: 'comp-1',
    );
    final dto = PayslipDto(
      id: id,
      cycleKey: '2026-09',
      gross: _money('5000.00'),
      deductions: _money('500.00'),
      net: _money('4500.00'),
      issuedAt: DateTime(2026, 9, 1),
      documentState: id == 'ps-2'
          ? PayslipDocumentState.expired
          : id == 'ps-3'
              ? PayslipDocumentState.queued
              : PayslipDocumentState.ready,
      employeeId: employeeId,
      periodStart: '2026-09-26',
      periodEnd: '2026-10-25',
      lines: [lineDto],
      downloadUrl: id == 'ps-3' || id == 'ps-2'
          ? null
          : 'https://storage.example.com/payslips/$id.pdf',
      downloadExpiresAt:
          id == 'ps-3' || id == 'ps-2' ? null : DateTime(2026, 10, 1),
    );
    return PayslipEntity.fromDto(dto);
  }
}

// Simulates employee B — completely different identity.
class _EmployeeBRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips(
          {String? cursor, int limit = 25}) async =>
      const PayslipPageEntity(items: [], nextCursor: null);
  @override
  Future<PayslipEntity> getPayslip(String id) =>
      throw const PayslipAccessDeniedException();
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _listHarness(PayslipListCubit cubit) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepositoryProvider<PayslipRepository>(
        create: (_) => _EmployeeARepo(),
        child: BlocProvider<PayslipListCubit>.value(
          value: cubit,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: PayslipListScreen(),
          ),
        ),
      ),
    );

Widget _detailHarness(PayslipDetailCubit cubit, {PayslipRepository? repo}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepositoryProvider<PayslipRepository>(
        create: (_) => repo ?? _EmployeeARepo(),
        child: BlocProvider<PayslipDetailCubit>.value(
          value: cubit,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: PayslipDetailScreen(payslipId: 'ps-1'),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PayslipListScreen', () {
    test('State machine: initial → loading → loaded', () async {
      final cubit = PayslipListCubit(repository: _EmployeeARepo());
      expect(cubit.state, isA<PayslipListInitial>());
      final future = cubit.load();
      expect(cubit.state, isA<PayslipListLoading>());
      await future;
      expect(cubit.state, isA<PayslipListLoaded>());
      final loaded = cubit.state as PayslipListLoaded;
      expect(loaded.items, hasLength(3));
    });

    test('State machine: initial → loading → empty', () async {
      final cubit = PayslipListCubit(repository: _EmptyRepo());
      await cubit.load();
      expect(cubit.state, isA<PayslipListEmpty>());
    });

    test('State machine: initial → loading → denied', () async {
      final cubit = PayslipListCubit(repository: _AlwaysDeniedRepo());
      await cubit.load();
      expect(cubit.state, isA<PayslipListDenied>());
    });

    test('State machine: initial → loading → error on network failure',
        () async {
      final cubit = PayslipListCubit(repository: _NetworkErrorRepo());
      await cubit.load();
      expect(cubit.state, isA<PayslipListError>());
    });

    testWidgets('Loading spinner is shown during load', (tester) async {
      final cubit = PayslipListCubit(repository: _EmptyRepo());
      await tester.pumpWidget(_listHarness(cubit));
      expect(find.byType(RequestListSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Empty state shows correct Arabic message', (tester) async {
      final cubit = PayslipListCubit(repository: _EmptyRepo());
      await tester.pumpWidget(_listHarness(cubit));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد كشوف رواتب بعد'), findsOneWidget);
    });

    testWidgets('Denied state shows access denied message', (tester) async {
      final cubit = PayslipListCubit(repository: _AlwaysDeniedRepo());
      await tester.pumpWidget(_listHarness(cubit));
      await tester.pumpAndSettle();
      expect(find.text('غير مصرح لك بعرض كشوف الرواتب'), findsOneWidget);
    });

    testWidgets('Network error shows retry button', (tester) async {
      final cubit = PayslipListCubit(repository: _NetworkErrorRepo());
      await tester.pumpWidget(_listHarness(cubit));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('payslip_list_retry_button')), findsOneWidget);
    });

    testWidgets('Loaded: shows payslip tiles for employee A only',
        (tester) async {
      final cubit = PayslipListCubit(repository: _EmployeeARepo());
      await tester.pumpWidget(_listHarness(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip_tile_ps-1')), findsOneWidget);
      expect(find.byKey(const Key('payslip_tile_ps-2')), findsOneWidget);
      expect(find.byKey(const Key('payslip_tile_ps-3')), findsOneWidget);
    });

    testWidgets('Identity isolation: employee B sees empty list',
        (tester) async {
      final cubit = PayslipListCubit(repository: _EmployeeBRepo());
      await tester.pumpWidget(_listHarness(cubit));
      await tester.pumpAndSettle();
      // Employee B has no payslips → empty state, no employee A tiles
      expect(find.byKey(const Key('payslip_tile_ps-1')), findsNothing);
      expect(find.text('لا توجد كشوف رواتب بعد'), findsOneWidget);
    });

    testWidgets('200% text scale: denied state renders without overflow',
        (tester) async {
      final cubit = PayslipListCubit(repository: _AlwaysDeniedRepo());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _listHarness(cubit),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('غير مصرح لك بعرض كشوف الرواتب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text scale: payslip list renders without overflow',
        (tester) async {
      final cubit = PayslipListCubit(repository: _EmployeeARepo());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _listHarness(cubit),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip_tile_ps-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PayslipDetailScreen', () {
    test('State machine: denied', () async {
      final cubit = PayslipDetailCubit(repository: _AlwaysDeniedRepo());
      await cubit.load('ps-1');
      expect(cubit.state, isA<PayslipDetailDenied>());
    });

    test('State machine: not found', () async {
      final cubit = PayslipDetailCubit(repository: _NotFoundRepo());
      await cubit.load('ps-missing');
      expect(cubit.state, isA<PayslipDetailNotFound>());
    });

    test('State machine: network error', () async {
      final cubit = PayslipDetailCubit(repository: _NetworkErrorRepo());
      await cubit.load('ps-1');
      expect(cubit.state, isA<PayslipDetailError>());
    });

    test('State machine: loaded with ready document', () async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await cubit.load('ps-1');
      expect(cubit.state, isA<PayslipDetailLoaded>());
      final loaded = cubit.state as PayslipDetailLoaded;
      expect(loaded.payslip.documentState, PayslipState.ready);
      expect(loaded.payslip.downloadUrl, isNotNull);
    });

    test('State machine: loaded with expired document — no download URL',
        () async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await cubit.load('ps-2');
      expect(cubit.state, isA<PayslipDetailLoaded>());
      final loaded = cubit.state as PayslipDetailLoaded;
      expect(loaded.payslip.documentState, PayslipState.expired);
      expect(loaded.payslip.downloadUrl, isNull);
    });

    test('State machine: queued — no document, no URL', () async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await cubit.load('ps-3');
      expect(cubit.state, isA<PayslipDetailLoaded>());
      final loaded = cubit.state as PayslipDetailLoaded;
      expect(loaded.payslip.documentState, PayslipState.queued);
      // Queued payslip must not claim document is ready
      expect(loaded.payslip.documentState.isDocumentAvailable, isFalse);
      expect(loaded.payslip.downloadUrl, isNull);
    });

    testWidgets(
        'Denied renders access denied message — no line count or URL exposed',
        (tester) async {
      final cubit = PayslipDetailCubit(repository: _AlwaysDeniedRepo());
      await tester.pumpWidget(_detailHarness(cubit, repo: _AlwaysDeniedRepo()));
      await tester.pumpAndSettle();
      expect(find.text('غير مصرح لك بعرض هذا الكشف'), findsOneWidget);
      // No amounts or download button must be visible after denial
      expect(find.byKey(const Key('payslip_download_button')), findsNothing);
    });

    testWidgets('Not found renders not-found message', (tester) async {
      final cubit = PayslipDetailCubit(repository: _NotFoundRepo());
      await tester.pumpWidget(_detailHarness(cubit, repo: _NotFoundRepo()));
      await tester.pumpAndSettle();
      expect(find.text('كشف الراتب غير موجود'), findsOneWidget);
    });

    testWidgets('Network error shows retry button', (tester) async {
      final cubit = PayslipDetailCubit(repository: _NetworkErrorRepo());
      await tester.pumpWidget(_detailHarness(cubit, repo: _NetworkErrorRepo()));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('payslip_detail_retry_button')), findsOneWidget);
    });

    testWidgets('Ready payslip shows download button', (tester) async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await tester.pumpWidget(_detailHarness(cubit));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip_download_button')), findsOneWidget);
    });

    testWidgets('Queued state shows "not ready" message — no download button',
        (tester) async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RepositoryProvider<PayslipRepository>(
            create: (_) => _EmployeeARepo(),
            child: BlocProvider<PayslipDetailCubit>.value(
              value: cubit,
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: PayslipDetailScreen(payslipId: 'ps-3'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip_queued_message')), findsOneWidget);
      expect(find.byKey(const Key('payslip_download_button')), findsNothing);
    });

    testWidgets('Expired state shows expiry message — no download button',
        (tester) async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RepositoryProvider<PayslipRepository>(
            create: (_) => _EmployeeARepo(),
            child: BlocProvider<PayslipDetailCubit>.value(
              value: cubit,
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: PayslipDetailScreen(payslipId: 'ps-2'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip_expired_message')), findsOneWidget);
      expect(find.byKey(const Key('payslip_download_button')), findsNothing);
    });

    testWidgets('200% text scale: detail screen renders without overflow',
        (tester) async {
      final cubit = PayslipDetailCubit(repository: _EmployeeARepo());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _detailHarness(cubit),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip_download_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text scale: error state renders without overflow',
        (tester) async {
      final cubit = PayslipDetailCubit(repository: _NetworkErrorRepo());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _detailHarness(cubit, repo: _NetworkErrorRepo()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('payslip_detail_retry_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Privacy: denied response must not expose row count or URL',
        (tester) async {
      // Verify that after a 403, no amounts, URLs, or counts from a different
      // identity leak into the denied-state widget tree.
      final cubit = PayslipDetailCubit(repository: _AlwaysDeniedRepo());
      await tester.pumpWidget(_detailHarness(cubit, repo: _AlwaysDeniedRepo()));
      await tester.pumpAndSettle();
      // Should not find download URL text, payroll lines, or amounts
      expect(find.text('5000.00 SDG'), findsNothing);
      expect(find.text('4500.00 SDG'), findsNothing);
      expect(find.byKey(const Key('payslip_download_button')), findsNothing);
    });
  });
}
