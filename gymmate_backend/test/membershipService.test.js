const assert = require('node:assert/strict');
const test = require('node:test');

const MembershipService = require('../services/membershipService');

test('manual paid assignment preview treats submitted payment as received', () => {
  const summary = MembershipService.buildPaymentSummary({
    request: {
      paymentMode: 'cash',
      paymentReference: 'CASH-123',
    },
    requestPayments: [],
    currentMembership: null,
    currentTemplate: null,
    targetTemplate: {
      price: 1500,
    },
    action: 'activate_now',
    templateRules: {},
    override: {
      manualPaymentAmount: 1500,
      assumePaymentReceived: true,
    },
  });

  assert.equal(summary.expectedAmount, 1500);
  assert.equal(summary.amountPaid, 1500);
  assert.equal(summary.remainingAmount, 0);
  assert.equal(summary.paymentStatusDecision, 'paid');
});

test('manual unpaid assignment preview still reports pending payment', () => {
  const summary = MembershipService.buildPaymentSummary({
    request: {
      paymentMode: 'cash',
    },
    requestPayments: [],
    currentMembership: null,
    currentTemplate: null,
    targetTemplate: {
      price: 1500,
    },
    action: 'activate_now',
    templateRules: {},
    override: {
      manualPaymentAmount: 1500,
    },
  });

  assert.equal(summary.expectedAmount, 1500);
  assert.equal(summary.amountPaid, 0);
  assert.equal(summary.remainingAmount, 1500);
  assert.equal(summary.paymentStatusDecision, 'unpaid');
});
