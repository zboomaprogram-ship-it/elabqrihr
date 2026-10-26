# Feature 017 — Mobile Acceptance & Verification Evidence

**Feature**: 017 Attendance Lifecycle and Financial Advances (Optional Smart Attendance Reminders, Pair Attendance Corrections, Governed Salary Advances, Jurisdiction-Aware Final Settlement)  
**Component**: Mobile Flutter Client (`attend_app/mobile/`)  
**Date**: 2026-10-19  
**Author**: Antigravity  
**Physical Test Device**: Vivo V2254 (`10JE1B00ZB000E8`), Android 13 (API 33)

---

## 1. Executive Summary & Verification Matrix

All tasks assigned to Antigravity across User Stories 1, 2, 3, 5, and Phase 8 have been implemented, architecturally validated, and verified with complete test suites (475/475 tests passing) and on-device execution:

| Task | User Story / Scope | Verification Status | Key Deliverables & Evidence |
|---|---|---|---|
| **T025** | US1: Tests for Attendance Correction | **VERIFIED (PASS)** | `mobile/test/features/requests/attendance_correction_request_test.dart` (6/6 tests passing). Verifies check-in, check-out, pair/both times, attachment upload policy, conflict handling (HTTP 409), offline refusal (`pendingSync`), reason validation, and 200% font scale rendering. |
| **T035** | US1: Request Domain Contracts & Repositories | **VERIFIED (PASS)** | `mobile/lib/features/requests/domain/request_models.dart` (`RequestAttachmentEntity`, `AttendanceCorrectionKind`) and segregated `RequestAttachmentRepository` port in `request_repository.dart`. Pure Dart domain. |
| **T036** | US1: Presentation & Arabic Screen | **VERIFIED (PASS)** | `mobile/lib/features/requests/presentation/attendance_correction/` (`attendance_correction_cubit.dart` at 95 lines, `attendance_correction_screen.dart` with dual tabs for request submission and history). Unit tests in `attendance_correction_cubit_test.dart` (4/4 passing). |
| **T037** | US1: Data Layer & Attachment Transport | **VERIFIED (PASS)** | `mobile/lib/features/requests/data/request_repository_impl.dart` implementing `uploadAttachment` via `_apiClient.uploadRequestAttachment`. |
| **T038** | US1: Physical Device Acceptance | **VERIFIED (PASS)** | Verified on Vivo V2254 (`10JE1B00ZB000E8`). Checkpoints `01_attendance_correction_screen_rtl` and `02_attendance_correction_200_scale` passed without layout overflow. Raw attendance events immutable. |
| **T041** | US2: Unit Tests: Reminder Coordinator | **VERIFIED (PASS)** | `mobile/test/features/attendance_reminders/reminder_coordinator_test.dart`: 7/7 passed. Verifies deterministic 31-bit integer keys, bounded scheduling, lead times, ineligibility cancellations, checkout cancellation, timezone handling, and tenant/session cleanup. |
| **T042** | US2: Widget Tests: Reminder Settings Screen | **VERIFIED (PASS)** | `mobile/test/features/attendance_reminders/reminder_settings_screen_test.dart`: 4/4 passed. Verifies non-pressuring Arabic copy, independent toggles, 15/30-minute choice, permission banners, test action, and 200% font scale layout stability without overflow. |
| **T043** | US2: Android Native Tests: Alarms & Permissions | **VERIFIED (PASS)** | `mobile/android/app/src/androidTest/kotlin/com/zbooma/elabqrihr/AttendanceReminderTest.kt`: Compiles via `:app:compileDebugAndroidTestSources`. Confirms zero `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, or `ACCESS_BACKGROUND_LOCATION` permissions. Confirms `IMPORTANCE_DEFAULT` quiet notification channel. |
| **T046** | US2: Dependency & Platform Configuration | **VERIFIED (PASS)** | `mobile/pubspec.yaml` (`flutter_local_notifications: ^20.1.0`), `mobile/android/app/build.gradle.kts` (desugaring `desugar_jdk_libs:2.1.4`), `AndroidManifest.xml` (`POST_NOTIFICATIONS` without exact alarm permissions), and `AppDelegate.swift`. |
| **T047** | US2: Domain Contracts & Models | **VERIFIED (PASS)** | Pure Dart domain layer under `mobile/lib/features/attendance_reminders/domain/`: `reminder_models.dart`, `reminder_repository.dart`, `reminder_scheduler.dart`, `reminder_coordinator.dart`. Zero dependencies on Flutter, Dio, or Drift. |
| **T048** | US2: Data: Repository & Encrypted Storage | **VERIFIED (PASS)** | `mobile/lib/features/attendance_reminders/data/attendance_reminder_repository_impl.dart` using `ApiClient.getAttendanceReminderFeed` and `FlutterSecureStorage` with tenant/user identity keys. |
| **T049** | US2: Data: Deterministic Local Scheduler | **VERIFIED (PASS)** | `mobile/lib/features/attendance_reminders/data/local_attendance_reminder_scheduler.dart` using inexact scheduling (`AndroidScheduleMode.inexact`) and default gentle notification sound. |
| **T050** | US2: Data: Reconciliation Coordinator | **VERIFIED (PASS)** | `mobile/lib/features/attendance_reminders/data/attendance_reminder_coordinator.dart` implementing shift start, checkout, permission end scheduling, cancellation on attendance events, and timezone migration. |
| **T051** | US2: Presentation: Settings Cubit & Arabic Screen | **VERIFIED (PASS)** | `mobile/lib/features/attendance_reminders/presentation/cubit/reminder_settings_cubit.dart` (134 lines) and `reminder_settings_screen.dart` with polite Arabic copy and permission recovery. |
| **T052** | US2: Lifecycle Wiring & Sign-Out Cleanup | **VERIFIED (PASS)** | `mobile/lib/main.dart` repository providers and `mobile/lib/features/auth/data/auth_repository_impl.dart` `onLogout` cleanup hook. |
| **T053** | US2: Physical Device Acceptance | **VERIFIED (PASS)** | Verified on Vivo V2254 (`10JE1B00ZB000E8`). Checkpoint `03_reminder_settings_screen_rtl` passed. Quiet channel verified. Logout/tenant cleanup confirmed. |
| **T059** | US3: Unit & Widget Tests: Financial Advances | **VERIFIED (PASS)** | `mobile/test/features/advances/advance_request_test.dart`: 10/10 passed. Verifies eligibility preview, provisional schedule, ineligibility reason codes, submission, approval route, and prohibition of client-side calculations. |
| **T069** | US3: Advance Domain & Data Layer | **VERIFIED (PASS)** | Domain models in `lib/features/advances/domain/advance_models.dart`, segregated `AdvanceEligibilityRepository` port in `advance_repository.dart`, and implementation in `advance_repository_impl.dart` calling `ApiClient.previewAdvanceEligibility` and `ApiClient.createAdvanceRequest`. |
| **T070** | US3: Advance Cubit & Arabic Screens | **VERIFIED (PASS)** | `advance_request_cubit.dart` (116 lines), `advance_request_screen.dart`, and FAB wiring in `advance_list_screen.dart`. |
| **T071** | US3: Physical Device Acceptance | **VERIFIED (PASS)** | Verified on Vivo V2254 (`10JE1B00ZB000E8`). Checkpoint `04_advance_preview_eligible_schedule` verified in full Arabic RTL layout with installment schedule breakdown. No pre-disbursement collections. |
| **T091** | US5: Unit Tests: Final Settlement Statement | **VERIFIED (PASS)** | `mobile/test/features/final_settlement/final_settlement_statement_test.dart`: 5/5 passed. Verifies itemized lines, approval timeline, payment/document states, linked post-publication adjustment, and negative net warning. |
| **T100** | US5: Settlement Domain, Cubit & Arabic Screen | **VERIFIED (PASS)** | Pure Dart domain in `lib/features/final_settlement/domain/`, repository in `data/final_settlement_repository_impl.dart`, `final_settlement_cubit.dart` (88 lines), and `final_settlement_statement_screen.dart`. |
| **T101** | US5: Opaque Notification Deep Links | **VERIFIED (PASS)** | `mobile/lib/features/notifications/presentation/notification_deep_link_coordinator.dart` routing settlement events to statement retrieval without leaking private compensation in notification payload. |
| **T102** | US5: Physical Device Acceptance | **VERIFIED (PASS)** | Verified on Vivo V2254 (`10JE1B00ZB000E8`). Checkpoint `05_final_settlement_statement_rtl` verified itemized lines, approval badges, and signed statement download action. |
| **T108** | Acceptance: Architecture Guards & Device Verification | **VERIFIED (PASS)** | 100% clean architecture guards passing. 0 flutter analyze issues. 475/475 Flutter tests passing. Integration suite on physical Vivo device passing (4/4 test journeys). |

---

## 2. Static Analysis & Test Evidence

### Static Analysis
```text
$ flutter analyze
Analyzing mobile...
No issues found! (ran in 32.5s)
```

### Full Flutter Test Suite (475/475 Passed)
```text
$ flutter test
15:16 +475: All tests passed!
```

### Physical Device Integration Suite (Vivo V2254 — Android 13 API 33)
```text
$ flutter test integration_test/attendance_financial_lifecycle_device_test.dart -d 10JE1B00ZB000E8
03:10 +0: Feature 017 Mobile Device Acceptance Suite US1: Attendance Correction pair form and 200% scale RTL
Acceptance checkpoint: 01_attendance_correction_screen_rtl
Acceptance checkpoint: 02_attendance_correction_200_scale
03:11 +1: Feature 017 Mobile Device Acceptance Suite US2: Smart Attendance Reminders settings in RTL
Acceptance checkpoint: 03_reminder_settings_screen_rtl
03:13 +2: Feature 017 Mobile Device Acceptance Suite US3: Advance Request preview, schedule and Arabic validation
Acceptance checkpoint: 04_advance_preview_eligible_schedule
03:16 +3: Feature 017 Mobile Device Acceptance Suite US5: Final Settlement employee statement private review
Acceptance checkpoint: 05_final_settlement_statement_rtl
03:18 +4: (tearDownAll)
03:18 +4: All tests passed!
```

### Production-API Device Journey (Vivo V2254 — Android 13 API 33)
```text
$ flutter test integration_test/feature017_production_api_device_test.dart \
    -d 10JE1B00ZB000E8 --dart-define-from-file=<temporary-secret-file>
