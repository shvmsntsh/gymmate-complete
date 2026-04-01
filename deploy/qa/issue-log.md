# GymMate QA Issue Log

## Environment
- Date: 2026-04-01
- Browser: Chrome via Playwright
- Admin local: http://127.0.0.1:4173
- Mobile local: http://127.0.0.1:8090
- Backend local: http://127.0.0.1:5050
- QA DB: gymmate_qa

## Accounts
- Superadmin: qa_superadmin@gymmate.local / QaAdmin123!
- Owner: qa_owner_iron@gymmate.local / QaOwner123!
- Trainer: qa_trainer_iron@gymmate.local / QaTrainer123!
- Member: qa_member_iron@gymmate.local / QaMember123!

## Issues
| ID | Severity | Surface | Route/Screen | Viewport | Account | Repro | Expected | Actual | Root Cause | Fix Status | Retest |
|---|---|---|---|---|---|---|---|---|---|---|---|
| QA-001 | P0 | Mobile | Quick Join | 390x844 | Guest | Open Quick Join from entry | Phone join form renders | Blank screen | Nested auth shell / full-screen composition | Fixed in code | Pass on local Chrome mobile. See `deploy/qa/screenshots/mobile-quick-join-final.png` |
| QA-002 | P1 | Mobile | Entry | 390x844 | Guest | Open start screen | Only primary entry actions visible | Extra preview block remains below fold | Unneeded secondary hero section | Fixed in code | Pass on local Chrome mobile. See `deploy/qa/screenshots/mobile-entry.png` |
| QA-003 | P1 | Mobile | Role setup | 390x844 | Guest | Open role selection | Swipeable role cards on compact screens | Stacked cards, poor mobile fit | Compact layout not adapted | Fixed in code | Pass on local Chrome mobile. See `deploy/qa/screenshots/mobile-role-slider-final.png` |
| QA-004 | P1 | Admin | Register gym | 390x844 | Superadmin | Open register gym on mobile height | Submit CTA reachable | Form submit can be clipped | Public shell overflow/min-height issue | Fixed in code | Pass on local Chrome mobile. See `deploy/qa/screenshots/admin-register-mobile.png` |
| QA-005 | P0 | Cross-flow | Admin register -> mobile owner login | Desktop + mobile | Superadmin/Owner | Register gym in admin, then login in mobile | New owner can login immediately | Gym exists but owner login fails | Gym registration created only gym record, not linked user | Fixed in code | Pass on local QA backend + admin UI. Gym registration succeeded and `/api/auth/login` for new owner returned 200 |
| QA-006 | P1 | Admin | Gym details error state | Desktop | Superadmin | Open a stale gym id route | Show a proper not-found state | Page rendered `Not provided` for an error payload | Gym details view ignored non-200 responses | Fixed in code | Pass. Real dashboard drill-down loads actual gym details; stale ids now surface an error |
| QA-007 | P1 | Mobile | Member navigation | 390x844 | Member | Login as a member and inspect the bottom nav | Dashboard, Progress, Plan, Coach, Profile tabs available | Progress tab was missing even though the role shell expected five tabs | `MainNavigationScaffold` never added `ProgressPage` for members | Fixed in code | Rebuilt locally with the new nav shell before production deploy |
| QA-008 | P1 | Mobile | Trainer navigation | 390x844 | Trainer | Login as a trainer and inspect the bottom nav | Dashboard, Trainees, Profile tabs available | Trainees tab was missing even though trainer navigation logic expected it | `MainNavigationScaffold` never added `TraineesListPage` for trainers | Fixed in code | Rebuilt locally with the new nav shell before production deploy |
| QA-009 | P2 | Mobile QA tooling | Authenticated browser sweep | 390x844 | Owner/Trainer/Member/Admin | Try to seed an authenticated Flutter web session directly in Chrome automation | Authenticated screenshots should show the actual dashboards | Earlier automation reported stored state but still captured the guest entry screen | Flutter web secure storage on browser is encrypted and canvas-based, so plain `localStorage` injection produced false positives | Tooling corrected during investigation | Ongoing: real canvas login submission remains less deterministic than admin DOM automation |
| QA-010 | P1 | Mobile | Member dashboard | 390x844 | Member | Login as a member and open the dashboard | Progress chart loads without console errors | Dashboard requested `/api/member/progress-participation` and got a 404 | Backend route never existed even though mobile dashboard called it | Fixed in backend and deployed | Pass on production. Member login now returns 200 and no 404 is logged in the sweep report |
| QA-011 | P1 | Mobile | Trainer dashboard | 390x844 | Trainer | Login as a trainer and open the dashboard | Attendance/progress chart loads without console errors | Dashboard requested `/api/trainer/attendance-progress` and got a 404 | Backend route never existed even though mobile dashboard called it | Fixed in backend and deployed | Pass in isolated production trainer login check. `/api/auth/login` returned 200 and the dashboard no longer logs the attendance 404 |
| QA-012 | P1 | Mobile | Demo owner flow | 390x844 | Demo owner | Login to the live demo owner account | Owner lands on the real owner dashboard with invites/profile available | Demo owners were forced into brand setup because seeded gyms had no logo | Demo seed data created valid gyms but incomplete branding | Fixed in seed data and reseeded production | Pass on production. Owner now lands on the owner dashboard instead of the branding gate |
