# LDSS-stage1 Auto Room Assignment and Exam Scheduling Implementation Plan

## Scope and Method
- Scope scanned: `C:\Users\ADMIN\Desktop\LDSS-stage1` only.
- Constraint followed: read-only scan of basis folder; no source files were modified.
- Objective: design a production-ready plan for auto room assignment + exam scheduling at around 2,000 examinees.

## Executive Summary
- Exam scheduling is already implemented in schema and secretary UI/JS.
- Room assignment is not explicitly modeled as a first-class entity; current implementation uses `venue` at batch level.
- Existing implementation is functional for moderate scale but has bottlenecks for high-volume operations (client-side full-table reads, per-row sequential writes).
- Best integration point for room-assignment configuration is existing System Administrator Scholarship Settings (`ranking_settings.ranking_basis.controls`).
- Recommended path: add dedicated room and assignment model, move bulk assignment to server-side/RPC job flow, keep UI thin, and enforce idempotency + auditability.

## 1) What Is Already Done (Basis Folder)

### 1.1 Database schema and RLS are already exam-ready
- Exam batch table exists with schedule and location:
  - `exam_batches(batch_label, exam_datetime, venue, capacity, status, created_by, timestamps)`
  - Evidence: [ldss_phase1_schema_rls.sql:1181](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1181)
- Exam record table exists with one-record-per-application model:
  - `exam_records(application_id unique, batch_id, exam_control_no unique, scheduled_at, result, status, encoded_by, checked_by)`
  - Evidence: [ldss_phase1_schema_rls.sql:1195](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1195)
- Interview records also carry `scheduled_at` + `venue`, showing consistent scheduling pattern:
  - Evidence: [ldss_phase1_schema_rls.sql:1216](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1216)
- RLS and grants are in place for exam tables (staff write, owner/staff read):
  - Evidence: [ldss_phase1_schema_rls.sql:1309](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1309), [ldss_phase1_schema_rls.sql:1344](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1344), [ldss_phase1_schema_rls.sql:1460](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1460)

### 1.2 Secretary exam scheduling UI and write flow are already live
- Exam batches page already supports creating batch schedule + venue + capacity and assigning applicants to batch:
  - Evidence: [secretary-exam-batches.html:119](C:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:119), [secretary-exam-batches.html:123](C:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:123), [secretary-exam-batches.html:206](C:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:206)
- JS creates batches and persists to `exam_batches`:
  - Evidence: [supabase-secretary-exam-batches.js:329](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:329), [supabase-secretary-exam-batches.js:380](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:380)
- Assignment flow upserts exam records and updates application status to `exam_scheduled`:
  - Evidence: [supabase-secretary-exam-batches.js:477](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:477), [supabase-secretary-exam-batches.js:488](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:488)
- Exam results encoding updates status to `exam_completed`, `passed_exam`, or `failed_exam`:
  - Evidence: [supabase-secretary-exam-results.js:343](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:343), [supabase-secretary-exam-results.js:352](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:352)

### 1.3 System Administrator settings already has a natural integration point
- Scholarship settings already stores workflow control flags in `ranking_settings.ranking_basis.controls`.
- Current controls include intake mode, timing, secretary edits, photo requirement, and interview automation.
  - Evidence: [supabase-superadmin-scholarship-settings.js:23](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:23), [supabase-superadmin-scholarship-settings.js:555](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:555)
- Scholarship settings UI already contains quota/control sections where room-assignment controls can be added cleanly.
  - Evidence: [super-admin-scholarship-settings.html:522](C:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:522), [super-admin-scholarship-settings.html:618](C:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:618)

### 1.4 Operational maturity signals already present
- Latest basis updates are dated March 22, 2026 (intake override + audit logs):
  - Evidence: [README.md:34](C:/Users/ADMIN/Desktop/LDSS-stage1/README.md:34), [README.md:35](C:/Users/ADMIN/Desktop/LDSS-stage1/README.md:35)
- Existing batch job pattern exists for reminder campaigns (`batch_size`, `batch_delay_minutes`), useful precedent for assignment jobs:
  - Evidence: [reminder_campaign_jobs_hotfix_2026_03_19.sql:10](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/reminder_campaign_jobs_hotfix_2026_03_19.sql:10)

## 2) Gap Analysis (What Is Missing)

### 2.1 Missing data model for explicit room assignment
- No dedicated room assignment entity detected (`room`, `seat`, `room_assignment` not present).
- Current model has only batch-level `venue`, which is not enough for multi-room orchestration or per-applicant seating.

### 2.2 Missing high-volume-safe assignment engine
- Current assignment executes per-applicant writes in a loop from client JS:
  - `exam_records.upsert` + `applications.update` + notification insert per selected applicant.
  - Evidence: [supabase-secretary-exam-batches.js:452](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:452)
