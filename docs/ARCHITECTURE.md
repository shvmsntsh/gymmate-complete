# GymMate MVP Architecture

GymMate MVP is a monorepo with three product surfaces and one production deployment flow.

| Surface | Path | Runtime | Purpose |
| --- | --- | --- | --- |
| Backend API | `gymmate_backend/` | Express.js, MongoDB, Node.js | Source of truth for gyms, users, roles, memberships, payments, announcements, attendance, branding, and admin/member workflows. |
| Member app | `gymmate_mobile/` | Flutter | Member-facing app deployed at `/`. |
| Admin app | `gymmate_admin_vite/` | Vue 3, Vuetify, Vite | Owner, trainer, and superadmin workspace deployed at `/admin`. |
| Deployment scripts | `deploy/vercel/` | Bash, Vercel CLI | Builds and deploys backend first, then a combined frontend artifact. |

## Backend Responsibilities

The backend should remain the single source of truth for:

- Membership status, dates, active membership selection, entitlements, renewals, freezes, cancellations, and payment state.
- User role and permission decisions.
- Trainer assignment and gym ownership boundaries.
- Gym branding and operational settings.
- Payment receipts and membership audit history.

Client apps should render backend state rather than independently deriving business rules when possible.

## Frontend Responsibilities

The admin app handles workspace workflows for superadmins, owners, and trainers. It should call backend APIs for authorization-sensitive decisions and avoid duplicating membership, payment, or role rules.

The Flutter member app handles member self-service and root web/mobile presentation. It should treat backend membership summaries and entitlements as canonical.

## Data Model Notes

The membership system currently contains legacy plan catalog support plus newer membership templates:

- `MembershipPlanCatalog` supports older owner/member summary flows.
- `MembershipTemplate` and `MemberMembership` support the newer membership workspace.
- `MemberMembership` is the canonical member membership record.
- `MembershipChangeRequest` supports newer membership change workflows.
- `MembershipRequest` remains for older request flows that still appear in summaries.

Keep compatibility in place until the clients no longer depend on legacy fields.

## Operational Boundaries

Use small, targeted changes. Avoid changing the frontend framework split, replacing MongoDB, or moving business truth into either client. The maintainable path is to centralize backend rules gradually while preserving deployed behavior.
