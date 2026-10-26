import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/screens/requests_home_screen.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/approval_timeline_widget.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/request_card.dart';
import 'package:attend_mobile/features/requests/presentation/widgets/request_status_chip.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

void main() {
  late MockRequestRepository repository;

  setUp(() {
    repository = MockRequestRepository();
    when(() => repository.watchPendingRequests())
        .thenAnswer((_) => Stream.value([]));
    when(() => repository.listMyRequests(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          type: any(named: 'type'),
          state: any(named: 'state'),
        )).thenAnswer((_) async => []);
    when(() => repository.getMyLeaveBalances()).thenAnswer((_) async => []);
  });

  group('RequestStatusChip Tests (T021, T024, T062)', () {
    testWidgets('renders correct Arabic label for pendingSync', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
              body: RequestStatusChip(state: RequestState.pendingSync)),
        ),
      );
      expect(find.text('في انتظار المزامنة'), findsOneWidget);
    });

    testWidgets('renders correct Arabic label for approved', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RequestStatusChip(state: RequestState.approved)),
        ),
      );
      expect(find.text('معتمد'), findsOneWidget);
    });

    testWidgets('renders correct Arabic label for conflict', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RequestStatusChip(state: RequestState.conflict)),
        ),
      );
      expect(find.text('تعارض'), findsOneWidget);
    });
  });

  group('ApprovalTimelineWidget Tests (T021, T024)', () {
    testWidgets('renders two-stage approval steps with roles and status',
        (tester) async {
      final steps = [
        const ApprovalStepEntity(
          id: 'step-1',
          position: 1,
          reviewerRole: 'manager',
          reviewerName: 'عمر المدير',
          state: 'approved',
          comment: 'تم التحقق من الجدول',
        ),
        const ApprovalStepEntity(
          id: 'step-2',
          position: 2,
          reviewerRole: 'hr',
          state: 'pending',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: ApprovalTimelineWidget(steps: steps),
            ),
          ),
        ),
      );

      expect(find.text('مسار الموافقات'), findsOneWidget);
      expect(find.text('المرحلة 1: المدير المباشر'), findsOneWidget);
      expect(find.text('المراجع: عمر المدير'), findsOneWidget);
      expect(find.text('ملاحظة: تم التحقق من الجدول'), findsOneWidget);
      expect(find.text('المرحلة 2: الموارد البشرية'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);
    });
  });

  group('RequestCard Widget Tests (T021, T024)', () {
    testWidgets('renders offline banner when state is pendingSync',
        (tester) async {
      final request = RequestEntity(
        id: 'r-offline',
        employeeId: 'emp-1',
        type: RequestType.leave,
        state: RequestState.pendingSync,
        revision: 1,
        requestedMinutes: 480,
        submittedAt: DateTime.parse('2026-09-21T09:00:00Z'),
        details: const {'reason': 'سفر طارئ'},
        steps: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RequestCard(request: request, onTap: () {}),
          ),
        ),
      );

      expect(find.text('طلب إجازة'), findsOneWidget);
      expect(find.text('السبب: سفر طارئ'), findsOneWidget);
      expect(find.text('في انتظار المزامنة'), findsWidgets);
    });
  });

  group('RequestsHomeScreen Widget Tests (T021, T024, T062)', () {
    testWidgets('renders tabs, Arabic RTL, and filter bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: RepositoryProvider<RequestRepository>.value(
              value: repository,
              child: const RequestsHomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إدارة الطلبات والموافقات'), findsOneWidget);
      expect(find.text('طلباتي'), findsOneWidget);
      expect(find.text('تقديم طلب'), findsOneWidget);
      expect(find.text('لا توجد طلبات في هذا القسم حالياً'), findsOneWidget);
    });
  });
}
