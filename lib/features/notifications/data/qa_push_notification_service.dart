import 'package:attend_mobile/core/trust/trust_ports.dart';

/// The separate USB sandbox has in-app notices but no live push provider.
final class QaPushNotificationService implements PushNotificationPort {
  const QaPushNotificationService();

  @override
  Future<PushPermissionState> currentPermission() async =>
      PushPermissionState.unavailable;
  @override
  Future<PushPermissionState> requestPermission() => currentPermission();
  @override
  Future<String?> enableAndGetToken() async => null;
  @override
  Future<String?> initialMessageId() async => null;
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<String> get foregroundMessageIds => const Stream.empty();
  @override
  Stream<String> get openedMessageIds => const Stream.empty();
  @override
  Future<void> disable() async {}
}
