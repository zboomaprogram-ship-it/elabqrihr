import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Notification Architecture Guard Tests (T051–T052)', () {
    test(
        'Notification presentation layer must never import data, dio, or drift',
        () {
      final notifPresentationDir =
          Directory('lib/features/notifications/presentation');
      expect(notifPresentationDir.existsSync(), isTrue);

      final forbiddenImports = [
        'package:dio/',
        'package:drift/',
        '/data/',
        'generated_api',
      ];

      final violations = <String>[];

      for (final entity in notifPresentationDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.startsWith('import ')) {
              for (final forbidden in forbiddenImports) {
                if (line.contains(forbidden)) {
                  violations.add('${entity.path}:${i + 1} -> $line');
                }
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Notification presentation must only depend on domain abstractions, not data/network/storage details:\n${violations.join('\n')}',
      );
    });

    test(
        'Notification domain layer must be independent of Flutter, UI, Dio, and Drift',
        () {
      final notifDomainDir = Directory('lib/features/notifications/domain');
      expect(notifDomainDir.existsSync(), isTrue);

      final forbiddenInDomain = [
        'package:flutter/',
        'package:dio/',
        'package:drift/',
        '/presentation/',
        '/data/',
      ];

      final violations = <String>[];

      for (final entity in notifDomainDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.startsWith('import ')) {
              for (final forbidden in forbiddenInDomain) {
                if (line.contains(forbidden)) {
                  violations.add('${entity.path}:${i + 1} -> $line');
                }
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Notification domain must be pure Dart without UI or infrastructure:\n${violations.join('\n')}',
      );
    });

    test('NotificationCubit must remain below 300 non-generated lines', () {
      final cubitFile = File(
          'lib/features/notifications/presentation/cubit/notification_cubit.dart');
      expect(cubitFile.existsSync(), isTrue);

      final lineCount = cubitFile.readAsLinesSync().length;
      expect(
        lineCount,
        lessThan(300),
        reason:
            'NotificationCubit should remain focused and below 300 lines (actual: $lineCount)',
      );
    });
  });
}
