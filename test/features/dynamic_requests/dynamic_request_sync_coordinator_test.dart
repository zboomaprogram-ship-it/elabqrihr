import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/features/dynamic_requests/data/dynamic_request_sync_coordinator.dart';
import 'package:attend_mobile/features/dynamic_requests/domain/dynamic_request_repository.dart';

class _MockSyncRepo extends Fake implements DynamicRequestRepository {
  int syncCallCount = 0;

  @override
  Future<void> synchronizeOutbox() async {
    syncCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicRequestSyncCoordinator Tests (T063)', () {
    test('Automatically triggers sync on startup', () async {
      final repo = _MockSyncRepo();
      final coordinator = DynamicRequestSyncCoordinator(
        repository: repo,
        periodicInterval: const Duration(seconds: 10),
        autoStart: true,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(repo.syncCallCount, equals(1));
      coordinator.dispose();
    });

    test('Triggers sync on AppLifecycleState.resumed', () async {
      final repo = _MockSyncRepo();
      final coordinator = DynamicRequestSyncCoordinator(
        repository: repo,
        periodicInterval: const Duration(seconds: 10),
        autoStart: false,
      );
      coordinator.start();

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = repo.syncCallCount;

      // Simulate lifecycle resumed
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repo.syncCallCount, equals(initialCount + 1));
      coordinator.dispose();
    });

    test('Triggers sync periodically and cancels on dispose', () async {
      final repo = _MockSyncRepo();
      final coordinator = DynamicRequestSyncCoordinator(
        repository: repo,
        periodicInterval: const Duration(milliseconds: 100),
        autoStart: true,
      );

      await Future.delayed(const Duration(milliseconds: 250));
      expect(repo.syncCallCount, greaterThanOrEqualTo(2));

      final countBeforeDispose = repo.syncCallCount;
      coordinator.dispose();

      await Future.delayed(const Duration(milliseconds: 200));
      expect(repo.syncCallCount, equals(countBeforeDispose));
    });
  });
}
