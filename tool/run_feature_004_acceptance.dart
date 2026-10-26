// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const adb = '/Users/seg/Library/Android/sdk/platform-tools/adb';
const pkg = 'com.zbooma.elabqrihr';
const activity = '$pkg/.MainActivity';

Future<void> runProcess(String executable, List<String> args,
    {String? workingDirectory}) async {
  final res = await Process.run(executable, args,
      workingDirectory: workingDirectory);
  if (res.exitCode != 0) {
    throw ProcessException(
        executable, args, 'Command failed (${res.exitCode}):\n${res.stderr}\n${res.stdout}');
  }
}

Future<void> main(List<String> args) async {
  print('================================================================');
  print('Feature 004 Acceptance Evidence Runner (T059 & T066)');
  print('================================================================');

  final screenshotDir = Directory('test-results/screenshots');
  if (!screenshotDir.existsSync()) {
    screenshotDir.createSync(recursive: true);
  }

  final talkbackDir = Directory('test-results/talkback');
  if (!talkbackDir.existsSync()) {
    talkbackDir.createSync(recursive: true);
  }

  // 1. Build APK once if needed
  final apkFile = File('build/app/outputs/flutter-apk/app-debug.apk');
  if (!apkFile.existsSync() || args.contains('--rebuild')) {
    print('\n>>> [1/3] Building debug APK for experience_capture_app.dart...');
    final buildRes = await Process.run(
      'flutter',
      ['build', 'apk', '--debug', '-t', 'lib/experience_capture_app.dart'],
      workingDirectory: '/Users/seg/Shemais/Shemais/attend_app/mobile',
    );
    if (buildRes.exitCode != 0) {
      stderr.writeln('FATAL: APK build failed:\n${buildRes.stderr}\n${buildRes.stdout}');
      exit(1);
    }
    print('Built app-debug.apk successfully.');
  } else {
    print('\n>>> [1/3] Reusing existing app-debug.apk (${apkFile.lengthSync()} bytes).');
  }

  // Target devices
  final devices = [
    ('emulator-5554', 'emulator_5554', true),
    ('10JE1B00ZB000E8', 'vivo_v2254', false),
  ];

  final client = HttpClient();

  for (final (deviceId, prefix, isEmulator) in devices) {
    print('\n================================================================');
    print('Processing Device: $deviceId ($prefix)');
    print('================================================================');

    // Check device state
    final devState = await Process.run(adb, ['-s', deviceId, 'get-state']);
    if (devState.exitCode != 0 || !devState.stdout.toString().contains('device')) {
      print('WARNING: Device $deviceId is not connected or ready. Skipping.');
      continue;
    }

    // Print device metadata
    final modelRes = await Process.run(adb, ['-s', deviceId, 'shell', 'getprop', 'ro.product.model']);
    final relRes = await Process.run(adb, ['-s', deviceId, 'shell', 'getprop', 'ro.build.version.release']);
    final sdkRes = await Process.run(adb, ['-s', deviceId, 'shell', 'getprop', 'ro.build.version.sdk']);
    final seRes = await Process.run(adb, ['-s', deviceId, 'shell', 'getenforce']);
    final wmSizeRes = await Process.run(adb, ['-s', deviceId, 'shell', 'wm', 'size']);
    final wmDenRes = await Process.run(adb, ['-s', deviceId, 'shell', 'wm', 'density']);

    print('Device Model:    ${modelRes.stdout.toString().trim()}');
    print('Android Release: ${relRes.stdout.toString().trim()}');
    print('SDK Level:       ${sdkRes.stdout.toString().trim()}');
    print('SELinux:         ${seRes.stdout.toString().trim()}');
    print('Resolution:      ${wmSizeRes.stdout.toString().trim()}');
    print('Density:         ${wmDenRes.stdout.toString().trim()}');

    // Install APK
    print('\nInstalling APK on $deviceId...');
    final installRes = await Process.run(adb, [
      '-s',
      deviceId,
      'install',
      '-r',
      '-d',
      'build/app/outputs/flutter-apk/app-debug.apk',
    ]);
    if (installRes.exitCode != 0 || !installRes.stdout.toString().contains('Success')) {
      print('Install failed: ${installRes.stdout}\n${installRes.stderr}');
      continue;
    }
    print('Installed successfully.');

    // Port forward
    await Process.run(adb, ['-s', deviceId, 'forward', 'tcp:8889', 'tcp:8889']);

    // Stop and start app
    await Process.run(adb, ['-s', deviceId, 'shell', 'am', 'force-stop', pkg]);
    await Process.run(adb, ['-s', deviceId, 'shell', 'am', 'start', '-n', activity]);

    // Wait for HTTP server
    print('Waiting for experience_capture_app to report ready...');
    bool ready = false;
    for (int i = 0; i < 45; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      try {
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:8889/status'));
        final resp = await req.close();
        if (resp.statusCode == HttpStatus.ok) {
          ready = true;
          break;
        }
      } catch (_) {}
    }

    if (!ready) {
      print('ERROR: App failed to respond on port 8889 within 45s. Skipping $deviceId.');
      await Process.run(adb, ['-s', deviceId, 'forward', '--remove', 'tcp:8889']);
      continue;
    }
    print('App is ready on port 8889.');

    Future<void> setView(String screen, double scale) async {
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:8889/view'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'screen': screen, 'scale': scale}));
      final resp = await req.close();
      await resp.drain();
      await Future.delayed(const Duration(milliseconds: 700));
    }

    // A. 16 Screenshots for emulator
    if (isEmulator) {
      print('\n>>> Capturing 16 Role x Screen x Scale Screenshots on $deviceId...');
      final roles = ['employee', 'manager', 'hr', 'admin'];
      final screens = ['home', 'attendance'];
      final scales = [1.0, 2.0];

      for (final role in roles) {
        for (final screen in screens) {
          for (final scale in scales) {
            final scaleLabel = scale == 1.0 ? '100' : '200';
            final screenKey = '${role}_$screen';
            final filename = 'emulator_5554_${role}_${screen}_$scaleLabel.png';
            final targetPath = 'test-results/screenshots/$filename';

            print('  -> Capturing $filename (font_scale: $scale)...');
            await Process.run(adb, ['-s', deviceId, 'shell', 'settings', 'put', 'system', 'font_scale', scale.toString()]);
            await setView(screenKey, scale);

            const remoteImg = '/data/local/tmp/screencap.png';
            await Process.run(adb, ['-s', deviceId, 'shell', 'rm', '-f', remoteImg]);
            await Process.run(adb, ['-s', deviceId, 'shell', 'screencap', '-p', remoteImg]);
            await Process.run(adb, ['-s', deviceId, 'pull', remoteImg, targetPath]);

            final screencapFile = File(targetPath);
            if (screencapFile.existsSync() && screencapFile.lengthSync() > 1000) {
              print('     OK: $filename (${screencapFile.lengthSync()} bytes)');
            } else {
              print('     WARNING: $filename empty or missing!');
            }
          }
        }
      }
    }

    // B. 5 TalkBack / UIAutomator XML Surfaces
    print('\n>>> Capturing 5 TalkBack / UIAutomator Traversal Surfaces on $deviceId...');
    final surfaces = [
      ('home', 'employee_home'),
      ('attendance', 'employee_attendance'),
      ('dynamic_form', 'dynamic_form'),
      ('dynamic_history', 'dynamic_history'),
      ('assigned_approval', 'assigned_approval'),
    ];

    await Process.run(adb, ['-s', deviceId, 'shell', 'settings', 'put', 'system', 'font_scale', '1.0']);

    for (final (surfaceName, screenKey) in surfaces) {
      final xmlFilename = '${prefix}_talkback_$surfaceName.xml';
      final localXmlPath = 'test-results/talkback/$xmlFilename';
      const remoteXmlPath = '/data/local/tmp/dump.xml';

      print('  -> Capturing TalkBack surface: $surfaceName ($screenKey)...');
      await setView(screenKey, 1.0);

      // Run uiautomator dump on device
      await Process.run(adb, ['-s', deviceId, 'shell', 'rm', '-f', remoteXmlPath]);
      final dumpRes = await Process.run(adb, ['-s', deviceId, 'shell', 'uiautomator', 'dump', remoteXmlPath]);
      print('     uiautomator output: ${dumpRes.stdout.toString().trim()}');

      // Pull XML to host
      await Process.run(adb, ['-s', deviceId, 'pull', remoteXmlPath, localXmlPath]);

      final xmlFile = File(localXmlPath);
      if (xmlFile.existsSync() && xmlFile.lengthSync() > 200) {
        print('     OK: $xmlFilename (${xmlFile.lengthSync()} bytes)');
      } else {
        print('     WARNING: $xmlFilename empty or missing!');
      }
    }

    // Reset font scale and port forward
    await Process.run(adb, ['-s', deviceId, 'shell', 'settings', 'put', 'system', 'font_scale', '1.0']);
    await Process.run(adb, ['-s', deviceId, 'forward', '--remove', 'tcp:8889']);
  }

  client.close();
  print('\n================================================================');
  print('Feature 004 Acceptance Evidence Capture Complete!');
  print('================================================================');
}
