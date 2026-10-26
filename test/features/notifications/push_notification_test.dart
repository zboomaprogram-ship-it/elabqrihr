import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/core/api/generated/contract_types.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/notifications/domain/notification_models.dart';
import 'package:attend_mobile/features/notifications/domain/notification_repository.dart';
import 'package:attend_mobile/features/notifications/presentation/notification_deep_link_coordinator.dart';
import 'package:attend_mobile/features/notifications/presentation/notification_open_listener.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/announcement_details_screen.dart';
import 'package:attend_mobile/features/notifications/presentation/screens/notification_settings_screen.dart';

class MockPushRegistrationPort extends Mock implements PushRegistrationPort {}

class MockPushNotificationPort extends Mock implements PushNotificationPort {}

class MockApiClient extends Mock implements ApiClient {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  late MockPushRegistrationPort mockRegistrationPort;
  late MockPushNotificationPort mockNotificationPort;
  late MockApiClient mockApiClient;
  late MockNotificationRepository mockNotificationRepo;

  setUpAll(() {
    registerFallbackValue(NotificationDestinationKind.request);
  });

  setUp(() {
    mockRegistrationPort = MockPushRegistrationPort();
    mockNotificationPort = MockPushNotificationPort();
    mockApiClient = MockApiClient();
    mockNotificationRepo = MockNotificationRepository();
  });

