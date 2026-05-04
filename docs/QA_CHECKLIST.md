# QA Checklist

Use this checklist for small solo-maintained releases. Keep the scope focused on the changed area.

## Always

- Confirm `git status --short` and avoid committing generated artifacts.
- Run `git diff --check`.
- Run the smallest meaningful backend/admin/mobile checks for the change.
- Smoke test production only after an explicit deploy.

## Backend

```bash
cd gymmate_backend
npm test
```

For membership changes, verify:

- Empty membership summary returns `No active plan`.
- Active paid or waived memberships are shown as active.
- Renewal due dates use the expected precedence.
- Legacy plan catalog summaries still render where used.
- New membership templates still render where used.
- Receipts and payment history still point to the correct membership.

`npm run lint` currently reports existing repo-wide lint issues. Use it when intentionally working on lint cleanup, not as a blocker for narrow fixes unless the touched files introduce new lint failures.

## Admin Web

```bash
cd gymmate_admin_vite
npm run build
```

Smoke paths:

- `/admin/login`
- Superadmin dashboard and system health
- Owner dashboard
- Workspace member list
- Member detail membership panel
- Settings light/dark mode

## Member Web/App

For deploy builds:

```bash
cd gymmate_mobile
flutter build web
```

Smoke paths:

- Member login
- Home/dashboard membership summary
- Membership receipt
- Announcements
- Attendance views

Flutter analysis currently has existing warnings in older/forked code. Treat analysis cleanup as a separate maintenance task.

## Production QA Accounts

Known QA seed emails:

- `qa_superadmin@gymmate.local`
- `qa_owner_iron@gymmate.local`
- `qa_trainer_iron@gymmate.local`
- `qa_member_iron@gymmate.local`
- `qa_owner_flow@gymmate.local`
- `qa_owner_empty@gymmate.local`

Do not add real member data to QA seed accounts.
