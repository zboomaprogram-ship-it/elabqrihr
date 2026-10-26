/// Defaults acceptance APK installation to an emulator. A physical installation
/// is selected only through an explicit command-line device argument.
String selectAcceptanceDevice({
  required List<String> args,
  required String devicesOutput,
  String? environmentDevice,
}) {
  if (args.isNotEmpty && args.first.trim().isNotEmpty) return args.first.trim();
  final configured = environmentDevice?.trim();
  if (configured != null && configured.startsWith('emulator-')) {
    return configured;
  }
  for (final line in devicesOutput.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 &&
        parts[0].startsWith('emulator-') &&
        parts[1] == 'device') {
      return parts[0];
    }
  }
  throw StateError(
    'No connected emulator. Pass an explicit device only when its installation may be replaced.',
  );
}
