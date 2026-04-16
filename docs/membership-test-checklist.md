# Membership System Test Checklist

## Pre-requisites
- Backend server running
- Admin dashboard running
- Mobile app running (or test environment)

---

## Test Case 1: Owner Creates Membership Plan

### Steps:
1. Login to admin dashboard as Owner
2. Navigate to Membership page (`/membership-new`)
3. Click "New Plan" button
4. Fill in plan details:
   - Name: "Test Monthly"
   - Price: 1000
   - Duration: 30 days
   - Category: monthly
   - Toggle "Visible to Members"
   - Enable some features (gymAccess, lockerAccess)
5. Click "Create Plan"
6. Verify plan appears in the list

### Expected Result:
- Plan created successfully
- Plan shows in the Plans tab
- Plan is visible to members

---

## Test Case 2: Member Views Available Plans

### Steps:
1. Login to mobile app as Member
2. Navigate to Membership tab
3. Scroll to "Available Plans" section

### Expected Result:
- Current membership status shown (or "No active plan")
- Available plans displayed (if any visible)
- Current plan highlighted as "CURRENT"
- Upgrade options shown for eligible plans

---

## Test Case 3: Member Submits Upgrade Request

### Steps:
1. From mobile app Membership screen
2. Tap "Upgrade" on an eligible plan
3. Select payment mode (e.g., "cash", "upi")
4. Add optional note
5. Submit request

### Expected Result:
- Request submitted successfully
- Request appears in Request History
- Status shows "Submitted"

---

## Test Case 4: Owner Views Request Queue

### Steps:
1. Login to admin dashboard as Owner
2. Navigate to Membership page
3. Click "Requests" tab

### Expected Result:
- All requests displayed
- Tabs filter by status (Submitted, Payment Review, Approved, Rejected)
- Request shows member name, type, target plan, payment mode

---

## Test Case 5: Owner Verifies Payment (Offline)

### Steps:
1. In admin dashboard Requests tab
2. Click on a request with "Awaiting Payment" status
3. Click "Verify Payment" button

### Expected Result:
- Request status changes to "Payment Review"
- Payment verified timestamp recorded

---

## Test Case 6: Owner Approves Request

### Steps:
1. Click on a pending request
2. Review current plan and target plan details
3. Click "Approve" button
4. Confirm approval

### Expected Result:
- Request status changes to "Approved"
- New membership created for member
- Member status becomes "Active"
- Entitlements updated based on new plan
- Audit log created

---

## Test Case 7: Member Sees Updated Plan

### Steps:
1. In mobile app, pull to refresh Membership screen
2. View current plan card

### Expected Result:
- New plan name displayed
- Status shows "Active"
- New entitlements visible (gym access, classes, etc.)
- Valid dates shown

---

## Test Case 8: Owner Rejects Request

### Steps:
1. In admin dashboard, click on pending request
2. Click "Reject" button
3. Enter rejection reason
4. Confirm rejection

### Expected Result:
- Request status changes to "Rejected"
- Admin note stored
- Member's current membership unchanged

---

## Test Case 9: Member Sees Rejection Reason

### Steps:
1. In mobile app, view request history
2. Tap on rejected request

### Expected Result:
- Rejection reason displayed
- Status shows "Rejected"

---

## Test Case 10: Member Requests Add-on

### Steps:
1. In mobile app, ensure member has active plan with available add-ons
2. Tap request add-on (e.g., "Personal Training")
3. Select payment mode
4. Submit request

### Expected Result:
- Add-on request created
- Owner sees it in requests queue as "add_on" type

---

## Test Case 11: Owner Approves Add-on

### Steps:
1. In admin dashboard, view add-on request
2. Click "Approve"

### Expected Result:
- Add-on added to member's entitlements
- Entitlements snapshot updated

---

## Test Case 12: Owner Freezes Membership

### Steps:
1. In admin dashboard, Members tab
2. Find active membership
3. Click "Freeze" action

### Expected Result:
- Membership status becomes "Frozen"
- Frozen until date set

---

## Edge Cases to Test

1. **Duplicate request prevention**: Member tries to submit another upgrade while one is pending
   - Expected: Error message "You already have a pending request"

2. **Expired request handling**: Request sits for too long
   - Expected: Status can be manually set to "expired"

3. **Offline payment with no proof**: Member selects cash but doesn't upload proof
   - Expected: Owner must manually verify

4. **Plan deactivation**: Owner deactivates a plan that members have requested
   - Expected: Existing requests can still be processed, but plan shows as inactive

---

## Data Verification Queries

### Check active memberships:
```javascript
db.membermemberships.find({ isActiveBaseMembership: true, status: 'active' })
```

### Check pending requests:
```javascript
db.membershipchangerequests.find({ status: { $in: ['submitted', 'awaiting_payment'] } })
```

### Check audit logs:
```javascript
db.membershipauditlogs.find().sort({ createdAt: -1 }).limit(20)
```