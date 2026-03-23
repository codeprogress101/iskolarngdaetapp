# LDSS-stage1 Auto Room Assignment + Exam Scheduling Implementation Plan (Read-Only Analysis)

## 1) Scope and Constraints
- Scan scope: `C:\Users\ADMIN\Desktop\LDSS-stage1` only.
- No code edits were performed in `LDSS-stage1`.
- This document is a planning and wiring report only.
- Local copy note: `LDSS-stage1` has no `.git` metadata in this environment, so latest-update evidence is based on dated files + README references.

## 2) Executive Summary
The basis portal already implements core exam scheduling: exam batch creation, control-number assignment, exam result encoding, and status transitions (`exam_scheduled`, `exam_completed`, `passed_exam`, `failed_exam`).

What is missing for robust auto room assignment:
- No dedicated room-assignment data model (`room`, `seat`) exists yet.
- Current location model is batch-level `venue` only.
- High-volume handling (~2000 examinees) is at risk because several flows load full datasets and process assignment row-by-row from the browser.

Recommended direction:
- Add centralized System Admin controls for room assignment defaults (number of rooms, examinees per room).
- Add explicit room-assignment schema and server-side bulk assignment routine.
- Keep secretary UI for review/override, not for heavy compute loops.

## 3) What Is Already Done (Basis Folder)

### 3.1 Exam Scheduling Core Exists
- DB tables exist for batches and records:
  - `exam_batches` with `batch_label`, `exam_datetime`, `venue`, `capacity`, `status`: `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1181`
  - `exam_records` with `batch_id`, `exam_control_no`, `scheduled_at`, `result`, `status`: `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1195`
- Indexes and update triggers exist:
  - `idx_exam_batches_datetime`, `idx_exam_records_batch_status`, etc.: `...ldss_phase1_schema_rls.sql:1275`
  - `trg_exam_batches_updated_at`, `trg_exam_records_updated_at`: `...ldss_phase1_schema_rls.sql:1285`
- RLS policies exist for staff/owner access:
  - `exam_batches_*` and `exam_records_*`: `...ldss_phase1_schema_rls.sql:1316`

### 3.2 Secretary Exam Batch UI + Logic Exists
- Page and UI controls for schedule/venue/capacity:
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:119`
  - `...secretary-exam-batches.html:123`
  - `...secretary-exam-batches.html:206`
- Batch creation inserts into `exam_batches`:
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:369`
  - `...supabase-secretary-exam-batches.js:380`
- Assignment writes `exam_records` and updates app status to `exam_scheduled`:
  - `...supabase-secretary-exam-batches.js:470`
  - `...supabase-secretary-exam-batches.js:478`
  - `...supabase-secretary-exam-batches.js:488`

### 3.3 Exam Result Encoding Exists
- Exam records are loaded and updated, then application status transitions:
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-results.js:226`
  - `...supabase-secretary-exam-results.js:343`
  - `...supabase-secretary-exam-results.js:352`

### 3.4 System Admin Settings Infrastructure Exists
- Scholarship settings page already persists `ranking_basis.controls` toggles:
  - HTML settings workspace: `C:\Users\ADMIN\Desktop\LDSS-stage1\SYSTEMADMINISTRATOR\super-admin-scholarship-settings.html:427`
  - Existing control flags area: `...super-admin-scholarship-settings.html:620`
  - JS default controls object: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-superadmin-scholarship-settings.js:23`
  - JS read/write of controls into payload: `...supabase-superadmin-scholarship-settings.js:555`
- Audit logging for settings actions already exists:
  - `...supabase-superadmin-scholarship-settings.js:584`
  - Supabase audit hotfix table/policies: `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\audit_logs_hotfix_2026_03_22.sql:1`

## 4) What To Be Added (Target Design)

### 4.1 Data Model Additions (Auto Room Assignment)
Use explicit room assignment model instead of only batch `venue`.

Recommended additions:
- `exam_room_configs` (global defaults per school year or active settings)
  - `is_enabled`
  - `default_room_count`
  - `default_examinees_per_room`
  - `assignment_strategy` (e.g., `control_no_asc`, `application_no_asc`, `random_seeded`)
- `exam_rooms` (optional if naming/metadata is needed)
  - `batch_id`, `room_code`, `capacity`, `sequence`
- `exam_room_assignments` (required for per-applicant room/seat)
  - `exam_record_id`
  - `batch_id`
  - `room_code`
  - `seat_no`
  - `assignment_run_id`, `assigned_at`, `assigned_by`

Required constraints/indexing (conceptual):
- One assignment per exam record.
- Unique seat per `(batch_id, room_code, seat_no)`.
- Indexed retrieval by `batch_id`, `room_code`, `exam_record_id`.

### 4.2 System Admin UI Controls (Requested Placeholder)
Best integration point: Scholarship Settings `System Control Flags` + scheduling section.

Add these controls in System Admin:
- `Enable Auto Room Assignment` (bool)
- `Number of Rooms` (int)
- `Examinees Per Room` (int)
- `Assignment Strategy` (select)
- `Lock Assignment After Publish` (bool)
- `Allow Secretary Override` (bool)

Wire these into `ranking_basis.controls` first for compatibility with existing settings architecture, then migrate to dedicated room config table if needed.

### 4.3 Secretary Workflow Additions
In Exam Batches module, add:
- `Preview Assignment` (shows room/seat distribution before commit)
- `Run Auto Assign` (server-side bulk process)
- `Re-run Assignment` (only if not locked)
- `Export Room List` (per room roll sheet)
- `Assignment Lock/Publish` state per batch

