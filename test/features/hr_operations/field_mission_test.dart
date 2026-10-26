import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/errors/app_failure.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_models.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_repository.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/field_mission_detail_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/field_mission_list_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/field_mission_detail_screen.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/field_mission_list_screen.dart';
import 'package:attend_mobile/features/hr_operations/presentation/widgets/revoke_mission_dialog.dart';

class MockHrOperationsRepository extends Mock
    implements HrOperationsRepository {}

void main() {
  late MockHrOperationsRepository mockRepository;

  final sampleMission = FieldMissionDetail(
    startsAt: DateTime(2026, 10, 18, 9, 0),
    endsAt: DateTime(2026, 10, 18, 17, 0),
    timezone: 'Africa/Cairo',
    purpose: 'زيارة موقع العميل لإجراء المعاينة الفنية الميدانية',
    destination: const FieldMissionDestination(
      label: 'موقع العميل - التجمع الخامس',
      latitude: 30.0131,
      longitude: 31.4289,
      radiusMeters: 250,
    ),
    authorizationState: MissionAuthorizationState.active,
  );

  final sampleDetail = HrOperationDetail(
    id: 'op-mission-123',
    operationKind: OperationKind.fieldMission,
    employeeId: 'emp-456',
    employeeName: 'أحمد محمود',
    state: 'active',
    revision: 2,
    submittedAt: DateTime(2026, 10, 17, 10, 30),
    nextActionLabelAr: 'المأمورية سارية المفعول',
    fieldMission: sampleMission,
    permissions: const ['revoke_mission'],
    timeline: [
      TimelineItem(
        id: 'tl-1',
        kind: 'submitted',
        occurredAt: DateTime(2026, 10, 17, 10, 30),
        labelAr: 'تم تقديم طلب المأمورية',
        actorLabel: 'أحمد محمود',
      ),
      TimelineItem(
        id: 'tl-2',
        kind: 'approved',
        occurredAt: DateTime(2026, 10, 17, 11, 0),
        labelAr: 'تم اعتماد المأمورية وتفعيل النطاق الجغرافي',
        actorLabel: 'مدير الموقع',
      ),
    ],
  );

  final sampleSummary = HrOperationSummary(
    id: 'op-mission-123',
    operationKind: OperationKind.fieldMission,
    employeeId: 'emp-456',
    employeeName: 'أحمد محمود',
    state: 'active',
    revision: 2,
    submittedAt: DateTime(2026, 10, 17, 10, 30),
    nextActionLabelAr: 'المأمورية سارية',
  );

  setUp(() {
    mockRepository = MockHrOperationsRepository();
  });

  group('FieldMission Cubit Tests', () {
    test('FieldMissionDetailCubit emits loaded state on success', () async {
      when(() => mockRepository.getOperationDetail('op-mission-123'))
          .thenAnswer((_) async => sampleDetail);

      final cubit = FieldMissionDetailCubit(repository: mockRepository);

      expect(
        cubit.stream,
        emitsInOrder([
          const FieldMissionDetailLoading(),
          FieldMissionDetailLoaded(detail: sampleDetail),
        ]),
      );

      await cubit.loadDetail('op-mission-123');
      await cubit.close();
    });

    test('FieldMissionDetailCubit emits forbidden state when unauthorized',
        () async {
      when(() => mockRepository.getOperationDetail('op-mission-123'))
          .thenThrow(const AuthFailure('غير مصرح لك بالاطلاع على هذا السجل.'));

      final cubit = FieldMissionDetailCubit(repository: mockRepository);

      expect(
        cubit.stream,
        emitsInOrder([
          const FieldMissionDetailLoading(),
          const FieldMissionDetailForbidden(
              'غير مصرح لك بالاطلاع على هذا السجل.'),
        ]),
      );

      await cubit.loadDetail('op-mission-123');
      await cubit.close();
    });

    test('FieldMissionDetailCubit revokes mission successfully', () async {
      final revokedMission = FieldMissionDetail(
        startsAt: sampleMission.startsAt,
        endsAt: sampleMission.endsAt,
        timezone: sampleMission.timezone,
        purpose: sampleMission.purpose,
        destination: sampleMission.destination,
        authorizationState: MissionAuthorizationState.revoked,
      );

      when(() => mockRepository.getOperationDetail('op-mission-123'))
          .thenAnswer((_) async => sampleDetail);
      when(() => mockRepository.revokeFieldMission(
            operationId: 'op-mission-123',
            commandId: any(named: 'commandId'),
            expectedRevision: 2,
            reason: 'إلغاء الزيارة بناء على طلب العميل',
          )).thenAnswer((_) async => revokedMission);

      final cubit = FieldMissionDetailCubit(repository: mockRepository);
      await cubit.loadDetail('op-mission-123');

      await cubit.revokeMission(
        operationId: 'op-mission-123',
        commandId: 'cmd-999',
        expectedRevision: 2,
        reason: 'إلغاء الزيارة بناء على طلب العميل',
      );

      expect(cubit.state, isA<FieldMissionDetailLoaded>());
      final loaded = cubit.state as FieldMissionDetailLoaded;
      expect(loaded.detail.state, 'revoked');
      expect(loaded.detail.fieldMission?.authorizationState,
          MissionAuthorizationState.revoked);
      await cubit.close();
    });

    test('FieldMissionListCubit loads missions and filters', () async {
      when(() => mockRepository.listOperations(
            kind: OperationKind.fieldMission,
            state: null,
          )).thenAnswer((_) async => [sampleSummary]);

      final cubit = FieldMissionListCubit(repository: mockRepository);

      expect(
        cubit.stream,
        emitsInOrder([
          const FieldMissionListLoading(),
          FieldMissionListLoaded(items: [sampleSummary]),
        ]),
      );

      await cubit.loadMissions();
      await cubit.close();
    });
  });

  group('FieldMission Widget Tests', () {
    testWidgets(
        'Detail screen displays destination, times, and safeguards notice',
        (tester) async {
      when(() => mockRepository.getOperationDetail('op-mission-123'))
          .thenAnswer((_) async => sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => FieldMissionDetailCubit(repository: mockRepository)
              ..loadDetail('op-mission-123'),
            child:
                const FieldMissionDetailScreen(operationId: 'op-mission-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('موقع العميل - التجمع الخامس'), findsOneWidget);
      expect(find.text('250 متر'), findsOneWidget);
      expect(
          find.textContaining(
              'الاستثناء الجغرافي يسري فقط خلال التوقيت المعتمد'),
          findsOneWidget);
      expect(find.text('معتمدة وسارية'), findsOneWidget);
      expect(find.text('إلغاء المأمورية الإدارية'), findsOneWidget);
    });

    testWidgets('Revocation dialog validates minimum 3 characters for reason',
        (tester) async {
      var wasCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RevokeMissionDialog(
              operationId: 'op-mission-123',
              expectedRevision: 2,
              onRevoke: ({
                required commandId,
                required expectedRevision,
                required reason,
              }) async {
                wasCalled = true;
              },
            ),
          ),
        ),
      );

      // Tap confirm without reason
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى كتابة سبب الإلغاء بوضوح (3 أحرف على الأقل).'),
          findsOneWidget);
      expect(wasCalled, isFalse);

      // Enter valid reason
      await tester.enterText(
          find.byType(TextField), 'تم تأجيل زيارة الموقع بطلب رسمي');
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
    });

    testWidgets(
        'Detail screen renders correctly at 200% font scale without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      when(() => mockRepository.getOperationDetail('op-mission-123'))
          .thenAnswer((_) async => sampleDetail);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: BlocProvider(
            create: (_) => FieldMissionDetailCubit(repository: mockRepository)
              ..loadDetail('op-mission-123'),
            child:
                const FieldMissionDetailScreen(operationId: 'op-mission-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('موقع العميل - التجمع الخامس'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        debugPrint('FLUTTER_ERROR_DETAILS: ${err.toStringDeep()}');
      }
      expect(err, isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });

    testWidgets('List screen renders summary cards and state chips',
        (tester) async {
      when(() => mockRepository.listOperations(
            kind: OperationKind.fieldMission,
            state: null,
          )).thenAnswer((_) async => [sampleSummary]);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => FieldMissionListCubit(repository: mockRepository)
              ..loadMissions(),
            child: FieldMissionListScreen(repository: mockRepository),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('أحمد محمود'), findsOneWidget);
      expect(find.text('سارية'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('السارية'), findsOneWidget);
    });
  });
}
