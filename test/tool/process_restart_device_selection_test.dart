import 'package:flutter_test/flutter_test.dart';
import '../../tool/acceptance_device.dart';

void main() {
  const connected =
      'List of devices attached\nphysical-example\tdevice\nemulator-5580\tdevice\n';
  test('default selection prefers an emulator over a connected physical phone',
      () {
    expect(selectAcceptanceDevice(args: [], devicesOutput: connected),
        'emulator-5580');
  });
  test('a physical-only default aborts before installation', () {
    expect(
        () => selectAcceptanceDevice(
            args: [], devicesOutput: 'physical-example\tdevice\n'),
        throwsStateError);
  });
  test('a physical ANDROID_SERIAL does not silently select a phone', () {
    expect(
        () => selectAcceptanceDevice(
            args: [],
            environmentDevice: 'physical-example',
            devicesOutput: 'physical-example\tdevice\n'),
        throwsStateError);
  });
  test('explicit device argument and explicit emulator environment are honored',
      () {
    expect(
        selectAcceptanceDevice(
            args: ['emulator-5580'], devicesOutput: connected),
        'emulator-5580');
    expect(
        selectAcceptanceDevice(
            args: ['physical-explicit'], devicesOutput: connected),
        'physical-explicit');
    expect(
        selectAcceptanceDevice(
            args: [],
            environmentDevice: 'emulator-5582',
            devicesOutput: connected),
        'emulator-5582');
  });
  test('disconnected emulators are skipped', () {
    expect(
        selectAcceptanceDevice(
            args: [],
            devicesOutput: 'emulator-5582\toffline\nemulator-5580\tdevice\n'),
        'emulator-5580');
  });
}