### 4.4 Applicant and Staff Read Models
Surface room/seat data in:
- Applicant tracking page
- Secretary exam results table and print/export
- Optional SMS/email/notification templates

## 5) What To Remove or Refactor

### 5.1 Stale TODO / Contradictory Copy
- Stale TODO says batch persistence is not done, but JS already persists:
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:113`
  - Contradicted by live insert logic: `...\js\supabase-secretary-exam-batches.js:380`
- UI copy says "Pending Exam and Submitted records only", but assignment logic includes `exam_scheduled` and `exam_completed` too:
  - UI text: `...secretary-exam-batches.html:166`
  - Logic: `...supabase-secretary-exam-batches.js:4`

### 5.2 Legacy Fallback Paths (Remove after migration)
- Applicant pages still have fallback TODOs that infer exam/interview from legacy `interviews` table:
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-applicant-application-detail.js:300`
  - `...supabase-applicant-dashboard.js:1080`
  - `...supabase-applicant-applications.js:481`

### 5.3 Duplicated Status Logic
Status transition/meta logic is duplicated across many files instead of centralized usage.
- Canonical workflow exists: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\ldss-workflow.js:1`
- Repeated status maps/arrays in additional modules:
  - `...\js\supabase-superadmin-user-management.js:14`
  - `...\js\supabase-secretary-applications.js:447`
  - `...\js\supabase-secretary-dashboard.js:2062`

Refactor direction:
- Keep `ldss-workflow.js` as single source of truth for status labels/order/next-steps and consume it everywhere.

## 6) High-Volume Analysis (~2000 Examinees)

### 6.1 Current Scale Risks
- Browser-side full table loads without pagination:
  - Exam batches module loads non-draft applications and profiles in bulk: `...\js\supabase-secretary-exam-batches.js:231`
  - Exam results module loads all `exam_records` and then joins applications/profiles client-side: `...\js\supabase-secretary-exam-results.js:224`
- Assignment loop performs per-applicant sequential writes (`exam_records`, `applications`, notifications):
  - `...\js\supabase-secretary-exam-batches.js:457`
  - This becomes thousands of round trips for 2000 examinees.
- Capacity value exists but is not enforced during assignment loop:
  - Capacity input exists and is stored: `...\js\supabase-secretary-exam-batches.js:333`, `:372`
  - No hard capacity enforcement before insert/upsert in assignment loop.

### 6.2 Best-Practice Scale Strategy
- Move heavy assignment logic to server-side bulk operation (single transaction per batch or chunked transactions).
- Use deterministic ordering + idempotent `assignment_run_id`.
- Add pagination, server filters, and index-supported queries for secretary pages.
- Batch notifications asynchronously (queue/job model), not inside per-row synchronous loop.
- Add concurrency guards (advisory lock or batch-level lock flag) to prevent double assignment runs.

## 7) Proposed Wiring Map (No Code, Architecture Only)

### 7.1 Config Wiring
- Source: System Admin Scholarship Settings (`ranking_settings.ranking_basis.controls`).
- Consumers:
  - Secretary Exam Batches page: auto-assign controls + runtime policy checks.
  - Assignment service/function: reads config and validates before assigning.

### 7.2 Assignment Execution Wiring
- Trigger options:
  - Manual: secretary clicks `Run Auto Assign`.
  - Optional auto: upon batch finalization if enabled by policy.
- Execution flow:
  - Validate batch + eligible records.
  - Compute rooms/seats from config.
  - Persist assignments + update statuses atomically.
  - Emit notification jobs.
  - Write audit log entry.

### 7.3 Read/Display Wiring
- Applicant detail/tracking reads assigned room/seat fields.
- Secretary results/print pages show room, seat, and assignment status.
- Reports aggregate counts per room and overflow/unassigned counts.

## 8) Minimal Phased Rollout Plan

### Phase 0: Cleanup First
- Remove stale TODO comments and contradictory copy.
- Consolidate status mapping to `ldss-workflow.js`.

### Phase 1: Config + Schema Foundation
- Add room-assignment config fields in System Admin settings.
- Add room assignment schema + constraints + indexes.

### Phase 2: Secretary UX and Bulk Engine
- Add preview/run/lock controls.
- Implement server-side batch assignment engine.
- Add assignment result summary and error bucket (invalid/unassigned).

### Phase 3: Applicant Visibility + Reporting
- Show room/seat in applicant tracking.
- Add room-based exports and dashboards.

### Phase 4: Hardening
- Load/perf test at 2,000 examinees (and above).
- Add telemetry, alerting, audit review, rollback scripts.

## 9) Risks If Not Addressed
- Inconsistent assignment results across reruns.
- Over-capacity rooming and duplicate seats.
- Slow secretary operations and timeout risk at scale.
- Auditability gaps for who triggered/changed assignment.
- Mixed status behavior due duplicated workflow logic.

## 10) Definition of Done for This Initiative
- Auto room assignment configurable in System Admin.
- Secretary can preview, run, lock, and export assignments.
- Applicant can see assigned room/seat.
- Assignment process is deterministic, auditable, and handles 2,000+ examinees within acceptable runtime.
- No stale TODO/copy contradictions remain in exam scheduling modules.

## 11) Latest Update Evidence (Basis Folder)
Latest dated basis updates in this local copy are March 22, 2026:
- `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\application_receive_override_hotfix_2026_03_22.sql`
- `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\audit_logs_hotfix_2026_03_22.sql`
- Referenced in README:
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\README.md:34`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\README.md:35`

These are foundational for policy control and auditability and should be leveraged for room-assignment governance.
