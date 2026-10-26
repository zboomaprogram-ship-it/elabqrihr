import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:attend_mobile/features/attendance/domain/attendance_repository.dart';

/// Runs durable attendance retries only when the app can reasonably reach the
/// network, and again when it returns to the foreground.
///
/// The repository keeps event IDs and capture timestamps immutable. This
/// coordinator only schedules attempts; it never creates or rewrites events.
class AttendanceSyncCoordinator with WidgetsBindingObserver {
  AttendanceSyncCoordinator({
    required AttendanceRepository repository,
    Connectivity? connectivity,
    this.periodicInterval = const Duration(minutes: 1),
  })  : _repository = repository,
        _connectivity = connectivity ?? Connectivity() {
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivity);
    _timer = Timer.periodic(periodicInterval, (_) => triggerSync());
    triggerSync();
  }

  final AttendanceRepository _repository;
  final Connectivity _connectivity;
  final Duration periodicInterval;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _syncing = false;
  bool _disposed = false;

  void _onConnectivity(List<ConnectivityResult> states) {
    if (!states.contains(ConnectivityResult.none)) triggerSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) triggerSync();
  }

  Future<void> triggerSync() async {
    if (_disposed || _syncing) return;
    _syncing = true;
    try {
      final states = await _connectivity.checkConnectivity();
      if (!states.contains(ConnectivityResult.none)) {
        await _repository.synchronizeOutbox();
      }
    } catch (_) {
      // A connectivity indication is not proof of Internet access. The next
      // lifecycle, radio, or timer event safely retries the persisted queue.
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
