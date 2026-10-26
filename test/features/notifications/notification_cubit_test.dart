import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_state.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late MockNotificationRepository repository;

  setUpAll(() {
    registerFallbackValue(NotificationDestinationKind.request);
  });

  setUp(() {
    repository = MockNotificationRepository();
  });

  final testDate = DateTime.parse('2026-09-26T10:00:00Z');

  final item1 = NotificationEntity(
    id: 'notif-1',
    kind: 'request_approved',
    titleKey: 'notification.request.approved.title',
    bodyKey: 'notification.request.approved.body',
    destinationKind: NotificationDestinationKind.request,
    destinationId: 'req-123',
    readState: NotificationReadState.unread,
    createdAt: testDate,
  );

  final item2 = NotificationEntity(
    id: 'notif-2',
    kind: 'attendance_accepted',
    titleKey: 'notification.attendance.accepted.title',
    bodyKey: 'notification.attendance.accepted.body',
    destinationKind: NotificationDestinationKind.attendance,
    destinationId: 'att-456',
    readState: NotificationReadState.read,
    readAt: testDate,
    createdAt: testDate,
  );

  group('NotificationCubit - Load and Refresh', () {
    test('initial state is NotificationInitial', () {
      final cubit = NotificationCubit(repository: repository);
      expect(cubit.state, equals(const NotificationInitial()));
      cubit.close();
    });

    blocTest<NotificationCubit, NotificationState>(
      'loadNotifications emits [NotificationLoading, NotificationLoaded] on success',
      build: () {
        when(() => repository.listNotifications(limit: any(named: 'limit')))
            .thenAnswer((_) async => NotificationPageEntity(
                  items: [item1, item2],
                  nextCursor: 'next-1',
                ));
        when(() => repository.getUnreadCount()).thenAnswer((_) async => 1);
        return NotificationCubit(repository: repository);
      },
      act: (cubit) => cubit.loadNotifications(),
      expect: () => [
        const NotificationLoading(),
        NotificationLoaded(
          notifications: [item1, item2],
          unreadCount: 1,
          nextCursor: 'next-1',
        ),
      ],
    );

    blocTest<NotificationCubit, NotificationState>(
      'loadNotifications emits [NotificationLoading, NotificationError] on failure',
      build: () {
        when(() => repository.listNotifications(limit: any(named: 'limit')))
            .thenThrow(Exception('Network timeout'));
        return NotificationCubit(repository: repository);
      },
      act: (cubit) => cubit.loadNotifications(),
      expect: () => [
        const NotificationLoading(),
        const NotificationError('تعذر تحميل الإشعارات. حاول مرة أخرى.'),
      ],
    );

    blocTest<NotificationCubit, NotificationState>(
      'refreshUnreadCount updates unreadCount in NotificationLoaded state',
      build: () {
        when(() => repository.getUnreadCount()).thenAnswer((_) async => 3);
        return NotificationCubit(repository: repository);
      },
      seed: () => NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
      ),
      act: (cubit) => cubit.refreshUnreadCount(),
      expect: () => [
        NotificationLoaded(
          notifications: [item1],
          unreadCount: 3,
        ),
      ],
    );
  });

  group('NotificationCubit - Monotonic Mark As Read', () {
    blocTest<NotificationCubit, NotificationState>(
      'markAsRead marks unread item as read and decrements count',
      build: () {
        final readItem1 = item1.copyWith(
          readState: NotificationReadState.read,
          readAt: testDate,
        );
        when(() => repository.markAsRead('notif-1'))
            .thenAnswer((_) async => readItem1);
        return NotificationCubit(repository: repository);
      },
      seed: () => NotificationLoaded(
        notifications: [item1, item2],
        unreadCount: 1,
      ),
      act: (cubit) => cubit.markAsRead('notif-1'),
      verify: (cubit) {
        verify(() => repository.markAsRead('notif-1')).called(1);
        final state = cubit.state as NotificationLoaded;
        expect(state.unreadCount, equals(0));
        expect(state.notifications.first.isRead, isTrue);
      },
    );

    blocTest<NotificationCubit, NotificationState>(
      'markAsRead on already-read item does not call repo or decrement count below 0',
      build: () => NotificationCubit(repository: repository),
      seed: () => NotificationLoaded(
        notifications: [item2],
        unreadCount: 0,
      ),
      act: (cubit) => cubit.markAsRead('notif-2'),
      expect: () => [],
      verify: (_) {
        verifyNever(() => repository.markAsRead(any()));
      },
    );

    blocTest<NotificationCubit, NotificationState>(
      'markAllAsRead marks all items read and resets count to 0',
      build: () {
        when(() => repository.markAllAsRead(
              commandId: any(named: 'commandId'),
              before: any(named: 'before'),
            )).thenAnswer((_) async => 1);
        return NotificationCubit(repository: repository);
      },
      seed: () => NotificationLoaded(
        notifications: [item1, item2],
        unreadCount: 1,
      ),
      act: (cubit) => cubit.markAllAsRead(),
      verify: (cubit) {
        verify(() => repository.markAllAsRead(
              commandId: any(named: 'commandId'),
              before: any(named: 'before'),
            )).called(1);
        final state = cubit.state as NotificationLoaded;
        expect(state.unreadCount, equals(0));
        expect(state.notifications.every((n) => n.isRead), isTrue);
      },
    );
  });

  group('NotificationCubit - Reauthorization', () {
    test('openNotification navigates when destination is authorized', () async {
      final readItem = item1.copyWith(
        readState: NotificationReadState.read,
        readAt: testDate,
      );
      when(() => repository.markAsRead('notif-1'))
          .thenAnswer((_) async => readItem);
      when(() => repository.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-123',
          )).thenAnswer((_) async => ReauthorizationResult.authorized);

      final cubit = NotificationCubit(repository: repository);
      cubit.emit(NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
      ));

      NotificationDestinationKind? navigatedKind;
      String? navigatedId;

      await cubit.openNotification(
        item: item1,
        onAuthorizedNavigation: (kind, id, _) {
          navigatedKind = kind;
          navigatedId = id;
        },
      );

      final state = cubit.state as NotificationLoaded;
      expect(state.actionError, isNull);
      expect(state.notifications.first.isRead, isTrue);
      expect(navigatedKind, equals(NotificationDestinationKind.request));
      expect(navigatedId, equals('req-123'));
      cubit.close();
    });

    test(
        'openNotification emits safe Arabic error and denies navigation when forbidden (403)',
        () async {
      final readItem = item1.copyWith(
        readState: NotificationReadState.read,
        readAt: testDate,
      );
      when(() => repository.markAsRead('notif-1'))
          .thenAnswer((_) async => readItem);
      when(() => repository.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-123',
          )).thenAnswer((_) async => ReauthorizationResult.forbidden);

      final cubit = NotificationCubit(repository: repository);
      cubit.emit(NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
      ));

      bool navigated = false;

      await cubit.openNotification(
        item: item1,
        onAuthorizedNavigation: (kind, id, _) {
          navigated = true;
        },
      );

      final state = cubit.state as NotificationLoaded;
      expect(state.actionError, equals('لم تعد لديك صلاحية فتح هذه الوجهة.'));
      expect(navigated, isFalse);
      expect(state.notifications.first.isRead, isTrue);
      cubit.close();
    });

    test(
        'openNotification emits safe Arabic error when destination is unavailable on mobile',
        () async {
      final readItem = item1.copyWith(
        readState: NotificationReadState.read,
        readAt: testDate,
      );
      when(() => repository.markAsRead('notif-1'))
          .thenAnswer((_) async => readItem);
      when(() => repository.reauthorizeDestination(
            NotificationDestinationKind.report,
            'rep-123',
          )).thenAnswer((_) async => ReauthorizationResult.unavailable);

      final unavailItem = item1.copyWith(
        destinationKind: NotificationDestinationKind.report,
        destinationId: 'rep-123',
      );

      final cubit = NotificationCubit(repository: repository);
      cubit.emit(NotificationLoaded(
        notifications: [unavailItem],
        unreadCount: 1,
      ));

      bool navigated = false;

      await cubit.openNotification(
        item: unavailItem,
        onAuthorizedNavigation: (kind, id, _) {
          navigated = true;
        },
      );

      final state = cubit.state as NotificationLoaded;
      expect(
          state.actionError, equals('هذه الوجهة غير متاحة على تطبيق الجوال.'));
      expect(navigated, isFalse);
      cubit.close();
    });

    test(
        'openNotification emits safe Arabic error when destination not found (404)',
        () async {
      final readItem = item1.copyWith(
        readState: NotificationReadState.read,
        readAt: testDate,
      );
      when(() => repository.markAsRead('notif-1'))
          .thenAnswer((_) async => readItem);
      when(() => repository.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-123',
          )).thenAnswer((_) async => ReauthorizationResult.notFound);

      final cubit = NotificationCubit(repository: repository);
      cubit.emit(NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
      ));

      bool navigated = false;

      await cubit.openNotification(
        item: item1,
        onAuthorizedNavigation: (kind, id, _) {
          navigated = true;
        },
      );

      final state = cubit.state as NotificationLoaded;
      expect(state.actionError, equals('الوجهة المطلوبة لم تعد موجودة.'));
      expect(navigated, isFalse);
      expect(state.notifications.first.isRead, isTrue);
      cubit.close();
    });
  });

  group('NotificationCubit - Cursor Pagination & Confirmed Read Failure', () {
    final item3 = NotificationEntity(
      id: 'notif-3',
      kind: 'system_alert',
      titleKey: 'notification.system.title',
      bodyKey: 'notification.system.body',
      destinationKind: NotificationDestinationKind.attendance,
      destinationId: 'att-789',
      readState: NotificationReadState.unread,
      createdAt: testDate,
    );

    blocTest<NotificationCubit, NotificationState>(
      'loadMoreNotifications appends new items without duplicates and updates nextCursor',
      build: () {
        when(() => repository.listNotifications(
              cursor: 'cursor-1',
              limit: 50,
            )).thenAnswer((_) async => NotificationPageEntity(
              items: [item1, item3], // item1 is duplicate, item3 is new
              nextCursor: 'cursor-2',
            ));
        return NotificationCubit(repository: repository);
      },
      seed: () => NotificationLoaded(
        notifications: [item1, item2],
        unreadCount: 1,
        nextCursor: 'cursor-1',
      ),
      act: (cubit) => cubit.loadMoreNotifications(),
      expect: () => [
        NotificationLoaded(
          notifications: [item1, item2],
          unreadCount: 1,
          nextCursor: 'cursor-1',
          isLoadingMore: true,
        ),
        NotificationLoaded(
          notifications: [item1, item2, item3],
          unreadCount: 1,
          nextCursor: 'cursor-2',
          isLoadingMore: false,
        ),
      ],
    );

    blocTest<NotificationCubit, NotificationState>(
      'loadMoreNotifications sets paginationError on failure',
      build: () {
        when(() => repository.listNotifications(
              cursor: 'cursor-1',
              limit: 50,
            )).thenThrow(Exception('Network error'));
        return NotificationCubit(repository: repository);
      },
      seed: () => NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
        nextCursor: 'cursor-1',
      ),
      act: (cubit) => cubit.loadMoreNotifications(),
      expect: () => [
        NotificationLoaded(
          notifications: [item1],
          unreadCount: 1,
          nextCursor: 'cursor-1',
          isLoadingMore: true,
        ),
        NotificationLoaded(
          notifications: [item1],
          unreadCount: 1,
          nextCursor: 'cursor-1',
          isLoadingMore: false,
          paginationError: 'تعذر تحميل المزيد من الإشعارات. حاول مرة أخرى.',
        ),
      ],
    );

    blocTest<NotificationCubit, NotificationState>(
      'markAsRead failure leaves item unread and emits safe Arabic error',
      build: () {
        when(() => repository.markAsRead('notif-1'))
            .thenThrow(Exception('Server error'));
        return NotificationCubit(repository: repository);
      },
      seed: () => NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
      ),
      act: (cubit) => cubit.markAsRead('notif-1'),
      expect: () => [
        NotificationLoaded(
          notifications: [item1],
          unreadCount: 1,
          actionError: 'تعذر تحديث حالة القراءة. حاول مرة أخرى.',
        ),
      ],
      verify: (cubit) {
        final state = cubit.state as NotificationLoaded;
        expect(state.notifications.first.isUnread, isTrue);
        expect(state.unreadCount, equals(1));
      },
    );

    test('markAllAsRead retains command ID across retries', () async {
      String? firstCommandId;
      String? secondCommandId;

      when(() => repository.markAllAsRead(
            commandId: any(named: 'commandId'),
            before: any(named: 'before'),
          )).thenAnswer((inv) {
        firstCommandId = inv.namedArguments[#commandId] as String?;
        throw Exception('Temporary timeout');
      });

      final cubit = NotificationCubit(repository: repository);
      cubit.emit(NotificationLoaded(
        notifications: [item1],
        unreadCount: 1,
      ));

      await cubit.markAllAsRead();

      expect(firstCommandId, isNotNull);
      final failedState = cubit.state as NotificationLoaded;
      expect(failedState.actionError,
          equals('تعذر تحديث حالة القراءة. حاول مرة أخرى.'));
      expect(failedState.notifications.first.isUnread, isTrue);

      // Now retry
      when(() => repository.markAllAsRead(
            commandId: any(named: 'commandId'),
            before: any(named: 'before'),
          )).thenAnswer((inv) {
        secondCommandId = inv.namedArguments[#commandId] as String?;
        return Future.value(0);
      });

      await cubit.markAllAsRead();

      expect(secondCommandId, equals(firstCommandId));
      final successState = cubit.state as NotificationLoaded;
      expect(successState.unreadCount, equals(0));
      expect(successState.notifications.first.isRead, isTrue);
      cubit.close();
    });
  });
}
