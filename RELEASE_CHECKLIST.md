# LDSP Applicant App Release Checklist

Use this checklist before shipping every release.

Release Version: `__________`  
Release Date: `__________`  
Prepared By: `__________`

## 1. Build Readiness
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes
- [ ] `flutter build apk --release` succeeds (or `flutter build appbundle`)

## 2. Config & Environment
- [ ] Supabase URL and anon key point to correct environment
- [ ] Android internet permission is present for release
- [ ] Admin-control toggles from portal are reflected in app behavior
- [ ] `versionCode` and `versionName` are updated

## 3. Core User Flows (UAT)
- [ ] Login with valid applicant account works
- [ ] Registration works when enabled, blocked when disabled
- [ ] Forgot password flow works (email sent + reset route)
- [ ] Create new application works
- [ ] Continue draft works after app restart
- [ ] Edit returned application works
- [ ] Submit/resubmit flow works
- [ ] Notifications bell opens page without blank/null state
- [ ] Logout returns to login and protected routes are blocked

## 4. Applicant Data Integrity
- [ ] Applications list shows only current applicant records
- [ ] Dashboard status matches latest application data
- [ ] Detail page (timeline/docs/exam/interview) matches portal data
- [ ] Required field validation blocks invalid submit
- [ ] No schema mismatch errors in normal user flow

## 5. UI/UX Quality
- [ ] Spacing/readability checked on small and medium Android phones
- [ ] Keyboard overlap and long-form scrolling are correct
- [ ] Date picker, dropdowns, and numeric-only inputs behave correctly
- [ ] Loading/empty/error states are clear on major screens
- [ ] Logos, icons, and splash assets display correctly

## 6. Reliability & Monitoring
- [ ] Network failures show friendly messages (no raw stack traces)
- [ ] Online/offline transition smoke test completed
- [ ] Crash/error monitoring is active for production builds (if enabled)
- [ ] No critical runtime crashes observed in smoke test

## 7. Security & Access
- [ ] Applicant-only role guard enforced
- [ ] `/register` route redirects when registration is disabled
- [ ] No admin/staff pages exposed in applicant app
- [ ] No sensitive tokens/secrets logged in production

## 8. Release Packaging
- [ ] Release APK/AAB installs on at least 2 physical Android devices
- [ ] Upgrade path from previous app version verified
- [ ] Post-install smoke test passed (launch, login, dashboard, form)
- [ ] Signed artifact and release notes archived

## 9. Go / No-Go
- [ ] No open blocker or critical defects
- [ ] Product owner/QA sign-off completed
- [ ] Release approved

Approval:
- Product Owner: `__________`
- QA Lead: `__________`
- Engineering: `__________`
