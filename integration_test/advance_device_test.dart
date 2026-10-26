// ignore_for_file: avoid_print
// Device acceptance test for Feature 006 advance screens (T041-T042, T063).
// Run with: flutter test integration_test/advance_device_test.dart -d 10JE1B00ZB000E8
// Screenshots saved to /sdcard/Download/f006_advances/ on device.
// Pull: adb -s 10JE1B00ZB000E8 pull /sdcard/Download/f006_advances/ test-results/screenshots/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_list_screen.dart';

MoneyDto _m(String a) => MoneyDto(currency: 'SDG', amount: a);

class _DeviceAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) async =>
      AdvancePageEntity(
        items: [
          AdvanceEntity.fromDto(AdvanceDto(
            id: 'adv-1',
            employeeId: 'emp-vivo-001',
            principal: _m('10000.00'),
            postedAmount: _m('2500.00'),
            remainingBalance: _m('7500.00'),
            state: AdvanceState.collecting,
            revision: 1,
          )),
          AdvanceEntity.fromDto(AdvanceDto(
            id: 'adv-2',
            employeeId: 'emp-vivo-001',
            principal: _m('5000.00'),
            postedAmount: _m('0.00'),
            remainingBalance: _m('5000.00'),
            state: AdvanceState.approved,
            revision: 1,
          )),
          AdvanceEntity.fromDto(AdvanceDto(
            id: 'adv-3',
            employeeId: 'emp-vivo-001',
            principal: _m('3000.00'),
            postedAmount: _m('3000.00'),
            remainingBalance: _m('0.00'),
            state: AdvanceState.settled,
            revision: 1,
          )),
        ],
        nextCursor: null,
      );
}

class _DeviceEmptyAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) async =>
      const AdvancePageEntity(items: [], nextCursor: null);
}

class _DeviceDeniedAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) =>
      throw const AdvanceAccessDeniedException();
}

const _outDir = '/sdcard/Download/f006_payslip';

Future<void> _save(
  IntegrationTestWidgetsFlutterBinding b,
  WidgetTester tester,
  String name,
) async {
  await b.convertFlutterSurfaceToImage();
  await tester.pumpAndSettle();
  final bytes = await b.takeScreenshot(name);
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  await File('$_outDir/$name').writeAsBytes(bytes);
  print('[SCREENSHOT] $name — ${bytes.length} bytes');
}

Widget _wrap(Widget screen, AdvanceRepository repo) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepositoryProvider<AdvanceRepository>.value(
        value: repo,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: screen,
        ),
      ),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('F006 Vivo V2254: advance list — loaded 100%', (tester) async {
    final repo = _DeviceAdvanceRepo();
    final cubit = AdvanceListCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<AdvanceListCubit>.value(
          value: cubit, child: const AdvanceListScreen()),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_advance_list_100.png');
  });

  testWidgets('F006 Vivo V2254: advance list — loaded 200%', (tester) async {
    final repo = _DeviceAdvanceRepo();
    final cubit = AdvanceListCubit(repository: repo);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(
          BlocProvider<AdvanceListCubit>.value(
              value: cubit, child: const AdvanceListScreen()),
          repo,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_advance_list_200.png');
  });

  testWidgets('F006 Vivo V2254: advance list — empty state', (tester) async {
    final repo = _DeviceEmptyAdvanceRepo();
    final cubit = AdvanceListCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<AdvanceListCubit>.value(
          value: cubit, child: const AdvanceListScreen()),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_advance_list_empty.png');
  });

  testWidgets('F006 Vivo V2254: advance list — denied state', (tester) async {
    final repo = _DeviceDeniedAdvanceRepo();
    final cubit = AdvanceListCubit(repository: repo);
    await tester.pumpWidget(_wrap(
      BlocProvider<AdvanceListCubit>.value(
          value: cubit, child: const AdvanceListScreen()),
      repo,
    ));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _save(binding, tester, 'vivo_v2254_f006_advance_list_denied.png');
  });
}
