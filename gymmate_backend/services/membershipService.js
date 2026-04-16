const mongoose = require('mongoose');
const crypto = require('crypto');
const MembershipTemplate = require('../models/MembershipTemplate');
const MemberMembership = require('../models/MemberMembership');
const MembershipChangeRequest = require('../models/MembershipChangeRequest');
const MembershipAuditLog = require('../models/MembershipAuditLog');
const PaymentEntry = require('../models/PaymentEntry');
const BillingReceipt = require('../models/BillingReceipt');

class MembershipService {
  static paymentEntryModes = new Set(['cash', 'upi', 'card', 'online', 'manual', 'waived']);

  static paidMembershipRequestTypes = new Set(['new_membership', 'renewal', 'upgrade', 'downgrade']);

  static isPopulatedRef(value) {
    return Boolean(
      value &&
        typeof value === 'object' &&
        !mongoose.Types.ObjectId.isValid(value) &&
        (value._id || value.id),
    );
  }

  static async resolveTemplateRef(templateRef) {
    if (!templateRef) return null;
    if (this.isPopulatedRef(templateRef)) return templateRef;
    return MembershipTemplate.findById(templateRef);
  }

  static isDateValue(value) {
    const date = value instanceof Date ? value : new Date(value);
    return !Number.isNaN(date.getTime());
  }

