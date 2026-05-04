function serializeActiveMembershipSummary(membership, plan = null) {
  if (!membership) {
    return {
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
    };
  }

  return {
    id: membership._id,
    planId:
      plan?._id ||
      membership.planId ||
      membership.membershipTemplateId?._id ||
      membership.membershipTemplateId ||
      null,
    planName:
      plan?.name ||
      membership.planName ||
      membership.membershipTemplateId?.name ||
      'No active plan',
    status: membership.status || 'inactive',
    paymentStatus: membership.paymentStatus || 'none',
    startDate: membership.startDate || null,
    endDate: membership.endDate || null,
    renewalDueDate:
      membership.renewalDueDate ||
      membership.nextRenewalDate ||
      membership.endDate ||
      null,
    addOns: {
      training: Boolean(
        membership.addOns?.training ||
          membership.entitlementsSnapshot?.personalTraining,
      ),
      diet: Boolean(
        membership.addOns?.diet ||
          membership.entitlementsSnapshot?.dietPlan,
      ),
    },
    notes: membership.notes || '',
  };
}

module.exports = {
  serializeActiveMembershipSummary,
};
