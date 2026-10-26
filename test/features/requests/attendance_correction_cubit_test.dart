import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/requests/domain/request_models.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';
import 'package:attend_mobile/features/requests/presentation/attendance_correction/attendance_correction_cubit.dart';
import 'package:attend_mobile/features/requests/presentation/attendance_correction/attendance_correction_state.dart';

class _MockRequestRepo extends Mock
    implements
        RequestRepository,
        EmployeeShiftRepository,
        RequestAttachmentRepository {}

void main() {
  late _MockRequestRepo repository;

  setUpAll(() {
    registerFallbackValue(RequestType.attendanceCorrection);
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    repository = _MockRequestRepo();
  });

  group('AttendanceCorrectionCubit Tests (T036)', () {
    test('loadPastShifts updates shifts list in initial state', () async {
      final sampleShift = EmployeeShiftEntity(
        shiftInstanceId: 'shift-001',
        businessDate: '2026-10-17',
        startsAt: DateTime.parse('2026-10-17T08:00:00Z'),
        endsAt: DateTime.parse('2026-10-17T16:00:00Z'),
        branchName: 'الفرع الرئيسي',
        state: 'completed',
      );

      when(() => repository.listMyShiftInstances(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => [sampleShift]);

      final cubit = AttendanceCorrectionCubit(
        repository: repository,
        shiftRepository: repository,
      );

      await cubit.loadPastShifts(
        startDate: '2026-10-01',
        endDate: '2026-10-17',
      );

      expect(cubit.state, isA<AttendanceCorrectionInitial>());
      final initial = cubit.state as AttendanceCorrectionInitial;
      expect(initial.shifts.length, 1);
      expect(initial.shifts.first.shiftInstanceId, 'shift-001');
    });

    test('uploadEvidence attaches uploaded file metadata to state', () async {
      final attachment = RequestAttachmentEntity(
        id: 'att-101',
        displayName: 'medical_report.pdf',
        mediaType: 'application/pdf',
        sizeBytes: 20480,
        state: 'ready',
        expiresAt: DateTime.parse('2026-10-20T00:00:00Z'),
      );

      when(() => repository.uploadAttachment(
            bytes: any(named: 'bytes'),
            filename: any(named: 'filename'),
            mediaType: any(named: 'mediaType'),
          )).thenAnswer((_) async => attachment);

      final cubit = AttendanceCorrectionCubit(
        repository: repository,
        shiftRepository: repository,
      );

      await cubit.uploadEvidence(
        bytes: [1, 2, 3],
        filename: 'medical_report.pdf',
        mediaType: 'application/pdf',
      );

      expect(cubit.state, isA<AttendanceCorrectionInitial>());
      final initial = cubit.state as AttendanceCorrectionInitial;
      expect(initial.attachment, isNotNull);
      expect(initial.attachment?.id, 'att-101');

      cubit.clearEvidence();
      final cleared = cubit.state as AttendanceCorrectionInitial;
      expect(cleared.attachment, isNull);
    });

    test('submitCorrection emits success for pair correction with evidence',
        () async {
      final req = RequestEntity(
        id: 'req-corr-001',
        employeeId: 'emp-01',
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
          )).thenAnswer((_) async => req);

      final cubit = AttendanceCorrectionCubit(
        repository: repository,
        shiftRepository: repository,
      );

      await cubit.submitCorrection(
        shiftInstanceId: 'shift-001',
        correctionKind: 'both',
        proposedCheckInAt: DateTime.parse('2026-10-17T08:00:00Z'),
        proposedCheckOutAt: DateTime.parse('2026-10-17T16:00:00Z'),
        evidenceAttachmentId: 'att-101',
        reason: 'عطل مفاجئ في جهاز البصمة مع إرفاق التقرير',
      );

      expect(cubit.state, isA<AttendanceCorrectionSuccess>());
      final success = cubit.state as AttendanceCorrectionSuccess;
      expect(success.isQueuedOffline, isFalse);
      expect(success.request.id, 'req-corr-001');
    });

    test(
        'submitCorrection maps conflict to AttendanceCorrectionError with isConflict=true',
        () async {
      when(() => repository.submitRequest(
            requestId: any(named: 'requestId'),
            type: RequestType.attendanceCorrection,
            payload: any(named: 'payload'),
          )).thenThrow(const ConflictFailure('طلب تصحيح مكرر للوردية المحددة'));

      final cubit = AttendanceCorrectionCubit(
        repository: repository,
        shiftRepository: repository,
      );

      await cubit.submitCorrection(
        shiftInstanceId: 'shift-001',
        correctionKind: 'add_check_in',
        proposedAt: DateTime.parse('2026-10-17T08:00:00Z'),
        reason: 'نسيان تسجيل الحضور صباحاً',
      );

      expect(cubit.state, isA<AttendanceCorrectionError>());
      final error = cubit.state as AttendanceCorrectionError;
      expect(error.isConflict, isTrue);
      expect(error.message, contains('طلب تصحيح مكرر'));
    });
  });
}
