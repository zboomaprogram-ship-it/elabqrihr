import 'dart:async';
import 'package:test/test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/core/location/location_service.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:attend_mobile/features/attendance/presentation/cubit/attendance_state.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  Object? submitError;
  AttendanceValidationStatus? returnedStatus;
  Completer<AttendanceEventEntity>? pendingSubmission;
  int submissionCalls = 0;
  ShiftContextEntity currentContext = ShiftContextEntity(
    shiftInstanceId: 'shift-123',
    branchName: 'Cairo HQ',
    shiftName: 'Morning Shift',
    scheduledStart: DateTime.utc(2026, 9, 20, 8, 0),
    scheduledEnd: DateTime.utc(2026, 9, 20, 16, 0),
    branchLocation: const GeoPoint(latitude: 30.0444, longitude: 31.2357),
    allowedRadiusMeters: 150.0,
    isCheckedIn: false,
  );

  final _pendingController =
      StreamController<List<AttendanceEventEntity>>.broadcast();

  @override
  Future<ShiftContextEntity> getCurrentShiftContext() async => currentContext;

  @override
  Future<AttendanceEventEntity> submitAttendanceEvent({
    required AttendanceEventType eventType,
    required String shiftInstanceId,
    GeoPoint? location,
    String? clientEventId,
    DateTime? capturedAt,
  }) async {
    submissionCalls++;
    if (submitError != null) throw submitError!;
    if (pendingSubmission != null) return pendingSubmission!.future;
    final event = AttendanceEventEntity(
      id: clientEventId ?? 'evt-1',
      eventType: eventType,
      capturedAt: capturedAt ?? DateTime.now().toUtc(),
      location: location ?? const GeoPoint(latitude: 30.0, longitude: 31.0),
      shiftInstanceId: shiftInstanceId,
      status: returnedStatus ?? AttendanceValidationStatus.accepted,
    );
    currentContext = ShiftContextEntity(
      shiftInstanceId: shiftInstanceId,
      branchName: currentContext.branchName,
      shiftName: currentContext.shiftName,
      scheduledStart: currentContext.scheduledStart,
      scheduledEnd: currentContext.scheduledEnd,
      branchLocation: currentContext.branchLocation,
      allowedRadiusMeters: currentContext.allowedRadiusMeters,
      isCheckedIn: eventType == AttendanceEventType.checkIn,
      lastEvent: event,
    );
    return event;
  }

  @override
  Stream<List<AttendanceEventEntity>> watchPendingEvents() =>
      _pendingController.stream;

  @override
  Future<void> synchronizeOutbox() async {}
}

void main() {
  group('AttendanceCubit', () {
    test('initial state is AttendanceInitial', () {
      final cubit = AttendanceCubit();
      expect(cubit.state, equals(const AttendanceInitial()));
      cubit.close();
    });

    test('loadShiftContext emits Loading then Ready', () async {
      final repo = FakeAttendanceRepository();
      final cubit = AttendanceCubit(repo);

      expectLater(
        cubit.stream,
        emitsInOrder([
          isA<AttendanceLoading>(),
          isA<AttendanceReady>(),
        ]),
      );

      await cubit.loadShiftContext();
      expect((cubit.state as AttendanceReady).shiftContext.shiftInstanceId,
          equals('shift-123'));
      cubit.close();
    });

    test('recordEvent checkIn updates context to checked in', () async {
      final repo = FakeAttendanceRepository();
      final cubit = AttendanceCubit(repo);

      await cubit.loadShiftContext();
      cubit.updateLocation(const GeoPoint(
          latitude: 30.0445, longitude: 31.2358, accuracyMeters: 10));

      await cubit.recordEvent(eventType: AttendanceEventType.checkIn);

      final state = cubit.state as AttendanceReady;
      expect(state.shiftContext.isCheckedIn, isTrue);
      cubit.close();
    });

    test('blocks and explains a mock location without saving attendance',
        () async {
      final repo = FakeAttendanceRepository()
        ..submitError = const MockLocationDetectedException();
      final cubit = AttendanceCubit(repo);
      await cubit.loadShiftContext();

      await cubit.recordEvent(eventType: AttendanceEventType.checkIn);

      final state = cubit.state as AttendanceReady;
      expect(state.errorMessage, AppStringsAr.locationIntegrityFailed);
      expect(state.shiftContext.isCheckedIn, isFalse);
      await cubit.close();
    });

    test('keeps a terminal rejection visible without refreshing context',
        () async {
      final repo = FakeAttendanceRepository()
        ..returnedStatus = AttendanceValidationStatus.rejected;
      final cubit = AttendanceCubit(repo);
      await cubit.loadShiftContext();
      await cubit.recordEvent(eventType: AttendanceEventType.checkIn);
      final state = cubit.state as AttendanceReady;
      expect(state.shiftContext.lastEvent?.status,
          AttendanceValidationStatus.rejected);
      await cubit.close();
    });

    test('ignores a second attendance tap while the first submission is active',
        () async {
      final repo = FakeAttendanceRepository()
        ..pendingSubmission = Completer<AttendanceEventEntity>();
      final cubit = AttendanceCubit(repo);
      await cubit.loadShiftContext();

      final first = cubit.recordEvent(eventType: AttendanceEventType.checkIn);
      await Future<void>.delayed(Duration.zero);
      final second = cubit.recordEvent(eventType: AttendanceEventType.checkIn);
      await Future<void>.delayed(Duration.zero);

      expect(repo.pendingSubmission, isNotNull);
      expect(repo.submissionCalls, 1);
      repo.pendingSubmission!.complete(AttendanceEventEntity(
        id: 'evt-once',
        eventType: AttendanceEventType.checkIn,
        capturedAt: DateTime.utc(2026, 10, 6),
        location: const GeoPoint(latitude: 30, longitude: 31),
        shiftInstanceId: 'shift-123',
        status: AttendanceValidationStatus.pendingSync,
      ));
      await Future.wait([first, second]);
      expect((cubit.state as AttendanceReady).shiftContext.lastEvent?.id,
          'evt-once');
      await cubit.close();
    });

    test('copyWith retains values unless an explicit clear is requested', () {
      final state = AttendanceReady(
        shiftContext: FakeAttendanceRepository().currentContext,
        currentLocation: const GeoPoint(latitude: 30, longitude: 31),
        errorMessage: 'existing error',
      );
      expect(state.copyWith(isSubmitting: true).errorMessage, 'existing error');
      expect(state.copyWith(clearErrorMessage: true).errorMessage, isNull);
      expect(
          state.copyWith(clearCurrentLocation: true).currentLocation, isNull);
    });
  });
}
