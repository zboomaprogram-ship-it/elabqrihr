import 'dart:async';
import 'dart:io';

import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM adapter with consent-first behavior.
///
/// This service only obtains a token after a user explicitly enables push in
/// settings. The caller must send that token to the authenticated API; neither
/// the token nor notification payload is logged locally.
final class FirebasePushNotificationService implements PushNotificationPort {
  FirebasePushNotificationService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  @override
  Stream<String> get tokenRefreshes =>
      _messaging.onTokenRefresh.where((token) => token.trim().isNotEmpty);

  @override
  Stream<String> get foregroundMessageIds => FirebaseMessaging.onMessage
      .map((msg) => msg.data['notificationId'] as String?)
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>();

  @override
  Stream<String> get openedMessageIds => FirebaseMessaging.onMessageOpenedApp
      .map((msg) => msg.data['notificationId'] as String?)
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>();

  @override
  Future<String?> initialMessageId() async {
    final message = await _messaging.getInitialMessage();
    final id = message?.data['notificationId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  @override
  Future<PushPermissionState> currentPermission() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return PushPermissionState.unavailable;
    }
    return _mapAuthorization(
        (await _messaging.getNotificationSettings()).authorizationStatus);
  }

  @override
  Future<PushPermissionState> requestPermission() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      return PushPermissionState.unavailable;
    }
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
    return _mapAuthorization(settings.authorizationStatus);
  }

  @override
  Future<String?> enableAndGetToken() async {
    final permission = await currentPermission();
    if (permission != PushPermissionState.granted) return null;
    await _messaging.setAutoInitEnabled(true);
    final token = await _messaging.getToken();
    return token?.trim().isEmpty ?? true ? null : token?.trim();
  }

  @override
  Future<void> disable() async {
    await _messaging.setAutoInitEnabled(false);
    await _messaging.deleteToken();
  }

  PushPermissionState _mapAuthorization(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional =>
        PushPermissionState.granted,
      AuthorizationStatus.denied => PushPermissionState.denied,
      AuthorizationStatus.notDetermined => PushPermissionState.unknown,
    };
  }
}
