import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/reminder_models.dart';
import '../domain/reminder_scheduler.dart';

class LocalAttendanceReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _initialized = false;

  static const String channelId = 'attendance_reminders_channel';
  static const String channelName = 'تنبيهات الحضور والورديات';
  static const String channelDescription =
      'إشعارات تذكيرية هادئة بمواعيد الحضور والانصراف والأذونات المعتمدة';

  LocalAttendanceReminderScheduler({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
    );
    _initialized = true;
  }

  NotificationDetails _buildNotificationDetails() {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const darwinPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );
  }

  @override
  Future<void> schedule(ScheduledReminderInstance instance) async {
    await initialize();

    final scheduledTz = tz.TZDateTime.from(instance.scheduledAt, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id: instance.notificationId,
      title: instance.titleAr,
      body: instance.bodyAr,
      scheduledDate: scheduledTz,
      notificationDetails: _buildNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexact,
      payload: instance.deterministicKey,
    );
  }

  @override
  Future<void> cancel(int notificationId) async {
    await initialize();
    await _notificationsPlugin.cancel(id: notificationId);
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _notificationsPlugin.cancelAll();
  }

  @override
  Future<List<int>> getPendingNotificationIds() async {
    await initialize();
    final requests =
        await _notificationsPlugin.pendingNotificationRequests();
    return requests.map((r) => r.id).toList();
  }

  @override
  Future<bool> hasPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidImpl?.areNotificationsEnabled();
      return enabled ?? false;
    } else if (Platform.isIOS) {
      return true; // Evaluated at permission request time on iOS
    }
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImpl?.requestPermissions(
        alert: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  @override
  Future<void> showTestNotification({
    required String titleAr,
    required String bodyAr,
  }) async {
    await initialize();
    await _notificationsPlugin.show(
      id: 999999,
      title: titleAr,
      body: bodyAr,
      notificationDetails: _buildNotificationDetails(),
    );
  }
}
