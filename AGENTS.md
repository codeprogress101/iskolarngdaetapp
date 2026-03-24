# AGENTS.md

This project is an applicant-only mobile app for the LDSP scholarship system.

## Product scope
- Platform: Flutter
- Backend: Supabase
- Audience: applicants only
- Excluded roles: secretary, admin, super_admin
- Source of truth for business rules: ../LDSS-stage1 web repo
- Output target for all implementation work: this Flutter repo only

## Core goals
1. Build a stable applicant mobile experience
2. Reuse Supabase tables and workflow logic from the web portal
3. Keep architecture simple, readable, and production-oriented
4. Defer uploads and complex admin workflows unless explicitly requested

## Working rules
- Read from the LDSS-stage1 repo for reference, but do not modify it unless explicitly asked
- Implement changes only in this Flutter project
- Prefer small, reviewable changes
- Explain assumptions before making schema-dependent changes
- When debugging, surface the exact failing request, file, and reason
- When blocked by backend/schema mismatch, provide exact SQL or data fix steps
- Do not introduce unnecessary packages
- Do not build staff/admin screens
- Keep mobile UI clean, modern, and touch-friendly

## Initial priority order
1. Supabase initialization
2. Auth flow
3. Applicant role guard
4. Dashboard
5. Applications list
6. Application detail / tracking
7. Profile page
8. Draft/edit flow
9. Upload flow later

## Expected Supabase tables
- profiles
- applications
- application_documents
- application_aux_data

## Expected auth rule
- Only users with profiles.role = 'applicant' may enter the app

## Coding style
- Use clear folder-based feature organization
- Prefer stateless widgets where possible
- Keep business logic outside large widget build methods
- Use defensive error handling for all Supabase calls
- Add debug logging only where useful for diagnosis
- Avoid breaking working routes

## When asked to fix bugs
Always inspect:
- main.dart
- app/router.dart
- auth/login_page.dart
- splash/splash_page.dart
- the related Supabase query path

## Definition of done
- Builds successfully
- Runs on Flutter web and mobile target
- Handles loading, empty, and error states
- Shows useful error messages instead of silent failures