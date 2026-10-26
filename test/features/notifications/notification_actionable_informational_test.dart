import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_state.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_center_screen.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

Widget buildTestApp({
  required Widget child,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
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
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScaleFactor),
          size: const Size(400, 800),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(NotificationDestinationKind.attendance);
  });

  late MockNotificationRepository mockRepo;
  late NotificationCubit cubit;

  final testDate = DateTime.parse('2026-10-21T09:00:00Z');

  final informationalEmployeeItem = NotificationEntity(
    id: 'notif-emp-1',
    kind: 'employee_invited',
    titleKey: 'notification.employee.invited.title',
    bodyKey: 'notification.employee.invited.body',
    destinationKind: NotificationDestinationKind.employee,
    destinationId: 'emp-101',
    readState: NotificationReadState.unread,
    createdAt: testDate,
  );

  final informationalEmptyDestinationItem = NotificationEntity(
    id: 'notif-empty-dest',
    kind: 'system_notice',
    titleKey: 'notification.employee.archived.title',
    bodyKey: 'notification.employee.archived.body',
    destinationKind: NotificationDestinationKind.attendance,
    destinationId: '',
    readState: NotificationReadState.unread,
    createdAt: testDate,
  );

  final actionableRequestItem = NotificationEntity(
    id: 'notif-req-1',
    kind: 'request_submitted',
    titleKey: 'notification.request.submitted.title',
    bodyKey: 'notification.request.submitted.body',
    destinationKind: NotificationDestinationKind.request,
    destinationId: 'req-202',
    readState: NotificationReadState.unread,
    createdAt: testDate,
  );

  setUp(() {
    mockRepo = MockNotificationRepository();
    cubit = NotificationCubit(repository: mockRepo);
  });

  tearDown(() {
    cubit.close();
  });

  group('A. Notification Actionable vs Informational Classification', () {
    test('1. employee destination is classified as informational (!isActionable)', () {
      expect(informationalEmployeeItem.isActionable, isFalse);
    });

    test('2. empty destination ID is classified as informational (!isActionable)', () {
      expect(informationalEmptyDestinationItem.isActionable, isFalse);
    });

    test('3. valid destinations with IDs are classified as actionable', () {
      for (final kind in [
        NotificationDestinationKind.attendance,
        NotificationDestinationKind.request,
        NotificationDestinationKind.approval,
        NotificationDestinationKind.report,
        NotificationDestinationKind.announcement,
        NotificationDestinationKind.finalSettlement,
      ]) {
        final item = NotificationEntity(
          id: 'test-1',
          kind: 'test',
          titleKey: 'test.title',
          bodyKey: 'test.body',
          destinationKind: kind,
          destinationId: 'id-1',
          readState: NotificationReadState.unread,
          createdAt: testDate,
        );
        expect(item.isActionable, isTrue, reason: 'Kind $kind should be actionable');
      }
    });

    test('4. tapping informational item marks read, decrements unread count, does not navigate or error',
        () async {
      when(() => mockRepo.listNotifications(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => NotificationPageEntity(
                items: [informationalEmployeeItem],
              ));
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);
      when(() => mockRepo.markAsRead('notif-emp-1')).thenAnswer(
        (_) async => informationalEmployeeItem.copyWith(
          readState: NotificationReadState.read,
          readAt: DateTime.now(),
        ),
      );

      await cubit.loadNotifications();

      bool didNavigate = false;
      await cubit.openNotification(
        item: informationalEmployeeItem,
        onAuthorizedNavigation: (_, __, ___) {
          didNavigate = true;
        },
      );

      expect(didNavigate, isFalse, reason: 'Informational item must not navigate');
      verify(() => mockRepo.markAsRead('notif-emp-1')).called(1);
      verifyNever(() => mockRepo.reauthorizeDestination(any(), any()));

      final state = cubit.state;
      expect(state, isA<NotificationLoaded>());
      final loaded = state as NotificationLoaded;
      expect(loaded.unreadCount, equals(0));
      expect(loaded.actionError, isNull,
          reason: 'Informational item tap must never emit actionError');
      expect(loaded.notifications.first.isRead, isTrue);
    });

    test('5. tapping actionable item reauthorizes destination before navigation',
        () async {
      when(() => mockRepo.listNotifications(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => NotificationPageEntity(
                items: [actionableRequestItem],
              ));
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);
      when(() => mockRepo.markAsRead('notif-req-1')).thenAnswer(
        (_) async => actionableRequestItem.copyWith(
          readState: NotificationReadState.read,
          readAt: DateTime.now(),
        ),
      );
      when(() => mockRepo.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-202',
          )).thenAnswer((_) async => ReauthorizationResult.authorized);

      await cubit.loadNotifications();

      bool didNavigate = false;
      String? navigatedId;
      await cubit.openNotification(
        item: actionableRequestItem,
        onAuthorizedNavigation: (kind, id, _) {
          didNavigate = true;
          navigatedId = id;
        },
      );

      expect(didNavigate, isTrue);
      expect(navigatedId, equals('req-202'));
      verify(() => mockRepo.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-202',
          )).called(1);
    });

    test('6. failed actionable reauthorization emits retryable error in cubit',
        () async {
      when(() => mockRepo.listNotifications(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => NotificationPageEntity(
                items: [actionableRequestItem],
              ));
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);
      when(() => mockRepo.markAsRead('notif-req-1')).thenAnswer(
        (_) async => actionableRequestItem.copyWith(
          readState: NotificationReadState.read,
        ),
      );
      when(() => mockRepo.reauthorizeDestination(any(), any()))
          .thenAnswer((_) async => ReauthorizationResult.forbidden);

      await cubit.loadNotifications();

      bool didNavigate = false;
      await cubit.openNotification(
        item: actionableRequestItem,
        onAuthorizedNavigation: (_, __, ___) {
          didNavigate = true;
        },
      );

      expect(didNavigate, isFalse);
      final loaded = cubit.state as NotificationLoaded;
      expect(loaded.actionError, equals('لم تعد لديك صلاحية فتح هذه الوجهة.'));
    });
  });

  group('B. NotificationCenterScreen Feedback Scoping & UI', () {
    testWidgets('7. navigating away / popping clears feedback error',
        (tester) async {
      when(() => mockRepo.listNotifications(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => NotificationPageEntity(
                items: [actionableRequestItem],
              ));
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);
      when(() => mockRepo.markAsRead(any())).thenAnswer((_) async =>
          actionableRequestItem.copyWith(readState: NotificationReadState.read));
      when(() => mockRepo.reauthorizeDestination(any(), any()))
          .thenAnswer((_) async => ReauthorizationResult.forbidden);

      await cubit.loadNotifications();

      await tester.pumpWidget(buildTestApp(
        child: Navigator(
          onGenerateRoute: (settings) => NotificationCenterScreen.route(
            cubit: cubit,
            repository: mockRepo,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap card to trigger error
      final cardFinder = find.byKey(Key('notification_item_${actionableRequestItem.id}'));
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.text('لم تعد لديك صلاحية فتح هذه الوجهة.'), findsOneWidget);

      // Now pop the route
      Navigator.of(tester.element(find.byType(NotificationCenterScreen))).pop();
      await tester.pumpAndSettle();

      // Action error is cleared
      final loaded = cubit.state as NotificationLoaded;
      expect(loaded.actionError, isNull,
          reason: 'Leaving NotificationCenterScreen must clear actionError');
    });

    testWidgets('8. Arabic translations for invited, scheduled, archived keys render properly',
        (tester) async {
      final scheduledItem = NotificationEntity(
        id: 'notif-sched',
        kind: 'assignment_scheduled',
        titleKey: 'notification.assignment.scheduled.title',
        bodyKey: 'notification.assignment.scheduled.body',
        destinationKind: NotificationDestinationKind.attendance,
        destinationId: 'att-1',
        readState: NotificationReadState.read,
        createdAt: testDate,
      );

      final archivedItem = NotificationEntity(
        id: 'notif-arch',
        kind: 'employee_archived',
        titleKey: 'notification.employee.archived.title',
        bodyKey: 'notification.employee.archived.body',
        destinationKind: NotificationDestinationKind.employee,
        destinationId: 'emp-arch',
        readState: NotificationReadState.read,
        createdAt: testDate,
      );

      when(() => mockRepo.listNotifications(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => NotificationPageEntity(
                items: [
                  informationalEmployeeItem,
                  scheduledItem,
                  archivedItem,
                ],
              ));
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);

      await cubit.loadNotifications();

      await tester.pumpWidget(buildTestApp(
        child: BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: RepositoryProvider<NotificationRepository>.value(
            value: mockRepo,
            child: const NotificationCenterScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify exact Arabic titles are rendered
      expect(find.text('دعوة موظف جديد'), findsOneWidget);
      expect(find.text('تكليف وظيفي جديد'), findsOneWidget);
      expect(find.text('أرشفة موظف'), findsOneWidget);
      expect(find.text('إشعار جديد'), findsNothing);
    });

    testWidgets('9. 200% text scale in RTL renders without overflow',
        (tester) async {
      when(() => mockRepo.listNotifications(
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => NotificationPageEntity(
                items: [informationalEmployeeItem],
              ));
      when(() => mockRepo.getUnreadCount()).thenAnswer((_) async => 1);

      await cubit.loadNotifications();

      await tester.pumpWidget(buildTestApp(
        textScaleFactor: 2.0,
        child: BlocProvider<NotificationCubit>.value(
          value: cubit,
          child: RepositoryProvider<NotificationRepository>.value(
            value: mockRepo,
            child: const NotificationCenterScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('دعوة موظف جديد'), findsOneWidget);
    });
  });
}