- This is vulnerable to latency, partial failures, and long UI lock during 2,000-record operations.

### 2.3 Missing pagination and server-side composition for heavy lists
- Exam management and exam result pages read broad datasets without pagination/limits.
  - Evidence: [supabase-secretary-exam-batches.js:255](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:255), [supabase-secretary-exam-results.js:226](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:226)

### 2.4 Missing indexes for observed query patterns at scale
- `exam_records` queries sort by `scheduled_at`, but existing indexes emphasize `updated_at` and `result`.
  - Evidence: [ldss_phase1_schema_rls.sql:1277](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1277), [ldss_phase1_schema_rls.sql:1278](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1278)
- Applications are frequently ordered by `updated_at` in secretary exam flow; current index is `(status, created_at)`.
  - Evidence: [supabase-secretary-exam-batches.js:257](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:257), [ldss_phase1_schema_rls.sql:339](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:339)

## 3) Recommended DB Design for Auto Room Assignment

### 3.1 Core design recommendation
- Keep `exam_batches` as schedule header.
- Add explicit room model and assignment model.

### 3.2 Suggested entities (conceptual)
- `exam_rooms`
  - Purpose: canonical room catalog per school year or per site.
  - Fields: `room_code`, `room_name`, `capacity`, `venue/building`, `is_active`.
- `exam_batch_rooms`
  - Purpose: selected rooms allocated to a specific exam batch.
  - Fields: `batch_id`, `room_id`, `effective_capacity`, `sort_order`.
- `exam_room_assignments`
  - Purpose: per-applicant seating assignment.
  - Fields: `exam_record_id` (or `application_id`), `batch_id`, `room_id`, `seat_no`, `assigned_by`, `assigned_at`, `assignment_version`.

### 3.3 Critical constraints
- One assignment per exam record per batch.
- Unique `(batch_id, room_id, seat_no)`.
- Capacity guard: assigned count in a batch room cannot exceed effective capacity.
- Foreign keys with cascade behavior aligned to existing exam lifecycle.

### 3.4 Index recommendations for 2,000 scale
- Index by `batch_id` and `room_id` for assignment lookup.
- Composite index for listing by `batch_id` and `seat_no`.
- Index for `exam_records(scheduled_at desc)` and potentially `applications(updated_at desc)` in secretary views.

## 4) System Admin Wiring Plan (Requested Room Config Placeholders)

### 4.1 Best integration point
- Use existing System Administrator Scholarship Settings (same page and persistence path).
- Persist settings in `ranking_settings.ranking_basis.controls`.

### 4.2 Add these control placeholders
- `auto_room_assignment_enabled` (bool)
- `room_count_default` (int)
- `examinees_per_room_default` (int)
- `room_assignment_strategy` (enum text: sequential, balanced, randomized_seeded)
- `reserve_buffer_percent` (int)
- `allow_manual_override_after_auto_assign` (bool)

### 4.3 Why this path is best
- Reuses existing settings governance and audit flow.
- Avoids creating a second admin configuration surface.
- Maintains one source of truth for workflow controls.

## 5) What To Wire End-to-End

### 5.1 Data and policy layer
- Add new room/assignment tables and constraints.
- Add RLS policies parallel to exam tables (staff write, applicant read via ownership).
- Add audited RPC for bulk auto-assignment execution.

### 5.2 Execution layer
- Move bulk assignment from client loop to server-side RPC/job.
- Support dry-run mode returning projected distribution and conflicts.
- Support commit mode with idempotency key and assignment version.

### 5.3 UI layer (Secretary)
- Add "Auto Assign Rooms" action per selected batch.
- Show preflight summary: rooms, capacity, applicants, overflow.
- Show assignment status + rerun lock + override indicators.
- Keep manual adjust flow for exceptions.

### 5.4 UI layer (System Admin)
- Add room assignment section in Scholarship Settings.
- Inputs for number of rooms and examinees per room (requested).
- Add validation and helper text for high-volume behavior.

### 5.5 Notifications and applicant visibility
- Notify applicants only after assignment publish/lock step.
- Include schedule, venue, room, and seat in notification payload.
- Ensure applicant pages read assignment fields from one canonical table/view.

## 6) What To Remove / Refactor

### 6.1 Remove stale TODO and misleading copy
- Stale TODO says batch persistence not done, but JS already persists.
  - Evidence: [secretary-exam-batches.html:113](C:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:113)
- README confirms generic TODO markers remain in UI pages.
  - Evidence: [README.md:92](C:/Users/ADMIN/Desktop/LDSS-stage1/README.md:92)

### 6.2 Refactor client-heavy bulk writes
- Replace per-record JS loop with single server-side command for atomicity/performance.
  - Evidence: [supabase-secretary-exam-batches.js:452](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:452)

