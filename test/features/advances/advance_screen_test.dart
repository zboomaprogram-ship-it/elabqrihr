// Tests for Feature 006 self-service advance screens (T041).
// Covers: identity isolation, loading, empty, denied, network error, retry,
// balance/state rendering, Arabic RTL, and 200% text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/advances/domain/advance_models.dart';
import 'package:attend_mobile/features/advances/domain/advance_repository.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_cubit.dart';
import 'package:attend_mobile/features/advances/presentation/cubit/advance_list_state.dart';
import 'package:attend_mobile/features/advances/presentation/screens/advance_list_screen.dart';
import 'package:attend_mobile/core/design_system/widgets/skeleton_loaders.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

MoneyDto _m(String amt) => MoneyDto(currency: 'SDG', amount: amt);

class _DeniedAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) =>
      throw const AdvanceAccessDeniedException();
}

class _EmptyAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) async =>
      const AdvancePageEntity(items: [], nextCursor: null);
}

class _NetworkErrorAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) =>
      throw Exception('SocketException: Connection refused');
}

class _EmployeeAAdvanceRepo implements AdvanceRepository {
  final String employeeId = 'emp-A';

  AdvanceDto _dto({
    required String id,
    required String principal,
    required String posted,
    required String remainingBalance,
    required AdvanceState state,
  }) =>
      AdvanceDto(
        id: id,
        employeeId: employeeId,
        principal: _m(principal),
        postedAmount: _m(posted),
        remainingBalance: _m(remainingBalance),
        state: state,
        revision: 1,
      );

  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) async =>
      AdvancePageEntity(
        items: [
          AdvanceEntity.fromDto(_dto(
            id: 'adv-1',
            principal: '10000.00',
            posted: '2500.00',
            remainingBalance: '7500.00',
            state: AdvanceState.collecting,
          )),
          AdvanceEntity.fromDto(_dto(
            id: 'adv-2',
            principal: '5000.00',
            posted: '0.00',
            remainingBalance: '5000.00',
            state: AdvanceState.approved,
          )),
          AdvanceEntity.fromDto(_dto(
            id: 'adv-3',
            principal: '3000.00',
            posted: '3000.00',
            remainingBalance: '0.00',
            state: AdvanceState.settled,
          )),
        ],
        nextCursor: null,
      );
}

class _EmployeeBAdvanceRepo implements AdvanceRepository {
  @override
  Future<AdvancePageEntity> listMyAdvances(
          {String? cursor, int limit = 25, String? state}) async =>
      const AdvancePageEntity(items: [], nextCursor: null);
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _harness(AdvanceListCubit cubit, {AdvanceRepository? repo}) =>
    MaterialApp(
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
        value: repo ?? _EmployeeAAdvanceRepo(),
        child: BlocProvider<AdvanceListCubit>.value(
          value: cubit,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: AdvanceListScreen(),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AdvanceListCubit', () {
    test('State machine: initial -> loading -> loaded', () async {
      final cubit = AdvanceListCubit(repository: _EmployeeAAdvanceRepo());
      expect(cubit.state, isA<AdvanceListInitial>());
      final future = cubit.load();
      expect(cubit.state, isA<AdvanceListLoading>());
      await future;
      expect(cubit.state, isA<AdvanceListLoaded>());
      final loaded = cubit.state as AdvanceListLoaded;
      expect(loaded.items, hasLength(3));
      expect(loaded.items.first.remainingBalance.amount, '7500.00');
    });

    test('State machine: initial -> loading -> empty', () async {
      final cubit = AdvanceListCubit(repository: _EmptyAdvanceRepo());
      await cubit.load();
      expect(cubit.state, isA<AdvanceListEmpty>());
    });

    test('State machine: initial -> loading -> denied on 403', () async {
      final cubit = AdvanceListCubit(repository: _DeniedAdvanceRepo());
      await cubit.load();
      expect(cubit.state, isA<AdvanceListDenied>());
    });

    test('State machine: initial -> loading -> error on network failure',
        () async {
      final cubit = AdvanceListCubit(repository: _NetworkErrorAdvanceRepo());
      await cubit.load();
      expect(cubit.state, isA<AdvanceListError>());
    });
  });

  group('AdvanceListScreen UI', () {
    testWidgets('Loading indicator is rendered initially', (tester) async {
      final cubit = AdvanceListCubit(repository: _EmptyAdvanceRepo());
      await tester.pumpWidget(_harness(cubit));
      expect(find.byType(RequestListSkeleton), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Empty state renders correct Arabic text', (tester) async {
      final cubit = AdvanceListCubit(repository: _EmptyAdvanceRepo());
      await tester.pumpWidget(_harness(cubit, repo: _EmptyAdvanceRepo()));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد سلف مالية مسجلة'), findsOneWidget);
    });

    testWidgets(
        '403 Denied state renders access denied message without leaking amounts',
        (tester) async {
      final cubit = AdvanceListCubit(repository: _DeniedAdvanceRepo());
      await tester.pumpWidget(_harness(cubit, repo: _DeniedAdvanceRepo()));
      await tester.pumpAndSettle();
      expect(find.text('غير مصرح لك بعرض بيانات السلف'), findsOneWidget);
      // Ensure zero amount leak
      expect(find.textContaining('SDG'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('Network error state renders retry button', (tester) async {
      final cubit = AdvanceListCubit(repository: _NetworkErrorAdvanceRepo());
      await tester
          .pumpWidget(_harness(cubit, repo: _NetworkErrorAdvanceRepo()));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('advance_list_retry_button')), findsOneWidget);
      expect(find.text('تعذّر تحميل بيانات السلف'), findsOneWidget);
    });

    testWidgets(
        'Loaded state renders advance cards with verbatim server amounts',
        (tester) async {
      final cubit = AdvanceListCubit(repository: _EmployeeAAdvanceRepo());
      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advance_card_adv-1')), findsOneWidget);
      expect(find.byKey(const Key('advance_card_adv-2')), findsOneWidget);
      expect(find.byKey(const Key('advance_card_adv-3')), findsOneWidget);

      // Verbatim amounts rendered from server
      expect(find.text('10000.00 SDG'), findsOneWidget);
      expect(find.text('2500.00 SDG'), findsOneWidget);
      expect(find.text('7500.00 SDG'), findsOneWidget);

      // State label
      expect(find.text('قيد السداد'), findsOneWidget);
      expect(find.text('معتمدة'), findsOneWidget);
      expect(find.text('تمت التسوية'), findsOneWidget);
    });

    testWidgets('Identity isolation: Employee B sees zero Employee A advances',
        (tester) async {
      final cubit = AdvanceListCubit(repository: _EmployeeBAdvanceRepo());
      await tester.pumpWidget(_harness(cubit, repo: _EmployeeBAdvanceRepo()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advance_card_adv-1')), findsNothing);
      expect(find.byKey(const Key('advance_card_adv-2')), findsNothing);
      expect(find.text('10000.00 SDG'), findsNothing);
      expect(find.text('لا توجد سلف مالية مسجلة'), findsOneWidget);
    });

    testWidgets('200% text scale: advance list renders without overflow',
        (tester) async {
      final cubit = AdvanceListCubit(repository: _EmployeeAAdvanceRepo());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _harness(cubit),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('advance_card_adv-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text scale: denied state renders without overflow',
        (tester) async {
      final cubit = AdvanceListCubit(repository: _DeniedAdvanceRepo());
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _harness(cubit, repo: _DeniedAdvanceRepo()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('غير مصرح لك بعرض بيانات السلف'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
