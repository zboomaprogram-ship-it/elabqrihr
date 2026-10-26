import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_motion.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';
import 'package:attend_mobile/core/design_system/app_strings_ar.dart';

void main() {
  group('T062 Design System & Accessibility Tests', () {
    test(
        'AppTheme defines approved Attend palette (#0272F2, #AAD5FF, light canvas)',
        () {
      expect(AppTheme.primaryColor, equals(const Color(0xFF0272F2)));
      expect(AppTheme.secondaryColor, equals(const Color(0xFFAAD5FF)));
      expect(AppTheme.backgroundColor, equals(const Color(0xFFF8FAFC)));
      expect(AppTheme.textPrimary, equals(const Color(0xFF17162E)));
    });

    testWidgets(
        'ElevatedButton satisfies minimum 44x44 touch target and RTL directionality',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text(AppStringsAr.submit),
                ),
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);

      final size = tester.getSize(buttonFinder);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('Supports 200% dynamic text enlargement without layout errors',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: ListView(
                  children: const [
                    Text(AppStringsAr.myRequestsTitle),
                    Text(AppStringsAr.typeLeave),
                    Text(AppStringsAr.statePendingApproval),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text(AppStringsAr.myRequestsTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('six local motion assets are valid, small Lottie JSON files', () {
      for (final asset in AppMotionAsset.values) {
        final file = File(asset.path);
        expect(file.existsSync(), isTrue, reason: asset.path);
        expect(file.lengthSync(), lessThanOrEqualTo(150 * 1024));
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(json['v'], isNotNull);
        expect(json['layers'], isA<List<dynamic>>());
      }
      expect(File('assets/animations/ASSETS.md').existsSync(), isTrue);
    });

    testWidgets('reduced motion renders a static accessible animation frame',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: true,
              accessibleNavigation: true,
            ),
            child: Scaffold(
              body: AppMotion(
                asset: AppMotionAsset.requestSubmitted,
                semanticLabel: 'تم إرسال الطلب',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('تم إرسال الطلب'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing motion asset falls back without blocking the screen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppMotion(
              asset: AppMotionAsset.emptyRequests,
              assetPath: 'assets/animations/does_not_exist.json',
              semanticLabel: 'حالة فارغة',
              fallbackIcon: Icons.inbox_outlined,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.bySemanticsLabel('حالة فارغة'), findsOneWidget);
    });

    testWidgets(
        'RTL navigation icons correctly mirror back arrow and chevron forward',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: const Text('العنوان'),
              ),
              body: const ListTile(
                title: Text('إعدادات'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // BackButton uses Icons.arrow_back which has matchTextDirection: true
      final backIconFinder = find.byIcon(Icons.arrow_back);
      expect(backIconFinder, findsOneWidget);
      final Icon backIcon = tester.widget(backIconFinder);
      expect(backIcon.icon!.matchTextDirection, isTrue);

      // Trailing drill-down chevron uses Icons.chevron_right which has matchTextDirection: true
      final chevronFinder = find.byIcon(Icons.chevron_right);
      expect(chevronFinder, findsOneWidget);
      final Icon chevronIcon = tester.widget(chevronFinder);
      expect(chevronIcon.icon!.matchTextDirection, isTrue);
    });
  });
}
