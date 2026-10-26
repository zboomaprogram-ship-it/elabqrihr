import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/cubits/request_form_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/forms/attendance_correction_form.dart';

class _MockRequestRepository extends Mock
    implements RequestRepository, EmployeeShiftRepository {}

Widget _buildTestApp({
  required RequestRepository repository,
  required EmployeeShiftRepository shiftRepository,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          size: const Size(1080, 2400),
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: BlocProvider(
          create: (_) => RequestFormCubit(
            repository: repository,
            shiftRepository: shiftRepository,
          ),
          child: Scaffold(
            body: AttendanceCorrectionForm(onSuccess: () {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockRequestRepository repository;

  final sampleShift = EmployeeShiftEntity(
    shiftInstanceId: 'shift-past-001',
    businessDate: '2026-10-15',
    startsAt: DateTime.parse('2026-10-15T08:00:00Z'),
    endsAt: DateTime.parse('2026-10-15T17:00:00Z'),
    branchName: 'الفرع الرئيسي',
    state: 'completed',
  );

  setUpAll(() {
    registerFallbackValue(RequestType.attendanceCorrection);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = _MockRequestRepository();
    when(() => repository.listMyShiftInstances(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) async => [sampleShift]);
  });

  group('User Story 1: Attendance Correction Tests (T025)', () {
    test(
        'cubit successfully submits single punch correction and enters pending state',
        () async {
      final cubit = RequestFormCubit(
        repository: repository,
        shiftRepository: repository,
      );

      final returnedRequest = RequestEntity(
        id: 'req-corr-101',
        employeeId: 'emp-001',
        type: RequestType.attendanceCorrection,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 0,
        submittedAt: DateTime.now(),
        details: const {
          'shiftInstanceId': 'shift-past-001',
          'correctionKind': 'add_check_in',
        },
        steps: const [],
      );

      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: any(named: 'payload'),
          )).thenAnswer((_) async => returnedRequest);

      final proposedAt = DateTime.parse('2026-10-15T08:05:00Z');
      await cubit.submitAttendanceCorrection(
        shiftInstanceId: 'shift-past-001',
        correctionKind: 'add_check_in',
        proposedAt: proposedAt,
        reason: 'نسيان تسجيل بصمة الدخول بسبب عطل في البوابة',
      );

      expect(cubit.state, isA<RequestFormSuccess>());
      final success = cubit.state as RequestFormSuccess;
      expect(success.isQueuedOffline, isFalse);
      expect(success.request.state, RequestState.pendingApproval);

      verify(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: captureAny(named: 'payload'),
          )).called(1);
    });

    test('cubit sends a combined correction as an explicit attendance pair',
        () async {
      final cubit = RequestFormCubit(
        repository: repository,
        shiftRepository: repository,
      );
      final returnedRequest = RequestEntity(
        id: 'req-corr-pair-101',
        employeeId: 'emp-001',
        type: RequestType.attendanceCorrection,
        state: RequestState.pendingApproval,
        revision: 1,
        requestedMinutes: 0,
        submittedAt: DateTime.now(),
        details: const {'correctionKind': 'both'},
        steps: const [],
      );
      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: any(named: 'payload'),
          )).thenAnswer((_) async => returnedRequest);

      await cubit.submitAttendanceCorrection(
        shiftInstanceId: 'shift-past-001',
        correctionKind: 'both',
        proposedCheckInAt: DateTime.parse('2026-10-15T08:05:00Z'),
        proposedCheckOutAt: DateTime.parse('2026-10-15T17:10:00Z'),
        reason: 'تعطل الهاتف أثناء تسجيل الحضور والانصراف',
      );

      final captured = verify(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: captureAny(named: 'payload'),
          )).captured.single as Map<String, dynamic>;
      expect(captured['correctionKind'], 'both');
      expect(captured['proposedAt'], isNull);
      expect(captured['proposedCheckInAt'], isNotNull);
      expect(captured['proposedCheckOutAt'], isNotNull);
    });

    test(
        'cubit maps HTTP 409 conflict to RequestFormError with isConflict=true',
        () async {
      final cubit = RequestFormCubit(
        repository: repository,
        shiftRepository: repository,
      );

      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: any(named: 'payload'),
          )).thenThrow(const ConflictFailure('طلب تصحيح مكرر لهذه الوردية'));

      await cubit.submitAttendanceCorrection(
        shiftInstanceId: 'shift-past-001',
        correctionKind: 'add_check_in',
        proposedAt: DateTime.parse('2026-10-15T08:05:00Z'),
        reason: 'طلب مكرر تجريبي للاختبار',
      );

      expect(cubit.state, isA<RequestFormError>());
      final err = cubit.state as RequestFormError;
      expect(err.isConflict, isTrue);
      expect(err.message, contains('طلب تصحيح مكرر'));
    });

    test(
        'offline submission is flagged as pendingSync and never claims completed on server',
        () async {
      final cubit = RequestFormCubit(
        repository: repository,
        shiftRepository: repository,
      );

      final offlineQueuedRequest = RequestEntity(
        id: 'req-corr-offline-1',
        employeeId: 'emp-001',
        type: RequestType.attendanceCorrection,
        state: RequestState.pendingSync,
        revision: 1,
        requestedMinutes: 0,
        submittedAt: DateTime.now(),
        details: const {
          'shiftInstanceId': 'shift-past-001',
          'correctionKind': 'add_check_out',
        },
        steps: const [],
      );

      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: any(named: 'payload'),
          )).thenAnswer((_) async => offlineQueuedRequest);

      await cubit.submitAttendanceCorrection(
        shiftInstanceId: 'shift-past-001',
        correctionKind: 'add_check_out',
        proposedAt: DateTime.parse('2026-10-15T17:10:00Z'),
        reason: 'نسيان تسجيل الانصراف أثناء انقطاع الشبكة',
      );

      expect(cubit.state, isA<RequestFormSuccess>());
      final state = cubit.state as RequestFormSuccess;
      expect(state.isQueuedOffline, isTrue);
      // Offline requests must NOT be marked approved or completed
      expect(state.request.state, isNot(RequestState.approved));
    });

    testWidgets('renders Arabic form and validates reason length',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        repository: repository,
        shiftRepository: repository,
      ));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.attendanceCorrectionTitle), findsOneWidget);
      expect(find.text('الوردية المطلوب تصحيحها'), findsOneWidget);
      expect(find.text('نوع التصحيح المطلوب'), findsOneWidget);
      expect(find.text('تاريخ البصمة'), findsOneWidget);
      expect(find.text('التوقيت الفعلي'), findsOneWidget);

      // Select shift
      await tester.tap(find.byKey(const Key('attendance-correction-shift')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('الفرع الرئيسي').last);
      await tester.pumpAndSettle();

      // Submit with empty reason triggers validation error
      await tester
          .tap(find.widgetWithText(ElevatedButton, AppStringsAr.submitRequest));
      await tester.pumpAndSettle();

      expect(
          find.text('يرجى كتابة سبب واضح لا يقل عن 10 أحرف'), findsOneWidget);
    });

    testWidgets(
        'renders cleanly at 200% font scale without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(
        repository: repository,
        shiftRepository: repository,
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.attendanceCorrectionTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
