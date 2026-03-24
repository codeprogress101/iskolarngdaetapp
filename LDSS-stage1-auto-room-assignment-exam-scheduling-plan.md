# LDSS-stage1 Plan: Auto Room Assignment + Exam Scheduling (Read-Only Analysis)

Date: 2026-03-23
Scope: `C:\Users\ADMIN\Desktop\LDSS-stage1` only (no Flutter scan)
Method: Static read-only scan of HTML, JS, SQL, README. No file edits in `LDSS-stage1`.

## 1. Executive Summary

The basis portal already has working exam scheduling foundations:
- exam batches with schedule and venue
- applicant-to-batch assignment
- exam control number support
- exam result encoding and status transitions
- centralized System Admin policy settings persisted in `ranking_settings.ranking_basis.controls`

What is not implemented yet is true per-applicant auto room assignment (room + seat allocation at scale). Current implementation uses `venue` (batch-level location) and manual/bulk batch assignment, not deterministic room/seat auto-allocation.

For an expected load of ~2000 examinees, the recommended implementation is:
- keep current exam scheduling flow
- add explicit room-assignment policy controls in System Admin settings
- add normalized room-assignment data model + constraints + indexes
- move heavy assignment logic to DB-side RPC (set-based), not browser loops
- keep secretary UI as trigger/orchestrator with preview, lock, and rerun rules

## 2. What Is Already Done (Verified)

### 2.1 Exam Scheduling Core
- SQL tables exist for scheduling and records:
  - `exam_batches` with `batch_label`, `exam_datetime`, `venue`, `capacity`, `status`
  - `exam_records` with `application_id`, `batch_id`, `exam_control_no`, `scheduled_at`, `result`, `status`
- Evidence:
  - [ldss_phase1_schema_rls.sql:1181](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1181)
  - [ldss_phase1_schema_rls.sql:1195](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1195)
  - [ldss_phase1_schema_rls.sql:1275](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1275)
  - [ldss_phase1_schema_rls.sql:1277](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1277)

### 2.2 Secretary Scheduling UI + JS
- Exam batch creation UI already has date/time, venue, capacity fields.
- Secretary can assign selected applicants to batch with control number seed.
- JS writes batch and exam record data; updates application status to `exam_scheduled`.
- Evidence:
  - [secretary-exam-batches.html:119](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:119)
  - [secretary-exam-batches.html:123](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:123)
  - [secretary-exam-batches.html:127](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:127)
  - [secretary-exam-batches.html:181](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:181)
  - [secretary-exam-batches.html:206](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:206)
  - [supabase-secretary-exam-batches.js:254](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:254)
  - [supabase-secretary-exam-batches.js:256](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:256)
  - [supabase-secretary-exam-batches.js:471](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:471)
  - [supabase-secretary-exam-batches.js:478](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:478)
  - [supabase-secretary-exam-batches.js:488](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:488)

### 2.3 Exam Results + Workflow Movement
- Exam results page reads `exam_records` and updates application status to `exam_completed`, `passed_exam`, or `failed_exam`.
- Evidence:
  - [supabase-secretary-exam-results.js:224](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:224)
  - [supabase-secretary-exam-results.js:352](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:352)

### 2.4 System Admin Settings Framework (Best Integration Point)
- `super-admin-scholarship-settings` already stores policy controls in `ranking_settings.ranking_basis.controls`.
- Existing controls include intake override, workflow flags, and interview automation flag.
- Read/save/audit wiring already exists and should be reused.
- Evidence:
  - [super-admin-scholarship-settings.html:500](c:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:500)
  - [super-admin-scholarship-settings.html:507](c:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:507)
  - [super-admin-scholarship-settings.html:619](c:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:619)
  - [supabase-superadmin-scholarship-settings.js:23](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:23)
  - [supabase-superadmin-scholarship-settings.js:555](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:555)
  - [supabase-superadmin-scholarship-settings.js:658](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:658)
  - [supabase-superadmin-scholarship-settings.js:701](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:701)

