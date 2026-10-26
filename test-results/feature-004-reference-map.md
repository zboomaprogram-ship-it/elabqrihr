# Feature 004 — Architecture & Information Architecture Reference Map

**Feature**: 004 — Product Experience and Configurable Requests  
**Author**: Antigravity (Mobile Engineer)  
**Governing Work Order**: `plan/ANTIGRAVITY_WORK_ORDER_004.md`  
**Structural Reference**: `../zawolf_hr/specs/ui_redesign/` (specs 01 through 06)  
**Visual Brand**: **العبقري HR** (Attend)  
**Write Boundary**: `mobile/` exclusively

---

## 1. Executive Summary & Design System Mapping

The structural redesign adopts the information architecture, dashboard hierarchy, section order, component responsibilities, spacing discipline, grouped navigation, and state coverage from `zawolf_hr/specs/ui_redesign/`. It **completely rejects and discards** the legacy dark cyberpunk/cyan visual identity (`#050607`, `#45F0FF`, `#166C8C`, dark cards, glow effects).

### Visual Identity Tokens (Attend / العبقري HR)

| Token Role | Hex Value | Semantic Usage |
|---|---|---|
| **Primary Brand** | `#0272F2` | Primary buttons, active navigation indicators, key branding accents |
| **Secondary Accent** | `#AAD5FF` | Soft badges, focused borders, subtle highlights |
| **Canvas / Background** | `#F8FAFC` | Scaffold canvas background (light slate) |
| **Surface** | `#FFFFFF` | Cards, modals, bottom sheets, navigation bar, app bar |
| **Surface Subdued** | `#F1F5F9` | Secondary containers, input background fill, inactive chips |
| **Border / Divider** | `#E2E8F0` | Card borders (1px solid), table dividers, outline borders |
| **Text Primary** | `#17162E` | High-contrast headings, primary labels, card titles |
| **Text Secondary** | `#64748B` | Subtitles, metadata, timestamps, helper text |
| **Text Muted** | `#94A3B8` | Placeholders, disabled text |
| **Status Success** | `#10B981` | Present, approved, normal sync |
| **Status Warning** | `#F59E0B` | Pending review, late, warning state |
| **Status Danger** | `#EF4444` | Rejected, conflict, error, absent |

---

## 2. Component Mapping (ZaWolf Spec 01 & 04 -> Attend Mobile)

| ZaWolf Redesign Spec Component | Attend Mobile Component / Path | Visual Adaptation |
|---|---|---|
| `WolfCard` | `AttendCard` (`mobile/lib/core/design_system/widgets/attend_card.dart`) | Radius 12, `#FFFFFF` surface, `#E2E8F0` border, subtle shadow. No dark fill, no cyan border glow. |
| `StatCard` | `AttendStatCard` / `StatCard` | Radius 12, clean white container, semantic icon background tint, large display number in `#17162E`. |
| `StatusPill` | `AttendStatusPill` (`mobile/lib/core/design_system/widgets/attend_status_pill.dart`) | Fully rounded pill, soft semantic background fill, high-contrast dark semantic text. |
| `SectionHeader` | `AttendSectionHeader` | Arabic title in 18px w600 (`#17162E`), optional trailing action button in `#0272F2`. |
| `EmptyState` | `AppMotion` / `AttendEmptyState` | Local Lottie semantic animation + Arabic title + explanatory caption + optional action. |
| `ErrorState` | `AttendErrorState` | Bounded error container, safe Arabic translation via `AppFailureMapper`, retry button. |
| `PriorityStrip` | `AttendPriorityStrip` | Prominent top banner alerting user of actionable pending items (e.g. pending approvals). Hidden when count is 0. |
| `FilterBar` | `AttendFilterBar` | Horizontal scrollable chip bar; selected chip filled with `#0272F2` (white text); unselected `#F1F5F9`. |
| `CheckInRadarButton` | `AttendRadarButton` | 140x140 circular radar button, `#0272F2` gradient, ripple pulse animation, center action text. |
| `Avatar` | `AttendAvatar` | Initials circular avatar, `#AAD5FF` background with `#0272F2` text. |

---

