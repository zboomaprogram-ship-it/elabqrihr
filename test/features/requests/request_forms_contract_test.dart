import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/forms/attendance_correction_form.dart';
import 'package:attend_mobile/features/requests/presentation/forms/leave_request_form.dart';
import 'package:attend_mobile/features/requests/presentation/forms/permission_request_form.dart';

class _MockRequestRepository extends Mock
    implements RequestRepository, EmployeeShiftRepository {}

Widget _formApp({
  required RequestRepository repository,
  required EmployeeShiftRepository shiftRepository,
  required Widget child,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: BlocProvider(
        create: (_) => RequestFormCubit(
          repository: repository,
          shiftRepository: shiftRepository,
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestType.attendanceCorrection);
    registerFallbackValue(<String, dynamic>{});
  });

  testWidgets(
      'leave submission is disabled when server categories are unavailable',
      (tester) async {
    final repository = _MockRequestRepository();
    when(repository.getMyLeaveBalances).thenAnswer((_) async => const []);

    await tester.pumpWidget(_formApp(
      repository: repository,
      shiftRepository: repository,
      child: LeaveRequestForm(onSuccess: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد أنواع إجازات متاحة لهذا الحساب حالياً.'),
        findsOneWidget);
    expect(find.text('إعادة تحميل الأرصدة'), findsOneWidget);
    final submit = tester.widget<ElevatedButton>(find.widgetWithText(
      ElevatedButton,
      'إرسال الطلب',
    ));
    expect(submit.onPressed, isNull);
  });

  testWidgets(
      'attendance correction submits only the selected authorized shift',
      (tester) async {
    final repository = _MockRequestRepository();
    const shiftId = '8c52084c-cb14-41d9-813a-773cefb180a0';
    when(() => repository.listMyShiftInstances(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          EmployeeShiftEntity(
            shiftInstanceId: shiftId,
            businessDate: '2026-09-20',
            startsAt: DateTime.utc(2026, 9, 20, 6),
            endsAt: DateTime.utc(2026, 9, 20, 14),
            branchName: 'Cairo HQ',
            state: 'completed',
          ),
        ]);
    when(() => repository.submitRequest(
          requestId: any(named: 'requestId'),
          type: any(named: 'type'),
          payload: any(named: 'payload'),
        )).thenAnswer((invocation) async {
      final payload =
          invocation.namedArguments[#payload]! as Map<String, dynamic>;
      expect(payload['shiftInstanceId'], shiftId);
      return RequestEntity(
        id: invocation.namedArguments[#requestId]! as String,
        employeeId: 'employee-1',
        type: RequestType.attendanceCorrection,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 0,
        submittedAt: DateTime.utc(2026, 9, 21),
        details: payload,
        steps: const [],
      );
    });

    await tester.pumpWidget(_formApp(
      repository: repository,
      shiftRepository: repository,
      child: AttendanceCorrectionForm(onSuccess: () {}),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('attendance-correction-shift')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Cairo HQ').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'نسيان بصمة الحضور');
    await tester.tap(find.widgetWithText(ElevatedButton, 'إرسال الطلب'));
    await tester.pumpAndSettle();

    verify(() => repository.submitRequest(
          requestId: any(named: 'requestId'),
          type: RequestType.attendanceCorrection,
          payload: any(named: 'payload'),
        )).called(1);
  });

  testWidgets(
      'permission request loads scheduled shifts and submits late arrival without active attendance',
      (tester) async {
    final repository = _MockRequestRepository();
    const shiftId = '9d63195d-db25-42ea-924b-884deec291b1';
    when(() => repository.listMyShiftInstances(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          EmployeeShiftEntity(
            shiftInstanceId: shiftId,
            businessDate: '2026-09-22',
            startsAt: DateTime.utc(2026, 9, 22, 9),
            endsAt: DateTime.utc(2026, 9, 22, 17),
            branchName: 'Cairo HQ',
            state: 'scheduled',
          ),
        ]);
    when(() => repository.submitRequest(
          requestId: any(named: 'requestId'),
          type: any(named: 'type'),
          payload: any(named: 'payload'),
        )).thenAnswer((invocation) async {
      final payload =
          invocation.namedArguments[#payload]! as Map<String, dynamic>;
      expect(payload['shiftInstanceId'], shiftId);
      expect(payload['categoryCode'], 'late_arrival');
      return RequestEntity(
        id: invocation.namedArguments[#requestId]! as String,
        employeeId: 'employee-1',
        type: RequestType.permission,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 60,
        submittedAt: DateTime.utc(2026, 9, 22),
        details: payload,
        steps: const [],
      );
    });

    await tester.pumpWidget(_formApp(
      repository: repository,
      shiftRepository: repository,
      child: PermissionRequestForm(onSuccess: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('permission-shift-dropdown')), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, '').last, 'تأخير في المواصلات');
    await tester.tap(find.widgetWithText(ElevatedButton, 'إرسال الطلب'));
    await tester.pumpAndSettle();

    verify(() => repository.submitRequest(
          requestId: any(named: 'requestId'),
          type: RequestType.permission,
          payload: any(named: 'payload'),
        )).called(1);
  });
}