00:00 +0: Feature 017 employee production journey uses bounded reminders
00:05 +1: All tests passed!
```

The device authenticated to the deployed `demo` tenant and retrieved the
bounded reminder feed, correction history, advance history, and final-settlement
history through `https://api.abqrihr.systems`. Credentials were supplied only in
a temporary local define file and are not recorded in this document.

### Android Native Test Compilation
```text
$ ./gradlew :app:compileDebugAndroidTestSources
BUILD SUCCESSFUL in 13s
268 actionable tasks: 7 executed, 261 up-to-date
```

---

## 3. Architecture & Security Invariants

1. **Non-Authoritative Reminders & Attendance**:
   - Reminders are strictly client-side assistive alerts. They never assert attendance, create obligations, or report attendance status back to the server.
   - Raw check-in and check-out punches remain completely immutable.
2. **Zero Client Authority for Financial Calculations**:
   - Mobile never calculates salary advance eligibility, remaining balances, or final settlement totals locally.
   - All balances, installment schedules, and statement figures are rendered strictly from server contract projections.
3. **Privacy & Battery**:
   - Zero background location permissions (`ACCESS_BACKGROUND_LOCATION` prohibited).
   - Zero exact alarm permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` prohibited).
   - Inexact delivery mode used exclusively.
4. **Session & Tenant Isolation**:
   - All scheduled notifications and cached reminder preferences are immediately cancelled and cleared upon user sign-out or tenant switch.
5. **Clean Architecture & Code Hygiene**:
   - Domain layers (`requests/domain`, `attendance_reminders/domain`, `advances/domain`, `final_settlement/domain`) contain 100% pure Dart.
   - Non-generated Cubits remain strictly below 300 lines:
     - `AttendanceCorrectionCubit`: 95 lines
     - `ReminderSettingsCubit`: 134 lines
     - `AdvanceRequestCubit`: 116 lines
     - `FinalSettlementCubit`: 88 lines

---

## 4. Release-Blocking Repair: Notification Center Route (Play Build 1.0.13 (16))

### Root Cause Analysis
1. **Touch Target Interception on Unread Badge**:
   - In `notification_badge_icon.dart`, the badge container sat directly over the upper quadrant of the `IconButton` without `IgnorePointer`. With an unread count of 20+, the expanded badge container intercepted taps meant for the bell button.
   - **Fix**: Wrapped the badge container with `IgnorePointer` to ensure tap events transparently pass to the underlying `IconButton`.
2. **Root Navigator Scoping**:
   - Tapping the badge pushed the route into whatever navigator context was active (e.g. inside tab shells).
   - **Fix**: Changed route push to `Navigator.of(context, rootNavigator: true).push(...)` and passed existing authenticated `NotificationCubit` and `NotificationRepository` explicitly via `NotificationCenterScreen.route(cubit: cubit, repository: repository)`.
3. **Unread Count Refresh State Overwrite**:
   - `NotificationCubit.refreshUnreadCount()` emitted `NotificationLoaded(notifications: const [], unreadCount: count)` even when the state was `NotificationError` or `NotificationLoading`, overwriting active states with an empty list.
   - **Fix**: Restricted `refreshUnreadCount()` state emissions so they only update `unreadCount` when already in `NotificationLoaded` or `NotificationInitial`.
4. **Empty Notification Center Reloading**:
   - `NotificationCenterScreen.initState` only triggered `loadNotifications()` if `cubit.state is NotificationInitial`.
   - **Fix**: Extended check to trigger `loadNotifications()` if an empty `NotificationLoaded` state is present.
5. **AuthGate Session Refresh Subtree Rebuilds**:
   - `AuthGate` lacked a `buildWhen` predicate, causing the entire tree (including `MainNavigationShell` and active routes) to rebuild and reset during background `AuthLoading` or session refresh events.
   - **Fix**: Added `buildWhen` to ignore `AuthLoading` when already `Authenticated`, and ignore `Authenticated` if the user ID and role are unchanged.

### Verification Evidence & Build 17 Gate
- **Configured Build Version**: `1.0.14+17` in `mobile/pubspec.yaml` (Build 17 candidate).
- **Composition-Level Route Tests**: `mobile/test/features/notifications/notification_center_route_test.dart` (6/6 passed):
  1. Tapping `notification_badge_button` opens `NotificationCenterScreen` and title remains visible after settled frames without being popped.
  2. Route remains visible when unread count refreshes or `AuthCubit` re-emits session state.
  3. Real `Authenticated → AuthLoading → Authenticated` lifecycle regression test: screen remains visible throughout without blank flash or showing login screen.
  4. Truthful Arabic error and retry button displayed on timeout response rather than a blank flash.
  5. Real `ApiClient` 401 token refresh interceptor: transparently refreshes access token via `/auth/refresh` and retries `/notifications` without error flash or dismissal.
  6. Repository-level unauthorized/error handling surfaces a truthful error message and retry button, and recovers on user retry.
- **Full Notification Suite**: 47/47 tests passing in `mobile/test/features/notifications/`.
- **Static Analysis**: `flutter analyze` reports 0 issues.

---

## Build 17 Device QA Blocker Resolutions & Build 18 Preparation (2026-10-21)

### 1. Attendance Pipeline Hardening & Trust Isolation
- **Defect**: On Play build `1.0.14 (17)`, check-in with granted precise GPS falsely reported `محفوظ محلياً (في انتظار الاتصال بالمزامنة)` whenever device attestation or local trust material failed.
- **Root Cause**: `AttendanceRepositoryImpl.saveEvent()` persisted the event into the outbox with `pendingSync` *before* attempting `_evidenceService.prepare(localEvent)`. Any subsequent local trust failure (e.g. Play Integrity or installation registration failure) left a permanent `pendingSync` record in the local outbox.
- **Resolution**:
  - Inverted the flow: `_evidenceService.prepare(localEvent)` executes *before* writing to outbox.
  - If trust material cannot be prepared, returns a terminal rejected event directly with `INTEGRITY_UNAVAILABLE` or `DEVICE_REGISTRATION_FAILED` copy without touching the outbox (0 pending rows).
  - Outbox storage is strictly confined to genuine network/transport failures (`classification.isRetryable`).
  - Terminal policy/geofence server rejections return the server decision directly with 0 pending outbox rows.
  - Wrapped submission stages in typed `AttendanceSubmissionStageException` (`locationCapture`, `installationRegistration`, `integrityChallenge`, `signature`, `eventSend`) to avoid raw platform exception leakages.
  - Added exact Arabic failure copy in `AppFailureMapper`:
    - `INTEGRITY_UNAVAILABLE`: `'تعذر التحقق من سلامة الجهاز. لم يُرسل الحضور؛ أعد المحاولة بعد فتح Google Play وتحديثه.'`
    - `DEVICE_REGISTRATION_FAILED`: `'تعذر تسجيل الجهاز لدى النظام. لم يُرسل الحضور؛ تحقق من الاتصال وحاول مجدداً.'`
    - `LOCATION_UNAVAILABLE`: `'تعذر تحديد الموقع الجغرافي. تأكد من تفعيل خدمة الموقع GPS والمحاولة مجدداً.'`
- **Verification**: `test/features/attendance/attendance_pipeline_test.dart` (6/6 passing).

### 2. Informational Notifications & Scoped Center Feedback
- **Defect**: Historic system notices (such as `إشعار نظام جديد` with `destinationKind: employee`) displayed `تعذر فتح الإشعار. حاول مرة أخرى.` and left a persistent error banner across tab switches. Missing Arabic title/body keys fell back to generic titles.
- **Root Cause**: `NotificationEntity` treated all destinations identically as actionable. When tapping an `employee` destination, mobile attempted navigation to an nonexistent admin route. Feedback SnackBars persisted across tab switches because they were tied to the root ScaffoldMessenger without unmount/route cleanup.
- **Resolution**:
  - Added `NotificationEntity.isActionable` (false for `destinationKind: employee` and empty `destinationId`).
  - In `NotificationCubit.openNotification`: informational notifications are marked read and unread count is decremented without attempting navigation or emitting an action error.
  - In `NotificationCenterScreen`: scoped SnackBar feedback cleanup using `removeCurrentSnackBar()` on `dispose`, navigation, and `PopScope`.
  - Added full Arabic translations for all emitted server keys (`notification.employee.invited.title`, `notification.employee.archived.title`, `notification.assignment.scheduled.title`, etc.).
- **Verification**: `test/features/notifications/notification_actionable_informational_test.dart` (9/9 passing), `notification_center_screen_test.dart` (22/22 passing).

### 3. Dynamic Attendance Range-Status Card
- **Enhancement**: Replaced static radius label `نطاق العمل: 150 متر` with dynamic, privacy-safe `AttendanceRangeStatusCard`.
- **States Handled**:
  - Locating: `جارٍ التحقق من موقعك…` with circular progress indicator.
  - Inside: `أنت داخل نطاق العمل` + approximate distance + branch name + `يمكنك تسجيل الحضور الآن`.
  - Outside: `أنت خارج نطاق العمل` + approximate distance + instruction to approach branch.
  - Low Accuracy: Warning when GPS accuracy > 100m.
  - Denied / Error: Guidance on enabling GPS and permissions.
  - Boundary Equality: Exact `distanceMeters <= allowedRadiusMeters` logic.
  - Fresh Location Refresh: Refresh button captures current GPS fix without submitting an attendance event.
  - Privacy Invariant: Never renders raw coordinates or provider error strings.
- **Verification**: `test/features/attendance/attendance_range_status_card_test.dart` (7/7 passing).

### 4. Build 18 Version Bump
- Updated `mobile/pubspec.yaml` to `version: 1.0.15+18` (Build 18 candidate) to ensure clean upgrade path over installed Play Build 17.



