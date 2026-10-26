import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reports & Notifications Architecture Guards', () {
    test(
        'presentation layer must not import dio, drift, or concrete repositories',
        () {
      final dirsToCheck = [
        Directory('lib/features/reports/presentation'),
        Directory('lib/features/notifications/presentation'),
      ];

      final forbiddenImports = [
        'package:dio',
        'package:drift',
        'report_repository_impl.dart',
        'notification_repository_impl.dart',
        'report_dto.dart',
        'notification_dto.dart',
      ];

      for (final dir in dirsToCheck) {
        if (!dir.existsSync()) continue;
        final files = dir.listSync(recursive: true).whereType<File>();

        for (final file in files) {
          if (!file.path.endsWith('.dart')) continue;
          final lines = file.readAsLinesSync();

          for (final line in lines) {
            for (final forbidden in forbiddenImports) {
              expect(
                line.contains(forbidden),
                isFalse,
                reason:
                    'Forbidden import "$forbidden" found in presentation file: ${file.path}',
              );
            }
          }
        }
      }
    });

    test(
        'ReportsCubit and NotificationCubit must each remain below 300 non-generated lines',
        () {
      final reportsCubitFile =
          File('lib/features/reports/presentation/cubit/reports_cubit.dart');
      expect(reportsCubitFile.existsSync(), isTrue);
      final reportsLines = reportsCubitFile
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .length;
      expect(reportsLines, lessThan(300),
          reason: 'ReportsCubit exceeds 300 non-empty lines ($reportsLines)');

      final notifCubitFile = File(
          'lib/features/notifications/presentation/cubit/notification_cubit.dart');
      expect(notifCubitFile.existsSync(), isTrue);
      final notifLines = notifCubitFile
          .readAsLinesSync()
          .where((l) => l.trim().isNotEmpty)
          .length;
      expect(notifLines, lessThan(300),
          reason:
              'NotificationCubit exceeds 300 non-empty lines ($notifLines)');
    });
  });
}
