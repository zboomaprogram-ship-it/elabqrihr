import 'package:flutter_test/flutter_test.dart';
import 'package:attend_mobile/core/network/background_sync_policy.dart';

void main() {
  group('headless background replay QA guard', () {
    test('ordinary QA builds exit without replay', () {
      expect(
        shouldSkipBackgroundSyncForQa(
          qaSandbox: true,
          workerReplayHarness: false,
          releaseMode: false,
        ),
        isTrue,
      );
    });

    test('replay harness bypass is limited to non-release QA builds', () {
      expect(
        shouldSkipBackgroundSyncForQa(
          qaSandbox: true,
          workerReplayHarness: true,
          releaseMode: false,
        ),
        isFalse,
      );
    });

    test('replay harness flag is rejected outside non-release QA builds', () {
      expect(
        () => shouldSkipBackgroundSyncForQa(
          qaSandbox: false,
          workerReplayHarness: true,
          releaseMode: false,
        ),
        throwsStateError,
      );
      expect(
        () => shouldSkipBackgroundSyncForQa(
          qaSandbox: true,
          workerReplayHarness: true,
          releaseMode: true,
        ),
        throwsStateError,
      );
    });
  });
}
