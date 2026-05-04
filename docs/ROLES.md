# Roles And Permissions

GymMate uses backend role and permission checks to protect workspace actions. The admin and member apps may hide UI, but backend checks are authoritative.

## Roles

| Role | Primary Surface | Expected Scope |
| --- | --- | --- |
| `superadmin` | Admin | Platform-level visibility across gyms, tenants, deployment health, and support workflows. |
| `owner` | Admin | Full gym-level operations: members, memberships, payments, trainers, announcements, biometric configuration, and settings. |
| `trainer` | Admin | Trainer-focused workspace for assigned members and permitted operational tasks. |
| `gym_member` | Member app | Member-facing membership, receipt, attendance, and announcement workflows. |

## Backend Permission Pattern

Backend controllers use helpers from `gymmate_backend/utils/roles.js`, most commonly:

- `hasRole(user, [...])`
- `hasPermission(user, 'permission.key')`

Controller-level helpers then map these to product abilities. For example, owner workspace access can be granted by role or by a specific permission such as `workspace.access`.

## Maintenance Rules

- Add or change permission behavior in the backend first.
- Keep client navigation in sync with backend abilities, but do not rely on hidden UI for security.
- Prefer explicit permission names for new admin capabilities.
- Keep owner override behavior intentional and visible in controller helpers.
- Document new role-sensitive flows in this file and add focused tests when permission logic becomes shared.

## QA Accounts

Production QA seed users currently include:

- Superadmin: `qa_superadmin@gymmate.local`
- Owner: `qa_owner_iron@gymmate.local`
- Trainer: `qa_trainer_iron@gymmate.local`
- Member: `qa_member_iron@gymmate.local`
- Flow owner: `qa_owner_flow@gymmate.local`
- Empty owner: `qa_owner_empty@gymmate.local`

Passwords live in the deployment handoff and QA seed scripts. Rotate or remove public seed users before using GymMate for real customer data.
