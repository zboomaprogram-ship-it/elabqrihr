import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/api/api_client.dart';
import 'package:attend_mobile/main.dart';

void main() {
  group('Network Security & Production Hardening Tests', () {
    test('QA accepts only local sandbox targets and never production', () {
      expect(
          ApiClient.validateBaseUrl('http://127.0.0.1:5300/api/v1',
              isRelease: false, qaSandbox: true),
          'http://127.0.0.1:5300/api/v1');
      for (final url in [
        'https://api.abqrihr.systems/api/v1',
        'http://192.168.1.2:5300/api/v1',
        'http://127.0.0.1.attacker.example/api/v1',
        'http://user@127.0.0.1:5300/api/v1',
        'file:///tmp/example'
      ]) {
        expect(
            () => ApiClient.validateBaseUrl(url,
                isRelease: false, qaSandbox: true),
            throwsArgumentError);
      }
    });
    test('QA mode cannot bypass production release network rules', () {
      expect(
          () => ApiClient.validateBaseUrl('http://127.0.0.1:5300/api/v1',
              isRelease: true, qaSandbox: true),
          throwsArgumentError);
    });

    test('main/AndroidManifest.xml strictly prohibits cleartext HTTP traffic',
        () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue,
          reason: 'main/AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains('android:usesCleartextTraffic="true"'),
        isFalse,
        reason:
            'Production AndroidManifest must NOT allow cleartext traffic (usesCleartextTraffic="true")',
      );
    });

    test(
        'debug/AndroidManifest.xml isolates cleartext traffic to debug builds only',
        () {
      final debugManifest = File('android/app/src/debug/AndroidManifest.xml');
      expect(debugManifest.existsSync(), isTrue,
          reason: 'debug/AndroidManifest.xml must exist');

      final content = debugManifest.readAsStringSync();
      expect(
        content.contains('android:usesCleartextTraffic="true"'),
        isTrue,
        reason:
            'Debug manifest should provide cleartext traffic for local emulators without compromising production',
      );
    });

    test('build.gradle.kts forbids debug signing fallback for release builds',
        () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue,
          reason: 'build.gradle.kts must exist');

      final content = gradleFile.readAsStringSync();
      expect(
        content.contains('signingConfigs.getByName("debug")'),
        isFalse,
        reason: 'Release builds must not fall back to debug signing keystores',
      );
      expect(
        content.contains('key.properties'),
        isTrue,
        reason:
            'build.gradle.kts must reference key.properties for production signing',
      );
    });

    test('resolveDefaultApiBaseUrl provides valid secure URI', () {
      final defaultUrl = resolveDefaultApiBaseUrl();
      final uri = Uri.tryParse(defaultUrl);
      expect(uri, isNotNull);
      expect(uri!.scheme, isIn(['http', 'https']));
      expect(uri.path.endsWith('/api/v1'), isTrue);
    });

    test('ApiClient.validateBaseUrl allows valid HTTPS URLs in release mode',
        () {
      expect(
        ApiClient.validateBaseUrl('https://api.abqrihr.systems/api/v1',
            isRelease: true),
        equals('https://api.abqrihr.systems/api/v1'),
      );
    });

    test('ApiClient.validateBaseUrl rejects plain http:// in release mode', () {
      expect(
        () => ApiClient.validateBaseUrl('http://api.abqrihr.systems/api/v1',
            isRelease: true),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('Production release builds require HTTPS'),
        )),
      );
    });

    test('ApiClient.validateBaseUrl rejects localhost in release mode', () {
      expect(
        () => ApiClient.validateBaseUrl('https://localhost:3000/api/v1',
            isRelease: true),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('prohibit local or emulator hosts'),
        )),
      );
    });

    test(
        'ApiClient.validateBaseUrl rejects Android emulator 10.0.2.2 in release mode',
        () {
      expect(
        () => ApiClient.validateBaseUrl('https://10.0.2.2:3000/api/v1',
            isRelease: true),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('prohibit local or emulator hosts'),
        )),
      );
    });

    test(
        'ApiClient.validateBaseUrl rejects internal LAN IP ranges in release mode',
        () {
      expect(
        () => ApiClient.validateBaseUrl('https://192.168.1.50:3000/api/v1',
            isRelease: true),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ApiClient.validateBaseUrl('https://10.0.0.5:3000/api/v1',
            isRelease: true),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'ApiClient.validateBaseUrl permits localhost/emulator when isRelease is false',
        () {
      expect(
        ApiClient.validateBaseUrl('http://10.0.2.2:3000/api/v1',
            isRelease: false),
        equals('http://10.0.2.2:3000/api/v1'),
      );
      expect(
        ApiClient.validateBaseUrl('http://localhost:3000/api/v1',
            isRelease: false),
        equals('http://localhost:3000/api/v1'),
      );
    });
  });
}
