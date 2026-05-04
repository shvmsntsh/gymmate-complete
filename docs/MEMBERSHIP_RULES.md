# Membership Rules

Membership behavior belongs in the backend. Clients should display backend summaries and send owner/member actions to the API instead of recalculating membership truth.

## Canonical Records

- `MemberMembership` is the canonical membership record for a member.
- `MembershipTemplate` is the newer plan/template model.
- `MembershipPlanCatalog` is retained for legacy summary compatibility.
- `MembershipChangeRequest` is the newer request workflow.
- `MembershipRequest` is the legacy request workflow still shown in some member summaries.

## Active Membership Selection

The member membership summary selects a membership for the signed-in member when either:

- `isActiveBaseMembership` is true, or
- the membership has an active-like status and paid/waived payment state.

When multiple records match, active base membership wins first, then the latest activation/update timestamps.

## Status Rules

`MembershipService.computeStatus` is the central status calculator for newer membership flows:

- `canceled` and `rejected` stay terminal.
- A frozen membership with a future `frozenUntil` is `frozen`.
- Missing dates are payment or approval pending depending on payment state.
- Future start dates are pending approval.
- Past end dates are expired.
- Memberships inside the template renewal lead window are renewal due.
- Unpaid and payment-under-review states remain pending.
- Otherwise the membership is active.

## Summary Shape

`gymmate_backend/utils/membershipSummary.js` serializes the legacy-compatible active membership summary used by operations/member endpoints. It preserves:

- Empty state: `No active plan`, inactive status, no payment.
- Legacy plan override when a `MembershipPlanCatalog` row is provided.
- New template fallback when only `membershipTemplateId` is available.
- Renewal date precedence: `renewalDueDate`, then `nextRenewalDate`, then `endDate`.
- Add-on compatibility across legacy `addOns` and newer `entitlementsSnapshot`.

## Change Guidelines

- Update backend utilities/services before changing frontend derivations.
- Keep old plan catalog fallback until all clients are migrated.
- Add focused `node:test` tests for any status or summary behavior change.
- Do not introduce a second membership source of truth in Vue or Flutter.
