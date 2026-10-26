// ignore_for_file: avoid_print
// Physical device acceptance test for Feature 016 Dynamic HR Operations (T037, T051, T062).
// Exercises Arabic RTL flows on connected Android device at 100% and 200% text scale.
// Run with: flutter test integration_test/dynamic_hr_operations_device_test.dart -d 10JE1B00ZB000E8

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_models.dart';
import 'package:attend_mobile/features/hr_operations/domain/hr_operations_repository.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/field_mission_detail_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/disciplinary_case_detail_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/cubit/clearance_case_detail_cubit.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/field_mission_detail_screen.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/field_mission_list_screen.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/disciplinary_case_detail_screen.dart';
import 'package:attend_mobile/features/hr_operations/presentation/screens/resignation_clearance_detail_screen.dart';

class _DeviceHrOperationsRepo implements HrOperationsRepository {
  final List<HrOperationSummary> missionSummaries = [
    HrOperationSummary(
      id: 'op-dev-mis-1',
      operationKind: OperationKind.fieldMission,
      employeeId: 'emp-v2254-001',
      employeeName: 'محمد أحمد المصطفى',
      state: 'active',
      revision: 2,
      submittedAt: DateTime.utc(2026, 10, 17, 8, 30),
      nextActionLabelAr: 'مأمورية عمل سارية في موقع العميل',
    ),
  ];

  late HrOperationDetail missionDetail;
  late HrOperationDetail disciplinaryDetail;
  late HrOperationDetail clearanceDetail;

  _DeviceHrOperationsRepo() {
    missionDetail = HrOperationDetail(
      id: 'op-dev-mis-1',
      operationKind: OperationKind.fieldMission,
      employeeId: 'emp-v2254-001',
      employeeName: 'محمد أحمد المصطفى',
      state: 'active',
      revision: 2,
      submittedAt: DateTime.utc(2026, 10, 17, 8, 30),
      nextActionLabelAr: 'مأمورية سارية المفعول',
      fieldMission: FieldMissionDetail(
        startsAt: DateTime(2026, 10, 17, 9, 0),
        endsAt: DateTime(2026, 10, 17, 17, 0),
        timezone: 'Africa/Cairo',
        purpose: 'زيارة موقع العميل لإجراء المعاينة الفنية الميدانية',
        destination: const FieldMissionDestination(
          label: 'مشروع العاصمة الإدارية - موقع العميل',
          latitude: 30.0131,
          longitude: 31.4289,
          radiusMeters: 300,
        ),
        authorizationState: MissionAuthorizationState.active,
      ),
      permissions: const ['revoke_mission'],
      timeline: [
        TimelineItem(
          id: 'tl-d-1',
          kind: 'approved',
          occurredAt: DateTime.utc(2026, 10, 17, 8, 45),
          labelAr: 'تم اعتماد المأمورية ومنح استثناء النطاق الجغرافي المؤقت',
          actorLabel: 'مدير العمليات الميدانية',
        ),
      ],
    );

    disciplinaryDetail = HrOperationDetail(
      id: 'op-dev-disc-1',
      operationKind: OperationKind.disciplinaryCase,
      employeeId: 'emp-v2254-001',
      employeeName: 'محمد أحمد المصطفى',
      state: 'notice_delivered',
      revision: 1,
      submittedAt: DateTime.utc(2026, 10, 16, 14, 0),
      nextActionLabelAr: 'مطلوب تأكيد العلم والاستلام',
      disciplinary: DisciplinaryDetail(
        policyTitle: 'إشعار إداري بلائحة الالتزام بمواعيد العمل',
        incidentAt: DateTime(2026, 10, 15, 9, 30),
        noticeRevision: 1,
        acknowledgmentState: 'not_acknowledged',
        grievanceDueAt: DateTime(2026, 10, 26, 23, 59),
        consequenceState: 'proposed',
      ),
      permissions: const ['acknowledge_notice', 'submit_grievance'],
      timeline: [
        TimelineItem(
          id: 'tl-d-2',
          kind: 'notice_delivered',
          occurredAt: DateTime.utc(2026, 10, 16, 14, 0),
          labelAr: 'تم تسليم الإشعار الإداري رسمياً للموظف',
          actorLabel: 'إدارة الموارد البشرية',
        ),
      ],
    );

    clearanceDetail = HrOperationDetail(
      id: 'op-dev-clr-1',
      operationKind: OperationKind.clearance,
      employeeId: 'emp-v2254-001',
      employeeName: 'محمد أحمد المصطفى',
      state: 'clearance_in_progress',
      revision: 2,
      submittedAt: DateTime.utc(2026, 10, 15, 10, 0),
      nextActionLabelAr: 'استيفاء بنود العهد المتبقية',
      resignation: ResignationDetail(
        requestedLastWorkingDate: DateTime(2026, 11, 15),
        approvedLastWorkingDate: DateTime(2026, 11, 15),
        noticeDays: 30,
        state: 'accepted',
      ),
      clearance: ClearanceCase(
        id: 'case-dev-clr-1',
        employeeId: 'emp-v2254-001',
        state: 'in_progress',
        revision: 2,
        targetLastWorkingDate: DateTime(2026, 11, 15),
        items: const [
          ClearanceItem(
            id: 'it-dev-1',
            titleAr: 'تسليم جهاز اللابتوب وملحقاته',
            mandatory: true,
            evidenceRequired: true,
            state: 'pending',
            revision: 1,
            assigneeLabel: 'إدارة تكنولوجيا المعلومات',
          ),
          ClearanceItem(
            id: 'it-dev-2',
            titleAr: 'تسليم بطاقة الدخول وبطاقة التأمين',
            mandatory: true,
            evidenceRequired: false,
            state: 'completed',
            revision: 1,
            assigneeLabel: 'الشؤون الإدارية',
          ),
        ],
      ),
      permissions: const ['decide_clearance_item', 'finalize_clearance'],
      timeline: [
        TimelineItem(
          id: 'tl-d-3',
          kind: 'clearance_started',
          occurredAt: DateTime.utc(2026, 10, 15, 10, 0),
          labelAr: 'بدء مرحلة إخلاء الطرف وتوزيع بنود العهد على الأقسام',
          actorLabel: 'مسؤول الموارد البشرية',
        ),
      ],
    );
  }