### 6.3 Tighten production config behavior
- Reduce reliance on local fallback settings in production deployments.
  - Evidence: [supabase-superadmin-scholarship-settings.js:668](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:668)

## 7) Scale and Reliability Analysis for ~2,000 Examinees

### 7.1 Current risks at 2,000
- Full dataset loads into browser memory on secretary exam pages.
- Sequential network round-trips per applicant for assignment.
- Partial success states likely if network fails mid-run.
- No explicit room-seat uniqueness constraints yet.

### 7.2 Best-practice controls
- Server-side batch assignment with transaction boundaries.
- Idempotency token for every auto-assign run.
- Immutable assignment version once published; rerun generates next version.
- Background job pattern for very large runs (already precedent in reminder campaigns).
- Structured audit entries for run metadata and outcome counts.

### 7.3 Performance targets (recommended)
- Auto-assign 2,000 records in bounded chunks with progress telemetry.
- No full-table client scans for core secretary pages.
- Deterministic assignment output (same inputs = same result unless strategy changes).

## 8) Migration Plan (Phased, No-Code)

### Phase 0: Discovery and freeze window
- Confirm final assignment rules and conflict handling.
- Snapshot current exam tables and settings.

### Phase 1: Schema and policy foundation
- Add room and assignment entities, constraints, and indexes.
- Add RLS and grants aligned to existing staff/applicant model.

### Phase 2: Configuration wiring
- Extend Scholarship Settings controls with room-assignment placeholders.
- Validate and persist via existing `ranking_settings` save flow.

### Phase 3: Assignment engine
- Introduce server-side dry-run and commit flow.
- Implement idempotency and assignment versioning.

### Phase 4: Secretary UX integration
- Add auto-assign action + preflight dialog + status view.
- Add manual override screen for exceptions.

### Phase 5: Applicant visibility and notifications
- Publish room assignments to applicant tracking views and notifications.
- Lock assignment after publish unless privileged override.

### Phase 6: Rollout and hardening
- Pilot on one exam batch.
- Measure runtime and failure rates.
- Tune room strategy defaults and indexing before full rollout.

## 9) Rollback Strategy
- Keep old manual assignment flow active behind feature flag until cutover confidence is achieved.
- If assignment rollout fails:
  - disable auto-assign flag,
  - revert to previous assignment version,
  - keep exam schedule active.
- Preserve audit trail for all rollback decisions.

## 10) Acceptance Checklist
- 2,000 examinees can be assigned without browser lock or partial data corruption.
- No duplicate seat assignments under concurrent runs.
- Applicants can view assigned room/seat reliably after publish.
- Admin can configure room count and examinees-per-room from Scholarship Settings.
- Audit logs capture who ran assignment, when, and result metrics.

## Evidence Index (Key References)
- [README.md:86](C:/Users/ADMIN/Desktop/LDSS-stage1/README.md:86)
- [README.md:92](C:/Users/ADMIN/Desktop/LDSS-stage1/README.md:92)
- [ldss_phase1_schema_rls.sql:1181](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1181)
- [ldss_phase1_schema_rls.sql:1195](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1195)
- [ldss_phase1_schema_rls.sql:1275](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1275)
- [ldss_phase1_schema_rls.sql:1309](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/ldss_phase1_schema_rls.sql:1309)
- [secretary-exam-batches.html:113](C:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:113)
- [secretary-exam-batches.html:119](C:/Users/ADMIN/Desktop/LDSS-stage1/SECRETARY/secretary-exam-batches.html:119)
- [supabase-secretary-exam-batches.js:329](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:329)
- [supabase-secretary-exam-batches.js:421](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-batches.js:421)
- [supabase-secretary-exam-results.js:226](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-secretary-exam-results.js:226)
- [super-admin-scholarship-settings.html:522](C:/Users/ADMIN/Desktop/LDSS-stage1/SYSTEMADMINISTRATOR/super-admin-scholarship-settings.html:522)
- [supabase-superadmin-scholarship-settings.js:23](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:23)
- [supabase-superadmin-scholarship-settings.js:555](C:/Users/ADMIN/Desktop/LDSS-stage1/js/supabase-superadmin-scholarship-settings.js:555)
- [reminder_campaign_jobs_hotfix_2026_03_19.sql:10](C:/Users/ADMIN/Desktop/LDSS-stage1/supabase/reminder_campaign_jobs_hotfix_2026_03_19.sql:10)

## Note on "Latest" in this local copy
- `C:\Users\ADMIN\Desktop\LDSS-stage1` currently has no `.git` metadata (`NO_GIT_METADATA`), so latest-update inference is based on dated SQL filenames and README references.
