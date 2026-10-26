// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'acceptance_device.dart';

void main(List<String> args) async {
  final adb = '/Users/seg/Library/Android/sdk/platform-tools/adb';

  final devListRes = await Process.run(adb, ['devices']);
  final device = selectAcceptanceDevice(
    args: args,
    environmentDevice: Platform.environment['ANDROID_SERIAL'],
    devicesOutput: devListRes.stdout.toString(),
  );

  print('================================================================');
  print('T036 Android Process-Restart Offline Acceptance Journey');
  print('Target: $device');
  print('================================================================');

  final harnessApk = _prebuiltApk(args, '--harness-apk=');
  final restoreApk = _prebuiltApk(args, '--restore-apk=');

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
  print('[HOST] Device SELinux Mode: ${selinuxRes.stdout.toString().trim()}');
  if (selinuxRes.exitCode != 0 ||
      selinuxRes.stdout.toString().trim() != 'Enforcing') {
    stderr.writeln(
        'ERROR: Process-restart acceptance requires enforcing SELinux');
    exit(1);
  }

  // 2. Build and install acceptance harness APK
  print(
      '\n>>> [PRE-STEP] Building and installing lib/acceptance_harness.dart APK...');
  if (harnessApk == null) {
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
  }

  final installRes = await Process.run(adb, [
    '-s',
    device,
    'install',
    '-r',
    '-d',
    harnessApk ?? 'build/app/outputs/flutter-apk/app-debug.apk',
  ]);
  if (installRes.exitCode != 0 ||
      !installRes.stdout.toString().contains('Success')) {
    stderr.writeln(
        'FATAL: Failed to install acceptance harness APK:\n${installRes.stdout}\n${installRes.stderr}');
    exit(1);
  }
  print('[HOST] Acceptance harness installed successfully.');

  // Ensure app is force-stopped
  await Process.run(adb, ['-s', device, 'shell', 'am', 'force-stop', pkg]);

  // Clean old markers in app's private files directory via run-as
  await Process.run(adb, [
    '-s',
    device,
    'shell',
    'run-as $pkg rm -f files/current_phase.txt files/phase1_result.txt files/phase2_result.txt app_flutter/current_phase.txt app_flutter/phase1_result.txt app_flutter/phase2_result.txt',
  ]);

  // 3. Start Host Mock HTTP Server on loopback:8088
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8088);
  print(
      '[HOST SERVER] Listening on http://127.0.0.1:8088 (accessible at 10.0.2.2:8088 on Android)...');

  int submissionCount = 0;
  String? receivedEventId;

  server.listen((HttpRequest req) async {
    final path = req.uri.path;
    print('[HOST SERVER] Request: ${req.method} $path');

    if (req.method == 'GET' && path == '/api/v1/attendance/current-shift') {
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'shiftInstanceId': 'shift-restart-001',
        'branchName': 'Cairo HQ',
        'shiftName': 'Morning Shift',
        'scheduledStart': '2026-09-20T08:00:00Z',
        'scheduledEnd': '2026-09-20T16:00:00Z',
        'branchLocation': {'latitude': 30.0444, 'longitude': 31.2357},
        'allowedRadiusMeters': 150.0,
        'isCheckedIn': false,
      }));
      await req.response.close();
    } else if (req.method == 'POST' && path == '/api/v1/attendance/events') {
      submissionCount++;
      final bodyStr = await utf8.decoder.bind(req).join();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      receivedEventId = (body['eventId'] ?? body['id']) as String?;

      print(
          '[HOST SERVER] Received attendance event #$submissionCount: $receivedEventId');

      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'id': receivedEventId,
        'result': 'accepted',
        'status': 'ACCEPTED',
        'reasonCode': 'ACCEPTED',
        'capturedAt':
            body['capturedAt'] ?? DateTime.now().toUtc().toIso8601String(),
        'location':
            body['location'] ?? {'latitude': 30.0444, 'longitude': 31.2357},
      }));
      await req.response.close();
    } else {
      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    }
  });

  try {
    // -----------------------------------------------------------------
    // PHASE 1: Launch Phase 1 on Android (Offline Capture)
    // -----------------------------------------------------------------
    print(
        '\n>>> [STEP 1] Setting Phase 1 in private storage & launching Android app...');
    // Create files directory if needed and write phase marker
    await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "mkdir -p app_flutter files && echo 1 > app_flutter/current_phase.txt && echo 1 > files/current_phase.txt"',
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
    }

    if (phase1Result == null) {
      stderr.writeln(
          'FATAL: Phase 1 timed out (120s) or did not produce success marker.');
      exit(1);
    }

    print('\n[HOST] Phase 1 Result: $phase1Result');
    final pid1Match = RegExp(r'PID=(\d+)').firstMatch(phase1Result);
    final pid1 = pid1Match?.group(1);
    if (pid1 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 1 result: $phase1Result');
      exit(1);
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

    // Verify the process is completely terminated
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
      exit(1);
    }
    print(
        '[HOST] Confirmed Phase 1 process $pid1 terminated. In-memory state destroyed.');

    await Future.delayed(const Duration(seconds: 1));

    // -----------------------------------------------------------------
    // PHASE 2: Launch Fresh Process on Android (Reconnect & Sync)
    // -----------------------------------------------------------------
    print(
        '\n>>> [STEP 3] Setting Phase 2 in private storage & launching fresh Android process...');
    await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "echo 2 > app_flutter/current_phase.txt && echo 2 > files/current_phase.txt"',
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
    }

    if (phase2Result == null) {
      stderr.writeln(
          'FATAL: Phase 2 timed out (120s) or did not produce success marker.');
      exit(1);
    }

    print('\n[HOST] Phase 2 Result: $phase2Result');
    final pid2Match = RegExp(r'PID=(\d+)').firstMatch(phase2Result);
    final pid2 = pid2Match?.group(1);
    if (pid2 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 2 result: $phase2Result');
      exit(1);
    }
    print('[HOST] Phase 2 Process ID: $pid2');

    // Extract terminal status from phase 2 result
    final statusMatch =
        RegExp(r'STATUS=([a-zA-Z0-9_]+)').firstMatch(phase2Result);
    final terminalStatus = statusMatch?.group(1);

    // -----------------------------------------------------------------
    // ACCEPTANCE ASSERTIONS
    // -----------------------------------------------------------------
    print('\n>>> [STEP 4] Verifying Acceptance Assertions:');

    // 1. Process ID assertion: PID 1 != PID 2
    print(
        '  [ASSERTION 1] Checking distinct process IDs: PID1=$pid1 vs PID2=$pid2');
    if (pid1 == pid2) {
      stderr.writeln(
          'FAIL: PID did not change! Phase 1 ($pid1) == Phase 2 ($pid2). Test objects may have been reused.');
      exit(1);
    }
    print(
        '  [PASS] Process restart proven: PID $pid1 -> PID $pid2 (distinct processes, zero in-memory reuse).');

    // 2. Exact event ID received by server
    print(
        '  [ASSERTION 2] Checking event ID received by server: $receivedEventId');
    if (receivedEventId != 'journey-restart-evt-001') {
      stderr.writeln(
          'FAIL: Server received unexpected event ID: $receivedEventId');
      exit(1);
    }
    print(
        '  [PASS] Server received expected event ID: journey-restart-evt-001');

    // 3. Exactly one terminal submission (no duplicates)
    print('  [ASSERTION 3] Checking server submission count: $submissionCount');
    if (submissionCount != 1) {
      stderr.writeln(
          'FAIL: Server received $submissionCount submissions; expected exactly 1.');
      exit(1);
    }
    print('  [PASS] Server received exactly one submission (no duplicates).');

    // 4. Terminal status
    print('  [ASSERTION 4] Checking client terminal status: $terminalStatus');
    if (terminalStatus != 'accepted') {
      stderr.writeln('FAIL: Terminal status is not accepted: $terminalStatus');
      exit(1);
    }
    print('  [PASS] Terminal status is accepted.');

    print('\n================================================================');
    print('T036 ACCEPTANCE PASSED: All process-restart criteria satisfied!');
    print('PID 1: $pid1');
    print('PID 2: $pid2');
    print('Event ID: $receivedEventId');
    print('Terminal Status: $terminalStatus');
    print('Server Submissions: $submissionCount');
    print('================================================================');
  } finally {
    await server.close(force: true);

    // Restore the normal application debug APK on this selected test device.
    print('\n>>> [POST-STEP] Rebuilding normal lib/main.dart debug APK...');
    if (restoreApk == null) {
      final restoreBuild = await Process.run(
        'flutter',
        ['build', 'apk', '--debug', '-t', 'lib/main.dart'],
        workingDirectory: '/Users/seg/Shemais/Shemais/attend_app/mobile',
      );
      if (restoreBuild.exitCode != 0) {
        stderr.writeln(restoreBuild.stderr);
        throw StateError('Normal debug APK restore build failed');
      }
    }
    final restoreInstall = await Process.run(adb, [
      '-s',
      device,
      'install',
      '-r',
      '-d',
      restoreApk ?? 'build/app/outputs/flutter-apk/app-debug.apk',
    ]);
    if (restoreInstall.exitCode != 0 ||
        !restoreInstall.stdout.toString().contains('Success')) {
      stderr.writeln(restoreInstall.stderr);
      throw StateError('Normal debug APK restore installation failed');
    }
    print(
        '[POST-STEP] Normal main.dart debug APK restored on the selected test device.');
  }
}

String? _prebuiltApk(List<String> args, String prefix) {
  final values = args.where((arg) => arg.startsWith(prefix)).toList();
  if (values.isEmpty) return null;
  if (values.length != 1) {
    throw ArgumentError('Duplicate prebuilt APK argument');
  }
  final path = values.single.substring(prefix.length);
  if (path.isEmpty || !File(path).existsSync()) {
    throw ArgumentError('The explicit prebuilt APK must exist');
  }
  return path;
}
