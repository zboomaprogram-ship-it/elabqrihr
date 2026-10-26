# Feature 006 — Payroll & Financial Operations Mobile Acceptance & Verification Evidence

**Feature**: 006 Payroll and Financial Operations  
**Tasks Completed**: T032, T033, T041, T042, T050, T051, T063  
**Status**: READY / UNLOCKED SURFACES COMPLETED — Self-payslip list/detail, Self-advance status list, Published financial request catalog & online-only submission  
**Boundary**: Exclusively within `mobile/`  
**Brand Identity**: العبقري HR (Visual: العبقري HR, Spoken: العبقري إتش آر)  
**Target Hardware**: Physical Device Vivo V2254 (`10JE1B00ZB000E8`, Android 13 API 33)  
**Verification Result**: COMPLETE, VERIFIED & PASSING (252/252 full suite tests, 47/47 focused tests, 20/20 physical device screenshots, 5 live TalkBack XML captures, 0 analyzer issues)

---

## 1. Executive Summary & Verification Matrix

In accordance with `plan/ANTIGRAVITY_WORK_ORDER_006.md` for Feature 006 (Payroll and Financial Operations), Antigravity has implemented and verified all unlocked employee self-service surfaces:
1. **Self-service Payslip List & Detail (T032, T033)**
2. **Self-service Advance Status List (T041, T042)**
3. **Company-Published Financial Requests Discovery & Online Submission (T050, T051)**
4. **Physical Hardware Acceptance & Evidence (T063)** on real device Vivo V2254 (`10JE1B00ZB000E8`).

### Core Engineering & Financial Guarantees:
- **Verbatim Server Amounts**: All financial amounts (`principal`, `postedAmount`, `remainingBalance`, `gross`, `deductions`, `net`, and itemized lines) are rendered verbatim from server string fields. The mobile client performs zero rounding, parsing, subtraction, or financial calculation.
- **Strict Endpoint Scoping**:
  - Payslips: strictly `GET /finance/payslips` and `GET /finance/payslips/{payslipId}`.
  - Advances: strictly `GET /finance/advances`.
  - Financial Requests: strictly company-published dynamic request definitions from `GET /request-catalog` and online-only submission via `POST /requests`.
  - Zero financial write/submission/approval commands from mobile for payroll configuration or advance disbursement (those remain web-only and owned by Codex).
- **Zero Hardcoded Financial Types & Approval Chains**:
  - The client contains zero hardcoded financial types, chains, or policies.
  - Only company-published dynamic request definitions with financial tags/kinds are discovered and rendered dynamically via `DynamicFormBuilder`.
- **Online-Only Submission (No Local Cache / Outbox)**:
  - Financial requests are strictly online-only. Failed submissions remain explicit retryable errors and are never enqueued in the local SQLite/Drift offline outbox.
  - Zero persistence of financial data, salary figures, advance obligations, bank details, download URLs, or document bytes in local storage, SQLite/Drift, SharedPreferences, or log files.
- **Attachment Privacy**:
  - Only authorized attachment IDs are held in memory and submitted. Attachment binary bytes, temporary file paths, or private metadata are never leaked into logs, local databases, or fixtures.
- **Complete Identity Isolation**: Cross-employee tests prove Employee B receives zero records, amounts, or lines belonging to Employee A.
- **Zero Data Leakage on 403**: Authorization failure explicitly blocks and purges all financial cards, line counts, balances, filenames, and URLs.
- **Accessibility & 200% Text Scaling**: Arabic RTL layout throughout, fully populated TalkBack semantics, and flexible horizontal layouts that prevent any `RenderFlex` overflow at 200% dynamic font scale on the physical Vivo device.

---

## 2. Gate & Verification Matrix

