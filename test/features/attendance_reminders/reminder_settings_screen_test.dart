import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_coordinator.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_models.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_repository.dart';
import 'package:attend_mobile/features/attendance_reminders/domain/reminder_scheduler.dart';
import 'package:attend_mobile/features/attendance_reminders/presentation/cubit/reminder_settings_cubit.dart';
import 'package:attend_mobile/features/attendance_reminders/presentation/screens/reminder_settings_screen.dart';

class MockReminderRepository extends Mock implements ReminderRepository {}

class MockReminderScheduler extends Mock implements ReminderScheduler {}

class MockReminderCoordinator extends Mock implements ReminderCoordinator {}

void main() {
  late MockReminderRepository mockRepository;
  late MockReminderScheduler mockScheduler;
  late MockReminderCoordinator mockCoordinator;
  late ReminderSettingsCubit cubit;

  setUpAll(() {
    registerFallbackValue(const ReminderPreferences());
  });

  setUp(() {
    mockRepository = MockReminderRepository();
    mockScheduler = MockReminderScheduler();
    mockCoordinator = MockReminderCoordinator();

    when(() => mockScheduler.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRepository.getPreferences()).thenAnswer(
      (_) async => const ReminderPreferences(
        shiftStartEnabled: true,
        shiftStartLeadMinutes: 15,
        checkoutEnabled: true,
        permissionReturnEnabled: false,
        permissionGranted: true,
        lastSyncAt: null,
      ),
    );
    when(() => mockRepository.savePreferences(any())).thenAnswer((_) async {});
    when(() => mockCoordinator.reconcile()).thenAnswer((_) async {});

    cubit = ReminderSettingsCubit(
      repository: mockRepository,
      scheduler: mockScheduler,
      coordinator: mockCoordinator,
    );
  });

  Widget buildHarness({double textScale = 1.0}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: BlocProvider<ReminderSettingsCubit>.value(
          value: cubit..loadSettings(),
          child: const ReminderSettingsScreen(),
        ),
      ),
    );
  }

  group('ReminderSettingsScreen Widget Tests (T042)', () {
    testWidgets('renders non-pressuring Arabic banner and switches',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('منبهات وتنبيهات الحضور'), findsOneWidget);
      expect(
        find.textContaining(
            'تنبيهات الحضور اختيارية تماماً، وتعمل بنغمات هادئة'),
        findsOneWidget,
      );
      expect(find.text('تنبيه موعد بداية الوردية'), findsOneWidget);
      expect(find.text('تذكير تسجيل الانصراف'), findsOneWidget);
      expect(find.text('تنبيه العودة من الإذن'), findsOneWidget);
      expect(find.text('قبل 15 دقيقة'), findsOneWidget);
      expect(find.text('قبل 30 دقيقة'), findsOneWidget);
      expect(find.text('تجربة التنبيه'), findsOneWidget);
    });

    testWidgets('shows permission banner when permission is not granted',
        (tester) async {
      when(() => mockScheduler.hasPermission()).thenAnswer((_) async => false);
      when(() => mockRepository.getPreferences()).thenAnswer(
        (_) async => const ReminderPreferences(
          permissionGranted: false,
        ),
      );

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      expect(find.text('إذن الإشعارات غير مفعل'), findsOneWidget);
      expect(find.text('تفعيل الإذن'), findsOneWidget);
    });

    testWidgets('triggers test notification when button is pressed',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockScheduler.showTestNotification(
            titleAr: any(named: 'titleAr'),
            bodyAr: any(named: 'bodyAr'),
          )).thenAnswer((_) async {});

      await tester.pumpWidget(buildHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('تجربة التنبيه'));
      await tester.pumpAndSettle();

      verify(() => mockScheduler.showTestNotification(
            titleAr: 'تجربة تنبيهات الحضور',
            bodyAr: any(named: 'bodyAr'),
          )).called(1);
    });

    testWidgets(
        'renders cleanly at 200% font scale without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(buildHarness(textScale: 2.0));
      await tester.pumpAndSettle();

      expect(find.text('منبهات وتنبيهات الحضور'), findsOneWidget);
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
