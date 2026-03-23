# LDSS-stage1 Master Plan: Auto Room Assignment and Exam Scheduling (Read-Only Analysis)

Date: March 23, 2026
Scope scanned: `C:\Users\ADMIN\Desktop\LDSS-stage1` only
Constraint followed: No code changes in `LDSS-stage1` (analysis/report only)

## 1) Executive Summary

The basis portal already has working exam scheduling foundations:
- exam batch creation
- applicant-to-batch assignment
- control number assignment
- exam result encoding
- status transitions (`pending_exam` -> `exam_scheduled` -> `exam_completed` / `passed_exam` / `failed_exam`)

The missing capability is first-class auto room assignment at per-applicant granularity.
Current design uses batch-level `venue` only, which is not enough for multi-room or seat-level management at ~2,000 examinees.

Recommended direction:
- keep current exam scheduling flow
- add explicit room assignment data model
- add System Administrator room configuration controls
- move heavy assignment logic from browser loops to server-side set-based execution
- add auditability, idempotency, lock/freeze behavior, and rollback safety

## 2) Latest Update Evidence (Basis Folder)

`LDSS-stage1` local copy has no `.git` metadata, so latest update evidence is based on dated files and README references.

Latest dated hotfixes found:
- `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\application_receive_override_hotfix_2026_03_22.sql`
- `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\audit_logs_hotfix_2026_03_22.sql`

README references:
- `C:\Users\ADMIN\Desktop\LDSS-stage1\README.md:34`
- `C:\Users\ADMIN\Desktop\LDSS-stage1\README.md:35`
- exam scheduling feature statement: `C:\Users\ADMIN\Desktop\LDSS-stage1\README.md:86`

## 3) What Is Already Done

### 3.1 Schema and Security
- `exam_batches` exists with schedule/location/capacity fields.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1181`
- `exam_records` exists with `batch_id`, `exam_control_no`, `scheduled_at`, result/status fields.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1195`
- `ranking_settings` exists and already stores `ranking_basis` JSON controls.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1254`
- RLS and grants for exam tables are already present.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1315`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1344`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1460`

### 3.2 Secretary Exam Scheduling UI/Flow
- Exam batch UI fields already exist for label, datetime, venue, capacity.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:119`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:123`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:127`
- Batch create persists into `exam_batches`.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:369`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:380`
- Applicant assignment writes `exam_records` and pushes application status to `exam_scheduled`.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:470`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:478`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:488`

### 3.3 Secretary Exam Results UI/Flow
- Result encoding reads/writes `exam_records` and updates application workflow status.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-results.js:226`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-results.js:343`
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-results.js:352`

### 3.4 System Admin Settings Infrastructure
- Scholarship settings already has a structured controls workspace and persistence path via `ranking_basis.controls`.
  - UI page: `C:\Users\ADMIN\Desktop\LDSS-stage1\SYSTEMADMINISTRATOR\super-admin-scholarship-settings.html:620`
  - JS payload controls wiring: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-superadmin-scholarship-settings.js:555`

## 4) What Is Missing for Auto Room Assignment

### 4.1 Data Model Gaps
- No dedicated `room` table.
- No dedicated per-applicant room/seat assignment table.
- No explicit assignment lock state for exam room allocations.

### 4.2 Orchestration Gaps
- Current assignment is browser-side row loop (`for (let i...)`) with per-row upsert/update/notify.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:457`
- This is fragile for 2,000 records (slow, partial failures, retry complexity).

### 4.3 Capacity and Consistency Gaps
- `capacity` is captured but not enforced in assignment loop.
  - no hard check before assignment commit.
- No deterministic assignment strategy setting (e.g., by control number or application number).
- No seat uniqueness guard at DB level.

### 4.4 Configuration Gaps
- No dedicated system controls for room assignment parameters yet.
- `auto_set_for_interview` exists in settings but is only stored, not actively consumed by exam/interview processors.
  - references appear in settings code, no operational usage found in exam scripts.

## 5) What To Remove or Refactor

### 5.1 Stale / misleading TODOs
- Remove stale TODO in exam batches HTML that says persistence is pending.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:113`