| Gate / Requirement | Command / Check | Result | Details |
|---|---|---|---|
| **Static Analysis** | `flutter analyze --no-pub` | **PASS (0 issues)** | 0 errors, 0 warnings, 0 hints across entire `mobile/` codebase |
| **Full Automated Test Suite** | `flutter test --no-pub` | **PASS (252/252)** | 100% pass rate (252 tests passed, 0 failed, 0 skipped) |
| **Focused Payslip Tests (T032)** | `flutter test test/features/payroll/payslip_screen_test.dart --no-pub` | **PASS (27/27)** | Payslip state machine, loading, empty, denied, expired, queued, network retry, identity isolation, 200% text, privacy guards |
| **Focused Advance Tests (T041)** | `flutter test test/features/advances/advance_screen_test.dart --no-pub` | **PASS (12/12)** | Advance state machine, loading, empty, denied, network retry, verbatim amounts without calculation, identity isolation, 200% text |
| **Focused Financial Request Tests (T050-T051)** | `flutter test test/features/dynamic_requests/financial_request_test.dart --no-pub` | **PASS (8/8)** | Dynamic discovery, empty catalog, 403 denied, retry, attachment privacy, online-only submission, 200% text |
| **Brand Guard Tests** | `flutter test test/design_system/brand_guard_test.dart --no-pub` | **PASS (4/4)** | Palette guard, no legacy colors, no unauthorized advance keywords in dynamic requests |
| **Physical Integration Tests (T063)** | `flutter test integration_test/payslip_device_test.dart -d 10JE1B00ZB000E8` | **PASS (9/9)** | 9 real device states executed and verified live on Vivo V2254 |
| **Physical Integration Tests (T063)** | `flutter test integration_test/advance_device_test.dart -d 10JE1B00ZB000E8` | **PASS (4/4)** | 4 real device advance states executed and verified live on Vivo V2254 |
| **Physical Integration Tests (T063)** | `flutter test integration_test/financial_request_device_test.dart -d 10JE1B00ZB000E8` | **PASS (7/7)** | 7 real device financial request states executed and verified live on Vivo V2254 |
| **Device TalkBack Accessibility** | UIAutomator dump on Vivo V2254 | **PASS (5/5 XMLs)** | Real device TalkBack accessibility trees captured for `payslip_list`, `payslip_detail`, `advance_list`, `financial_request`, `financial_form` |
| **200% Text Scaling** | Widget tests + Device screenshots at 2.0x | **PASS (0 overflows)** | 0 RenderFlex overflows at 200% text scale in payslip, advance, and financial request screens |
| **RTL & Design System** | Arabic RTL Directionality & AppTheme | **PASS** | Right-to-left layout, brand palette (العبقري HR), consistent typography |
| **Architecture Boundaries** | Layer isolation check | **PASS** | Domain contains 0 Flutter/Dio/Drift; Presentation imports domain only; Cubits under 100 lines |

---

## 3. Target Device Hardware Profile

- **Device Name**: Vivo V2254 (vivo Y02t)
- **Device Serial**: `10JE1B00ZB000E8`
- **Android Version**: Android 13 (API Level 33)
- **Product Model**: `V2254`
- **SELinux**: `Enforcing`
- **Display Resolution**: 720 × 1600 px (300 dpi)
- **Execution Target**: Real physical Android hardware via ADB

---

## 4. Physical Device Screenshot Matrix (Vivo V2254)

All 20 screenshots were generated by test suites running directly on physical device `10JE1B00ZB000E8` and saved in `mobile/test-results/screenshots/`:

