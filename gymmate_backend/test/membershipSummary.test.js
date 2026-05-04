const assert = require('node:assert/strict');
const test = require('node:test');

const { serializeActiveMembershipSummary } = require('../utils/membershipSummary');

test('serializeActiveMembershipSummary returns an inactive empty summary', () => {
  assert.deepEqual(serializeActiveMembershipSummary(null), {
    id: null,
    planId: null,
    planName: 'No active plan',
    status: 'inactive',
    paymentStatus: 'none',
    startDate: null,
    endDate: null,
    renewalDueDate: null,
    addOns: { training: false, diet: false },
    notes: '',
  });
});

test('serializeActiveMembershipSummary prefers an explicit legacy plan row', () => {
  const startDate = new Date('2026-01-01T00:00:00.000Z');
  const endDate = new Date('2026-03-31T00:00:00.000Z');
  const renewalDueDate = new Date('2026-03-24T00:00:00.000Z');

  const summary = serializeActiveMembershipSummary(
    {
      _id: 'membership-1',
      planId: 'legacy-plan-1',
      planName: 'Stored Plan Name',
      membershipTemplateId: { _id: 'template-1', name: 'Template Plan' },
      status: 'active',
      paymentStatus: 'paid',
      startDate,
      endDate,
      renewalDueDate,
      nextRenewalDate: new Date('2026-03-20T00:00:00.000Z'),
      addOns: { training: true, diet: false },
      entitlementsSnapshot: { personalTraining: false, dietPlan: true },
      notes: 'Paid at front desk',
    },
    { _id: 'legacy-plan-2', name: 'Legacy Catalog Plan' },
  );

  assert.equal(summary.planId, 'legacy-plan-2');
  assert.equal(summary.planName, 'Legacy Catalog Plan');
  assert.equal(summary.renewalDueDate, renewalDueDate);
  assert.deepEqual(summary.addOns, { training: true, diet: true });
  assert.equal(summary.notes, 'Paid at front desk');
});

test('serializeActiveMembershipSummary falls back to membership template data', () => {
  const endDate = new Date('2026-05-31T00:00:00.000Z');
  const nextRenewalDate = new Date('2026-05-24T00:00:00.000Z');

  const summary = serializeActiveMembershipSummary({
    _id: 'membership-2',
    membershipTemplateId: { _id: 'template-2', name: 'Gold Monthly' },
    status: 'renewal_due',
    paymentStatus: 'waived',
    endDate,
    nextRenewalDate,
    entitlementsSnapshot: { personalTraining: true, dietPlan: false },
  });

  assert.equal(summary.planId, 'template-2');
  assert.equal(summary.planName, 'Gold Monthly');
  assert.equal(summary.paymentStatus, 'waived');
  assert.equal(summary.renewalDueDate, nextRenewalDate);
  assert.deepEqual(summary.addOns, { training: true, diet: false });
});

test('serializeActiveMembershipSummary uses stable defaults for partial memberships', () => {
  const endDate = new Date('2026-06-30T00:00:00.000Z');

  const summary = serializeActiveMembershipSummary({
    _id: 'membership-3',
    membershipTemplateId: 'template-3',
    endDate,
  });

  assert.equal(summary.planId, 'template-3');
  assert.equal(summary.planName, 'No active plan');
  assert.equal(summary.status, 'inactive');
  assert.equal(summary.paymentStatus, 'none');
  assert.equal(summary.renewalDueDate, endDate);
  assert.deepEqual(summary.addOns, { training: false, diet: false });
});