  static asDate(value, fallback = null) {
    if (!value) return fallback;
    if (typeof value === 'string') {
      const trimmed = value.trim();
      const dateOnlyMatch = trimmed.match(/^(\d{4})-(\d{2})-(\d{2})$/);
      if (dateOnlyMatch) {
        const [, year, month, day] = dateOnlyMatch;
        const date = new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), 12, 0, 0, 0));
        return Number.isNaN(date.getTime()) ? fallback : date;
      }
    }
    const date = value instanceof Date ? value : new Date(value);
    return Number.isNaN(date.getTime()) ? fallback : date;
  }

  static addDays(dateValue, days) {
    const date = new Date(dateValue);
    date.setDate(date.getDate() + Number(days || 0));
    return date;
  }

  static normalizeTemplateRules(template) {
    const rules = template?.rules || {};
    return {
      canUpgrade: rules.canUpgrade !== false,
      canDowngrade: rules.canDowngrade === true,
      canFreeze: rules.canFreeze === true,
      freezeLimitDays: Number(rules.freezeLimitDays || 0),
      requiresOwnerApproval: rules.requiresOwnerApproval !== false,
      overlapPolicy: rules.overlapPolicy || 'warn_and_require_override',
      approvalTimingPolicy: rules.approvalTimingPolicy || 'by_request_type',
      prorationMode: rules.prorationMode || 'none',
      prorationPolicy: rules.prorationPolicy || rules.prorationMode || 'none',
      freezePolicy: rules.freezePolicy || 'extend_end_date',
      manualOverridePolicy: rules.manualOverridePolicy || 'owner_only',
      paymentModesAllowed: Array.isArray(rules.paymentModesAllowed)
        ? rules.paymentModesAllowed
        : ['cash', 'upi', 'card', 'online', 'manual', 'waived'],
    };
  }

  static computeMembershipEndDate(startDate, template, overrideEndDate = null) {
    if (overrideEndDate) {
      return this.asDate(overrideEndDate);
    }

    if (!startDate) return null;
    return this.addDays(startDate, Number(template?.durationDays || 0));
  }

  static computeNextRenewalDate(endDate, template, overrideRenewalDate = null) {
    if (overrideRenewalDate) {
      return this.asDate(overrideRenewalDate);
    }

    if (!endDate) return null;
    return this.addDays(endDate, -Number(template?.renewalLeadDays || 0));
  }

  static getDefaultActionForRequestType(requestType, currentMembership, templateRules) {
    const activeCoverageExists =
      currentMembership?.endDate && this.asDate(currentMembership.endDate) > new Date();

    if (requestType === 'freeze') return 'freeze_extend';
    if (requestType === 'cancel') return 'cancel_membership';
    if (requestType === 'add_on') return 'activate_now';

    if (!activeCoverageExists) {
      return 'activate_now';
    }

    if (templateRules.approvalTimingPolicy === 'queue_after_current') {
      return 'queue_after_current';
    }

    if (templateRules.approvalTimingPolicy === 'activate_immediately') {
      return 'activate_now';
    }

    if (requestType === 'upgrade') {
      return 'activate_now';
    }

    return 'queue_after_current';
  }

  static computeProrationCredit(currentMembership, currentTemplate, targetTemplate, action, templateRules) {
    if (
      action !== 'activate_now' ||
      !currentMembership?.startDate ||
      !currentMembership?.endDate ||
      !currentTemplate?.price
    ) {
      return 0;
    }

    if (!['credit_remaining_days'].includes(templateRules.prorationPolicy)) {
      return 0;
    }

    const now = new Date();
    const currentEnd = this.asDate(currentMembership.endDate);
    const currentStart = this.asDate(currentMembership.startDate);
    if (!currentEnd || !currentStart || currentEnd <= now || currentEnd <= currentStart) {
      return 0;
    }

    const totalMs = currentEnd.getTime() - currentStart.getTime();
    const remainingMs = currentEnd.getTime() - now.getTime();
    if (totalMs <= 0 || remainingMs <= 0) {
      return 0;
    }

    const creditRatio = remainingMs / totalMs;
    const planPrice = Number(currentTemplate.price || 0);
    return Number((planPrice * creditRatio).toFixed(2));
  }

  static computeExpectedAmount(request, targetTemplate) {
    if (!targetTemplate) return 0;

    let amount = Number(targetTemplate.price || 0);
    if (request?.requestType === 'new_membership') {
      amount += Number(targetTemplate.joiningFee || 0);
    }
    return Number(amount.toFixed(2));
  }

  static buildWarning(code, message, severity = 'warning', blocking = false) {
    return { code, message, severity, blocking };
  }

  static buildPaymentSummary({
    request,
    requestPayments,
    currentMembership,
    currentTemplate,
    targetTemplate,
    action,
    templateRules,
    override = {},
  }) {
    const amountPaid = requestPayments.reduce((sum, entry) => sum + Number(entry.amount || 0), 0);
    const paymentWaived = this.isPaymentWaived(request);
    const creditAmount = this.computeProrationCredit(
      currentMembership,
      currentTemplate,
      targetTemplate,
      action,
      templateRules,
    );
    const hasManualAmount =
      override.manualPaymentAmount !== undefined &&
      override.manualPaymentAmount !== null &&
      override.manualPaymentAmount !== '';
    const normalizedManualAmount = Number(override.manualPaymentAmount);
    const expectedAmount = hasManualAmount && Number.isFinite(normalizedManualAmount)
      ? Number(Math.max(0, normalizedManualAmount).toFixed(2))
      : this.computeExpectedAmount(request, targetTemplate);
    const remainingAmount = paymentWaived
      ? 0
      : Number(Math.max(0, expectedAmount - creditAmount - amountPaid).toFixed(2));

    return {
      expectedAmount,
      amountPaid: Number(amountPaid.toFixed(2)),
      creditedAmount: Number(creditAmount.toFixed(2)),
      remainingAmount,
      paymentStatusDecision: paymentWaived
        ? 'waived'
        : remainingAmount <= 0 ? 'paid' : amountPaid > 0 ? 'payment_under_review' : 'unpaid',
    };
  }

  static isPaymentWaived(request) {
    return (
      request?.paymentMode === 'waived' ||
      request?.paymentStatus === 'waived' ||
      request?.paymentStatusDecision === 'waived'
    );
  }

  static async findPaymentConflicts(gymId, request, paymentSummary) {
    const warnings = [];
    const reference = String(request?.paymentReference || '').trim();
    const hasObjectId = mongoose.Types.ObjectId.isValid(String(request?._id || ''));

    if (reference) {
      const duplicateReference = await PaymentEntry.findOne({
        gymId,
        reference,
        ...(hasObjectId ? { membershipRequestId: { $ne: request._id } } : {}),
      }).lean();

      if (duplicateReference) {
        warnings.push(
          this.buildWarning(
            'duplicate_payment_reference',
            'Payment reference already used in this gym.',
            'error',
            true,
          ),
        );
      }
    }

    if (paymentSummary.amountPaid > 0) {
      const possibleDuplicatePayment = await PaymentEntry.findOne({
        gymId,
        memberId: request.memberId,
        ...(hasObjectId ? { membershipRequestId: { $ne: request._id } } : {}),
        amount: paymentSummary.amountPaid,
        mode: this.normalizePaymentEntryMode(request.paymentMode),
      })
        .sort({ recordedAt: -1, createdAt: -1 })
        .lean();

      if (possibleDuplicatePayment) {
        warnings.push(
          this.buildWarning(
            'possible_duplicate_payment',
            'Member already has similar payment recorded. Review before approval.',
          ),
        );
      }
    }

    return warnings;
  }

  static async computeDecisionPreview({
    gymId,
    request,
    currentMembership = null,
    requestedEffectiveDate = null,
    override = {},
  }) {
    const targetTemplate = await this.resolveTemplateRef(request?.targetMembershipTemplateId);
    const currentTemplate = await this.resolveTemplateRef(currentMembership?.membershipTemplateId);
    const templateRules = this.normalizeTemplateRules(targetTemplate || currentTemplate);
    const requestPayments = await this.getPaymentEntriesForRequest(gymId, request._id);

    let action = this.getDefaultActionForRequestType(
      request.requestType,
      currentMembership,
      templateRules,
    );

    if (override.overrideMode === 'force_immediate') {
      action = 'activate_now';
    } else if (override.overrideMode === 'force_queue') {
      action = 'queue_after_current';
    }

    const warnings = [];
    const blockers = [];
    const hasActiveCoverage =
      currentMembership?.endDate && this.asDate(currentMembership.endDate) > new Date();

    if (hasActiveCoverage && ['new_membership', 'renewal', 'upgrade', 'downgrade'].includes(request.requestType)) {
      warnings.push(
        this.buildWarning(
          'active_plan_exists',
          'Member has active paid coverage that has not expired yet.',
        ),
      );
    }

    if (hasActiveCoverage && action === 'activate_now' && request.requestType !== 'upgrade') {
      blockers.push(
        this.buildWarning(
          'approval_before_expiry',
          'Approval would start new plan before current paid plan expires.',
          'error',
          true,
        ),
      );
    }

    let startDate;
    if (override.manualStartDate) {
      startDate = this.asDate(override.manualStartDate);
    } else if (requestedEffectiveDate) {
      startDate = this.asDate(requestedEffectiveDate);
    } else if (action === 'queue_after_current' && currentMembership?.endDate) {
      startDate = this.asDate(currentMembership.endDate);
    } else {
      startDate = new Date();
    }

    let endDate = this.computeMembershipEndDate(startDate, targetTemplate, override.manualEndDate);
    let nextRenewalDate = this.computeNextRenewalDate(endDate, targetTemplate, override.manualNextRenewalDate);

    if (action === 'freeze_extend' && currentMembership) {
      const extensionDays = Number(override.extensionDays || request.freezeDays || templateRules.freezeLimitDays || 0);
      startDate = this.asDate(currentMembership.startDate);
      endDate = this.addDays(currentMembership.endDate, extensionDays);
      nextRenewalDate = this.computeNextRenewalDate(endDate, currentTemplate, override.manualNextRenewalDate);
    }

    if (!startDate || !endDate || endDate < startDate) {
      blockers.push(
        this.buildWarning(
          'invalid_membership_dates',
          'Start and end dates are invalid for this membership decision.',
          'error',
          true,
        ),
      );
    }

    if (nextRenewalDate && endDate && nextRenewalDate > endDate) {
      blockers.push(
        this.buildWarning(
          'invalid_next_renewal_date',
          'Next renewal date cannot be after membership end date.',
          'error',
          true,
        ),
      );
    }

    const paymentSummary = this.buildPaymentSummary({
      request,
      requestPayments,
      currentMembership,
      currentTemplate,
      targetTemplate,
      action,
      templateRules,
      override,
    });
    const paymentWarnings = await this.findPaymentConflicts(gymId, request, paymentSummary);
    warnings.push(...paymentWarnings.filter((item) => !item.blocking));
    blockers.push(...paymentWarnings.filter((item) => item.blocking));

    if (
      paymentSummary.remainingAmount > 0 &&
      this.paidMembershipRequestTypes.has(request.requestType) &&
      !this.isPaymentWaived(request) &&
      !override.allowPendingPayment
    ) {
      blockers.push(
        this.buildWarning(
          'payment_remaining',
          `Payment still pending: ${paymentSummary.remainingAmount.toFixed(2)}. Verify payment before approval.`,
          'error',
          true,
        ),
      );
    }

    const acknowledgedWarnings = Array.isArray(override.acknowledgedWarnings)
      ? override.acknowledgedWarnings
      : [];
    const unresolvedBlockingCodes = blockers
      .map((item) => item.code)
      .filter((code) => !acknowledgedWarnings.includes(code));

    const overrideRequired =
      unresolvedBlockingCodes.length > 0 ||
      Boolean(override.manualStartDate || override.manualEndDate || override.overrideMode);

    return {
      action,
      computedDates: {
        startDate,
        endDate,
        nextRenewalDate,
      },
      paymentSummary,
      warnings,
      blockers,
      overrideRequired,
      overrideAllowed: templateRules.manualOverridePolicy === 'owner_only',
      auditPreview: {
        currentMembershipId: currentMembership?._id || null,
        targetMembershipTemplateId: targetTemplate?._id || null,
        overrideMode: override.overrideMode || null,
        overrideReason: override.overrideReason || '',
      },
    };
  }

  static normalizePaymentEntryMode(mode) {
    const normalizedMode = String(mode || '').trim().toLowerCase();
    if (!this.paymentEntryModes.has(normalizedMode)) {
      throw new Error('Unsupported payment mode');
    }
    return normalizedMode;
  }

  static async ensureRequestPaymentEntry(request, adminId) {
    if (!request?.gymId || !request?.memberId) {
      return null;
    }

    const existingEntry = await PaymentEntry.findOne({
      gymId: request.gymId,
      membershipRequestId: request._id,
    }).sort({ recordedAt: -1, createdAt: -1 });

    if (existingEntry) {
      return existingEntry;
    }

    const template = await this.resolveTemplateRef(request.targetMembershipTemplateId);

    const amount = request.paymentMode === 'waived' ? 0 : Number(template?.price || 0);
    const mode = this.normalizePaymentEntryMode(request.paymentMode);

    return PaymentEntry.create({
      gymId: request.gymId,
      memberId: request.memberId,
      membershipId: null,
      membershipRequestId: request._id,
      amount,
      mode,
      reference: request.paymentReference || '',
      note: `Auto-recorded from ${request.requestType} request verification.`,
      recordedBy: adminId,
      recordedAt: request.verifiedAt || new Date(),
    });
  }

  static async createMembershipPaymentEntry(membership, amount, adminId, note) {
    if (!membership?._id || membership.paymentStatus !== 'paid') {
      return null;
    }

    return PaymentEntry.create({
      gymId: membership.gymId,
      memberId: membership.memberId,
      membershipId: membership._id,
      membershipRequestId: null,
      amount: Number(amount || 0),
      mode: this.normalizePaymentEntryMode(membership.paymentMethod),
      reference: membership.paymentReference || '',
      note: note || 'Auto-recorded membership payment.',
      recordedBy: adminId,
      recordedAt: membership.activatedAt || membership.startDate || new Date(),
    });
  }

  static async ensureReceiptForMembership(membership, adminId, amountOverride = null) {
    if (!membership?._id || membership.paymentStatus !== 'paid') {
      return null;
    }

    const existing = await BillingReceipt.findOne({ membershipId: membership._id });
    if (existing) {
      return existing;
    }

    const template = await this.resolveTemplateRef(membership.membershipTemplateId);
    const amount = amountOverride !== null && amountOverride !== undefined && amountOverride !== ''
      ? Number(amountOverride)
      : Number(template?.price || 0);
    const issuedAt = membership.activatedAt || membership.startDate || new Date();
    const datePart = new Date(issuedAt).toISOString().slice(0, 10).replace(/-/g, '');

    return BillingReceipt.create({
      gymId: membership.gymId,
      memberId: membership.memberId,
      membershipId: membership._id,
      planName: template?.name || 'Membership Plan',
      amount: Number.isFinite(amount) ? Number(Math.max(0, amount).toFixed(2)) : 0,
      currency: 'INR',
      paymentMethod: membership.paymentMethod || '',
      paymentReference: membership.paymentReference || '',
      receiptNumber: `GM-${datePart}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
      publicToken: crypto.randomBytes(24).toString('hex'),
      issuedAt,
      createdBy: adminId || membership.approvedBy || membership.memberId,
    });
  }

  static computeStatus(membership, template = null) {
    const now = new Date();
    
    if (membership.status === 'canceled' || membership.status === 'rejected') {
      return membership.status;
    }
    
    if (membership.isFrozen && membership.frozenUntil && now < membership.frozenUntil) {
      return 'frozen';
    }
    
    if (!membership.startDate || !membership.endDate) {
      if (membership.paymentStatus === 'unpaid') return 'pending_payment';
      return 'pending_approval';
    }

    if (membership.startDate && now < membership.startDate) {
      return 'pending_approval';
    }
    
    if (now > membership.endDate) {
      return 'expired';
    }
    
    if (template && template.renewalLeadDays) {
      const renewalThreshold = new Date(membership.endDate);
      renewalThreshold.setDate(renewalThreshold.getDate() - template.renewalLeadDays);
      if (now >= renewalThreshold && now <= membership.endDate) {
        return 'renewal_due';
      }
    }
    
    if (membership.paymentStatus === 'unpaid') return 'pending_payment';
    if (membership.paymentStatus === 'payment_under_review') return 'pending_approval';
    
    return 'active';
  }

  static async computeAndUpdateStatus(membershipId) {
    const membership = await MemberMembership.findById(membershipId).populate('membershipTemplateId');
    if (!membership) return null;
    
    const computedStatus = this.computeStatus(membership, membership.membershipTemplateId);
    
    if (computedStatus !== membership.status) {
      membership.status = computedStatus;
      await membership.save();
    }

    if (membership.isActiveBaseMembership && membership.status === 'expired') {
      const queuedMembership = await MemberMembership.findOne({
        gymId: membership.gymId,
        memberId: membership.memberId,
        isActiveBaseMembership: false,
        status: 'pending_approval',
        startDate: { $lte: new Date() },
      })
        .populate('membershipTemplateId')
        .sort({ startDate: 1, createdAt: 1 });

      if (queuedMembership) {
        membership.isActiveBaseMembership = false;
        await membership.save();

        queuedMembership.isActiveBaseMembership = true;
        queuedMembership.status = 'active';
        queuedMembership.activatedAt = queuedMembership.activatedAt || new Date();
        await queuedMembership.save();

        return queuedMembership;
      }
    }
    
    return membership;
  }

  static async createTemplate(gymId, userId, templateData) {
    const template = new MembershipTemplate({
      ...templateData,
      gymId,
      createdBy: userId,
    });
    
    await template.save();
    
    await this.logAudit(gymId, null, 'membership_template', template._id, 'created', userId, {
      name: template.name,
      category: template.category,
      price: template.price,
      durationDays: template.durationDays,
    });
    
    return template;
  }

  static async updateTemplate(gymId, templateId, updateData) {
    const template = await MembershipTemplate.findOneAndUpdate(
      { _id: templateId, gymId },
      { $set: updateData },
      { new: true }
    );
    
    if (!template) {
      throw new Error('Template not found');
    }
    
    await this.logAudit(gymId, null, 'membership_template', template._id, 'updated', updateData.updatedBy || null, updateData);
    
    return template;
  }

  static async deleteTemplate(gymId, templateId, userId) {
    const template = await MembershipTemplate.findOneAndUpdate(
      { _id: templateId, gymId },
      { $set: { active: false } },
      { new: true }
    );
    
    if (!template) {
      throw new Error('Template not found');
    }
    
    await this.logAudit(gymId, null, 'membership_template', template._id, 'updated', userId, { active: false });
    
    return template;
  }

  static async getTemplates(gymId, options = {}) {
    const query = { gymId };
    
    if (options.active !== undefined) query.active = options.active;
    if (options.visibleToMembers !== undefined) query.visibleToMembers = options.visibleToMembers;
    if (options.category) query.category = options.category;
    
    return MembershipTemplate.find(query).sort({ sortOrder: 1, name: 1 });
  }

  static async getTemplateById(gymId, templateId) {
    return MembershipTemplate.findOne({ _id: templateId, gymId });
  }

  static async getMemberMemberships(gymId, memberId) {
    return MemberMembership.find({ gymId, memberId })
      .populate('membershipTemplateId')
      .sort({ createdAt: -1 });
  }

  static async getPaymentEntriesForRequest(gymId, requestId) {
    if (!mongoose.Types.ObjectId.isValid(String(requestId || ''))) {
      return [];
    }
    return PaymentEntry.find({
      gymId,
      membershipRequestId: requestId,
    })
      .populate('recordedBy', 'name email')
      .sort({ recordedAt: -1, createdAt: -1 })
      .lean();
  }

  static async getPaymentEntriesForMember(gymId, memberId) {
    return PaymentEntry.find({
      gymId,
      memberId,
    })
      .populate('recordedBy', 'name email')
      .sort({ recordedAt: -1, createdAt: -1 })
      .lean();
  }

  static async getActiveMembership(gymId, memberId) {
    const membership = await MemberMembership.findOne({
      gymId,
      memberId,
      isActiveBaseMembership: true,
    }).populate('membershipTemplateId');
    
    if (membership) {
      return this.computeAndUpdateStatus(membership._id);
    }
    
    return null;
  }

  static async assignMembership(gymId, memberId, templateId, adminId, options = {}) {
    const template = await MembershipTemplate.findById(templateId);
    if (!template) {
      throw new Error('Template not found');
    }

    const existingActive = await MemberMembership.findOne({
      gymId,
      memberId,
      isActiveBaseMembership: true,
      status: { $nin: ['canceled', 'rejected', 'expired'] },
    }).populate('membershipTemplateId');

    if (existingActive && options.flowType !== 'manual_change') {
      throw new Error(
        'Member already has a current plan. Use Manage to renew or change the current membership.',
      );
    }

    const currentTemplate = await this.resolveTemplateRef(
      existingActive?.membershipTemplateId,
    );
    const sameTemplate =
      existingActive &&
      currentTemplate &&
      String(currentTemplate._id) === String(template._id);
    const currentRank = Number(currentTemplate?.upgradeRank || 0);
    const targetRank = Number(template?.upgradeRank || 0);
    const requestType = !existingActive
      ? 'new_membership'
      : sameTemplate
      ? 'renewal'
      : targetRank >= currentRank
      ? 'upgrade'
      : 'downgrade';
    const previewOverride = { ...options };
    if (options.paymentAmount !== undefined) {
      previewOverride.manualPaymentAmount = options.paymentAmount;
    }
    if (options.paymentStatus !== 'paid') {
      previewOverride.allowPendingPayment = true;
    }

    if (
      options.flowType === 'manual_change' &&
      existingActive &&
      !previewOverride.overrideMode &&
      !previewOverride.manualStartDate &&
      !previewOverride.manualEndDate &&
      !previewOverride.manualNextRenewalDate
    ) {
      previewOverride.overrideMode = 'force_queue';
    }

    const assignmentPreview = await this.computeDecisionPreview({
      gymId,
      request: {
        _id: `manual-${memberId}-${templateId}`,
        memberId,
        requestType,
        targetMembershipTemplateId: template,
        paymentMode: options.paymentMethod,
        paymentReference: options.paymentReference || '',
      },
      currentMembership: existingActive,
      requestedEffectiveDate: options.startDate,
      override: previewOverride,
    });

    if (assignmentPreview.blockers.length && !previewOverride.overrideReason) {
      throw new Error(assignmentPreview.blockers.map((item) => item.message).join(' | '));
    }

    if (existingActive && assignmentPreview.action === 'activate_now') {
      existingActive.isActiveBaseMembership = false;
      await existingActive.save();
    }

    const startDate = assignmentPreview.computedDates.startDate;
    const endDate = assignmentPreview.computedDates.endDate;
    const nextRenewalDate = assignmentPreview.computedDates.nextRenewalDate;
    
    const membership = new MemberMembership({
      gymId,
      memberId,
      membershipTemplateId: templateId,
      status: assignmentPreview.action === 'queue_after_current'
        ? 'pending_approval'
        : options.paymentStatus === 'paid' ? 'active' : 'pending_payment',
      startDate,
      endDate,
      nextRenewalDate,
      activatedAt: options.paymentStatus === 'paid' ? new Date() : null,
      approvedBy: adminId,
      paymentStatus: options.paymentStatus || 'unpaid',
      paymentMethod: options.paymentMethod || null,
      paymentReference: options.paymentReference || '',
      notes: options.notes || '',
      entitlementsSnapshot: {
        ...template.includedFeatures,
        personalTraining: options.addOns?.personalTraining || false,
        dietPlan: options.addOns?.dietPlan || false,
      },
      isActiveBaseMembership: assignmentPreview.action !== 'queue_after_current',
    });
    
    await membership.save();

    if (membership.paymentStatus === 'paid') {
      await this.createMembershipPaymentEntry(
        membership,
        assignmentPreview.paymentSummary.expectedAmount,
        adminId,
        options.flowType === 'manual_change'
          ? 'Auto-recorded from manual plan change.'
          : 'Auto-recorded from membership assignment.',
      );
      await this.ensureReceiptForMembership(
        membership,
        adminId,
        assignmentPreview.paymentSummary.expectedAmount,
      );
    }
    
    await this.logAudit(gymId, memberId, 'member_membership', membership._id, 'created', adminId, {
      templateName: template.name,
      startDate,
      endDate,
      paymentStatus: membership.paymentStatus,
      decisionPreview: assignmentPreview,
      flowType: options.flowType || 'new_assign',
    });
    
    if (membership.status === 'active') {
      await this.logAudit(gymId, memberId, 'member_membership', membership._id, 'activated', adminId, {
        templateName: template.name,
      });
    }
    
    return membership;
  }

  static async createChangeRequest(gymId, memberId, requestData) {
    const requiresCurrentMembership = ['renewal', 'upgrade', 'downgrade', 'freeze', 'cancel', 'add_on'].includes(
      requestData.requestType,
    );

    if (requiresCurrentMembership && !requestData.currentMembershipId) {
      throw new Error('An active membership is required for this request type.');
    }

    const activeRequests = await MembershipChangeRequest.find({
      gymId,
      memberId,
      status: { $in: ['submitted', 'awaiting_payment', 'payment_under_review'] },
      requestType: { $in: ['upgrade', 'renewal', 'downgrade'] },
    });
    
    if (activeRequests.length > 0) {
      throw new Error('You already have a pending upgrade/renewal request. Please wait for it to be processed.');
    }
    
    const request = new MembershipChangeRequest({
      ...requestData,
      gymId,
      memberId,
      status: 'submitted',
      requestedAt: new Date(),
    });
    
    await request.save();
    
    await this.logAudit(gymId, memberId, 'membership_change_request', request._id, 'request_submitted', memberId, {
      requestType: request.requestType,
      targetTemplateId: request.targetMembershipTemplateId,
    });
    
    return request;
  }

  static async verifyPayment(requestId, gymId, adminId, paymentData) {
    const request = await MembershipChangeRequest.findOne({ _id: requestId, gymId });

    if (!request) {
      throw new Error('Request not found');
    }

    if (!['submitted', 'awaiting_payment'].includes(request.status)) {
      throw new Error('Request has already been processed');
    }

    request.status = 'payment_under_review';
    request.verifiedAt = new Date();
    request.verifiedBy = adminId;

    if (paymentData.paymentMethod) {
      request.paymentMode = paymentData.paymentMethod;
    }
    if (paymentData.paymentReference) {
      request.paymentReference = paymentData.paymentReference;
    }

    await request.save();
    await request.populate('targetMembershipTemplateId', 'price');
    await this.ensureRequestPaymentEntry(request, adminId);

    await this.logAudit(
      gymId,
      request.memberId,
      'membership_change_request',
      request._id,
      'payment_verified',
      adminId,
      {
        paymentMethod: request.paymentMode,
        paymentReference: request.paymentReference,
      },
    );

    return request;
  }

  static async approveRequest(requestId, gymId, adminId, options = {}) {
    const request = await MembershipChangeRequest.findOne({ _id: requestId, gymId })
      .populate('targetMembershipTemplateId');

    if (!request) {
      throw new Error('Request not found');
    }

    if (!['submitted', 'awaiting_payment', 'payment_under_review'].includes(request.status)) {
      throw new Error('Request has already been processed');
    }

    let membership;

    if (
      request.requestType === 'new_membership' ||
      request.requestType === 'renewal' ||
      request.requestType === 'upgrade' ||
      request.requestType === 'downgrade'
    ) {
      const template = request.targetMembershipTemplateId;

      const currentActive = await MemberMembership.findOne({
        gymId,
        memberId: request.memberId,
        isActiveBaseMembership: true,
      }).populate('membershipTemplateId');

      const hasManualApprovalInputs = Boolean(
        options.overrideMode ||
          options.manualStartDate ||
          options.manualEndDate ||
          options.manualNextRenewalDate ||
          options.overrideReason,
      );

      const decisionPreview = await this.computeDecisionPreview({
        gymId,
        request,
        currentMembership: currentActive,
        requestedEffectiveDate: hasManualApprovalInputs ? options.effectiveDate : null,
        override: options,
      });

      if (decisionPreview.blockers.length) {
        throw new Error(decisionPreview.blockers.map((item) => item.message).join(' | '));
      }

      request.status = 'approved';
      request.decidedAt = new Date();
      request.decidedBy = adminId;
      request.adminNote = options.adminNote || '';
      request.effectiveDate = decisionPreview.computedDates.startDate;

      await MembershipChangeRequest.updateOne(
        { _id: request._id },
        {
          $set: {
            status: request.status,
            decidedAt: request.decidedAt,
            decidedBy: request.decidedBy,
            adminNote: request.adminNote,
            effectiveDate: request.effectiveDate,
          },
        },
      );

      if (currentActive) {
        if (decisionPreview.action === 'activate_now') {
          currentActive.isActiveBaseMembership = false;
        }
        if (decisionPreview.action === 'activate_now' && (request.requestType === 'upgrade' || request.requestType === 'downgrade')) {
          currentActive.status = 'canceled';
        }
        if (decisionPreview.action === 'activate_now') {
          await currentActive.save();

          await this.logAudit(gymId, request.memberId, 'member_membership', currentActive._id, 'deactivated', adminId, {
            replacedBy: request._id,
            reason: request.requestType,
            overrideReason: options.overrideReason || '',
          });
        }
      }

      const startDate = decisionPreview.computedDates.startDate;
      const endDate = decisionPreview.computedDates.endDate;
      const nextRenewalDate = decisionPreview.computedDates.nextRenewalDate;

      membership = new MemberMembership({
        gymId,
        memberId: request.memberId,
        membershipTemplateId: request.targetMembershipTemplateId,
        status: decisionPreview.action === 'queue_after_current' ? 'pending_approval' : 'active',
        startDate,
        endDate,
        nextRenewalDate,
        activatedAt: decisionPreview.action === 'queue_after_current' ? null : new Date(),
        approvedBy: adminId,
        paymentStatus: decisionPreview.paymentSummary.paymentStatusDecision === 'waived' ? 'waived' : 'paid',
        paymentMethod: request.paymentMode,
        paymentReference: request.paymentReference || '',
        notes: request.memberNote,
        entitlementsSnapshot: {
          ...template?.includedFeatures,
          personalTraining: request.requestedAddOns?.personalTraining || false,
          dietPlan: request.requestedAddOns?.dietPlan || false,
        },
        isActiveBaseMembership: decisionPreview.action !== 'queue_after_current',
      });

      await membership.save();
      if (
        membership.paymentStatus === 'paid' &&
        decisionPreview.paymentSummary.amountPaid <= 0 &&
        decisionPreview.paymentSummary.expectedAmount > 0
      ) {
        await this.createMembershipPaymentEntry(
          membership,
          decisionPreview.paymentSummary.expectedAmount - decisionPreview.paymentSummary.creditedAmount,
          adminId,
          'Auto-recorded from membership approval.',
        );
      }
      await PaymentEntry.updateMany(
        {
          gymId,
          memberId: request.memberId,
          membershipRequestId: request._id,
          membershipId: null,
        },
        {
          $set: {
            membershipId: membership._id,
          },
        },
      );
      if (membership.paymentStatus === 'paid') {
        await this.ensureReceiptForMembership(
          membership,
          adminId,
          decisionPreview.paymentSummary.expectedAmount,
        );
      }

      await this.logAudit(gymId, request.memberId, 'member_membership', membership._id, 'created', adminId, {
        templateName: template?.name,
        requestType: request.requestType,
        decisionPreview,
      });

      if (decisionPreview.action !== 'queue_after_current') {
        await this.logAudit(gymId, request.memberId, 'member_membership', membership._id, 'activated', adminId, {
          templateName: template?.name,
        });
      } else {
        await this.logAudit(gymId, request.memberId, 'member_membership', membership._id, 'queued', adminId, {
          templateName: template?.name,
          queueStartDate: startDate,
        });
      }

      if (request.requestType === 'upgrade') {
        await this.logAudit(gymId, request.memberId, 'member_membership', membership._id, 'upgraded', adminId, {
          fromTemplate: currentActive?.membershipTemplateId,
          toTemplate: template?._id,
        });
      } else if (request.requestType === 'downgrade') {
        await this.logAudit(gymId, request.memberId, 'member_membership', membership._id, 'downgraded', adminId, {
          fromTemplate: currentActive?.membershipTemplateId,
          toTemplate: template?._id,
        });
      } else if (request.requestType === 'renewal') {
        await this.logAudit(gymId, request.memberId, 'member_membership', membership._id, 'renewed', adminId, {
          templateName: template?.name,
        });
      }
    } else if (request.requestType === 'add_on') {
      request.status = 'approved';
      request.decidedAt = new Date();
      request.decidedBy = adminId;
      request.adminNote = options.adminNote || '';
      await request.save();
      const currentActive = await MemberMembership.findOne({
        gymId,
        memberId: request.memberId,
        isActiveBaseMembership: true,
      });

      if (!currentActive) {
        throw new Error('Active membership not found for add-on request.');
      }

      if (request.requestedAddOns?.personalTraining) {
        currentActive.entitlementsSnapshot.personalTraining = true;
      }
      if (request.requestedAddOns?.dietPlan) {
        currentActive.entitlementsSnapshot.dietPlan = true;
      }

      await currentActive.save();

      await this.logAudit(gymId, request.memberId, 'member_membership', currentActive._id, 'entitlements_updated', adminId, {
        addedAddOns: request.requestedAddOns,
      });
    } else if (request.requestType === 'freeze') {
      request.status = 'approved';
      request.decidedAt = new Date();
      request.decidedBy = adminId;
      request.adminNote = options.adminNote || '';
      await request.save();
      const currentActive = await MemberMembership.findOne({
        gymId,
        memberId: request.memberId,
        isActiveBaseMembership: true,
      }).populate('membershipTemplateId');

      if (!currentActive) {
        throw new Error('Active membership not found for freeze request.');
      }

      const template = currentActive.membershipTemplateId;
      const templateRules = this.normalizeTemplateRules(template);
      const freezeDays = Number(options.freezeDays || templateRules.freezeLimitDays || 0);

      currentActive.isFrozen = true;
      currentActive.frozenAt = new Date();
      currentActive.frozenUntil = this.addDays(new Date(), freezeDays);
      currentActive.status = 'frozen';
      currentActive.endDate = this.addDays(currentActive.endDate, freezeDays);
      currentActive.nextRenewalDate = this.computeNextRenewalDate(
        currentActive.endDate,
        template,
      );

      await currentActive.save();

      await this.logAudit(gymId, request.memberId, 'member_membership', currentActive._id, 'frozen', adminId, {
        freezeDays,
        frozenUntil: currentActive.frozenUntil,
      });
    } else if (request.requestType === 'cancel') {
      request.status = 'approved';
      request.decidedAt = new Date();
      request.decidedBy = adminId;
      request.adminNote = options.adminNote || '';
      await request.save();
      const currentActive = await MemberMembership.findOne({
        gymId,
        memberId: request.memberId,
        isActiveBaseMembership: true,
      });

      if (!currentActive) {
        throw new Error('Active membership not found for cancel request.');
      }

      currentActive.isActiveBaseMembership = false;
      currentActive.status = 'canceled';
      await currentActive.save();

      await this.logAudit(gymId, request.memberId, 'member_membership', currentActive._id, 'canceled', adminId, {
        reason: request.memberNote,
      });
    }

    await this.logAudit(gymId, request.memberId, 'membership_change_request', request._id, 'request_approved', adminId, {
      requestType: request.requestType,
      overrideReason: options.overrideReason || '',
      overrideMode: options.overrideMode || null,
    });

    return { request, membership };
  }

  static async adjustMembershipDates(gymId, membershipId, adminId, adjustment) {
    const membership = await MemberMembership.findOne({ _id: membershipId, gymId })
      .populate('membershipTemplateId');

    if (!membership) {
      throw new Error('Membership not found');
    }

    const changeType = adjustment.changeType || 'manual_date_edit';
    const oldValues = {
      startDate: membership.startDate,
      endDate: membership.endDate,
      nextRenewalDate: membership.nextRenewalDate,
    };

    if (changeType === 'freeze_extension') {
      const extensionDays = Number(adjustment.extensionDays || 0);
      membership.endDate = this.addDays(membership.endDate, extensionDays);
    } else {
      membership.startDate = this.asDate(adjustment.startDate, membership.startDate);
      membership.endDate = this.asDate(adjustment.endDate, membership.endDate);
    }

    membership.nextRenewalDate = this.computeNextRenewalDate(
      membership.endDate,
      membership.membershipTemplateId,
      adjustment.nextRenewalDate,
    );

    if (!membership.startDate || !membership.endDate || membership.endDate < membership.startDate) {
      throw new Error('Invalid membership dates');
    }

    await membership.save();

    await this.logAudit(gymId, membership.memberId, 'member_membership', membership._id, 'owner_adjusted', adminId, {
      changeType,
      reason: adjustment.reason || '',
      oldValues,
      newValues: {
        startDate: membership.startDate,
        endDate: membership.endDate,
        nextRenewalDate: membership.nextRenewalDate,
      },
      acknowledgedWarnings: adjustment.acknowledgedWarnings || [],
    });

    return membership;
  }

  static async rejectRequest(requestId, gymId, adminId, reason) {
    const request = await MembershipChangeRequest.findOne({ _id: requestId, gymId });

    if (!request) {
      throw new Error('Request not found');
    }

    if (!['submitted', 'awaiting_payment', 'payment_under_review'].includes(request.status)) {
      throw new Error('Request has already been processed');
    }

    request.status = 'rejected';
    request.decidedAt = new Date();
    request.decidedBy = adminId;
    request.adminNote = reason || 'Request rejected';

    await request.save();

    await this.logAudit(gymId, request.memberId, 'membership_change_request', request._id, 'request_rejected', adminId, {
      reason: request.adminNote,
    });

    return request;
  }

  static async getChangeRequests(gymId, options = {}) {
    const query = { gymId };
    
    if (options.status) query.status = options.status;
    if (options.memberId) query.memberId = options.memberId;
    if (options.requestType) query.requestType = options.requestType;
    
    return MembershipChangeRequest.find(query)
      .populate('memberId', 'name email phone')
      .populate('targetMembershipTemplateId')
      .populate('currentMembershipId')
      .sort({ requestedAt: -1 })
      .limit(options.limit || 100);
  }

  static async getChangeRequestById(gymId, requestId) {
    return MembershipChangeRequest.findOne({ _id: requestId, gymId })
      .populate('memberId', 'name email phone')
      .populate('targetMembershipTemplateId')
      .populate('currentMembershipId');
  }

  static async getMemberChangeRequests(memberId, options = {}) {
    const query = { memberId };
    
    if (options.status) query.status = options.status;
    
    return MembershipChangeRequest.find(query)
      .populate('targetMembershipTemplateId')
      .sort({ requestedAt: -1 })
      .limit(options.limit || 50);
  }

  static async unfreezeMembership(gymId, membershipId, adminId) {
    const membership = await MemberMembership.findOne({ _id: membershipId, gymId });
    
    if (!membership) {
      throw new Error('Membership not found');
    }
    
    if (!membership.isFrozen) {
      throw new Error('Membership is not frozen');
    }
    
    membership.isFrozen = false;
    membership.frozenUntil = null;
    membership.status = this.computeStatus(membership);
    
    await membership.save();
    
    await this.logAudit(gymId, membership.memberId, 'member_membership', membership._id, 'unfrozen', adminId, {});
    
    return membership;
  }

  static async cancelMembership(gymId, membershipId, adminId, reason) {
    const membership = await MemberMembership.findOne({ _id: membershipId, gymId });
    
    if (!membership) {
      throw new Error('Membership not found');
    }
    
    membership.isActiveBaseMembership = false;
    membership.status = 'canceled';
    membership.notes = membership.notes + (reason ? `\nCancellation: ${reason}` : '');
    
    await membership.save();
    
    await this.logAudit(gymId, membership.memberId, 'member_membership', membership._id, 'canceled', adminId, {
      reason,
    });
    
    return membership;
  }

  static async getAuditLogs(gymId, memberId, options = {}) {
    const query = { gymId };
    if (memberId) query.memberId = memberId;
    
    return MembershipAuditLog.find(query)
      .populate('performedBy', 'name email')
      .sort({ createdAt: -1 })
      .limit(options.limit || 100);
  }

  static async logAudit(gymId, memberId, entityType, entityId, action, performedBy, payload = {}, options = {}) {
    const log = new MembershipAuditLog({
      gymId,
      memberId: memberId || null,
      entityType,
      entityId,
      action,
      performedBy,
      payload,
    });
    
    if (options.session) {
      await log.save({ session: options.session });
    } else {
      await log.save();
    }
    
    return log;
  }

  static async getMemberEntitlements(gymId, memberId) {
    const membership = await this.getActiveMembership(gymId, memberId);
    
    if (!membership) {
      return null;
    }
    
    return {
      membership: {
        id: membership._id,
        status: membership.status,
        startDate: membership.startDate,
        endDate: membership.endDate,
        templateName: membership.membershipTemplateId?.name,
      },
      entitlements: membership.entitlementsSnapshot,
    };
  }

  static async getAvailablePlans(gymId, memberId) {
    const templates = await MembershipTemplate.find({
      gymId,
      active: true,
      visibleToMembers: true,
    }).sort({ sortOrder: 1, upgradeRank: 1 });
    
    const currentMembership = await this.getActiveMembership(gymId, memberId);
    
    const plans = templates.map(template => {
      const isCurrent = currentMembership?.membershipTemplateId?._id?.toString() === template._id.toString();
      const canUpgrade = template.rules?.canUpgrade && 
        currentMembership && 
        template.upgradeRank > (currentMembership.membershipTemplateId?.upgradeRank || 0);
      const canDowngrade = template.rules?.canDowngrade && 
        currentMembership && 
        template.upgradeRank < (currentMembership.membershipTemplateId?.upgradeRank || 0);
      
      return {
        id: template._id,
        name: template.name,
        shortDescription: template.shortDescription,
        fullDescription: template.fullDescription,
        durationDays: template.durationDays,
        price: template.price,
        joiningFee: template.joiningFee,
        category: template.category,
        includedFeatures: template.includedFeatures,
        availableAddOns: template.availableAddOns,
        rules: template.rules,
        upgradeRank: template.upgradeRank,
        isCurrent,
        canUpgrade,
        canDowngrade,
        canRenew: template.category !== 'trial',
      };
    });
    
    return {
      currentMembership: currentMembership ? {
        id: currentMembership._id,
        status: currentMembership.status,
        templateName: currentMembership.membershipTemplateId?.name,
        startDate: currentMembership.startDate,
        endDate: currentMembership.endDate,
        entitlements: currentMembership.entitlementsSnapshot,
      } : null,
      plans,
    };
  }
}

module.exports = MembershipService;
