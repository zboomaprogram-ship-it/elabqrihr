import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

void main() {
  group('T040 Brand Guard & Visual Identity Tests', () {
    test('AppTheme strictly satisfies Attend light palette', () {
      expect(AppTheme.primaryColor, equals(const Color(0xFF0272F2)));
      expect(AppTheme.secondaryColor, equals(const Color(0xFFAAD5FF)));
      expect(AppTheme.backgroundColor, equals(const Color(0xFFF8FAFC)));
      expect(AppTheme.surfaceColor, equals(Colors.white));
      expect(AppTheme.textPrimary, equals(const Color(0xFF17162E)));
    });

    test(
        'Production mobile/lib code contains zero legacy Zawolf colors or glow tokens',
        () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final forbiddenTokens = [
        '0xFF050607',
        '0xFF45F0FF',
        '0xFF166C8C',
        '0x2445F0FF',
        '0x1F45F0FF',
        'borderGlow',
        'wolfGlow',
        'ZaWolf',
      ];

      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        for (final token in forbiddenTokens) {
          if (content.contains(token)) {
            violations.add('${file.path} contains forbidden token "$token"');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'Production presentation code must not contain legacy Zawolf tokens:\n${violations.join("\n")}');
    });

    test(
        'Production catalog code contains zero unauthorized financial or advance entries',
        () {
      final libDir = Directory('lib');
      final forbiddenCatalogKeywords = [
        'advance',
        'salary_advance',
        'سلفة',
        'قرض',
        'سلف مالية',
        'مستحقات',
        'قسيمة راتب',
      ];

      final violations = <String>[];

      // Check request catalog and forms
      final requestFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              f.path.contains('/requests/') ||
              f.path.contains('/dynamic_requests/'));

      for (final file in requestFiles) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync().toLowerCase();

        for (final keyword in forbiddenCatalogKeywords) {
          if (content.contains(keyword.toLowerCase())) {
            violations.add(
                '${file.path} contains unauthorized financial keyword "$keyword"');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'Feature 004 strictly forbids financial/advance workflows:\n${violations.join("\n")}');
    });

    test(
        'Production summary widgets contain zero hardcoded demo business numbers',
        () {
      final libDir = Directory('lib/features/dashboard');
      if (!libDir.existsSync()) return;

      final forbiddenHardcodedNumbers = [
        '14 يوماً',
        '160 ساعة',
        '12 موظفاً',
      ];

      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        for (final item in forbiddenHardcodedNumbers) {
          if (content.contains(item)) {
            violations
                .add('${file.path} contains hardcoded demo value "$item"');
          }
        }
      }

      expect(violations, isEmpty,
          reason:
              'Dashboards must not present hardcoded sample numbers:\n${violations.join("\n")}');
    });
  });
}
