# LDSP Applicant App Development Guide

This file is the living guide for feature changes, UX updates, hardening work, and release readiness in `ldsp_applicant`.

## How To Use This File
- Add one entry for every meaningful change batch.
- Keep entries short, factual, and linked to files changed.
- Include validation done (`analyze`, `test`, manual QA).
- If a backend dependency exists, note it clearly.

## Change Log Template
Use this block for every new update:

```md
## YYYY-MM-DD - <Short title>
### Scope
- <What changed>

### Files
- [file1](absolute/path)
- [file2](absolute/path)

### Why
- <User or product reason>

### Validation
- flutter analyze: <result>
- flutter test: <result>
- Manual QA: <result>

### Notes / Risks
- <Any backend dependency, known limitation, or follow-up>
```

## Current Architecture Snapshot (2026-03-23)
- Platform: Flutter (applicant-only)
- Backend: Supabase
- Primary navigation: bottom nav shell (`Home`, `Applications`, `Notifications`, `Profile`)
- Auth flows:
  - Login/register
  - Email OTP verify
  - Forgot/reset password
- Core modules:
  - Dashboard
  - Applications list/detail/edit
  - Notifications
  - Profile

## Recent Updates

## 2026-03-23 - Motion polish third pass (subtle + lightweight)
### Scope
- Applied subtle entrance stagger per section on Dashboard, Applications list, and Application detail pages.
- Kept press-scale interaction on primary/secondary buttons for tactile feedback.
- Retained lightweight animated timeline reveal for activity/tracking items.

### Files
- [dashboard_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/dashboard/dashboard_page.dart)
- [applications_list_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/applications_list_page.dart)
- [application_detail_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/application_detail_page.dart)
- [app_components.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/ui/components/app_components.dart)

### Validation
- flutter analyze: pass
- flutter test: pass

### Notes / Risks
- Animation timing is intentionally short to avoid added cognitive load.
- No backend logic/schema changes were introduced in this pass.

## 2026-03-23 - Security and release hardening pass
### Scope
- Tightened reset-password route/session gating.
- Registration policy set to fail-safe when policy check fails.
- Reduced sensitive backend error leakage in user-facing messages.
- Added Android release signing fallback if `key.properties` is missing.
- Added iOS `Podfile`, identity cleanup, and env template.

### Files
- [router.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/app/router.dart)
- [reset_password_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/reset_password_page.dart)
- [feature_policy_service.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/core/services/feature_policy_service.dart)
- [login_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/login_page.dart)
- [register_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/register_page.dart)
- [forgot_password_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/forgot_password_page.dart)
- [dashboard_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/dashboard/dashboard_page.dart)
- [notifications_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/notifications/notifications_page.dart)
- [build.gradle.kts](C:/Users/Admin/Desktop/ldsp_applicant/android/app/build.gradle.kts)
- [Info.plist](C:/Users/Admin/Desktop/ldsp_applicant/ios/Runner/Info.plist)
- [project.pbxproj](C:/Users/Admin/Desktop/ldsp_applicant/ios/Runner.xcodeproj/project.pbxproj)
- [Podfile](C:/Users/Admin/Desktop/ldsp_applicant/ios/Podfile)
- [.env.example](C:/Users/Admin/Desktop/ldsp_applicant/.env.example)

### Validation
- flutter analyze: pass
- flutter test: pass
- flutter build apk --release: pass

### Notes / Risks
- Full enforcement of workflow rules still requires strict Supabase RLS and DB constraints.

## 2026-03-23 - UX shell + hierarchy pass
### Scope
- Introduced consistent signed-in app shell with bottom navigation.
- Added profile destination and page.
- Reworked dashboard/list/detail action hierarchy.
- Improved auth CTA grouping and edit-form step naming clarity.

### Files
- [app_shell.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/ui/components/app_shell.dart)
- [profile_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/profile/profile_page.dart)
- [router.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/app/router.dart)
- [dashboard_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/dashboard/dashboard_page.dart)
- [applications_list_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/applications_list_page.dart)
- [notifications_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/notifications/notifications_page.dart)
- [application_detail_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/application_detail_page.dart)
- [application_edit_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/application_edit_page.dart)
- [auth_scaffold.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/widgets/auth_scaffold.dart)
- [login_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/login_page.dart)
- [register_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/auth/register_page.dart)
- [app_theme.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/ui/theme/app_theme.dart)

### Validation
- flutter analyze: pass
- flutter test: pass

### Notes / Risks
- Screen-level micro-interactions and skeleton patterns were added in the next entry.

## 2026-03-23 - Premium micro-interactions + spacing rhythm pass
### Scope
- Added animated page-state transitions (fade + slight slide).
- Added pulse skeleton loading components and applied to key screens.
- Added reusable `SectionGap` spacing helper for consistent vertical rhythm.

### Files
- [app_components.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/ui/components/app_components.dart)
- [dashboard_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/dashboard/dashboard_page.dart)
- [applications_list_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/applications_list_page.dart)
- [notifications_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/notifications/notifications_page.dart)
- [profile_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/profile/profile_page.dart)
- [application_detail_page.dart](C:/Users/Admin/Desktop/ldsp_applicant/lib/features/applications/application_detail_page.dart)

### Validation
- flutter analyze: pass
- flutter test: pass

### Notes / Risks
- Skeletons are intentionally lightweight (pulse style, no extra dependency).
- For very long lists, keep skeleton count limited for performance.

## Release Checklist (Quick)
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Android release:
  - Provide `android/key.properties` + keystore for production signing
  - Run `flutter build appbundle --release` (or `apk`)
- iOS release (macOS required):
  - `pod install` in `ios/`
  - Configure Team ID and signing
  - Build archive via Xcode or CI
- Confirm `.env` values are injected in CI/release

## Known Boundaries
- Applicant-only app. Admin/secretary controls remain on portal side.
- Any exam/room-assignment behavior should be enabled when portal schema/rules are finalized.