  Widget createWidget(Widget child) {
    return MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );
  }

  group(
      'Feature 012 Task T054: Push Notification Permissions & Settings Widget Tests',
      () {
    testWidgets(
        '1. Displays push master toggle and category preferences cleanly in Arabic',
        (tester) async {
      when(() => mockNotificationPort.currentPermission())
          .thenAnswer((_) async => PushPermissionState.granted);
      when(() => mockApiClient.getNotificationPreferences())
          .thenAnswer((_) async => [
                const NotificationPreferenceDto(
                    category: 'attendance', pushEnabled: true, revision: 1),
                const NotificationPreferenceDto(
                    category: 'approvals', pushEnabled: false, revision: 1),
              ]);

      await tester.pumpWidget(createWidget(NotificationSettingsScreen(
        pushRegistrationPort: mockRegistrationPort,
        pushNotificationPort: mockNotificationPort,
        apiClient: mockApiClient,
      )));
      await tester.pumpAndSettle();

      expect(find.text('إعدادات الإشعارات'), findsOneWidget);
      expect(find.text('إشعارات الجهاز (Push)'), findsOneWidget);
      expect(find.text('تفضيلات فئات الإشعارات'), findsOneWidget);
      expect(find.text('تنبيهات الحضور والانصراف'), findsOneWidget);
      expect(find.text('قرارات الاعتماد والطلبات'), findsOneWidget);

      final masterSwitch =
          tester.widget<Switch>(find.byKey(const Key('push_master_switch')));
      expect(masterSwitch.value, isTrue);

      final approvalsSwitch = tester.widget<Switch>(find.descendant(
        of: find.byKey(const Key('category_pref_approvals')),
        matching: find.byType(Switch),
      ));
      expect(approvalsSwitch.value, isFalse);
    });

    testWidgets(
        '2. Non-pressuring denied-permission state displays polite guidance without nagging',
        (tester) async {
      when(() => mockNotificationPort.currentPermission())
          .thenAnswer((_) async => PushPermissionState.denied);
      when(() => mockApiClient.getNotificationPreferences())
          .thenAnswer((_) async => []);

      await tester.pumpWidget(createWidget(NotificationSettingsScreen(
        pushRegistrationPort: mockRegistrationPort,
        pushNotificationPort: mockNotificationPort,
        apiClient: mockApiClient,
      )));
      await tester.pumpAndSettle();

      expect(
          find.textContaining(
              'إشعارات النظام متوقفة حالياً. يمكنك تفعيلها في أي وقت'),
          findsOneWidget);
      // Ensures no aggressive modal dialog or system alert is forced
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
        '3. Enabling push requests permission and registers token via PushRegistrationPort',
        (tester) async {
      when(() => mockNotificationPort.currentPermission())
          .thenAnswer((_) async => PushPermissionState.unknown);
      when(() => mockApiClient.getNotificationPreferences())
          .thenAnswer((_) async => []);
      when(() => mockRegistrationPort.enable(locale: 'ar'))
          .thenAnswer((_) async => PushRegistrationOutcome.enabled);

      await tester.pumpWidget(createWidget(NotificationSettingsScreen(
        pushRegistrationPort: mockRegistrationPort,
        pushNotificationPort: mockNotificationPort,
        apiClient: mockApiClient,
      )));
      await tester.pumpAndSettle();

      // Initially off
      final masterSwitchFinder = find.byKey(const Key('push_master_switch'));
      expect(tester.widget<Switch>(masterSwitchFinder).value, isFalse);

      // Change mock permission on subsequent check
      when(() => mockNotificationPort.currentPermission())
          .thenAnswer((_) async => PushPermissionState.granted);

      // Tap to enable
      await tester.tap(masterSwitchFinder);
      await tester.pumpAndSettle();

      verify(() => mockRegistrationPort.enable(locale: 'ar')).called(1);
      expect(tester.widget<Switch>(masterSwitchFinder).value, isTrue);
    });

    testWidgets('4. Disabling push calls PushRegistrationPort.disable()',
        (tester) async {
      when(() => mockNotificationPort.currentPermission())
          .thenAnswer((_) async => PushPermissionState.granted);
      when(() => mockApiClient.getNotificationPreferences())
          .thenAnswer((_) async => []);
      when(() => mockRegistrationPort.disable()).thenAnswer((_) async {});

      await tester.pumpWidget(createWidget(NotificationSettingsScreen(
        pushRegistrationPort: mockRegistrationPort,
        pushNotificationPort: mockNotificationPort,
        apiClient: mockApiClient,
      )));
      await tester.pumpAndSettle();

      final masterSwitchFinder = find.byKey(const Key('push_master_switch'));
      expect(tester.widget<Switch>(masterSwitchFinder).value, isTrue);

      await tester.tap(masterSwitchFinder);
      await tester.pumpAndSettle();

      verify(() => mockRegistrationPort.disable()).called(1);
      expect(tester.widget<Switch>(masterSwitchFinder).value, isFalse);
    });

    testWidgets(
        '5. Toggling a category preference submits updated list with expectedRevision',
        (tester) async {
      when(() => mockNotificationPort.currentPermission())
          .thenAnswer((_) async => PushPermissionState.granted);
      when(() => mockApiClient.getNotificationPreferences())
          .thenAnswer((_) async => [
                const NotificationPreferenceDto(
                    category: 'attendance', pushEnabled: true, revision: 2),
              ]);
      when(() => mockApiClient.replaceNotificationPreferences(
            expectedRevision: any(named: 'expectedRevision'),
            items: any(named: 'items'),
          )).thenAnswer((inv) async {
        final items =
            inv.namedArguments[#items] as List<NotificationPreferenceInputDto>;
        return items
            .map((i) => NotificationPreferenceDto(
                  category: i.category,
                  pushEnabled: i.pushEnabled,
                  revision: 3,
                ))
            .toList();
      });

      await tester.pumpWidget(createWidget(NotificationSettingsScreen(
        pushRegistrationPort: mockRegistrationPort,
        pushNotificationPort: mockNotificationPort,
        apiClient: mockApiClient,
      )));
      await tester.pumpAndSettle();

      // Toggle attendance off
      final switchFinder = find.descendant(
        of: find.byKey(const Key('category_pref_attendance')),
        matching: find.byType(Switch),
      );
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      verify(() => mockApiClient.replaceNotificationPreferences(
            expectedRevision: 2,
            items: any(named: 'items'),
          )).called(1);
    });
  });

  group(
      'Feature 012 Task T054 & T061: Deep-Link Reauthorization Coordinator Tests',
      () {
    final testNotification = NotificationEntity(
      id: 'notif-deep-001',
      kind: 'request_approved',
      titleKey: 'notification.request.approved.title',
      bodyKey: 'notification.request.approved.body',
      destinationKind: NotificationDestinationKind.request,
      destinationId: 'req-001',
      readState: NotificationReadState.unread,
      createdAt: DateTime.utc(2026, 10, 6, 10, 0),
    );

    test('reauthorizes valid destination and marks unread notification as read',
        () async {
      when(() => mockNotificationRepo.getNotification('notif-deep-001'))
          .thenAnswer((_) async => testNotification);
      when(() => mockNotificationRepo.markAsRead('notif-deep-001')).thenAnswer(
          (_) async =>
              testNotification.copyWith(readState: NotificationReadState.read));
      when(() => mockNotificationRepo.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-001',
          )).thenAnswer((_) async => ReauthorizationResult.authorized);

      final coordinator =
          NotificationDeepLinkCoordinator(repository: mockNotificationRepo);
      final result =
          await coordinator.resolveOpaqueNotification('notif-deep-001');

      expect(result, isA<DeepLinkAuthorized>());
      final auth = result as DeepLinkAuthorized;
      expect(auth.destinationKind, NotificationDestinationKind.request);
      expect(auth.destinationId, 'req-001');

      verify(() => mockNotificationRepo.markAsRead('notif-deep-001')).called(1);
      verify(() => mockNotificationRepo.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-001',
          )).called(1);
    });

    test(
        'revoked or forbidden destination returns DeepLinkForbidden without navigating',
        () async {
      when(() => mockNotificationRepo.getNotification('notif-deep-001'))
          .thenAnswer((_) async => testNotification);
      when(() => mockNotificationRepo.markAsRead('notif-deep-001')).thenAnswer(
          (_) async =>
              testNotification.copyWith(readState: NotificationReadState.read));
      when(() => mockNotificationRepo.reauthorizeDestination(
            NotificationDestinationKind.request,
            'req-001',
          )).thenAnswer((_) async => ReauthorizationResult.forbidden);

      final coordinator =
          NotificationDeepLinkCoordinator(repository: mockNotificationRepo);
      final result =
          await coordinator.resolveOpaqueNotification('notif-deep-001');

      expect(result, isA<DeepLinkForbidden>());
    });

    test('non-existent notification returns DeepLinkNotFound', () async {
      when(() => mockNotificationRepo.getNotification('notif-unknown'))
          .thenAnswer((_) async => null);

      final coordinator =
          NotificationDeepLinkCoordinator(repository: mockNotificationRepo);
      final result =
          await coordinator.resolveOpaqueNotification('notif-unknown');

      expect(result, isA<DeepLinkNotFound>());
      verifyNever(
          () => mockNotificationRepo.reauthorizeDestination(any(), any()));
    });
  });

  group('FCM notification-open routing', () {
    testWidgets(
        'reauthorizes an opaque FCM notification before opening its announcement',
        (tester) async {
      final openedIds = StreamController<String>.broadcast();
      addTearDown(openedIds.close);
      final port = _OpenedMessagePushPort(openedIds.stream);
      final item = NotificationEntity(
        id: 'notification-1',
        kind: 'company_announcement',
        titleKey: 'notification.company_announcement.title',
        bodyKey: 'notification.company_announcement.body',
        destinationKind: NotificationDestinationKind.announcement,
        destinationId: 'announcement-1',
        readState: NotificationReadState.read,
        createdAt: DateTime.utc(2026, 10, 19),
      );
      when(() => mockNotificationRepo.getNotification('notification-1'))
          .thenAnswer((_) async => item);
      when(() => mockNotificationRepo.reauthorizeDestination(
            NotificationDestinationKind.announcement,
            'announcement-1',
          )).thenAnswer((_) async => ReauthorizationResult.authorized);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PushNotificationPort>.value(value: port),
            RepositoryProvider<NotificationRepository>.value(
                value: mockNotificationRepo),
            RepositoryProvider<ApiClient>.value(value: mockApiClient),
          ],
          child: createWidget(
            const NotificationOpenListener(child: Scaffold(body: Text('home'))),
          ),
        ),
      );
      await tester.pump();
      openedIds.add('notification-1');
      await tester.pumpAndSettle();

      expect(find.byType(AnnouncementDetailsScreen), findsOneWidget);
      verify(() => mockNotificationRepo.reauthorizeDestination(
            NotificationDestinationKind.announcement,
            'announcement-1',
          )).called(1);
    });
  });
}

final class _OpenedMessagePushPort implements PushNotificationPort {
  const _OpenedMessagePushPort(this._opened);

  final Stream<String> _opened;

  @override
  Future<void> disable() async {}

  @override
  Future<String?> enableAndGetToken() async => null;

  @override
  Stream<String> get foregroundMessageIds => const Stream.empty();

  @override
  Future<String?> initialMessageId() async => null;

  @override
  Stream<String> get openedMessageIds => _opened;

  @override
  Future<PushPermissionState> currentPermission() async =>
      PushPermissionState.granted;

  @override
  Future<PushPermissionState> requestPermission() async =>
      PushPermissionState.granted;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}
