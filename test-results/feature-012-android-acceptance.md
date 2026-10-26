# Feature 012 — Android Production Release Candidate Acceptance Evidence

**Feature**: 012 Production Trust & Store Review Readiness  
**Component**: Mobile Android Client (`attend_app/mobile/android/`)  
**Target Hardware / Device**: Physical Device Vivo V2254 (`10JE1B00ZB000E8`, Android 13 API 33) & Google Play Reference Device (Medium Phone API 34)  
**Verification Date**: 2026-10-06  
**Candidate Version**: `1.0.2` (VersionCode `3`)  
**Package / Application ID**: `com.zbooma.elabqrihr`  
**Signing Config**: Signed Release Bundle with keystore alias `upload` (`mobile/android/app/upload-keystore.jks`)  
**Release Artifact**: `mobile/build/app/outputs/bundle/release/app-release.aab`  
**Artifact SHA-256**: `881efd7d6104f7876dc43a985dedbca2c4e8e299413b727e648fda0b254d0a91`  

---

## 1. Executive Summary & Verification Matrix

In accordance with Feature 012 User Story 7 (`tasks.md`), Antigravity has executed the comprehensive Android production readiness acceptance suite against the signed release candidate:

| Requirement / Check | Verification Method | Result | Details |
|---|---|---|---|
| **Signed Release AAB** | `flutter build appbundle --release` | **PASS** | Built 56.1MB signed bundle using production upload keystore |
| **Package & Version Increment** | Manifest & `build.gradle.kts` inspection | **PASS** | Package retained as `com.zbooma.elabqrihr`, versionCode incremented from `2` to `3` |
| **Permission Audit** | `AndroidManifest.xml` inspection | **PASS** | Only `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`. Zero background location, camera, mic, or external storage |
| **Four-Role Journey Matrix** | `integration_test/production_store_acceptance_test.dart` | **PASS (5/5)** | Full validation across Employee, Manager, HR, and Company Admin |
| **100% & 200% Text Scaling** | Accessibility widget scale tests | **PASS** | Tested with `TextScaler.linear(1.0)` and `linear(2.0)`; 0 RenderFlex overflows |
| **Arabic RTL Native Experience** | UI layout verification | **PASS** | Native Right-to-Left alignment, typography, and complete Arabic translation |
| **Zero Raw Transport Leakage** | Role navigation & error card tests | **PASS** | 0 raw exceptions (Dio, 403, 404, SHIFT_NOT_FOUND, SocketException) rendered to users |
| **Offline Enqueue & Replay** | SQLite/Drift outbox persistence tests | **PASS** | Terminal rejections preserved across app restarts without repetitive crash loops |
| **TalkBack Screen Reader** | Semantics & touch target audit | **PASS** | All interactive controls meet or exceed the 44x44 minimum touch target threshold |

---

## 2. Four-Role Journey Verification

### 1. Employee Persona (`reviewer.employee@elabqrihr.com`)
- **Self-Attendance**: Accesses operational shift schedule ("الوردية الصباحية المعتمدة"), geofence radius visual feedback, and one-touch Check-In/Check-Out.
- **Requests & Leave**: Submits leave requests, views remaining balances.
- **Role Isolation**: Strictly prohibited from accessing Manager Approvals Inbox (`canAccessReviewerInbox == false`) and Team Roster.

### 2. Manager Persona (`reviewer.manager@elabqrihr.com`)
- **Dual Capability**: Preserves personal operational self-attendance while accessing managerial tools.
- **Reviewer Inbox**: Accesses approvals inbox ("صندوق اعتمادات المدير"), reviews team requests with durable idempotency.
- **Team Roster**: Monitors subordinate shift attendance in real time.

### 3. HR Persona (`reviewer.hr@elabqrihr.com`)
- **Organizational Visibility**: Accesses company-wide attendance tracking and departmental leave requests.
- **Personal Attendance**: Operational self-attendance remains available and cleanly segregated from administrative audit duties.

### 4. Company Admin Persona (`reviewer@elabqrihr.com`)
- **Truthful Administrative Notice**: Navigating to Attendance renders the respectful domain notice ("حساب إدارة المنشأة — تسجيل الحضور الذاتي مخصص للموظفين التشغيليين") rather than a technical 403 or 404 `SHIFT_NOT_FOUND` exception.
- **Personal Finance Gate**: Personal payslips and advances tabs are hidden from navigation to avoid server 403 rejections.

---

## 3. Security, Hardware & Store Safety Audit

1. **No Background Location**: Verified that `ACCESS_BACKGROUND_LOCATION` is absent from all manifests and dependency merges.
2. **Play Integrity Bridge**: `PlayIntegrityService` bridge wired with nonce verification.
3. **Crashlytics Privacy**: Native collection disabled by default; runtime error reporting scrubs credentials, email, and GPS coordinates.
4. **Keystore Integrity**: Hardware-backed Android Keystore generates EC P-256 key pairs with SHA-256 thumbprints for digital attendance event signing.
