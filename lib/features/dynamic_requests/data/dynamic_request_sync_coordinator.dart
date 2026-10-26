import 'dart:async';
import 'package:flutter/widgets.dart';
import '../domain/dynamic_request_repository.dart';

/// Automatic lifecycle- and timer-triggered synchronization coordinator
/// for offline dynamic requests.
///
/// Automatically wakes on AppLifecycleState.resumed and runs a scheduled
/// periodic timer to evaluate persisted `nextRetryAt` schedules.
class DynamicRequestSyncCoordinator with WidgetsBindingObserver {
  final DynamicRequestRepository _repository;
  final Duration periodicInterval;
  Timer? _timer;
  bool _isSyncing = false;
  bool _disposed = false;

  DynamicRequestSyncCoordinator({
    required DynamicRequestRepository repository,
    this.periodicInterval = const Duration(seconds: 15),
    bool autoStart = true,
  }) : _repository = repository {
    if (autoStart) {
      start();
    }
  }

  void start() {
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    // Immediate sync on coordinator activation
    triggerSyncNow();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(periodicInterval, (_) {
      triggerSyncNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      triggerSyncNow();
    }
  }

  Future<void> triggerSyncNow() async {
    if (_disposed || _isSyncing) return;
    _isSyncing = true;
    try {
      await _repository.synchronizeOutbox();
    } catch (_) {
      // Background sync swallows transient network failures;
      // repository updates bounded nextRetryAt timestamps.
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