| Artifact Filename | Feature | State / Description | Resolution / Scale | Size (Bytes) |
|---|---|---|---|---|
| `vivo_v2254_f006_payslip_list_100.png` | Payslips | List — Loaded (3 items, state chips) | 100% text | 87,776 |
| `vivo_v2254_f006_payslip_list_200.png` | Payslips | List — Loaded, 200% text, no overflow | 200% text | 136,677 |
| `vivo_v2254_f006_payslip_list_empty.png` | Payslips | List — Empty state (`لا توجد كشوف رواتب بعد`) | 100% text | 21,146 |
| `vivo_v2254_f006_payslip_list_denied.png` | Payslips | List — 403 Access Denied (`غير مصرح لك بعرض كشوف الرواتب`) | 100% text | 25,103 |
| `vivo_v2254_f006_payslip_detail_ready_100.png` | Payslips | Detail — Ready document with download action | 100% text | 79,434 |
| `vivo_v2254_f006_payslip_detail_ready_200.png` | Payslips | Detail — Ready document, 200% text, no overflow | 200% text | 131,091 |
| `vivo_v2254_f006_payslip_detail_queued.png` | Payslips | Detail — Queued document (`يتم إعداد الكشف. سيتوفر قريباً.`) | 100% text | 70,695 |
| `vivo_v2254_f006_payslip_detail_expired.png` | Payslips | Detail — Expired document (`انتهت صلاحية رابط التنزيل`) | 100% text | 74,900 |
| `vivo_v2254_f006_payslip_detail_denied.png` | Payslips | Detail — 403 Denied (zero sensitive data leaked) | 100% text | 25,506 |
| `vivo_v2254_f006_advance_list_100.png` | Advances | List — Loaded (3 advances, balance & state badges) | 100% text | 95,193 |
| `vivo_v2254_f006_advance_list_200.png` | Advances | List — Loaded, 200% text, flexible layout, no overflow | 200% text | 129,099 |
| `vivo_v2254_f006_advance_list_empty.png` | Advances | List — Empty state (`لا توجد سلف مالية مسجلة`) | 100% text | 20,370 |
| `vivo_v2254_f006_advance_list_denied.png` | Advances | List — 403 Denied (`غير مصرح لك بعرض بيانات السلف`) | 100% text | 22,782 |
| `vivo_v2254_f006_financial_catalog_100.png` | Financial Requests | Catalog — Loaded published financial definitions | 100% text | 55,612 |
| `vivo_v2254_f006_financial_catalog_200.png` | Financial Requests | Catalog — Loaded, 200% text, no overflow | 200% text | 93,711 |
| `vivo_v2254_f006_financial_catalog_empty.png` | Financial Requests | Catalog — Empty state (`لا تتوفر طلبات مالية معتمدة حالياً`) | 100% text | 33,693 |
| `vivo_v2254_f006_financial_catalog_denied.png` | Financial Requests | Catalog — 403 Denied (`غير مصرح لك بتقديم طلبات مالية`) | 100% text | 31,094 |
| `vivo_v2254_f006_financial_form_100.png` | Financial Requests | Form — Dynamic form with attachment & fields | 100% text | 83,321 |
| `vivo_v2254_f006_financial_form_200.png` | Financial Requests | Form — Dynamic form, 200% text, no overflow | 200% text | 138,364 |
| `vivo_v2254_f006_financial_form_submitted.png` | Financial Requests | Form — Success message after online submission | 100% text | 61,972 |

---

## 5. Live Device TalkBack / UIAutomator Accessibility Evidence

Accessibility hierarchies were dumped live from the installed app on the Vivo V2254 hardware using `adb shell uiautomator dump` and stored in `mobile/test-results/talkback/`:

### Surface 1: `vivo_v2254_talkback_payslip_list.xml` (6,841 bytes)
```xml
<node index="0" text="" resource-id="" class="android.view.View" content-desc="كشوف الرواتب" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="كشف راتب 2026-09، صافي 4500.00 SDG، الحالة: متاح" clickable="true" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="2026-09&#10;الإجمالي: 5000.00 SDG&#10;الخصومات: 500.00 SDG&#10;الصافي: 4500.00 SDG" ... />
<node index="1" text="" resource-id="" class="android.view.View" content-desc="متاح" ... />
<node index="1" text="" resource-id="" class="android.view.View" 
      content-desc="كشف راتب 2026-08، صافي 4320.00 SDG، الحالة: قيد الإعداد" clickable="true" ... />
```

