import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/employee_summary_cards.dart';
import 'package:attend_mobile/features/dashboard/presentation/widgets/team_summary_card.dart';

void main() {
  group('Summary Cards Tests (T033, T034, US6)', () {
    testWidgets('EmployeeSummaryCards renders metrics and responds to taps',
        (tester) async {
      bool leaveTapped = false;
      bool requestsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmployeeSummaryCards(
              monthlyHoursText: '155 ساعة',
              availableLeaveDays: 18,
              pendingRequestsCount: 3,
              onLeaveTap: () => leaveTapped = true,
              onRequestsTap: () => requestsTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('نظرة عامة على الشهر'), findsOneWidget);
      expect(find.text('155 ساعة'), findsOneWidget);
      expect(find.text('18 يوم'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('18 يوم'));
      expect(leaveTapped, isTrue);

      await tester.tap(find.text('3'));
      expect(requestsTapped, isTrue);
    });

    testWidgets('TeamSummaryCard renders manager team counts and inbox action',
        (tester) async {
      bool reviewTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeamSummaryCard(
              totalMembers: 15,
              presentCount: 12,
              onLeaveCount: 3,
              pendingApprovalsCount: 4,
              onReviewInboxTap: () => reviewTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ملخص أداء الفريق اليوم'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4 بانتظار الموافقة'), findsOneWidget);

      final reviewButton = find.text('مراجعة الطلبات المعلقة');
      expect(reviewButton, findsOneWidget);
      await tester.tap(reviewButton);
      expect(reviewTapped, isTrue);
    });
  });
}
