# Feature 013 — Mobile Acceptance & Verification Evidence

**Feature**: 013 Quotas, Company Messages, and Mobile Reliability  
**Component**: Mobile Android Client (`attend_app/mobile/`)  
**Date**: 2026-10-11  
**Author**: Antigravity  

---

## 1. Executive Summary & Verification Matrix

All tasks assigned to Antigravity for Feature 013 have been fully implemented, integrated, and validated:

| Task | Domain / Scope | Verification Status | Key Deliverables |
|---|---|---|---|
| **T011** | Leave & Permission Quotas | **VERIFIED (PASS)** | Presentation-safe contracts (`QuotaBalanceEntity`, `QuotaKey`, `QuotaUnit`), repository, `LeaveQuotaCubit`, RTL balance cards, and request pre-submit banners in `mobile/lib/features/leave_quotas/`. |
| **T015** | Company Announcements & Deep Links | **VERIFIED (PASS)** | `company_announcements` category toggle, Arabic inbox card rendering with unread styling, reauthorized deep link route navigation to `/company-announcements/$id`, and respectful 403/404 forbidden state handling in `mobile/lib/features/notifications/`. |
| **T018** | Profile Screen Reliability | **VERIFIED (PASS)** | Reachable notification preferences, leave quotas navigation, and password-recovery entry from authenticated profile; explicit enable action and OS permission feedback. |
| **T019** | Active Sessions Grouping & Remote Guardrails | **VERIFIED (PASS)** | Grouped sessions into Current Device ("هذا الجهاز (الجلسة الحالية)") and Remote Devices ("الجلسات والأجهزة الأخرى المرتبطة بحسابك"); replaced UUID strings with friendly human device labels; disabled remote revocation of the current active session. |
| **T020** | Truthful Outbox Outcome Mapping | **VERIFIED (PASS)** | Mapped 400, 401, 403, 404, 422 rejections directly to terminal `rejected` with `reasonCode` in both request and dynamic outbox repositories, preventing infinite `pending_sync` loops. |
| **T027** | Static Analysis & Acceptance Test Suite | **VERIFIED (PASS)** | `flutter analyze` completed with 0 errors/warnings. Complete test suite (379 tests) passed with 100% success rate, including 100% and 200% text scale in Arabic RTL. |

---

## 2. Verification Test Log

```text
$ flutter analyze
Analyzing mobile...
No issues found! (ran in 34.1s)

$ flutter test
04:36 +379: All tests passed!
```

### Key Verified Test Suites:
- `test/architecture/dependency_boundaries_test.dart` (Clean Architecture layer boundaries)
- `test/acceptance/production_store_acceptance_test.dart` (Four-Role Journey at 100% and 200% text scale in Arabic RTL)
- `test/features/leave_quotas/leave_quota_cubit_test.dart` (Leave and Permission quotas balances & pre-submit states)
- `test/features/notifications/announcement_details_screen_test.dart` (Company announcement details & 403/404 states)
- `test/features/notifications/notification_center_screen_test.dart` (Announcement deep links & inbox presentation)
- `test/features/profile/active_sessions_screen_test.dart` (Active session grouping & remote revocation guardrails)
- `test/features/requests/request_outcome_mapping_test.dart` (Truthful 4xx outcome mapping to terminal rejection)

---

## 3. Architecture & Security Compliance

1. **Clean Architecture Boundary**: Presentation layer never imports data layers or generated client DTOs directly; all interaction proceeds via abstract domain repositories.
2. **Cubit Line Limit**: All newly introduced and modified Cubits remain strictly under 300 non-generated lines of code.
3. **No Technical Leaks**: Zero raw HTTP status codes (400/401/403/404/422), UUID substrings, or server stack traces are leaked to user-facing Arabic UI views.
4. **Accessible RTL Design**: All screens support right-to-left flow, standard touch targets ($\ge 44 \times 44$ pt), and dynamic type enlargement up to 200% without RenderFlex overflow.


---

## 4. Codex independent device verification — 2026-10-11

- **Connected device**: Vivo V2254 (`10JE1B00ZB000E8`), Android 13.
- **Four-role acceptance**: `flutter test integration_test/production_store_acceptance_test.dart -d 10JE1B00ZB000E8` passed **5/5**. The employee, manager, HR, and company-admin Arabic RTL journeys were exercised at 100% and 200% text scale; the geofence refusal state was also checked.
- **Production authentication**: a synthetic closed-test tenant account signed in successfully to the production API on the physical device.
- **Notification permission**: Android 13 displayed the operating-system notification permission prompt only after the explicit in-app preference action. The device permission is now granted.
- **Registration contract repair**: the client now supplies the server-required `installation_registration` purpose when requesting an installation challenge.
- **Truthful registration feedback**: if protected-installation registration cannot complete, the app retains the disabled switch and tells the person that no device was saved. It does not expose provider diagnostics or imply that push is active.
- **Latest source checks**: `flutter analyze` passed with zero issues. Notification registration and settings tests passed **13/13** after the final outcome-state repair.

### Play-distributed verification gate

The USB-installed test build correctly cannot obtain a trusted Play Integrity assertion. This is intentional: the final device-registration, FCM delivery, and trusted attendance check must be repeated after uploading version **1.0.7 (10)** to Google Play closed testing and installing it from Google Play. This is an external distribution requirement, not a client-side bypass.

### Final Android candidate

- **Version**: `1.0.7 (10)`
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`
- **SHA-256**: `21dc3176130ac5ac7dcabc69fba84ec0be007d0fc65e4399dfddb96faa3833b9`