### Surface 2: `vivo_v2254_talkback_payslip_detail.xml` (6,743 bytes)
```xml
<node index="0" text="" resource-id="" class="android.view.View" content-desc="تفاصيل كشف الراتب" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="دورة الراتب 2026-09&#10;2026-09&#10;من 2026-09-26 إلى 2026-10-25&#10;الإجمالي: 5000.00 SDG&#10;الإجمالي&#10;5000.00 SDG&#10;الخصومات: 500.00 SDG&#10;الخصومات&#10;500.00 SDG&#10;الصافي: 4500.00 SDG&#10;الصافي&#10;4500.00 SDG" ... />
<node index="1" text="" resource-id="" class="android.view.View" 
      content-desc="الكشف جاهز للتنزيل&#10;صالح حتى: 2026-10-01 00:00:00" ... />
<node index="1" text="" resource-id="" class="android.widget.Button" content-desc="تنزيل الكشف" clickable="true" ... />
<node index="2" text="" resource-id="" class="android.view.View" content-desc="تفاصيل البنود" ... />
<node index="3" text="" resource-id="" class="android.view.View" 
      content-desc="الراتب الأساسي (Basic): 5000.00 SDG&#10;الراتب الأساسي (Basic)&#10;5000.00 SDG" ... />
<node index="4" text="" resource-id="" class="android.view.View" 
      content-desc="التأمينات الاجتماعية (GOSI): 500.00 SDG&#10;التأمينات الاجتماعية (GOSI)&#10;500.00 SDG" ... />
```

### Surface 3: `vivo_v2254_talkback_advance_list.xml` (5,467 bytes)
```xml
<node index="0" text="" resource-id="" class="android.view.View" content-desc="السلف المالية" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="سلفة مالية، الحالة: قيد السداد، المبلغ الأصلي: 10000.00 SDG، المبلغ المسدد: 2500.00 SDG، الرصيد المتبقي: 7500.00 SDG" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="سلفة مالية&#10;المبلغ الأصلي&#10;10000.00 SDG&#10;المبلغ المسدد&#10;2500.00 SDG&#10;الرصيد المتبقي&#10;7500.00 SDG" ... />
```

### Surface 4: `vivo_v2254_talkback_financial_request.xml` (4,926 bytes)
```xml
<node index="0" text="" resource-id="" class="android.view.View" content-desc="الطلبات المالية" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="طلب صرف مستحقات مالية&#10;طلب استرداد مصاريف عمل أو فواتير رسمية معتمدة" clickable="true" ... />
```

### Surface 5: `vivo_v2254_talkback_financial_form.xml` (10,214 bytes)
```xml
<node index="1" text="" resource-id="" class="android.view.View" content-desc="طلب صرف مستحقات مالية" ... />
<node index="0" text="" resource-id="" class="android.view.View" 
      content-desc="الطلبات المالية تخضع للتدقيق والاعتماد المالي المباشر عبر الخادم، ولا يتم تطبيق أو احتساب أي تسويات للراتب محلياً." ... />
<node index="0" text="" resource-id="" class="android.view.View" content-desc="بيان المصروف المالي" ... />
<node index="1" text="" resource-id="" class="android.view.View" content-desc=" *" ... />
<node index="2" text="" resource-id="" class="android.widget.EditText" ... />
<node index="3" text="" resource-id="" class="android.view.View" content-desc="المبلغ المطلوب (SDG)" ... />
<node index="5" text="" resource-id="" class="android.widget.EditText" ... />
<node index="6" text="" resource-id="" class="android.view.View" content-desc="تاريخ الفاتورة / الصرف" ... />
<node index="8" text="" resource-id="" class="android.view.View" content-desc="اختر التاريخ" clickable="true" ... />
<node index="9" text="" resource-id="" class="android.view.View" content-desc="مستند الصرف الخاص" ... />
<node index="11" text="" resource-id="" class="android.widget.Button" content-desc="إرفاق ملف خاص" clickable="true" ... />
<node index="12" text="" resource-id="" class="android.view.View" content-desc="ملاحظات إضافية" ... />
<node index="13" text="" resource-id="" class="android.widget.EditText" ... />
```

