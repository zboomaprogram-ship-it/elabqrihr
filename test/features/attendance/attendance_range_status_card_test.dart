import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_models.dart';
import 'package:attend_mobile/features/attendance/presentation/widgets/attendance_range_status_card.dart';

Widget buildTestableCard({
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
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final now = DateTime.now().toUtc();
  const branchCenter = GeoPoint(
    latitude: 31.0409,
    longitude: 31.3785,
    accuracyMeters: 5.0,
  );

  final testShift = ShiftContextEntity(
    shiftInstanceId: 'shift-mansoura-1',
    branchName: 'فرع المنصورة',
    branchTimezone: 'Africa/Cairo',
    shiftName: 'وردية كاملة',
    scheduledStart: now,
    scheduledEnd: now.add(const Duration(hours: 8)),
    branchLocation: branchCenter,
    allowedRadiusMeters: 750.0,
    isCheckedIn: false,
  );

  group('AttendanceRangeStatusCard Widget Tests', () {
    testWidgets('1. Locating state: displays progress indicator and locating text',
        (tester) async {
      await tester.pumpWidget(buildTestableCard(
        child: AttendanceRangeStatusCard(
          shift: testShift,
          isLocating: true,
          onRefresh: () {},
        ),
      ));

      expect(find.text('جارٍ التحقق من موقعك…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('2. Inside state: shows inside message and branch name when distance < radius',
        (tester) async {
      // Very close to branch (approx 0 meters)
      const insideLocation = GeoPoint(
        latitude: 31.0409,
        longitude: 31.3785,
        accuracyMeters: 10.0,
      );

      await tester.pumpWidget(buildTestableCard(
        child: AttendanceRangeStatusCard(
          shift: testShift,
          currentLocation: insideLocation,
          onRefresh: () {},
        ),
      ));

      expect(find.text('أنت داخل نطاق العمل'), findsOneWidget);
      expect(find.textContaining('فرع المنصورة'), findsOneWidget);
      expect(find.text('يمكنك تسجيل الحضور الآن'), findsOneWidget);
    });

    testWidgets('3. Boundary equality: exactly at radius is considered inside',
        (tester) async {
      // Construct a point approximately 750 meters away
      // In latitude, 1 degree is roughly 111,139 meters. 750m is ~0.006748 degrees.
      const boundaryLatitude = 31.0409 + (750.0 / 111139.0);
      const boundaryLocation = GeoPoint(
        latitude: boundaryLatitude,
        longitude: 31.3785,
        accuracyMeters: 5.0,
      );

      final distance = boundaryLocation.distanceTo(testShift.branchLocation);
      // Create shift with allowedRadiusMeters exactly equal to computed distance
      final boundaryShift = testShift.copyWith(allowedRadiusMeters: distance);

      await tester.pumpWidget(buildTestableCard(
        child: AttendanceRangeStatusCard(
          shift: boundaryShift,
          currentLocation: boundaryLocation,
          onRefresh: () {},
        ),
      ));

      expect(find.text('أنت داخل نطاق العمل'), findsOneWidget);
      expect(find.text('يمكنك تسجيل الحضور الآن'), findsOneWidget);
    });

    testWidgets('4. Outside state: shows outside instruction when distance > radius',
        (tester) async {
      // Point in Cairo HQ (~110 km from Mansoura)
      const outsideLocation = GeoPoint(
        latitude: 30.0444,
        longitude: 31.2357,
        accuracyMeters: 10.0,
      );

      await tester.pumpWidget(buildTestableCard(
        child: AttendanceRangeStatusCard(
          shift: testShift,
          currentLocation: outsideLocation,
          onRefresh: () {},
        ),
      ));

      expect(find.text('أنت خارج نطاق العمل'), findsOneWidget);
      expect(
        find.text('يرجى الاقتراب من موقع العمل المصرح به لتسجيل الحضور.'),
        findsOneWidget,
      );
    });

    testWidgets('5. Location error / denied state: explains corrective action',
        (tester) async {
      await tester.pumpWidget(buildTestableCard(
        child: AttendanceRangeStatusCard(
          shift: testShift,
          locationError: 'صلاحية الموقع الدقيق مطلوبة للتحقق من النطاق.',
          onRefresh: () {},
        ),
      ));

      expect(find.text('تعذر تحديد الموقع بدقة'), findsOneWidget);
      expect(
        find.text('صلاحية الموقع الدقيق مطلوبة للتحقق من النطاق.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('تأكد من تفعيل خدمة GPS'),
        findsOneWidget,
      );
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('6. Refresh button invokes onRefresh callback', (tester) async {
      bool refreshed = false;
      await tester.pumpWidget(buildTestableCard(
        child: AttendanceRangeStatusCard(
          shift: testShift,
          onRefresh: () {
            refreshed = true;
          },
        ),
      ));

      final refreshBtn = find.byKey(const Key('attendance_refresh_location_btn'));
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pump();

      expect(refreshed, isTrue);
    });

    testWidgets('7. RTL 200% text scale test: renders without overflow',
        (tester) async {
      const outsideLocation = GeoPoint(
        latitude: 30.0444,
        longitude: 31.2357,
        accuracyMeters: 150.0, // Also test low accuracy warning
      );

      await tester.pumpWidget(buildTestableCard(
        textScaleFactor: 2.0,
        child: AttendanceRangeStatusCard(
          shift: testShift,
          currentLocation: outsideLocation,
          onRefresh: () {},
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('أنت خارج نطاق العمل'), findsOneWidget);
      expect(find.textContaining('دقة إشارة GPS منخفضة'), findsOneWidget);
    });
  });
}
