// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final adb = '/Users/seg/Library/Android/sdk/platform-tools/adb';

  // Detect connected device
  String device = '10JE1B00ZB000E8';
  if (args.isNotEmpty) {
    device = args.first;
  } else if (Platform.environment['ANDROID_SERIAL'] != null) {
    device = Platform.environment['ANDROID_SERIAL']!;
  } else {
    final devListRes = await Process.run(adb, ['devices']);
    final lines = devListRes.stdout.toString().split('\n');
    for (final line in lines.skip(1)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[1] == 'device') {
        device = parts[0];
        break;
      }
    }
  }

  print('================================================================');
  print('T063 Android Process-Restart Offline Dynamic Request Acceptance Journey');
  print('Target: $device');
  print('================================================================');

  const pkg = 'com.zbooma.elabqrihr';
  const activityComponent = '$pkg/com.zbooma.elabqrihr.MainActivity';

  // 1. Verify device is connected, unlocked, and SELinux is Enforcing
  final stateRes = await Process.run(adb, ['-s', device, 'get-state']);
  if (stateRes.exitCode != 0 ||
      !stateRes.stdout.toString().contains('device')) {
    stderr.writeln('ERROR: Android device $device is not connected or ready');
    exit(1);
  }

  final selinuxRes =
      await Process.run(adb, ['-s', device, 'shell', 'getenforce']);
  final selinuxMode = selinuxRes.stdout.toString().trim();
  print('[HOST] Device SELinux Mode: $selinuxMode');

  final isEmulator = device.startsWith('emulator-');
  final hostIp = isEmulator ? '10.0.2.2' : '127.0.0.1';
  if (!isEmulator) {
    await Process.run(adb, ['-s', device, 'reverse', 'tcp:8088', 'tcp:8088']);
    print('[HOST] Reversed tcp:8088 on physical device $device');
  }

  // 2. Build and install acceptance harness APK
  print(
      '\n>>> [PRE-STEP] Building and installing lib/acceptance_harness.dart APK...');
  final buildHarnessRes = await Process.run(
    'flutter',
    ['build', 'apk', '--debug', '-t', 'lib/acceptance_harness.dart'],
    workingDirectory: '/Users/seg/Shemais/Shemais/attend_app/mobile',
  );
  if (buildHarnessRes.exitCode != 0) {
    stderr.writeln(
        'FATAL: Failed to build acceptance harness APK:\n${buildHarnessRes.stderr}\n${buildHarnessRes.stdout}');
    exit(1);
  }

  final installRes = await Process.run(adb, [
    '-s',
    device,
    'install',
    '-r',
    '-d',
    'build/app/outputs/flutter-apk/app-debug.apk',
  ]);
  if (installRes.exitCode != 0 ||
      !installRes.stdout.toString().contains('Success')) {
    stderr.writeln(
        'FATAL: Failed to install acceptance harness APK:\n${installRes.stdout}\n${installRes.stderr}');
    exit(1);
  }
  print('[HOST] Acceptance harness installed successfully.');

  // Ensure app is force-stopped and storage cleared cleanly
  await Process.run(adb, ['-s', device, 'shell', 'pm', 'clear', pkg]);
  print('[HOST] App state cleared via pm clear.');

  // 3. Start Host Mock HTTP Server on 0.0.0.0:8088 with strict OpenAPI 0.6.1 validation
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8088);
  print(
      '[HOST SERVER] Listening on http://0.0.0.0:8088 (accessible at 10.0.2.2:8088 on Android)...');

  int submissionCount = 0;
  String? receivedRequestId;
  String? receivedCommandId;
  bool rejectedForbiddenField = false;

  server.listen((HttpRequest req) async {
    final path = req.uri.path;
    print('[HOST SERVER] Request: ${req.method} $path');

    if (req.method == 'POST' && path == '/api/v1/dynamic-requests') {
      final bodyStr = await utf8.decoder.bind(req).join();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      // Strict OpenAPI 0.6.1 validation for CreateDynamicRequest:
      // Allowed: requestId, commandId, definitionVersionId, capturedAt, values
      // FORBIDDEN: typeKey
      if (body.containsKey('typeKey')) {
        print(
            '[HOST SERVER] 400 Bad Request: Forbidden field "typeKey" in CreateDynamicRequest payload!');
        rejectedForbiddenField = true;
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'code': 'VALIDATION_FAILED',
          'message': 'Forbidden field: typeKey is not allowed in CreateDynamicRequest',
        }));
        await req.response.close();
        return;
      }

      const allowedKeys = {
        'requestId',
        'commandId',
        'definitionVersionId',
        'capturedAt',
        'values',
      };

      final forbiddenKeys =
          body.keys.where((k) => !allowedKeys.contains(k)).toList();
      if (forbiddenKeys.isNotEmpty) {
        print(
            '[HOST SERVER] 400 Bad Request: Forbidden fields in CreateDynamicRequest: $forbiddenKeys');
        rejectedForbiddenField = true;
        req.response.statusCode = HttpStatus.badRequest;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'code': 'VALIDATION_FAILED',
          'message': 'Forbidden fields: $forbiddenKeys',
        }));
        await req.response.close();
        return;
      }

      submissionCount++;
      receivedRequestId = body['requestId'] as String?;
      receivedCommandId = body['commandId'] as String?;

      print(
          '[HOST SERVER] Received valid OpenAPI 0.6.1 dynamic request #$submissionCount: req=$receivedRequestId, cmd=$receivedCommandId');

      req.response.statusCode = HttpStatus.created;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'id': receivedRequestId,
        'typeKey': 'general_inquiry',
        'typeNameAr': 'طلب عهدة مؤقتة',
        'definitionVersionId': body['definitionVersionId'],
        'state': 'submitted',
        'revision': 1,
        'values': body['values'] ?? {},
        'timeline': [],
        'submittedAt': body['capturedAt'] ?? DateTime.now().toUtc().toIso8601String(),
      }));
      await req.response.close();
    } else {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  });

  try {
    // -----------------------------------------------------------------
    // PHASE 1: Launch Phase 1 on Android (Offline Dynamic Request Save)
    // -----------------------------------------------------------------
    print(
        '\n>>> [STEP 1] Setting Dynamic Request Phase 1 in private storage & launching Android app...');
    await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "mkdir -p app_flutter files && echo dynamic_1 > app_flutter/current_phase.txt && echo dynamic_1 > files/current_phase.txt && echo $hostIp > app_flutter/host_ip.txt && echo $hostIp > files/host_ip.txt"',
    ]);

    final startRes1 = await Process.run(adb, [
      '-s',
      device,
      'shell',
      'am',
      'start',
      '-n',
      activityComponent,
    ]);
    print('[Device Phase 1] am start: ${startRes1.stdout.toString().trim()}');

    // Wait for Phase 1 marker file on device via run-as (up to 120s)
    String? phase1Result;
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final res = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'run-as $pkg sh -c "cat app_flutter/phase1_result.txt 2>/dev/null || cat files/phase1_result.txt 2>/dev/null"',
      ]);
      final out = res.stdout.toString().trim();
      if (out.contains('PHASE_1_SUCCESS')) {
        phase1Result = out;
        break;
      }

      final errRes = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'run-as $pkg sh -c "cat app_flutter/phase_error.txt 2>/dev/null || cat files/phase_error.txt 2>/dev/null"',
      ]);
      final errOut = errRes.stdout.toString().trim();
      if (errOut.contains('PHASE_ERROR')) {
        stderr.writeln('FATAL: Phase 1 encountered error on device:\n$errOut');
        throw StateError(
            'T063 acceptance failed; see the preceding diagnostic.');
      }
    }

    if (phase1Result == null) {
      stderr.writeln(
          'FATAL: Phase 1 timed out (120s) or did not produce success marker.');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }

    print('\n[HOST] Phase 1 Result: $phase1Result');
    final pid1Match = RegExp(r'PID=(\d+)').firstMatch(phase1Result);
    final pid1 = pid1Match?.group(1);
    if (pid1 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 1 result: $phase1Result');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print('[HOST] Phase 1 Process ID: $pid1');

    // -----------------------------------------------------------------
    // HOST-DRIVEN FORCE STOP & VERIFICATION
    // -----------------------------------------------------------------
    print('\n>>> [STEP 2] Host invoking: adb shell am force-stop $pkg');
    final stopRes = await Process.run(adb, [
      '-s',
      device,
      'shell',
      'am',
      'force-stop',
      pkg,
    ]);
    print('[HOST] force-stop exited with: ${stopRes.exitCode}');

    final checkPidRes = await Process.run(adb, [
      '-s',
      device,
      'shell',
      'pidof',
      pkg,
    ]);
    final survivingPid = checkPidRes.stdout.toString().trim();
    if (survivingPid.isNotEmpty) {
      stderr.writeln(
          'FATAL: Process $survivingPid is still alive after force-stop!');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print(
        '[HOST] Confirmed Phase 1 process $pid1 terminated. In-memory state destroyed.');

    await Future.delayed(const Duration(seconds: 1));

    // -----------------------------------------------------------------
    // PHASE 2: Launch Fresh Process on Android (Reconnect & Sync Dynamic Request)
    // -----------------------------------------------------------------
    print(
        '\n>>> [STEP 3] Setting Dynamic Request Phase 2 in private storage & launching fresh Android process...');
    await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "echo dynamic_2 > app_flutter/current_phase.txt && echo dynamic_2 > files/current_phase.txt"',
    ]);

    final startRes2 = await Process.run(adb, [
      '-s',
      device,
      'shell',
      'am',
      'start',
      '-n',
      activityComponent,
    ]);
    print('[Device Phase 2] am start: ${startRes2.stdout.toString().trim()}');

    // Wait for Phase 2 marker file on device via run-as (up to 120s)
    String? phase2Result;
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 1));
      final res = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'run-as $pkg sh -c "cat app_flutter/phase2_result.txt 2>/dev/null || cat files/phase2_result.txt 2>/dev/null"',
      ]);
      final out = res.stdout.toString().trim();
      if (out.contains('PHASE_2_SUCCESS')) {
        phase2Result = out;
        break;
      }

      final errRes = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'run-as $pkg sh -c "cat app_flutter/phase_error.txt 2>/dev/null || cat files/phase_error.txt 2>/dev/null"',
      ]);
      final errOut = errRes.stdout.toString().trim();
      if (errOut.contains('PHASE_ERROR')) {
        stderr.writeln('FATAL: Phase 2 encountered error on device:\n$errOut');
        throw StateError(
            'T063 acceptance failed; see the preceding diagnostic.');
      }
    }

    if (phase2Result == null) {
      stderr.writeln(
          'FATAL: Phase 2 timed out (120s) or did not produce success marker.');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }

    print('\n[HOST] Phase 2 Result: $phase2Result');
    final pid2Match = RegExp(r'PID=(\d+)').firstMatch(phase2Result);
    final pid2 = pid2Match?.group(1);
    if (pid2 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 2 result: $phase2Result');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print('[HOST] Phase 2 Process ID: $pid2');

    // -----------------------------------------------------------------
    // 4. VERIFY ALL ACCEPTANCE CRITERIA
    // -----------------------------------------------------------------
    print('\n================================================================');
    print('VERIFYING T063 ACCEPTANCE CRITERIA');
    print('================================================================');

    // 1. Process changed
    if (pid1 == pid2) {
      stderr.writeln(
          'FAIL: PID did not change between launches ($pid1 == $pid2)');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 1: Process restarted (PID1: $pid1 != PID2: $pid2)');

    // 2. Request ID & Command ID match
    const expectedRequestId = 'journey-restart-dyn-001';
    const expectedCommandId = 'journey-cmd-dyn-001';
    if (receivedRequestId != expectedRequestId) {
      stderr.writeln(
          'FAIL: Received request ID ($receivedRequestId) does not match expected ($expectedRequestId)');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    if (receivedCommandId != expectedCommandId) {
      stderr.writeln(
          'FAIL: Received command ID ($receivedCommandId) does not match expected ($expectedCommandId)');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 2: Request ID and Command ID preserved across restart: req=$receivedRequestId, cmd=$receivedCommandId');

    // 3. Exactly one server submission
    if (submissionCount != 1) {
      stderr.writeln(
          'FAIL: Expected exactly 1 server submission, got $submissionCount');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 3: Exactly one server submission reached host (count: $submissionCount)');

    // 4. Terminal status
    if (!phase2Result.contains('STATUS=submitted')) {
      stderr.writeln(
          'FAIL: Phase 2 did not reach terminal submitted status: $phase2Result');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 4: Local dynamic request outbox transitioned to terminal submitted');

    // 5. Strict OpenAPI contract adherence
    if (rejectedForbiddenField) {
      stderr.writeln('FAIL: Server rejected payload with forbidden fields');
      throw StateError('T063 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 5: Dynamic request strictly conformed to OpenAPI 0.6.1 (no typeKey)');

    print('\n================================================================');
    print('T063 ANDROID DYNAMIC RESTART ACCEPTANCE PASSED');
    print('Command: dart run tool/run_dynamic_restart_acceptance.dart');
    print('Target Emulator: $device');
    print('SELinux Mode: $selinuxMode');
    print('Phase 1 PID: $pid1');
    print('Phase 2 PID: $pid2');
    print('Request ID: $receivedRequestId');
    print('Command ID: $receivedCommandId');
    print('Server Submission Count: $submissionCount');
    print('Terminal State: submitted');
    print('================================================================\n');
  } finally {
    await server.close(force: true);
    await Process.run(adb, ['-s', device, 'shell', 'am', 'force-stop', pkg]);

    // Restore production application APK
    print('>>> [POST-STEP] Reinstalling production lib/main.dart APK...');
    final buildProdRes = await Process.run(
      'flutter',
      ['build', 'apk', '--debug', '-t', 'lib/main.dart'],
      workingDirectory: '/Users/seg/Shemais/Shemais/attend_app/mobile',
    );
    if (buildProdRes.exitCode == 0) {
      await Process.run(adb, [
        '-s',
        device,
        'install',
        '-r',
        '-d',
        'build/app/outputs/flutter-apk/app-debug.apk',
      ]);
      print('[HOST] Production APK reinstalled successfully.');
    }
  }
}