### 5.2 Heavy Client-Side Row Processing
- Replace per-record client write loop with server-side batch job/RPC.
- Keep UI as trigger + progress display only.

### 5.3 Duplicate or Transitional Logic
- Interview module still falls back to `interviews` after `interview_records` write failure.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-interview.js:587`
- Decide single source-of-truth and deprecate fallback path once migration is complete.

### 5.4 Settings Drift Risk
- Scholarship settings local fallback path can cause non-authoritative behavior in production if DB write fails.
  - `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-superadmin-scholarship-settings.js:711`
- For production, enforce DB persistence and display hard warning when unavailable.

## 6) Proposed Target Design

### 6.1 Database Design (Recommended)
Add these entities:
1. `exam_room_configs`
- purpose: central default policy configuration for auto assignment.
- suggested fields:
  - `school_year`
  - `auto_room_assignment_enabled` (bool)
  - `number_of_rooms` (int)
  - `examinees_per_room` (int)
  - `assignment_strategy` (text: `control_no_asc`, `application_no_asc`, `random_seeded`)
  - `freeze_after_publish` (bool)
  - `allow_reassign_after_publish` (bool)
  - `updated_by`, `updated_at`

2. `exam_rooms`
- purpose: per-batch room metadata.
- suggested fields:
  - `batch_id`
  - `room_code`
  - `room_name`
  - `capacity`
  - `is_active`

3. `exam_room_assignments`
- purpose: per-examinee placement.
- suggested fields:
  - `exam_record_id`
  - `batch_id`
  - `room_id` or `room_code`
  - `seat_no`
  - `assignment_version`
  - `is_locked`
  - `assigned_at`
  - `assigned_by`

Suggested DB constraints/indexing:
- unique (`exam_record_id`) for one active assignment per examinee.
- unique (`batch_id`, `room_id`, `seat_no`) for seat collision prevention.
- index on (`batch_id`, `room_id`) and (`batch_id`, `is_locked`).

### 6.2 System Admin Configuration UX (Requested placeholders)
Integrate into Scholarship Settings under System Control Flags.

Add controls:
1. `Auto Room Assignment` toggle.
2. `Number of Rooms` numeric input.
3. `Examinees Per Room` numeric input.
4. `Assignment Strategy` selector.
5. `Freeze Assignments After Publish` toggle.
6. `Allow Re-run After Publish` toggle.
7. optional `Room Prefix` (e.g., ROOM-) and `Seat Start` default.

Rationale:
- This aligns with existing settings architecture (`ranking_basis.controls`) and existing save/audit flow.

### 6.3 Assignment Engine (High-Volume Safe)
Implement as server-side function/RPC (or job worker), not browser loop.

Algorithm outline:
1. Load eligible exam records in batch.
2. Sort deterministically (strategy from config).
3. Generate room slots = `number_of_rooms * examinees_per_room`.
4. Assign sequentially room/seat.
5. Upsert assignments in bulk.
6. Write audit log and assignment summary.
7. Return metrics (`assigned`, `skipped`, `conflicts`, `duration_ms`).

Idempotency requirements:
- same input and version produces same output.
- re-run with same version should not duplicate.
- explicit new version only when admin confirms reassign.

### 6.4 Secretary and Applicant Wiring
Secretary:
- keep current scheduling UI.
- add a room assignment review page/section with filters by batch/room/status.
- actions: publish assignments, lock/unlock batch assignments, export list.

Applicant:
- on applicant tracking page, show exam schedule + assigned room + seat only after publish.
- when unassigned, show pending message.

## 7) High-Volume Design for ~2,000 Examinees

### 7.1 Performance Requirements
- avoid loading all records on every UI action.
- add server-side pagination/filtering for exam list pages.
- batch writes and notifications.
- avoid per-row network round-trips.

### 7.2 Reliability Controls
- transactional assignment per batch.
- optimistic lock/version checks for concurrent admin actions.
- retry-safe operations with job idempotency key.
- job state tracking (`queued`, `running`, `completed`, `failed`).

### 7.3 Data Quality Controls
- preflight validation before assignment:
  - missing control numbers
  - missing batches
  - capacity shortfall
  - duplicated or invalid records
- hard stop on invalid config (rooms/capacity <= 0).

### 7.4 Operational Controls
- dry-run mode: compute without commit and show stats.
- publish gate: assignments invisible to applicants until published.
- freeze gate: prevent accidental reshuffle.
- full audit entries for every run and publish event.

## 8) Phased Implementation Plan

Phase 0: Baseline hardening
1. Clean stale TODO/copy conflicts.
2. Add monitoring logs around exam assignment operations.
3. Confirm production-only settings persistence policy.

Phase 1: Schema and config
1. Add room config + room + assignment tables.
2. Add constraints and indexes.
3. Add RLS policies for super_admin/admin/secretary reads and controlled writes.

Phase 2: Admin controls
1. Add room assignment controls in Scholarship Settings.
2. Extend settings save/load and audit logging.
3. Add validation errors for impossible config.

Phase 3: Assignment engine
1. Implement server-side auto-assign RPC/job.
2. Add dry-run and commit modes.
3. Add publish/lock endpoints.

Phase 4: Secretary and applicant integration
1. Secretary review/override grid and export.
2. Applicant tracking display for room/seat.
3. Notification templates for assignment published/changed.

Phase 5: Scale and release
1. load test with realistic 2,000+ dataset.
2. verify throughput, lock behavior, and rollback.
3. rollout with feature flag and pilot batch.

## 9) Acceptance Criteria

1. Admin can configure:
- number of rooms
- examinees per room
- strategy
- publish/freeze behavior

2. Auto assignment run on 2,000 examinees completes within agreed SLA and zero seat collisions.

3. Re-run behavior is deterministic and auditable.

4. Applicants only see published room assignments.

5. Secretary can review and export room lists per batch and per room.

6. Rollback can restore pre-assignment state by assignment version.

## 10) Risks and Mitigations

1. Overbooking risk
- mitigate with DB uniqueness + capacity checks before commit.

2. Assignment churn/confusion
- mitigate with publish/freeze semantics and explicit reassign confirmation.

3. Partial failure at high volume
- mitigate with server transaction boundaries and job retry design.

4. Configuration misuse
- mitigate with strict validation and admin-only control access.

## 11) Direct Evidence Index

- Exam batch schema: `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1181`
- Exam record schema: `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1195`
- Ranking settings schema: `C:\Users\ADMIN\Desktop\LDSS-stage1\supabase\ldss_phase1_schema_rls.sql:1254`
- Exam batch UI fields: `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:119`
- Assignment button/UI: `C:\Users\ADMIN\Desktop\LDSS-stage1\SECRETARY\secretary-exam-batches.html:206`
- Batch creation JS: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:369`
- Assignment loop JS: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:457`
- Exam status update to `exam_scheduled`: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-batches.js:488`
- Exam result update flow: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-secretary-exam-results.js:343`
- System Admin settings controls UI: `C:\Users\ADMIN\Desktop\LDSS-stage1\SYSTEMADMINISTRATOR\super-admin-scholarship-settings.html:620`
- System Admin controls payload wiring: `C:\Users\ADMIN\Desktop\LDSS-stage1\js\supabase-superadmin-scholarship-settings.js:555`
- Latest hotfix references: `C:\Users\ADMIN\Desktop\LDSS-stage1\README.md:34`, `:35`, `:86`

---

Prepared from read-only analysis of `LDSS-stage1` only.
