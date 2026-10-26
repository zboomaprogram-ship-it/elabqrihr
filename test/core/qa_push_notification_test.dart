import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/notifications/data/qa_push_notification_service.dart';

void main() {
  test('QA has no live Firebase permission, token or message delivery',
      () async {
    const port = QaPushNotificationService();
    expect(await port.currentPermission(), PushPermissionState.unavailable);
    expect(await port.requestPermission(), PushPermissionState.unavailable);
    expect(await port.enableAndGetToken(), isNull);
    expect(await port.initialMessageId(), isNull);
    expect(await port.tokenRefreshes.toList(), isEmpty);
    expect(await port.foregroundMessageIds.toList(), isEmpty);
    expect(await port.openedMessageIds.toList(), isEmpty);
    await port.disable();
  });
}
