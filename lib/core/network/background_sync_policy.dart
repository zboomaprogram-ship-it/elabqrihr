/// Returns whether an ordinary QA build should short-circuit headless replay.
///
/// The opt-in replay harness is available only in debug QA packages. It uses
/// the normal replay composition against a local mock server and synthetic
/// provider token; it must never be enabled in a production build.
bool shouldSkipBackgroundSyncForQa({
  required bool qaSandbox,
  required bool workerReplayHarness,
  required bool releaseMode,
}) {
  if (workerReplayHarness && (!qaSandbox || releaseMode)) {
    throw StateError('Background replay harness requires a debug QA build');
  }
  return qaSandbox && !workerReplayHarness;
}
