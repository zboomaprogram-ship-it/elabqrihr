import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Architecture Tests - Clean Architecture Layer Boundaries', () {
    test('Presentation layer must never import data, dio, or drift packages',
        () {
      final presentationDir = Directory('lib/features');
      if (!presentationDir.existsSync()) return;

      final forbiddenImports = [
        'package:dio/',
        'package:drift/',
        '/data/',
        'generated_api',
      ];

      final violations = <String>[];

      for (final entity in presentationDir.listSync(recursive: true)) {
        if (entity is File &&
            entity.path.contains('/presentation/') &&
            entity.path.endsWith('.dart')) {
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
            'Presentation must only depend on domain contracts, not data/network/storage details:\n${violations.join('\n')}',
      );
    });

    test('Domain layer must be independent of Flutter, UI, Dio, and Drift', () {
      final featuresDir = Directory('lib/features');
      if (!featuresDir.existsSync()) return;

      final forbiddenInDomain = [
        'package:flutter/',
        'package:dio/',
        'package:drift/',
        '/presentation/',
        '/data/',
      ];

      final violations = <String>[];

      for (final entity in featuresDir.listSync(recursive: true)) {
        if (entity is File &&
            entity.path.contains('/domain/') &&
            entity.path.endsWith('.dart')) {
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
            'Domain must remain pure and free from framework/infrastructure dependencies:\n${violations.join('\n')}',
      );
    });
  });
}
