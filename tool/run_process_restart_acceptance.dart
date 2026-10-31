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

  final qaMode = args.contains('--isolated-qa');
  final proofMode = args.contains('--proof');
  final backgroundWorkerMode = args.contains('--background-worker');
  final rebootAfterPhase1 = args.contains('--reboot-after-phase1');
  if (proofMode && !qaMode) {
    throw ArgumentError('Proof mode requires isolated QA');
  }
  if (backgroundWorkerMode && (!qaMode || !proofMode)) {
    throw ArgumentError(
        'Background worker mode requires isolated QA proof mode');
  }
  if (rebootAfterPhase1 &&
      (!backgroundWorkerMode || !device.startsWith('emulator-'))) {
    throw ArgumentError(
        'Reboot acceptance requires the isolated QA background worker on an emulator');
  }
  var removeQaReverse = false;
  final pkg = qaMode ? 'com.zbooma.elabqrihr.qa' : 'com.zbooma.elabqrihr';
  final activityComponent = '$pkg/com.zbooma.elabqrihr.MainActivity';
  if (qaMode && (harnessApk == null || restoreApk == null)) {
    throw ArgumentError(
        'Isolated QA requires explicit harness and restore APKs');
  }
  if (qaMode) {
    for (final apk in [harnessApk!, restoreApk!]) {
      final badging = await Process.run(
        '/Users/seg/Library/Android/sdk/build-tools/36.1.0/aapt',
        ['dump', 'badging', apk],
      );
      if (badging.exitCode != 0 ||
          !badging.stdout.toString().contains("package: name='$pkg'")) {
        throw StateError('Refusing non-QA APK: $apk');
      }
    }
    final mappings =
        await Process.run(adb, ['-s', device, 'reverse', '--list']);
    if (mappings.exitCode != 0 ||
        mappings.stdout.toString().split('\n').any((line) =>
            line.contains('tcp:8088') && !line.contains('tcp:8088 tcp:8088'))) {
      throw StateError('Conflicting reverse mapping');
    }
    removeQaReverse = !mappings.stdout.toString().contains('tcp:8088 tcp:8088');
    final reverse = await Process.run(
        adb, ['-s', device, 'reverse', 'tcp:8088', 'tcp:8088']);
    if (reverse.exitCode != 0) {
      throw StateError('Failed to configure QA reverse');
    }
  }

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

  // Each isolated QA run must start with a fresh WorkManager database. Keep
  // prior retries and unique-work records from an earlier failed run from
  // delaying or replacing this run's one-shot replay.
  if (qaMode) {
    final installedQa = await Process.run(adb,
        ['-s', device, 'shell', 'pm', 'list', 'packages', '--user', '0', pkg]);
    if (installedQa.exitCode != 0) {
      stderr.writeln(
          'FATAL: Could not inspect isolated QA package state:\n${installedQa.stdout}\n${installedQa.stderr}');
      exit(1);
    }
    // A fresh isolated AVD has no QA package data to clear. Avoid treating
    // Android's `pm clear` response for an absent package as a test failure.
    if (installedQa.stdout.toString().contains('package:$pkg')) {
      await Process.run(adb, [
        '-s',
        device,
        'shell',
        'cmd',
        'jobscheduler',
        'cancel',
        '-u',
        '0',
        pkg,
      ]);
      final clearQaData =
          await Process.run(adb, ['-s', device, 'shell', 'pm', 'clear', pkg]);
      if (clearQaData.exitCode != 0 ||
          !clearQaData.stdout.toString().contains('Success')) {
        stderr.writeln(
            'FATAL: Could not clear isolated QA app data:\n${clearQaData.stdout}\n${clearQaData.stderr}');
        exit(1);
      }
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
    'run-as $pkg rm -f files/current_phase.txt files/phase1_result.txt files/phase2_result.txt files/proof_result.txt app_flutter/current_phase.txt app_flutter/phase1_result.txt app_flutter/phase2_result.txt app_flutter/proof_result.txt',
  ]);

  if (qaMode) {
    final host = await Process.run(adb, [
      '-s',
      device,
      'shell',
      'run-as $pkg sh -c "mkdir -p app_flutter && echo 127.0.0.1 > app_flutter/host_ip.txt"',
    ]);
    if (host.exitCode != 0) throw StateError('Failed to set QA host');
  }

  // 3. Start Host Mock HTTP Server on loopback:8088
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8088);
  print(
      '[HOST SERVER] Listening on http://127.0.0.1:8088 (accessible at 10.0.2.2:8088 on Android)...');

  int submissionCount = 0;
  int challengeCount = 0;
  String? receivedEventId;
  DateTime? receivedLocationTime;
  String? proofPublicKey;
  String? proofDigest;
  String? proofSignature;
  bool signatureVerified = false;

  server.listen((HttpRequest req) async {
    final path = req.uri.path;
    print('[HOST SERVER] Request: ${req.method} $path');

    if (proofMode &&
        req.method == 'POST' &&
        path == '/api/v1/attendance/integrity-challenges') {
      final body = jsonDecode(await utf8.decoder.bind(req).join())
          as Map<String, dynamic>;
      if (body['contentDigest'] != proofDigest ||
          body['eventId'] != 'journey-proof-evt-001' ||
          body['installationId'] != 'synthetic-server-installation') {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }
      challengeCount++;
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'challengeId': 'synthetic-challenge',
        'nonce': 'synthetic_nonce_1234567890',
        'expiresAt': '2099-01-01T00:00:00Z'
      }));
      await req.response.close();
    } else if (req.method == 'GET' &&
        path == '/api/v1/attendance/current-shift') {
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
      final location = body['location'] as Map<String, dynamic>?;
      receivedLocationTime =
          DateTime.tryParse(location?['capturedAt'] as String? ?? '');

      if (backgroundWorkerMode &&
          ((location?['latitude'] as num?)?.toDouble() != 30.0444 ||
              (location?['longitude'] as num?)?.toDouble() != 31.2357)) {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }

      if (proofMode) {
        final evidence = body['evidence'] as Map<String, dynamic>?;
        if (challengeCount != 1 ||
            proofPublicKey == null ||
            proofDigest == null ||
            evidence?['contentDigest'] != proofDigest ||
            evidence?['signature'] != proofSignature ||
            evidence?['challengeId'] != 'synthetic-challenge' ||
            evidence?['integrityToken'] != 'synthetic-provider-token') {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
        final dir = await Directory.systemTemp.createTemp('attend-proof-');
        final key = File('${dir.path}/public.der');
        final digest = File('${dir.path}/digest.bin');
        final signature = File('${dir.path}/signature.der');
        await key.writeAsBytes(base64Decode(proofPublicKey));
        await digest.writeAsBytes(List.generate(
            32,
            (i) => int.parse(proofDigest!.substring(i * 2, i * 2 + 2),
                radix: 16)));
        await signature.writeAsBytes(base64Decode(proofSignature!));
        final pem = File('${dir.path}/public.pem');
        final convert = await Process.run('openssl', [
          'pkey',
          '-pubin',
          '-inform',
          'DER',
          '-in',
          key.path,
          '-out',
          pem.path
        ]);
        final verify = convert.exitCode == 0
            ? await Process.run('openssl', [
                'dgst',
                '-sha256',
                '-verify',
                pem.path,
                '-signature',
                signature.path,
                digest.path
              ])
            : convert;
        signatureVerified = verify.exitCode == 0;
        if (!signatureVerified) {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
      }

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
      throw StateError("Acceptance assertion failed");
    }

    if (proofMode) {
      final proofResult = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'run-as $pkg cat app_flutter/proof_result.txt'
      ]);
      final parts = proofResult.stdout.toString().trim().split(':');
      if (proofResult.exitCode != 0 ||
          parts.length != 3 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(parts[1])) {
        throw StateError('Missing capture proof');
      }
      proofPublicKey = parts[0];
      proofDigest = parts[1];
      proofSignature = parts[2];
    }

    print('\n[HOST] Phase 1 Result: $phase1Result');
    final pid1Match = RegExp(r'PID=(\d+)').firstMatch(phase1Result);
    final pid1 = pid1Match?.group(1);
    if (pid1 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 1 result: $phase1Result');
      throw StateError("Acceptance assertion failed");
    }
    print('[HOST] Phase 1 Process ID: $pid1');
    final locationMatch = RegExp(r'LOCATION_MS=(\d+)').firstMatch(phase1Result);
    final expectedLocationMs = int.tryParse(locationMatch?.group(1) ?? '');
    if (expectedLocationMs == null) {
      stderr.writeln('FATAL: Missing original location timestamp');
      throw StateError("Acceptance assertion failed");
    }

    // -----------------------------------------------------------------
    // HOST-DRIVEN FORCE STOP & VERIFICATION
    // -----------------------------------------------------------------
    print('\n>>> [STEP 2] Terminating Phase 1 process');
    if (backgroundWorkerMode) {
      await Process.run(
          adb, ['-s', device, 'shell', 'input', 'keyevent', 'HOME']);
      final killRes =
          await Process.run(adb, ['-s', device, 'shell', 'am', 'kill', pkg]);
      print(
          '[HOST] am kill exited with: ${killRes.exitCode} (WorkManager remains eligible)');
    } else {
      final stopRes = await Process.run(
          adb, ['-s', device, 'shell', 'am', 'force-stop', pkg]);
      print('[HOST] force-stop exited with: ${stopRes.exitCode}');
    }

    // Verify the process is completely terminated
    var survivingPid = '';
    for (int i = 0; i < 10; i++) {
      final checkPidRes = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'pidof',
        pkg,
      ]);
      survivingPid = checkPidRes.stdout.toString().trim();
      if (survivingPid.isEmpty) break;
      await Future.delayed(const Duration(seconds: 1));
    }
    // `am kill` intentionally preserves WorkManager eligibility, but may leave
    // a foreground activity process alive on headless AVDs. Terminate only the
    // debuggable app's own process as a last resort; this is a process death,
    // not a package force-stop, so scheduled work remains eligible to run.
    if (survivingPid.isNotEmpty && backgroundWorkerMode) {
      final numericPid = int.tryParse(survivingPid.split(' ').first);
      if (numericPid != null) {
        await Process.run(adb, [
          '-s',
          device,
          'shell',
          'run-as $pkg kill -9 $numericPid',
        ]);
      }
      for (int i = 0; i < 10; i++) {
        final checkPidRes = await Process.run(adb, [
          '-s',
          device,
          'shell',
          'pidof',
          pkg,
        ]);
        survivingPid = checkPidRes.stdout.toString().trim();
        if (survivingPid.isEmpty) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    if (survivingPid.isNotEmpty) {
      stderr.writeln(
          'FATAL: Process $survivingPid is still alive after termination!');
      throw StateError("Acceptance assertion failed");
    }
    print(
        '[HOST] Confirmed Phase 1 process $pid1 terminated. In-memory state destroyed.');

    if (rebootAfterPhase1) {
      print('\n>>> [STEP 2A] Rebooting isolated QA emulator');
      await _printRebootRecoverySnapshot(adb, device, pkg, 'before reboot');
      final reboot = await Process.run(adb, ['-s', device, 'reboot']);
      if (reboot.exitCode != 0) {
        throw StateError('Failed to request isolated QA emulator reboot');
      }
      var booted = false;
      for (var attempt = 0; attempt < 90; attempt++) {
        final bootState = await Process.run(
          adb,
          ['-s', device, 'shell', 'getprop', 'sys.boot_completed'],
        ).timeout(const Duration(seconds: 5));
        if (bootState.exitCode == 0 &&
            bootState.stdout.toString().trim() == '1') {
          booted = true;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (!booted) {
        throw StateError('Isolated QA emulator did not finish rebooting');
      }
      final reverse = await Process.run(
        adb,
        ['-s', device, 'reverse', 'tcp:8088', 'tcp:8088'],
      );
      if (reverse.exitCode != 0) {
        throw StateError(
            'Failed to restore QA server port bridge after reboot');
      }
      print('[HOST] Emulator boot completed; local QA server bridge restored.');
      await _printRebootRecoverySnapshot(adb, device, pkg, 'after reboot');
    }

    if (backgroundWorkerMode) {
      final replayTimeoutSeconds = rebootAfterPhase1 ? 720 : 150;
      print(
          '[HOST] Waiting up to $replayTimeoutSeconds seconds for WorkManager replay to submit exactly one event...');
      for (int i = 0;
          i < replayTimeoutSeconds &&
              (submissionCount == 0 ||
                  (proofMode && (!signatureVerified || challengeCount != 1)));
          i++) {
        await Future.delayed(const Duration(seconds: 1));
      }
      if (submissionCount != 1 || !signatureVerified || challengeCount != 1) {
        if (rebootAfterPhase1) {
          await _printRebootRecoverySnapshot(
            adb,
            device,
            pkg,
            'after replay timeout',
          );
        }
        throw StateError(
            'Background worker did not complete one verified replay '
            '(submissions=$submissionCount, challenges=$challengeCount, '
            'signatureVerified=$signatureVerified)');
      }
      await Process.run(adb, ['-s', device, 'shell', 'am', 'kill', pkg]);
      var workerPid = '';
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final workerPidRes =
            await Process.run(adb, ['-s', device, 'shell', 'pidof', pkg]);
        workerPid = workerPidRes.stdout.toString().trim();
        if (workerPid.isEmpty) break;
      }
      if (workerPid.isNotEmpty) {
        // `am kill` can leave a package process alive after WorkManager has
        // completed its job. This is an isolated QA package; force-stop it to
        // establish the required cold-process boundary before Phase 2.
        print(
            '[HOST] Completed worker process remained after am kill; force-stopping isolated QA package.');
        final forceStop = await Process.run(
            adb, ['-s', device, 'shell', 'am', 'force-stop', pkg]);
        if (forceStop.exitCode != 0) {
          throw StateError('Could not force-stop completed QA worker process');
        }
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          final workerPidRes =
              await Process.run(adb, ['-s', device, 'shell', 'pidof', pkg]);
          workerPid = workerPidRes.stdout.toString().trim();
          if (workerPid.isEmpty) break;
        }
        if (workerPid.isNotEmpty) {
          throw StateError(
              'Isolated QA package remained alive after force-stop');
        }
      }
      print(
          '[HOST] WorkManager replay completed; its process was terminated before Phase 2.');
    }

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
      throw StateError("Acceptance assertion failed");
    }

    print('\n[HOST] Phase 2 Result: $phase2Result');
    final pid2Match = RegExp(r'PID=(\d+)').firstMatch(phase2Result);
    final pid2 = pid2Match?.group(1);
    if (pid2 == null) {
      stderr.writeln(
          'FATAL: Could not extract PID from Phase 2 result: $phase2Result');
      throw StateError("Acceptance assertion failed");
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
      throw StateError("Acceptance assertion failed");
    }
    print(
        '  [PASS] Process restart proven: PID $pid1 -> PID $pid2 (distinct processes, zero in-memory reuse).');

    // 2. Exact event ID received by server
    print(
        '  [ASSERTION 2] Checking event ID received by server: $receivedEventId');
    if (receivedEventId !=
        (proofMode ? 'journey-proof-evt-001' : 'journey-restart-evt-001')) {
      stderr.writeln(
          'FAIL: Server received unexpected event ID: $receivedEventId');
      throw StateError("Acceptance assertion failed");
    }
    print('  [PASS] Server received expected event ID: $receivedEventId');

    // 3. Exactly one terminal submission (no duplicates)
    print('  [ASSERTION 3] Checking server submission count: $submissionCount');
    if (submissionCount != 1) {
      stderr.writeln(
          'FAIL: Server received $submissionCount submissions; expected exactly 1.');
      throw StateError("Acceptance assertion failed");
    }
    print('  [PASS] Server received exactly one submission (no duplicates).');
    if (receivedLocationTime?.millisecondsSinceEpoch != expectedLocationMs) {
      stderr
          .writeln('FAIL: Location timestamp changed after restart and replay');
      throw StateError("Acceptance assertion failed");
    }
    print('  [PASS] Original location timestamp survived restart and replay.');
    if (proofMode && (!signatureVerified || challengeCount != 1)) {
      throw StateError('Capture signature or fresh challenge was not verified');
    }
    if (proofMode) {
      print(
          '  [PASS] Original Android Keystore signature verified after a fresh synthetic challenge.');
    }

    // 4. Terminal status
    print('  [ASSERTION 4] Checking client terminal status: $terminalStatus');
    if (terminalStatus != 'accepted') {
      stderr.writeln('FAIL: Terminal status is not accepted: $terminalStatus');
      throw StateError("Acceptance assertion failed");
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
    if (removeQaReverse) {
      await Process.run(adb, ['-s', device, 'reverse', '--remove', 'tcp:8088']);
    }

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

Future<void> _printRebootRecoverySnapshot(
  String adb,
  String device,
  String packageName,
  String phase,
) async {
  final package = await Process.run(
    adb,
    ['-s', device, 'shell', 'pm', 'list', 'packages', '-U', packageName],
  );
  final uidMatch = RegExp(r'uid:(\d+)').firstMatch(package.stdout.toString());
  final uid = int.tryParse(uidMatch?.group(1) ?? '');
  final appId = uid == null ? null : uid % 100000;
  final appJobUser =
      appId != null && appId >= 10000 ? 'u0a${appId - 10000}' : null;
  final jobs = await Process.run(
    adb,
    ['-s', device, 'shell', 'dumpsys', 'jobscheduler'],
  );
  final lines = jobs.stdout.toString().split('\n');
  final indexes = <int>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains(packageName) ||
        (appJobUser != null && lines[i].contains(appJobUser))) {
      indexes.add(i);
    }
  }
  print('[HOST] JobScheduler snapshot ($phase; uid=${uid ?? 'unknown'}):');
  if (indexes.isEmpty) {
    print('[HOST] No jobs labeled for the QA package/user were listed.');
  } else {
    final included = <int>{};
    for (final index in indexes) {
      for (var i = index - 2; i <= index + 5; i++) {
        if (i >= 0 && i < lines.length) included.add(i);
      }
    }
    for (final i in included.toList()..sort()) {
      print('[HOST] ${lines[i]}');
    }
  }

  final connectivity = await Process.run(
    adb,
    ['-s', device, 'shell', 'dumpsys', 'connectivity'],
  );
  final networkLines = connectivity.stdout
      .toString()
      .split('\n')
      .where((line) => RegExp(
            r'Active default network|NetworkAgentInfo|VALIDATED|CONNECTED',
          ).hasMatch(line))
      .take(12);
  print('[HOST] Connectivity snapshot ($phase):');
  for (final line in networkLines) {
    print('[HOST] $line');
  }
}