  @override
  Future<List<HrOperationSummary>> listOperations({
    OperationKind? kind,
    String? state,
    String? cursor,
    int limit = 25,
  }) async {
    return missionSummaries;
  }

  @override
  Future<HrOperationDetail> getOperationDetail(String operationId) async {
    if (operationId == 'op-dev-mis-1') return missionDetail;
    if (operationId == 'op-dev-disc-1') return disciplinaryDetail;
    return clearanceDetail;
  }

  @override
  Future<FieldMissionDetail> revokeFieldMission({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    final updated = FieldMissionDetail(
      startsAt: missionDetail.fieldMission!.startsAt,
      endsAt: missionDetail.fieldMission!.endsAt,
      timezone: missionDetail.fieldMission!.timezone,
      purpose: missionDetail.fieldMission!.purpose,
      destination: missionDetail.fieldMission!.destination,
      authorizationState: MissionAuthorizationState.revoked,
    );
    missionDetail = HrOperationDetail(
      id: missionDetail.id,
      operationKind: missionDetail.operationKind,
      employeeId: missionDetail.employeeId,
      employeeName: missionDetail.employeeName,
      state: 'revoked',
      revision: expectedRevision + 1,
      submittedAt: missionDetail.submittedAt,
      fieldMission: updated,
      timeline: [
        ...missionDetail.timeline,
        TimelineItem(
          id: commandId,
          kind: 'mission_revoked',
          occurredAt: DateTime.now(),
          labelAr: 'تم إلغاء المأمورية: $reason',
          actorLabel: 'الإدارة',
        ),
      ],
    );
    return updated;
  }

  @override
  Future<Acknowledgment> acknowledgeDisciplinaryNotice({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required int noticeRevision,
  }) async {
    return Acknowledgment(
      id: commandId,
      noticeRevision: noticeRevision,
      acknowledgedAt: DateTime.now(),
      meaning: 'receipt_only',
    );
  }

  @override
  Future<Grievance> submitDisciplinaryGrievance({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String statement,
    List<String>? attachmentIds,
  }) async {
    return Grievance(
      id: commandId,
      state: 'submitted',
      submittedAt: DateTime.now(),
      deadlineState: 'on_time',
      statement: statement,
    );
  }

  @override
  Future<ConsequencePreview> previewDisciplinaryConsequence({
    required String operationId,
    required String method,
    num? value,
  }) async {
    return const ConsequencePreview(
      postingState: 'not_posted',
      method: 'fixed',
      amountMinor: 25000,
      currency: 'EGP',
      explanationAr: 'مقترح خصم جزاء غير منشور للرواتب بعد',
    );
  }

  @override
  Future<ConsequenceDecision> decideDisciplinaryConsequence({
    required String operationId,
    required String commandId,
    required int expectedRevision,
    required String decision,
    required String reason,
    String? payrollCycleId,
    required String method,
    num? value,
  }) async {
    return ConsequenceDecision(
      id: commandId,
      state: decision == 'approve' ? 'approved' : 'waived',
      amountMinor: 25000,
      currency: 'EGP',
      decidedAt: DateTime.now(),
    );
  }

  @override
  Future<ClearanceItem> decideClearanceItem({
    required String caseId,
    required String itemId,
    required String commandId,
    required int expectedRevision,
    required String action,
    required String reason,
    String? assignedMembershipId,
    String? evidenceAttachmentId,
  }) async {
    return ClearanceItem(
      id: itemId,
      titleAr: 'تسليم جهاز اللابتوب وملحقاته',
      mandatory: true,
      evidenceRequired: true,
      state: 'completed',
      revision: expectedRevision + 1,
      assigneeLabel: 'إدارة تكنولوجيا المعلومات',
    );
  }

  @override
  Future<ClearanceCase> finalizeClearance({
    required String caseId,
    required String commandId,
    required int expectedRevision,
    required String reason,
  }) async {
    return ClearanceCase(
      id: caseId,
      employeeId: 'emp-v2254-001',
      state: 'completed',
      revision: expectedRevision + 1,
      items: clearanceDetail.clearance!.items,
    );
  }
}

Widget _buildDeviceHarness({
  required Widget child,
  required _DeviceHrOperationsRepo repo,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: RepositoryProvider<HrOperationsRepository>.value(
          value: repo,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _DeviceHrOperationsRepo repo;

  setUp(() {
    repo = _DeviceHrOperationsRepo();
  });

  group('Feature 016 Dynamic HR Operations Device Acceptance', () {
    testWidgets(
        'T037 [US1]: Field Mission journey at 100% and 200% scale on Vivo V2254',
        (tester) async {
      print('=== STARTING T037 FIELD MISSION DEVICE TEST ===');

      // 1. Render Mission List
      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        child: FieldMissionListScreen(repository: repo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مأموريات العمل الميدانية'), findsOneWidget);
      expect(find.text('محمد أحمد المصطفى'), findsOneWidget);
      expect(find.text('سارية'), findsOneWidget);
      print('[T037-1] Mission List rendered successfully');

      // 2. Render Mission Detail
      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        child: BlocProvider(
          create: (_) => FieldMissionDetailCubit(repository: repo)
            ..loadDetail('op-dev-mis-1'),
          child: const FieldMissionDetailScreen(operationId: 'op-dev-mis-1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مشروع العاصمة الإدارية - موقع العميل'), findsOneWidget);
      expect(find.text('معتمدة وسارية'), findsOneWidget);
      expect(
          find.textContaining(
              'الاستثناء الجغرافي يسري فقط خلال التوقيت المعتمد'),
          findsOneWidget);
      print('[T037-2] Mission Detail and server safeguards notice verified');

      // 3. Test 200% text scale without overflow
      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        textScale: 2.0,
        child: BlocProvider(
          create: (_) => FieldMissionDetailCubit(repository: repo)
            ..loadDetail('op-dev-mis-1'),
          child: const FieldMissionDetailScreen(operationId: 'op-dev-mis-1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('مشروع العاصمة الإدارية - موقع العميل'), findsOneWidget);
      expect(tester.takeException(), isNull);
      print(
          '[T037-3] 200% text scale renders cleanly without RenderFlex overflow');

      print('=== COMPLETED T037 FIELD MISSION DEVICE TEST ===');
    });

    testWidgets(
        'T051 [US2]: Disciplinary Notice & Grievance journey on Vivo V2254',
        (tester) async {
      print('=== STARTING T051 DISCIPLINARY NOTICE DEVICE TEST ===');

      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        child: BlocProvider(
          create: (_) => DisciplinaryCaseDetailCubit(repository: repo)
            ..loadDetail('op-dev-disc-1'),
          child:
              const DisciplinaryCaseDetailScreen(operationId: 'op-dev-disc-1'),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify legal receipt semantics
      expect(
        find.textContaining('تأكيد الاستلام يُعد إقراراً بالعلم بالواقعة فقط'),
        findsOneWidget,
      );

      // Verify truthful non-posting consequence badge
      expect(find.text('مقترح غير مخصوم'), findsOneWidget);
      expect(find.text('مخصوم من الراتب'), findsNothing);
      print(
          '[T051-1] Receipt-only copy and non-posting deduction badge verified');

      // Verify at 200% text scale
      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        textScale: 2.0,
        child: BlocProvider(
          create: (_) => DisciplinaryCaseDetailCubit(repository: repo)
            ..loadDetail('op-dev-disc-1'),
          child:
              const DisciplinaryCaseDetailScreen(operationId: 'op-dev-disc-1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('إقرار الاستلام والعلم'), findsOneWidget);
      expect(tester.takeException(), isNull);
      print(
          '[T051-2] Disciplinary Case at 200% scale verified without overflow');

      print('=== COMPLETED T051 DISCIPLINARY NOTICE DEVICE TEST ===');
    });

    testWidgets('T062 [US3]: Resignation & Clearance journey on Vivo V2254',
        (tester) async {
      print('=== STARTING T062 RESIGNATION & CLEARANCE DEVICE TEST ===');

      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        child: BlocProvider(
          create: (_) => ClearanceCaseDetailCubit(repository: repo)
            ..loadDetail('op-dev-clr-1'),
          child: const ResignationClearanceDetailScreen(
              operationId: 'op-dev-clr-1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تسليم جهاز اللابتوب وملحقاته'), findsOneWidget);
      expect(find.text('تسليم بطاقة الدخول وبطاقة التأمين'), findsOneWidget);
      expect(find.text('1 من 2'), findsOneWidget);
      expect(find.textContaining('تظل حالة التوظيف والصلاحيات نشطة'),
          findsOneWidget);
      print(
          '[T062-1] Clearance progress and active employment invariants verified');

      // Verify at 200% scale
      await tester.pumpWidget(_buildDeviceHarness(
        repo: repo,
        textScale: 2.0,
        child: BlocProvider(
          create: (_) => ClearanceCaseDetailCubit(repository: repo)
            ..loadDetail('op-dev-clr-1'),
          child: const ResignationClearanceDetailScreen(
              operationId: 'op-dev-clr-1'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تسليم جهاز اللابتوب وملحقاته'), findsOneWidget);
      expect(tester.takeException(), isNull);
      print('[T062-2] Resignation & Clearance at 200% scale verified cleanly');

      print('=== COMPLETED T062 RESIGNATION & CLEARANCE DEVICE TEST ===');
    });
  });
}
