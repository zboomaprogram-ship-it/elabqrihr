// ignore_for_file: avoid_print
// Device acceptance test for Feature 006 payslip screens (T063).
// Run with: flutter test integration_test/payslip_device_test.dart -d 10JE1B00ZB000E8
// Screenshots saved to /sdcard/Download/f006_payslip/ on device.
// Pull: adb -s 10JE1B00ZB000E8 pull /sdcard/Download/f006_payslip/ test-results/screenshots/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_models.dart';
import 'package:attend_mobile/features/payroll/domain/payslip_repository.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_list_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/cubit/payslip_detail_cubit.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_list_screen.dart';
import 'package:attend_mobile/features/payroll/presentation/screens/payslip_detail_screen.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

MoneyDto _m(String a) => MoneyDto(currency: 'SDG', amount: a);

class _StubRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips(
          {String? cursor, int limit = 25}) async =>
      PayslipPageEntity(
        items: [
          PayslipSummaryEntity.fromDto(PayslipSummaryDto(
            id: 'ps-ready',
            cycleKey: '2026-09',
            gross: _m('5000.00'),
            deductions: _m('500.00'),
            net: _m('4500.00'),
            issuedAt: DateTime(2026, 9, 1),
            documentState: PayslipDocumentState.ready,
          )),
          PayslipSummaryEntity.fromDto(PayslipSummaryDto(
            id: 'ps-queued',
            cycleKey: '2026-08',
            gross: _m('4800.00'),
            deductions: _m('480.00'),
            net: _m('4320.00'),
            issuedAt: DateTime(2026, 8, 1),
            documentState: PayslipDocumentState.queued,
          )),
          PayslipSummaryEntity.fromDto(PayslipSummaryDto(
            id: 'ps-expired',
            cycleKey: '2026-07',
            gross: _m('4600.00'),
            deductions: _m('460.00'),
            net: _m('4140.00'),
            issuedAt: DateTime(2026, 7, 1),
            documentState: PayslipDocumentState.expired,
          )),
        ],
        nextCursor: null,
      );

  @override
  Future<PayslipEntity> getPayslip(String id) async {
    final lines = [
      PayrollLineDto(
        id: 'line-1',
        kind: PayrollLineKind.earning,
        code: 'BASIC',
        amount: _m('5000.00'),
        sourceType: 'compensation',
        sourceId: 'comp-1',
      ),
      PayrollLineDto(
        id: 'line-2',
        kind: PayrollLineKind.deduction,
        code: 'GOSI',
        amount: _m('500.00'),
        sourceType: 'statutory',
        sourceId: 'stat-1',
      ),
    ];
    final state = switch (id) {
      'ps-queued' => PayslipDocumentState.queued,
      'ps-expired' => PayslipDocumentState.expired,
      _ => PayslipDocumentState.ready,
    };
    return PayslipEntity.fromDto(PayslipDto(
      id: id,
      cycleKey: id == 'ps-queued'
          ? '2026-08'
          : id == 'ps-expired'
              ? '2026-07'
              : '2026-09',
      gross: _m('5000.00'),
      deductions: _m('500.00'),
      net: _m('4500.00'),
      issuedAt: DateTime(2026, 9, 1),
      documentState: state,
      employeeId: 'emp-vivo-001',
      periodStart: '2026-09-26',
      periodEnd: '2026-10-25',
      lines: lines,
      downloadUrl: state == PayslipDocumentState.ready
          ? 'https://storage.example.com/payslips/$id.pdf'
          : null,
      downloadExpiresAt:
          state == PayslipDocumentState.ready ? DateTime(2026, 10, 1) : null,
    ));
  }
}

class _DeniedRepo implements PayslipRepository {
  @override
  Future<PayslipPageEntity> listMyPayslips({String? cursor, int limit = 25}) =>
      throw const PayslipAccessDeniedException();
  @override
  Future<PayslipEntity> getPayslip(String id) =>
      throw const PayslipAccessDeniedException();
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _outDir = '/sdcard/Download/f006_payslip';

Future<void> _save(
  IntegrationTestWidgetsFlutterBinding b,
  WidgetTester tester,
  String name,
) async {
  // Required before every takeScreenshot call on physical devices.
  await b.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  final bytes = await b.takeScreenshot(name);
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await File('$_outDir/$name').writeAsBytes(bytes);
  print('[SCREENSHOT] $name — ${bytes.length} bytes');
}

Widget _wrap(Widget screen, PayslipRepository repo) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepositoryProvider<PayslipRepository>.value(
        value: repo,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: screen,
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F006 Vivo V2254: payslip list — loaded 100%', (tester) async {
    final repo = _StubRepo();
    final cubit = PayslipListCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipListCubit>.value(
          value: cubit, child: const PayslipListScreen()),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_list_100.png');
  });

  testWidgets('F006 Vivo V2254: payslip list — loaded 200%', (tester) async {
    final repo = _StubRepo();
    final cubit = PayslipListCubit(repository: repo);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(
          BlocProvider<PayslipListCubit>.value(
              value: cubit, child: const PayslipListScreen()),
          repo,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_list_200.png');
  });

  testWidgets('F006 Vivo V2254: payslip list — empty state', (tester) async {
    final repo = _EmptyRepo();
    final cubit = PayslipListCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipListCubit>.value(
          value: cubit, child: const PayslipListScreen()),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_list_empty.png');
  });

  testWidgets('F006 Vivo V2254: payslip list — denied state', (tester) async {
    final repo = _DeniedRepo();
    final cubit = PayslipListCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipListCubit>.value(
          value: cubit, child: const PayslipListScreen()),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_list_denied.png');
  });

  testWidgets('F006 Vivo V2254: payslip detail — ready document 100%',
      (tester) async {
    final repo = _StubRepo();
    final cubit = PayslipDetailCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipDetailCubit>.value(
        value: cubit,
        child: const PayslipDetailScreen(payslipId: 'ps-ready'),
      ),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(
        binding, tester, 'vivo_v2254_f006_payslip_detail_ready_100.png');
  });

  testWidgets('F006 Vivo V2254: payslip detail — ready document 200%',
      (tester) async {
    final repo = _StubRepo();
    final cubit = PayslipDetailCubit(repository: repo);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(
          BlocProvider<PayslipDetailCubit>.value(
            value: cubit,
            child: const PayslipDetailScreen(payslipId: 'ps-ready'),
          ),
          repo,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(
        binding, tester, 'vivo_v2254_f006_payslip_detail_ready_200.png');
  });

  testWidgets('F006 Vivo V2254: payslip detail — queued state', (tester) async {
    final repo = _StubRepo();
    final cubit = PayslipDetailCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipDetailCubit>.value(
        value: cubit,
        child: const PayslipDetailScreen(payslipId: 'ps-queued'),
      ),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_detail_queued.png');
  });

  testWidgets('F006 Vivo V2254: payslip detail — expired document',
      (tester) async {
    final repo = _StubRepo();
    final cubit = PayslipDetailCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipDetailCubit>.value(
        value: cubit,
        child: const PayslipDetailScreen(payslipId: 'ps-expired'),
      ),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_detail_expired.png');
  });

  testWidgets('F006 Vivo V2254: payslip detail — denied (no URL/count exposed)',
      (tester) async {
    final repo = _DeniedRepo();
    final cubit = PayslipDetailCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<PayslipDetailCubit>.value(
        value: cubit,
        child: const PayslipDetailScreen(payslipId: 'ps-ready'),
      ),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_payslip_detail_denied.png');
  });
}
