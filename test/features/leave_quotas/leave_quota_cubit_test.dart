import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/leave_quotas/domain/leave_quota_models.dart';
import 'package:attend_mobile/features/leave_quotas/domain/leave_quota_repository.dart';
import 'package:attend_mobile/features/leave_quotas/presentation/cubit/leave_quota_cubit.dart';
import 'package:attend_mobile/features/leave_quotas/presentation/cubit/leave_quota_state.dart';
import 'package:attend_mobile/features/leave_quotas/presentation/widgets/leave_quota_balance_card.dart';
import 'package:attend_mobile/features/leave_quotas/presentation/widgets/request_quota_presubmit_banner.dart';

class _FakeLeaveQuotaRepository implements LeaveQuotaRepository {
  List<QuotaBalanceEntity> balances;
  bool shouldThrow;

  _FakeLeaveQuotaRepository({
    required this.balances,
    this.shouldThrow = false,
  });

  @override
  Future<List<QuotaBalanceEntity>> getMyBalances() async {
    if (shouldThrow) {
      throw Exception('Server error loading quota balances');
    }
    return balances;
  }
}

void main() {
  final sampleBalances = <QuotaBalanceEntity>[
    const QuotaBalanceEntity(
      quotaKey: QuotaKey.dayOff,
      unit: QuotaUnit.days,
      allowance: 30,
      resetCycle: QuotaResetCycle.annual,
      periodStart: '2026-01-01',
      periodEnd: '2026-12-31',
      granted: 30,
      reserved: 2,
      adjusted: 0,
      remaining: 20,
    ),
    const QuotaBalanceEntity(
      quotaKey: QuotaKey.timePermission,
      unit: QuotaUnit.minutes,
      allowance: 180,
      resetCycle: QuotaResetCycle.monthly,
      periodStart: '2026-10-01',
      periodEnd: '2026-10-31',
      granted: 180,
      reserved: 0,
      adjusted: 0,
      remaining: 120,
    ),
  ];

  group('LeaveQuotaCubit Tests', () {
    test('initial state is LeaveQuotaInitial', () {
      final repo = _FakeLeaveQuotaRepository(balances: sampleBalances);
      final cubit = LeaveQuotaCubit(repository: repo);
      expect(cubit.state, isA<LeaveQuotaInitial>());
      cubit.close();
    });

    test('loadBalances emits [Loading, Loaded] when successful', () async {
      final repo = _FakeLeaveQuotaRepository(balances: sampleBalances);
      final cubit = LeaveQuotaCubit(repository: repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<LeaveQuotaLoading>(),
          isA<LeaveQuotaLoaded>().having((s) => s.balances.length, 'length', 2),
        ]),
      );

      await cubit.loadBalances();
      cubit.close();
    });

    test('loadBalances emits [Loading, Error] on repository exception',
        () async {
      final repo = _FakeLeaveQuotaRepository(balances: [], shouldThrow: true);
      final cubit = LeaveQuotaCubit(repository: repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<LeaveQuotaLoading>(),
          isA<LeaveQuotaError>(),
        ]),
      );

      await cubit.loadBalances();
      cubit.close();
    });
  });

  group('Quota Model RTL Arabic Formats', () {
    test('formats day_off balance properly', () {
      final balance = sampleBalances[0];
      expect(balance.formattedRemaining, '20 يوم');
      expect(balance.formattedAllowance, '30 يوم');
      expect(balance.formattedReserved, '2 يوم');
    });

    test('formats time_permission balance properly into hours/minutes', () {
      final balance = sampleBalances[1];
      expect(balance.formattedRemaining, '2 ساعة');
      expect(balance.formattedAllowance, '3 ساعة');
      expect(balance.formattedReserved, '0 دقيقة');
    });
  });

  group('Leave Quota Widgets', () {
    testWidgets('LeaveQuotaBalanceCard displays quota values cleanly in Arabic',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeaveQuotaBalanceCard(
              balance: sampleBalances[0],
            ),
          ),
        ),
      );

      expect(find.text('20 يوم'), findsWidgets);
      expect(find.textContaining('30 يوم'), findsWidgets);
    });

    testWidgets('RequestQuotaPresubmitBanner shows warning if remaining is 0',
        (tester) async {
      const exhaustedBalance = QuotaBalanceEntity(
        quotaKey: QuotaKey.dayOff,
        unit: QuotaUnit.days,
        allowance: 30,
        resetCycle: QuotaResetCycle.annual,
        periodStart: '2026-01-01',
        periodEnd: '2026-12-31',
        granted: 30,
        reserved: 0,
        adjusted: 0,
        remaining: 0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RequestQuotaPresubmitBanner(
              balance: exhaustedBalance,
              requestedUnits: 0,
            ),
          ),
        ),
      );

      expect(find.textContaining('رصيدك المتاح حالياً 0'), findsOneWidget);
    });

    testWidgets(
        'RequestQuotaPresubmitBanner shows warning if requested exceeds remaining',
        (tester) async {
      final balance = sampleBalances[0]; // remaining: 20

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestQuotaPresubmitBanner(
              balance: balance,
              requestedUnits: 25,
            ),
          ),
        ),
      );

      expect(find.textContaining('تتجاوز رصيدك الحالي المتاح'), findsOneWidget);
    });
  });
}