### 2.5 Latest Basis Update Evidence
- Latest dated hotfixes in this local copy are March 22, 2026.
- Evidence:
  - [README.md:34](c:/Users/ADMIN/Desktop/LDSS-stage1/README.md:34)
  - [README.md:35](c:/Users/ADMIN/Desktop/LDSS-stage1/README.md:35)
  - [application_receive_override_hotfix_2026_03_22.sql](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/application_receive_override_hotfix_2026_03_22.sql)
  - [audit_logs_hotfix_2026_03_22.sql](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/audit_logs_hotfix_2026_03_22.sql)
- Note: no git metadata found in this local copy (`NO_GIT_METADATA`), so latest status is inferred from README + migration filenames.

## 3. Gap Analysis (What Must Be Added)

### 3.1 Functional Gaps
- No explicit per-applicant room/seat assignment model.
- No automatic assignment algorithm (deterministic, idempotent, lockable).
- No overflow policy when examinees exceed room capacity.
- No room assignment preview/reconciliation workflow before publishing.

### 3.2 Scale Gaps (2000 Examinees)
- Current secretary batch assignment uses browser loop per selected applicant.
- No server-side bulk assignment RPC for high-volume write operations.
- No visible pagination/range loading in exam batch/results admin screens.
- Capacity is captured but not strictly enforced during assignment write.
- Evidence:
  - [supabase-secretary-exam-batches.js:457](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:457)
  - [supabase-secretary-exam-batches.js:372](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:372)

### 3.3 Governance Gaps
- Room assignment policy is not yet configurable from System Admin.
- No dedicated audit granularity for room auto-assignment runs and reassignments.

## 4. Recommended Target Design

## 4.1 Integration Point in System Admin UI (Recommended)
Use `super-admin-scholarship-settings` and extend existing `ranking_basis.controls` pattern.

Why this is best:
- already wired save/load/audit path
- already used for workflow flags and intake controls
- minimizes duplication across modules

## 4.2 New Policy Fields to Add (System Admin)
Add under `ranking_basis.controls`:
- `auto_room_assignment_enabled` (bool)
- `room_count` (int)
- `examinees_per_room` (int)
- `room_label_prefix` (text, e.g., `Room`)
- `assignment_strategy` (enum-like text; default `exam_control_no_asc`)
- `assignment_lock_after_publish` (bool)
- `allow_reassignment_if_locked` (bool, default false)
- `overflow_policy` (text: `block` | `overflow_waitlist`)

Optional but useful:
- `seat_label_pattern` (text)
- `reserved_seats_per_room` (int)

## 4.3 Data Model Recommendation
For reliability and scale, use normalized assignment records (recommended over embedding in UI-only state).

Recommended entities:
- `exam_rooms` (per batch room metadata: `batch_id`, `room_code`, `capacity`, `sort_order`, `is_active`)
- `exam_room_assignments` (`exam_record_id`, `batch_id`, `room_id`, `seat_no`, `assignment_version`, `is_locked`, `assigned_at`, `assigned_by`, `assignment_source`)

Key constraints/indexes:
- unique: one assignment per exam record
- unique: `(batch_id, room_id, seat_no)`
- index: `(batch_id, room_id)` and `(batch_id, assignment_version)`
- index: exam-record lookup for applicant tracking

RLS:
- staff write access (secretary/admin/super_admin)
- applicant read only for own assignment via application ownership

## 5. Wiring Plan (Detailed)

### Phase A: Database + RPC Layer
1. Add schema objects for room configuration and assignment records.
2. Add RPC: `auto_assign_exam_rooms(batch_id, mode, assignment_version)`.
3. Enforce deterministic ordering (default by `exam_control_no`, fallback `application_no`, then `application_id`).
4. Enforce capacity and overflow policy in DB transaction.
5. Add audit entries for each auto-assign run: counts, version, actor, failures.

### Phase B: System Admin Scholarship Settings
1. Add a new section: `Exam Room Assignment Policy`.
2. Add fields listed in 4.2 to the form.
3. Extend existing JS parse/render/save (`readFormValues`, `applyForm`, snapshot, audit) to include new control keys.
4. Keep save path through existing `ranking_settings` upsert flow.

