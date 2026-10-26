import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_cubit.dart';
import 'package:attend_mobile/features/notifications/presentation/cubit/notification_state.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:attend_mobile/features/notifications/presentation/widgets/notification_badge_icon.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MockNotificationCubit extends MockCubit<NotificationState>
    implements NotificationCubit {}

Widget buildTestableWidget({
  required Widget child,
  required NotificationCubit cubit,
}) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: BlocProvider<NotificationCubit>.value(
      value: cubit,
      child: child,
    ),
  );
}

void main() {
  late MockNotificationCubit cubit;

  setUp(() {
    cubit = MockNotificationCubit();
    when(() => cubit.loadNotifications()).thenAnswer((_) async {});
  });

  final testDate = DateTime.parse('2026-09-26T10:00:00Z');

  final itemKnown = NotificationEntity(
    id: 'notif-1',
    kind: 'request_submitted',
    titleKey: 'notification.request.submitted.title',
    bodyKey: 'notification.request.submitted.body',
    destinationKind: NotificationDestinationKind.request,
    destinationId: 'req-123',
    readState: NotificationReadState.unread,
    createdAt: testDate,
  );

  final itemUnknown = NotificationEntity(
    id: 'notif-2',
    kind: 'future_kind',
    titleKey: 'notification.future.unknown.title',
    bodyKey: 'notification.future.unknown.body',
    destinationKind: NotificationDestinationKind.attendance,
    destinationId: 'att-456',
    readState: NotificationReadState.read,
    readAt: testDate,
    createdAt: testDate,
  );

  group('NotificationCenterScreen Widget Tests', () {
    testWidgets('renders empty state card when notifications are empty',
        (tester) async {
      when(() => cubit.state).thenReturn(const NotificationLoaded(
        notifications: [],
        unreadCount: 0,
      ));

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const NotificationCenterScreen(),
      ));

      expect(find.text('لا توجد إشعارات'), findsOneWidget);
      expect(find.text('الإشعارات'), findsOneWidget);
    });

    testWidgets(
        'renders notifications with translated Arabic titles and fallbacks',
        (tester) async {
      when(() => cubit.state).thenReturn(NotificationLoaded(
        notifications: [itemKnown, itemUnknown],
        unreadCount: 1,
      ));

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const NotificationCenterScreen(),
      ));

      // Known translation
      expect(find.text('طلب جديد'), findsOneWidget);
      expect(find.text('تم إرسال طلب للمراجعة.'), findsOneWidget);

      // Safe fallback translation for unknown keys
      expect(find.text('إشعار جديد'), findsOneWidget);
      expect(find.text('إشعار نظام جديد.'), findsOneWidget);
    });

    testWidgets('tapping mark all as read triggers cubit.markAllAsRead()',
        (tester) async {
      when(() => cubit.state).thenReturn(NotificationLoaded(
        notifications: [itemKnown],
        unreadCount: 1,
      ));
      when(() => cubit.markAllAsRead()).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const NotificationCenterScreen(),
      ));

      final markAllFinder = find.byKey(const Key('mark_all_read_button'));
      expect(markAllFinder, findsOneWidget);
      await tester.tap(markAllFinder);
      await tester.pump();

      verify(() => cubit.markAllAsRead()).called(1);
    });

    testWidgets('displays error SnackBar when actionError is present',
        (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable([
          NotificationLoaded(
            notifications: [itemKnown],
            unreadCount: 1,
            actionError: 'لم تعد لديك صلاحية فتح هذه الوجهة.',
          ),
        ]),
        initialState: NotificationLoaded(
          notifications: [itemKnown],
          unreadCount: 1,
        ),
      );

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const NotificationCenterScreen(),
      ));
      await tester.pump();

      expect(find.text('لم تعد لديك صلاحية فتح هذه الوجهة.'), findsOneWidget);
    });

    testWidgets('touch targets meet minimum 44x44 accessibility requirement',
        (tester) async {
      when(() => cubit.state).thenReturn(NotificationLoaded(
        notifications: [itemKnown],
        unreadCount: 1,
      ));

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const NotificationCenterScreen(),
      ));

      final markAllButton =
          tester.getSize(find.byKey(const Key('mark_all_read_button')));
      expect(markAllButton.width, greaterThanOrEqualTo(44.0));
      expect(markAllButton.height, greaterThanOrEqualTo(44.0));

      final itemFinder = find.byKey(Key('notification_item_${itemKnown.id}'));
      final itemSize = tester.getSize(itemFinder);
      expect(itemSize.height, greaterThanOrEqualTo(44.0));
    });
  });

  group('NotificationBadgeIcon Widget Tests', () {
    testWidgets(
        'caps the visible count while preserving the Arabic unread semantics and custom action',
        (tester) async {
      when(() => cubit.state).thenReturn(
          const NotificationLoaded(notifications: [], unreadCount: 101));
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildTestableWidget(
          cubit: cubit,
          child: Scaffold(body: NotificationBadgeIcon(onTap: () => taps++))));
      expect(find.text('+99'), findsOneWidget);
      expect(find.bySemanticsLabel('101 إشعار غير مقروء'), findsOneWidget);
      await tester.tap(find.byKey(const Key('notification_badge_button')));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('opens the notification center with the provided Cubit',
        (tester) async {
      when(() => cubit.state).thenReturn(
          const NotificationLoaded(notifications: [], unreadCount: 0));
      await tester.pumpWidget(buildTestableWidget(
          cubit: cubit, child: const Scaffold(body: NotificationBadgeIcon())));
      await tester.tap(find.byKey(const Key('notification_badge_button')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationCenterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('renders badge with count when unreadCount > 0',
        (tester) async {
      when(() => cubit.state).thenReturn(NotificationLoaded(
        notifications: [itemKnown],
        unreadCount: 5,
      ));

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const Scaffold(
          body: NotificationBadgeIcon(),
        ),
      ));

      expect(
          find.byKey(const Key('notification_unread_badge')), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('hides badge when unreadCount == 0', (tester) async {
      when(() => cubit.state).thenReturn(const NotificationLoaded(
        notifications: [],
        unreadCount: 0,
      ));

      await tester.pumpWidget(buildTestableWidget(
        cubit: cubit,
        child: const Scaffold(
          body: NotificationBadgeIcon(),
        ),
      ));

      expect(find.byKey(const Key('notification_unread_badge')), findsNothing);
    });
  });
}
