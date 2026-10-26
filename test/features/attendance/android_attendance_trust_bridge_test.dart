import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/attendance/data/android_attendance_trust_bridge.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.zbooma.elabqrihr/attendance_trust');
  late TargetPlatform? previousPlatform;

  setUp(() {
    previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = previousPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('uses the protected installation identity returned by Android',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'installationIdentity');
      return {
        'installationId': '2a4c0581-1e91-4ee4-8400-4f79e489bd32',
        'publicKeySpki': 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A',
        'publicKeyThumbprint': 'a' * 64,
        'keyAlgorithm': 'ES256',
      };
    });

    final installation =
        await AndroidAttendanceTrustBridge().ensureInstallation();

    expect(installation.id, '2a4c0581-1e91-4ee4-8400-4f79e489bd32');
    expect(installation.publicKey, startsWith('MIIB'));
    expect(installation.keyVersion, 1);
  });

  test('signs only a SHA-256 digest and returns opaque provider evidence',
      () async {
    final digest = 'b' * 64;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'installationIdentity':
          return {
            'installationId': '2a4c0581-1e91-4ee4-8400-4f79e489bd32',
            'publicKeySpki': 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A',
            'publicKeyThumbprint': 'a' * 64,
          };
        case 'signAttendanceDigest':
          expect(call.arguments, {'contentDigest': digest});
          return 'base64-signature';
        case 'requestIntegrityToken':
          expect(call.arguments, {'nonce': 'server-issued-nonce'});
          return 'opaque-integrity-token';
      }
      fail('Unexpected method ${call.method}');
    });

    final evidence = await AndroidAttendanceTrustBridge().signCanonicalEnvelope(
      canonicalEnvelope: digest,
      challenge: 'server-issued-nonce',
    );

    expect(calls, [
      'installationIdentity',
      'signAttendanceDigest',
      'requestIntegrityToken',
    ]);
    expect(evidence.signature, 'base64-signature');
    expect(evidence.platformAssertion, 'opaque-integrity-token');
  });

  test('does not expose Android provider diagnostics to the caller', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'KEYSTORE_UNAVAILABLE',
        message: 'hardware backed key is missing',
      );
    });

    expect(
      AndroidAttendanceTrustBridge().ensureInstallation(),
      throwsA(isA<AttendanceTrustUnavailableException>()),
    );
  });

  test('revokeLocalInstallation invokes method channel', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });

    await AndroidAttendanceTrustBridge().revokeLocalInstallation();

    expect(calls, ['revokeLocalInstallation']);
  });

  test('revokeLocalInstallation wraps PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'KEYSTORE_UNAVAILABLE');
    });

    expect(
      AndroidAttendanceTrustBridge().revokeLocalInstallation(),
      throwsA(isA<AttendanceTrustUnavailableException>()),
    );
  });
}
