import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';
import 'package:attend_mobile/features/pilot_guidance/pilot_guidance_sheet.dart';

void main() {
  group('Feature 003 Pilot Brand & Android Label Tests (T075)', () {
    test(
        'App name is exactly العبقري HR and spoken label is exact العبقري إتش آر',
        () {
      expect(AppStringsAr.appName, equals('العبقري HR'));
      expect(AppStringsAr.appNameSpoken, equals('العبقري إتش آر'));
      expect(AppStringsAr.appTitle, contains('العبقري HR'));
    });

    test('AndroidManifest.xml declares android:label as العبقري HR', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();
      expect(content, contains('android:label="العبقري HR"'));
    });

    test('build.gradle.kts declares the approved Attend application ID', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);
      final content = gradleFile.readAsStringSync();
      expect(content, contains('applicationId = "com.zbooma.elabqrihr"'));
    });

    test(
        'Legacy-name inventory: participant-facing strings do not contain legacy names',
        () {
      final participantStrings = [
        AppStringsAr.appName,
        AppStringsAr.appTitle,
        AppStringsAr.loginTitle,
        AppStringsAr.currentShift,
        AppStringsAr.pilotGuidanceTitle,
        AppStringsAr.pilotPrivacyNotice,
        AppStringsAr.pilotSupportRoute,
        AppStringsAr.pilotEmergencyWorkaround,
        AppStringsAr.pilotLimitationsNotice,
      ];

      for (final str in participantStrings) {
        expect(str.contains('حاضر —'), isFalse,
            reason: 'Found legacy name "حاضر —" in "$str"');
        expect(str.contains('Attend SaaS'), isFalse,
            reason: 'Found legacy name "Attend SaaS" in "$str"');
        expect(str.contains('attend_mobile'), isFalse,
            reason: 'Found legacy name "attend_mobile" in "$str"');
      }
    });

    test(
        'Arabic pilot guidance strings cover location, offline, privacy, support, and workaround',
        () {
      expect(AppStringsAr.pilotLocationNotice, isNotEmpty);
      expect(AppStringsAr.pilotOfflineNotice, isNotEmpty);
      expect(AppStringsAr.pilotPrivacyNotice, isNotEmpty);
      expect(AppStringsAr.pilotSupportRoute, isNotEmpty);
      expect(AppStringsAr.pilotEmergencyWorkaround, isNotEmpty);
      expect(AppStringsAr.pilotLimitationsNotice, isNotEmpty);
    });

    testWidgets(
        'Displays العبقري HR with accessible semantics and mixed RTL direction',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: AppStringsAr.appNameSpoken,
                excludeSemantics: true,
                child: const Text(
                  AppStringsAr.appName,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('العبقري HR'), findsOneWidget);
      expect(find.bySemanticsLabel('العبقري إتش آر'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Supports 200% dynamic text enlargement without layout errors',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(AppStringsAr.appName, style: TextStyle(fontSize: 24)),
                    SizedBox(height: 8),
                    Text(AppStringsAr.pilotGuidanceTitle,
                        style: TextStyle(fontSize: 18)),
                    SizedBox(height: 8),
                    Text(AppStringsAr.pilotPrivacyNotice),
                    SizedBox(height: 8),
                    Text(AppStringsAr.pilotEmergencyWorkaround),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStringsAr.appName), findsOneWidget);
    });

    testWidgets(
        'PilotGuidanceSheet renders all role-based pilot guidance sections',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PilotGuidanceSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStringsAr.pilotGuidanceTitle), findsOneWidget);
      expect(find.text(AppStringsAr.pilotPrivacyNotice), findsOneWidget);
      expect(find.text(AppStringsAr.pilotSupportRoute), findsOneWidget);
      expect(find.text(AppStringsAr.pilotEmergencyWorkaround), findsOneWidget);
      expect(find.text(AppStringsAr.pilotLimitationsNotice), findsOneWidget);
    });
  });
}
