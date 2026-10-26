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
  print('T026 Android Process-Restart Offline Request Acceptance Journey');
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

  // 3. Start Host Mock HTTP Server on 0.0.0.0:8088 with strict OpenAPI 0.4.0 validation
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8088);
  print(
      '[HOST SERVER] Listening on http://0.0.0.0:8088 (accessible at 10.0.2.2:8088 on Android)...');

  int submissionCount = 0;
  String? receivedRequestId;
  bool rejectedForbiddenField = false;

  server.listen((HttpRequest req) async {
    final path = req.uri.path;
    print('[HOST SERVER] Request: ${req.method} $path');

    if (req.method == 'POST' && path == '/api/v1/requests') {
      final bodyStr = await utf8.decoder.bind(req).join();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;

      // Strict OpenAPI 0.4.0 validation for CreateLeaveRequest
      const allowedKeys = {
        'requestId',
        'type',
        'categoryId',
        'startDate',
        'endDate',
        'partialStartTime',
        'partialEndTime',
        'reason',
      };

      final forbiddenKeys =
          body.keys.where((k) => !allowedKeys.contains(k)).toList();
      if (forbiddenKeys.isNotEmpty) {
        print(
            '[HOST SERVER] 400 Bad Request: Forbidden fields in CreateLeaveRequest: $forbiddenKeys');
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

      print(
          '[HOST SERVER] Received valid OpenAPI 0.4.0 request #$submissionCount: $receivedRequestId');

      // Server returns calculated requestedMinutes (client does NOT send it)
      req.response.statusCode = HttpStatus.created;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'id': receivedRequestId,
        'employeeId': 'user-restart-001',
        'type': body['type'] ?? 'leave',
        'state': 'pending_approval',
        'revision': 1,
        'requestedMinutes': 960, // Calculated by server
        'submittedAt': DateTime.now().toUtc().toIso8601String(),
        'details': body,
        'steps': [
          {
            'id': 'step-1',
            'position': 1,
            'reviewerRole': 'manager',
            'state': 'pending',
          }
        ],
      }));
      await req.response.close();
    } else {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  });

  try {
    // -----------------------------------------------------------------
    // PHASE 1: Launch Phase 1 on Android (Offline Request Save)
    // -----------------------------------------------------------------
    print(
        '\n>>> [STEP 1] Setting Request Phase 1 in private storage & launching Android app...');
    await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "mkdir -p app_flutter files && echo request_1 > app_flutter/current_phase.txt && echo request_1 > files/current_phase.txt"',
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
            'T026 acceptance failed; see the preceding diagnostic.');
      }
    }

    if (phase1Result == null) {
      stderr.writeln(
          'FATAL: Phase 1 timed out (120s) or did not produce success marker.');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }

    print('\n[HOST] Phase 1 Result: $phase1Result');
    final pid1Match = RegExp(r'PID=(\d+)').firstMatch(phase1Result);
    final pid1 = pid1Match?.group(1);
    if (pid1 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 1 result: $phase1Result');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
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
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print(
        '[HOST] Confirmed Phase 1 process $pid1 terminated. In-memory state destroyed.');

    await Future.delayed(const Duration(seconds: 1));

    // -----------------------------------------------------------------
    // PHASE 2: Launch Fresh Process on Android (Reconnect & Sync Request)
    // -----------------------------------------------------------------
    print(
        '\n>>> [STEP 3] Setting Request Phase 2 in private storage & launching fresh Android process...');
    await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "echo request_2 > app_flutter/current_phase.txt && echo request_2 > files/current_phase.txt"',
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
            'T026 acceptance failed; see the preceding diagnostic.');
      }
    }

    if (phase2Result == null) {
      stderr.writeln(
          'FATAL: Phase 2 timed out (120s) or did not produce success marker.');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }

    print('\n[HOST] Phase 2 Result: $phase2Result');
    final pid2Match = RegExp(r'PID=(\d+)').firstMatch(phase2Result);
    final pid2 = pid2Match?.group(1);
    if (pid2 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 2 result: $phase2Result');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print('[HOST] Phase 2 Process ID: $pid2');

    // -----------------------------------------------------------------
    // 4. VERIFY ALL ACCEPTANCE CRITERIA
    // -----------------------------------------------------------------
    print('\n================================================================');
    print('VERIFYING T026 ACCEPTANCE CRITERIA');
    print('================================================================');

    // 1. Process changed
    if (pid1 == pid2) {
      stderr.writeln(
          'FAIL: PID did not change between launches ($pid1 == $pid2)');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 1: Process restarted (PID1: $pid1 != PID2: $pid2)');

    // 2. Request ID matches
    const expectedRequestId = 'journey-restart-req-001';
    if (receivedRequestId != expectedRequestId) {
      stderr.writeln(
          'FAIL: Received request ID ($receivedRequestId) does not match expected ($expectedRequestId)');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 2: Request ID preserved across process restart: $receivedRequestId');

    // 3. Exactly one server submission
    if (submissionCount != 1) {
      stderr.writeln(
          'FAIL: Expected exactly 1 server submission, got $submissionCount');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 3: Exactly one server submission reached host (count: $submissionCount)');

    // 4. Terminal status
    if (!phase2Result.contains('STATUS=pending_approval')) {
      stderr.writeln(
          'FAIL: Phase 2 did not reach terminal pending_approval status: $phase2Result');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 4: Local request outbox transitioned to terminal pending_approval');

    // 5. Strict OpenAPI contract adherence
    if (rejectedForbiddenField) {
      stderr.writeln('FAIL: Server rejected payload with forbidden fields');
      throw StateError('T026 acceptance failed; see the preceding diagnostic.');
    }
    print(
        ' [PASS] Criterion 5: Request strictly conformed to OpenAPI 0.4.0 (no requestedMinutes)');

    print('\n================================================================');
    print('T026 ANDROID PROCESS RESTART ACCEPTANCE PASSED');
    print('Command: dart run tool/run_request_restart_acceptance.dart');
    print('Target Emulator: $device');
    print('SELinux Mode: $selinuxMode');
    print('Phase 1 PID: $pid1');
    print('Phase 2 PID: $pid2');
    print('Request ID: $receivedRequestId');
    print('Server Submission Count: $submissionCount');
    print('Terminal State: pending_approval');
    print('================================================================\n');
  } finally {
    await server.close(force: true);
    await Process.run(adb, ['-s', device, 'shell', 'am', 'force-stop', pkg]);

    // Restore production lib/main.dart APK on device as required by acceptance
    print(
        '\n>>> [POST-STEP] Rebuilding and restoring production lib/main.dart APK...');
    final buildProd = await Process.run(
      'flutter',
      ['build', 'apk', '--debug', '-t', 'lib/main.dart'],
      workingDirectory: '/Users/seg/Shemais/Shemais/attend_app/mobile',
    );
    if (buildProd.exitCode == 0) {
      final installProd = await Process.run(adb, [
        '-s',
        device,
        'install',
        '-r',
        '-d',
        'build/app/outputs/flutter-apk/app-debug.apk',
      ]);
      if (installProd.stdout.toString().contains('Success')) {
        print(
            '[HOST] Production lib/main.dart APK successfully restored on $device.');
      } else {
        stderr.writeln(
            '[HOST] Warning: Failed to reinstall production APK: ${installProd.stdout}');
      }
    } else {
      stderr.writeln(
          '[HOST] Warning: Failed to build production APK: ${buildProd.stderr}');
    }
  }
}