## 3. Screen Anatomy & Dashboard Structure (ZaWolf Spec 03 & 06 -> Attend Mobile)

### Home Screen (الرئيسية) — Employee & Management Roles
Follows R1 Anatomy strictly:
1. **Header**:
   - Branded Attend logo (`assets/images/logo.png`)
   - Arabic greeting ("مرحباً بك", user full name)
   - Date in Hijri / Gregorian Arabic format
   - Avatar / profile launcher
2. **Status Card** (Largest tap target):
   - Current day check-in/out status
   - Shift hours and branch name
   - Quick check-in action
3. **PriorityStrip**:
   - Tappable alert for pending requests / approvals needing action
   - Automatically hidden when 0 items
4. **Quick Actions Grid** (Max 4 items):
   - New Request (طلب جديد)
   - Shift Schedule (جدول الورديات)
   - Requests History (سجل الطلبات)
   - Pilot Guidance (دليل الاستخدام)
5. **Recent Activity**:
   - Last relevant request transitions and approval milestones

---

## 4. Role Navigation Matrix (ZaWolf Spec 02 -> Attend Mobile)

Only supported capabilities for Feature 004 are exposed in the navigation shell. All unapproved, web-only, or future financial features are strictly excluded.

| Role | Tab 1 | Tab 2 | Tab 3 | Tab 4 | Excluded / Future Capabilities |
|---|---|---|---|---|---|
| **Employee** | Home (`الرئيسية`) | Attendance (`الحضور`) | Requests (`الطلبات`) | Profile (`حسابي`) | No payroll, advances, tasks, performance badges |
| **Manager** | Home (`الرئيسية`) | Team (`الفريق`) | Approvals (`الموافقات`) | Profile (`حسابي`) | No payroll, advances, salary deductions |
| **HR / Admin** | Home (`الرئيسية`) | Attendance (`الحضور`) | Approvals (`الطلبات والموافقات`) | Profile (`حسابي`) | No web administration tools, no financial disbursements |

---

## 5. Request Catalog & Workflow Boundary

### Included Workflows (Feature 004 Supported)
1. **Leave Requests** (`طلب إجازة`): Built-in category selection, balance checking, date range picker, reason.
2. **Permission Requests** (`طلب إذن`): Built-in active shift binding, time duration picker, reason.
3. **Attendance Correction** (`تصحيح بصمة`): Built-in shift picker, missed check-in/out selection, reason.
4. **Dynamic Tenant Requests**: Loaded from tenant-published definitions (or local fallback definitions).

### Strictly Excluded Financial Workflows
The following workflows are **forbidden** in Feature 004 and have been completely removed from presentation, domain, and catalog code:
- Financial Advances (`سلفة مالية` / `advance`)
- Loans (`قرض` / `loan`)
- Expense Reimbursements (`استرداد مصروفات` / `reimbursement`)
- Salary Adjustments & Deductions (`تعديل الراتب` / `payroll_adjustment`)
- Payslip Inspection (`قسيمة الراتب` / `payslip`)

---

## 6. Asset & Motion Journey Contract

| User Journey | Asset Path | Asset Role | Reduced Motion Fallback |
|---|---|---|---|
| **App Bootstrap / Session Gate** | `assets/images/splash.png` + `assets/animations/splash_onboarding.json` | Visual brand recognition during auth check | Static `splash.png` with progress indicator |
| **Sign-in & Branded AppBars** | `assets/images/logo.png` | Attend official logo | N/A (Static image) |
| **Accepted Attendance Punch** | `assets/animations/checkin_success.json` | Immediate positive feedback on punch acceptance | Static `Icons.check_circle` in green |
| **Durable Request Submission** | `assets/animations/request_submitted.json` | Confirmation of local or server submission | Static `Icons.send_rounded` |
| **Empty Request History** | `assets/animations/empty_requests.json` | Encouraging empty state in requests tab | Static `Icons.inbox_outlined` |
| **Offline Sync / Queue In Progress**| `assets/animations/offline_sync.json` | Visual indicator that events are syncing | Static `Icons.sync` icon |
| **Empty Approvals Inbox** | `assets/animations/no_approvals.json` | Empty state in manager approvals screen | Static `Icons.done_all_rounded` |
