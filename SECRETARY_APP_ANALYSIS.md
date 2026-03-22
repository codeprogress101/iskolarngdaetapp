# Secretary App Analysis (Separate Flutter App)

## Goal
Create a separate Flutter mobile app for Secretary users (`ldsp_secretary`) while keeping the applicant app independent and stable.

## Why Separate App
- Cleaner security boundaries between applicant and staff workflows.
- Simpler role-based navigation and less UI complexity per app.
- Easier QA and release management per user type.

## Recommended Product Scope (Secretary MVP)
1. Secretary login + role guard
2. Dashboard (pending counts, urgent items)
3. Applications queue (filter/search by status, school year, program)
4. Application detail review page
5. Workflow actions:
   - Return for correction (with reason/remarks)
   - Forward/approve to next stage
6. Exam scheduling
7. Interview scheduling
8. Notification trigger visibility (actions that notify applicant)

## Architecture Direction
- Separate repository/app: `ldsp_secretary`
- Same Supabase backend project
- Secretary-only route module and feature folders
- Reuse common design language and component style from applicant app, but keep codebases separated

## Role and Access Rules
- Only allow accounts where `profiles.role = 'secretary'`
- Block applicant routes entirely in secretary app
- Enforce all role permissions server-side via Supabase RLS/policies (not only in Flutter UI)

## Backend/Schema Alignment Checklist
Before implementation, verify exact secretary dependencies from portal:
1. Tables/views/RPC used by secretary screens
2. Required columns for workflow updates (status, remarks, schedule fields)
3. Exact status transition rules used in LDSS-stage1
4. Notification side effects after secretary actions

If mismatch is found:
- Document exact table/column/RPC mismatch
- Do not guess field names

## UX Guidelines (Secretary-Mobile)
- Queue-first, action-oriented screens
- Card-based records with clear status chips
- Fast filters near top (status/year/type)
- Sticky action bar on detail page
- Confirmation dialogs for irreversible actions
- Required reason input for correction returns

## Suggested Build Phases
1. Phase A: Auth + role guard + route shell
2. Phase B: Dashboard + queue list (read-only)
3. Phase C: Detail review + return/forward actions
4. Phase D: Exam/interview scheduling
5. Phase E: Notification parity + action history
6. Phase F: Hardening, performance, and portal parity QA

## Security and Safety Requirements
- Server-side authorization and RLS enforcement are mandatory
- Validate workflow transitions against allowed states
- Avoid exposing raw backend errors in production UI
- Keep audit-friendly action records (who, when, what change)

## QA and Release Plan
1. Role tests: secretary cannot use applicant flow and vice versa
2. Workflow transition tests by status
3. Notification propagation tests to applicant app
4. Regression tests to protect existing applicant app behavior
5. UAT parity checks against LDSS-stage1 secretary screens

## Immediate Next Step
Create a detailed secretary parity matrix from LDSS-stage1:
- Screen-by-screen features
- Status/action mapping
- Data fields per action
- Blocking schema requirements