### Phase C: Secretary Exam Batches UI
1. Add action: `Auto Assign Rooms` per selected batch.
2. Add preview modal before commit:
- selected batch
- total examinees
- configured total seats (`room_count * examinees_per_room`)
- overflow count
3. Add post-run summary:
- assigned count
- unchanged count
- overflow/unassigned count
- locked count
4. Add `Re-run assignment` with explicit lock rules.

### Phase D: Applicant and Reporting Visibility
1. Add read-only room + seat display on applicant tracking page after scheduling.
2. Include room assignment in printable forms used by staff/applicant.
3. Ensure notification templates can include room and seat placeholders.

## 6. What To Remove / Refactor

### 6.1 Remove Stale TODOs and Mismatch Notes
- [secretary-exam-batches.html:113](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:113) says persistence is TODO even though it is implemented.

### 6.2 Refactor Hardcoded Notification Content
- move hardcoded notification text into centralized template configuration.
- Evidence:
  - [supabase-secretary-exam-batches.js:498](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:498)
  - [supabase-secretary-exam-results.js:372](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:372)

### 6.3 Refactor Client-Side Heavy Mutation Loop
- current per-record browser loop should be replaced by DB-side bulk operation for scale and consistency.
- Evidence:
  - [supabase-secretary-exam-batches.js:457](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:457)

### 6.4 Address Existing Settings Lifecycle Debt
- settings overwrite currently lacks versioned history per school year record lifecycle.
- Evidence:
  - [supabase-superadmin-scholarship-settings.js:699](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:699)

## 7. High-Volume Strategy for ~2000 Examinees

1. Prefer DB set-based assignment, not row-by-row browser writes.
2. Use chunked operations for notifications and non-critical side effects.
3. Add pagination/server filtering to secretary exam screens.
4. Use deterministic, idempotent assignment versioning.
5. Lock assignment post-publish unless authorized override.
6. Add operational metrics in UI:
- total scheduled
- assigned
- unassigned
- overflow
- last assignment version/time/actor

## 8. Best-Practice Non-Functional Requirements

1. Idempotency: same input + same version = same assignment output.
2. Concurrency safety: prevent simultaneous assignment runs on same batch.
3. Traceability: every run audited with actor and diff summary.
4. Recoverability: rollback or replay by assignment version.
5. Observability: clear operator messages for capacity failures and partial updates.
6. Security: keep staff-only write permissions; applicant read-only via ownership.

## 9. Proposed Rollout Sequence

1. Design approval and data contract freeze.
2. DB migration in staging.
3. System Admin settings UI/JS extension.
4. Secretary auto-assign preview + execute flow.
5. Applicant visibility update.
6. Load and concurrency testing with synthetic 2000 examinees.
7. Production rollout with feature flag enabled gradually.

## 10. Acceptance Checklist

1. Admin can configure room policy from Scholarship Settings.
2. Secretary can run auto-assignment per batch with preview and result summary.
3. System enforces capacity and deterministic assignment.
4. Applicant sees assigned room/seat when scheduled.
5. Audit logs capture every assignment run and control change.
6. 2000-examinee run completes within acceptable operational time.
7. No duplicate seats and no orphan assignments.

## 11. Evidence Index

- Exam scheduling implemented: [README.md:86](c:/Users/ADMIN/Desktop/LDSS-stage1/README.md:86)
- Workflow tables listed: [README.md:90](c:/Users/ADMIN/Desktop/LDSS-stage1/README.md:90)
- Latest update refs: [README.md:34](c:/Users/ADMIN/Desktop/LDSS-stage1/README.md:34), [README.md:35](c:/Users/ADMIN/Desktop/LDSS-stage1/README.md:35)
- Exam schema objects: [ldss_phase1_schema_rls.sql:1181](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1181), [ldss_phase1_schema_rls.sql:1195](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1195)
- Exam RLS policies: [ldss_phase1_schema_rls.sql:1316](c:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1316)
- System Admin controls architecture: [supabase-superadmin-scholarship-settings.js:23](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:23), [supabase-superadmin-scholarship-settings.js:555](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:555)
- Settings persistence: [supabase-superadmin-scholarship-settings.js:701](c:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:701)
- Receive control UI: [super-admin-scholarship-settings.html:500](c:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:500)
- Stale TODO marker: [secretary-exam-batches.html:113](c:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:113)