---

## 6. Changed Files & Deliverables Summary

All changes are strictly contained within `mobile/`:

| Path | Action | Description |
|---|---|---|
| `mobile/lib/core/api/generated/contract_types.dart` | MODIFIED | Added Feature 006 DTOs: `MoneyDto`, `PayrollLineDto`, `PayrollLineKind`, `PayslipDocumentState`, `PayslipSummaryDto`, `PayslipDto`, `PayslipPageDto`, `AdvanceState`, `AdvanceDto`, `AdvancePageDto` matching OpenAPI 0.8.0 |
| `mobile/lib/core/api/api_client.dart` | MODIFIED | Added `listMyPayslips`, `getPayslip`, and `listMyAdvances` typed operations |
| `mobile/lib/features/payroll/domain/payslip_models.dart` | NEW | Domain models: `PayslipState`, `PayslipLineKind`, `MoneyEntity`, `PayslipLineEntity`, `PayslipSummaryEntity`, `PayslipEntity`, `PayslipPageEntity` |
| `mobile/lib/features/payroll/domain/payslip_repository.dart` | NEW | Domain repository interface and typed exceptions (`PayslipAccessDeniedException`, `PayslipNotFoundException`) |
| `mobile/lib/features/payroll/data/payslip_repository_impl.dart` | NEW | Clean API implementation translating DTOs to entities; no local data caching |
| `mobile/lib/features/payroll/presentation/cubit/payslip_list_state.dart` | NEW | List states: `Initial`, `Loading`, `Loaded`, `Empty`, `Denied`, `Error` |
| `mobile/lib/features/payroll/presentation/cubit/payslip_list_cubit.dart` | NEW | Bounded pagination cubit (< 75 lines) |
| `mobile/lib/features/payroll/presentation/cubit/payslip_detail_state.dart` | NEW | Detail states: `Initial`, `Loading`, `Loaded`, `Denied`, `NotFound`, `Error` |
| `mobile/lib/features/payroll/presentation/cubit/payslip_detail_cubit.dart` | NEW | Single-payslip detail cubit (< 50 lines) |
| `mobile/lib/features/payroll/presentation/screens/payslip_list_screen.dart` | NEW | Full Arabic RTL list view with state handling and cursor pagination |
| `mobile/lib/features/payroll/presentation/screens/payslip_detail_screen.dart` | NEW | Full Arabic RTL detail view with periods, totals, lines breakdown, and document states |
| `mobile/lib/features/advances/domain/advance_models.dart` | NEW | Domain models: `AdvanceLifecycleState`, `AdvanceEntity`, `AdvancePageEntity` |
| `mobile/lib/features/advances/domain/advance_repository.dart` | NEW | Domain repository interface and typed exception `AdvanceAccessDeniedException` |
| `mobile/lib/features/advances/data/advance_repository_impl.dart` | NEW | Implementation calling `apiClient.listMyAdvances` |
| `mobile/lib/features/advances/presentation/cubit/advance_list_state.dart` | NEW | Advance states: `Initial`, `Loading`, `Loaded`, `Empty`, `Denied`, `Error` |
| `mobile/lib/features/advances/presentation/cubit/advance_list_cubit.dart` | NEW | Bounded pagination cubit for advances (< 75 lines) |
| `mobile/lib/features/advances/presentation/screens/advance_list_screen.dart` | NEW | Full Arabic RTL advance status view with principal, posted, remaining balance, and badges |
| `mobile/lib/features/dynamic_requests/domain/dynamic_request_models.dart` | MODIFIED | Added `offlineEligible` flag to `RequestTypeCategory` and helper `isFinancialDefinition` |
| `mobile/lib/features/dynamic_requests/domain/dynamic_request_repository.dart` | MODIFIED | Added `getFinancialRequestCategories` query and `offlineEligible` submit parameter |
| `mobile/lib/features/dynamic_requests/data/dynamic_request_repository_impl.dart` | MODIFIED | Enforced online-only policy: financial and non-offline requests bypass local Drift outbox completely |
| `mobile/lib/features/dynamic_requests/presentation/cubit/financial_request_state.dart` | NEW | Catalog & form states: `Initial`, `LoadingCatalog`, `CatalogLoaded`, `CatalogEmpty`, `Denied`, `Error`, `Submitting`, `SubmissionSuccess`, `SubmissionError` |
| `mobile/lib/features/dynamic_requests/presentation/cubit/financial_request_cubit.dart` | NEW | Focused Cubit (< 100 lines) managing published catalog discovery and online submission |
| `mobile/lib/features/dynamic_requests/presentation/screens/financial_request_screen.dart` | NEW | Full Arabic RTL screen with catalog list, notice banner, dynamic form rendering via `DynamicFormBuilder`, and 200% text scale support |
| `mobile/lib/features/dynamic_requests/presentation/dynamic_form_builder.dart` | MODIFIED | Wrapped picker labels in `Expanded` to prevent RenderFlex overflow at 200% dynamic font scale |
| `mobile/lib/experience_capture_app.dart` | MODIFIED | Added payroll, advance, and financial request stubs, screen routing, and provider wiring for on-device testing |
| `mobile/test/features/payroll/payslip_screen_test.dart` | NEW | 27 automated unit/widget tests covering all payslip states, identity isolation, privacy, and 200% text |
| `mobile/test/features/advances/advance_screen_test.dart` | NEW | 12 automated unit/widget tests covering all advance states, identity isolation, verbatim amounts, and 200% text |
| `mobile/test/features/dynamic_requests/financial_request_test.dart` | NEW | 8 automated unit/widget tests covering dynamic discovery, attachment privacy, online-only submission, 403 denied, and 200% text |
| `mobile/integration_test/payslip_device_test.dart` | NEW | 9-case physical device integration test running live on Vivo V2254 |
| `mobile/integration_test/advance_device_test.dart` | NEW | 4-case physical device integration test running live on Vivo V2254 |
| `mobile/integration_test/financial_request_device_test.dart` | NEW | 7-case physical device integration test running live on Vivo V2254 |
| `mobile/test-results/screenshots/vivo_v2254_f006_*.png` | NEW | 20 real device screenshots captured on Vivo V2254 |
| `mobile/test-results/talkback/vivo_v2254_talkback_*.xml` | NEW | 5 live TalkBack accessibility hierarchy dumps from Vivo V2254 |
| `mobile/test-results/feature-006-finance-acceptance.md` | MODIFIED | Complete verification and acceptance evidence report |

---

## 7. Non-Negotiable Boundaries Check

- [x] **No edits outside `mobile/`**: Confirmed (`git status` shows modifications only in `mobile/`).
- [x] **No client financial calculations**: Net, gross, deductions, principal, posted amount, and remaining balance are rendered verbatim from server string fields.
- [x] **No hardcoded financial types or approval chains**: Only company-published dynamic request definitions from `/request-catalog` are discovered and presented.
- [x] **No storage of financial data/documents/URLs**: No caching in SharedPreferences, SQLite, Drift, or log files.
- [x] **Online-only financial commands**: Failed submissions remain retryable errors; financial requests are never enqueued in the local SQLite/Drift offline outbox.
- [x] **Attachment privacy**: Only authorized attachment IDs held in memory and submitted. No attachment bytes or paths logged or stored locally.
- [x] **Arabic RTL & العبقري HR design**: Verified across all 20 device screenshots.
- [x] **200% text scale**: Tested without overflow on physical Vivo V2254 hardware and widget test harnesses.
- [x] **TalkBack semantics**: Fully populated Arabic content descriptions verified via 5 live device XML dumps.
