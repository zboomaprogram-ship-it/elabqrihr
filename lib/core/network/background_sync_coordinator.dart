import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:attend_mobile/core/trust/trust_ports.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';
import 'package:attend_mobile/features/requests/domain/request_repository.dart';

/// Method channel bridge to native WorkManager scheduler on Android.
final class WorkManagerBackgroundSyncScheduler implements BackgroundSyncScheduler {
  static const _channel = MethodChannel('com.zbooma.elabqrihr/background_sync');

  @override
  Future<void> scheduleForIdentity({
    required String tenantId,
    required String userId,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('scheduleForIdentity', {
        'tenantId': tenantId,
        'userId': userId,
      });
    } on PlatformException catch (_) {
      // Degrades gracefully without breaking app execution.
    }
  }

  @override
  Future<void> cancelForIdentity({
    required String tenantId,
    required String userId,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('cancelForIdentity', {
        'tenantId': tenantId,
        'userId': userId,
      });
    } on PlatformException catch (_) {
      // Degrades gracefully
    }
  }
}

/// Orchestrates synchronization of bounded due attendance events and
/// offline request outbox rows when connectivity is restored or during background replay.
///
/// Implements Feature 012 Task T063.
///
/// Principles:
/// 1. Processes bounded due rows without altering cryptographic evidence, capture times, or client IDs.
/// 2. Never captures background GPS coordinates or generates automated background check-ins.
/// 3. Idempotent: safe to run concurrently or sequentially.
final class BackgroundSyncCoordinator {
  BackgroundSyncCoordinator({
    required AttendanceRepository attendanceRepository,
    required RequestRepository requestRepository,
    BackgroundSyncScheduler? scheduler,
  })  : _attendanceRepository = attendanceRepository,
        _requestRepository = requestRepository,
        _scheduler = scheduler ?? WorkManagerBackgroundSyncScheduler();

  final AttendanceRepository _attendanceRepository;
  final RequestRepository _requestRepository;
  final BackgroundSyncScheduler _scheduler;

  bool _isSyncing = false;

  /// Runs outbox synchronization across attendance and request domains.
  Future<void> synchronizeAll() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      // 1. Synchronize eligible offline attendance events
      await _attendanceRepository.synchronizeOutbox();

      // 2. Synchronize eligible offline requests
      await _requestRepository.synchronizeOutbox();
    } finally {
      _isSyncing = false;
    }
  }

  /// Registers background WorkManager task for the authenticated session.
  Future<void> onSessionAuthenticated({
    required String tenantId,
    required String userId,
  }) async {
    await _scheduler.scheduleForIdentity(
      tenantId: tenantId,
      userId: userId,
    );
  }

  /// Cancels background WorkManager task upon user logout.
  Future<void> onSessionRevoked({
    required String tenantId,
    required String userId,
  }) async {
    await _scheduler.cancelForIdentity(
      tenantId: tenantId,
      userId: userId,
    );
  }
}
