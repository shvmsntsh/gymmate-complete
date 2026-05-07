<template>
  <AdminShell
    :is-dark="isDark"
    title="Membership"
    :eyebrow="membershipEyebrow"
    :description="membershipDescription"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <v-tabs v-model="activeTab" color="primary" class="mb-6">
      <v-tab value="memberships">Members</v-tab>
      <v-tab value="plans">Plans</v-tab>
      <v-tab v-if="hasLegacyRequests" value="requests">Requests</v-tab>
    </v-tabs>

    <StateBlock
      v-if="error"
      title="Error"
      :copy="error"
      icon="mdi-alert-circle-outline"
      tone="error"
      class="mb-6"
    />

    <v-window v-model="activeTab">
      <v-window-item value="plans">
        <PlansSection
          :templates="templates"
          :loading="loadingTemplates"
          @create="createTemplate"
          @update="updateTemplate"
          @delete="deleteTemplate"
        />
      </v-window-item>

      <v-window-item value="memberships">
        <MembershipsSection
          :memberships="memberships"
          :loading="loadingMemberships"
          :members="members"
          :assignable-member-count="assignableMembers.length"
          @unfreeze="unfreezeMembership"
          @cancel="cancelMembership"
          @assign="openAssignDialog"
          @view="openMembershipReview"
          @receipt="openReceiptLink"
        />
      </v-window-item>

      <v-window-item v-if="hasLegacyRequests" value="requests">
        <RequestsSection
          :requests="requests"
          :loading="loadingRequests"
          @verify-payment="verifyPayment"
          @approve="openRequestApproval"
          @reject="openRequestReject"
          @view="openRequestDetail"
        />
      </v-window-item>
    </v-window>

    <v-dialog v-model="requestDialog" max-width="700" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <span class="text-h6">Request Details</span>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="requestDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text v-if="selectedRequest" class="pa-4">
          <RequestDetailCard
            :request="selectedRequest"
            :current-membership="selectedMemberMembership"
            :request-payments="selectedRequestPayments"
            :membership-payments="selectedMembershipPayments"
            :decision-preview="selectedDecisionPreview"
          />
        </v-card-text>
        <v-divider />
        <v-card-actions class="pa-4">
          <v-spacer />
          <v-btn variant="text" @click="requestDialog = false">Close</v-btn>
          <v-btn
            v-if="selectedRequest && canVerifyPayment"
            color="info"
            variant="tonal"
            :loading="processing"
            @click="handleVerifyPayment"
          >
            Verify Payment
          </v-btn>
          <v-btn
            v-if="selectedRequest && canApprove"
            color="primary"
            :loading="processing"
            @click="openApproveDialog"
          >
            Approve
          </v-btn>
          <v-btn
            v-if="selectedRequest && canReject"
            color="error"
            variant="outlined"
            :loading="processing"
            @click="openRejectDialog"
          >
            Reject
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="approveDialog" max-width="680" scrollable>
      <v-card rounded="xl">
        <v-card-title class="text-h6 pa-4">Approve Request Safely</v-card-title>
        <v-card-text class="pa-4 pt-0">
          <v-alert
            v-if="selectedDecisionPreview?.warnings?.length"
            type="warning"
            variant="tonal"
            class="mb-4"
          >
            {{ selectedDecisionPreview.warnings.map((item) => item.message).join(" | ") }}
          </v-alert>
          <v-alert
            v-if="selectedDecisionPreview?.blockers?.length"
            type="error"
            variant="tonal"
            class="mb-4"
          >
            {{ selectedDecisionPreview.blockers.map((item) => item.message).join(" | ") }}
          </v-alert>

          <div class="approval-summary admin-surface admin-surface--muted mb-4">
            <div class="text-overline text-medium-emphasis">Safe Approval Summary</div>
            <div class="text-body-1 font-weight-medium">
              {{ approvalSummaryTitle }}
            </div>
            <div class="text-body-2 text-medium-emphasis">
              {{ approvalSummaryCopy }}
            </div>
          </div>

          <v-row>
            <v-col cols="12" md="6">
              <v-text-field
                :model-value="formatDate(selectedDecisionPreview?.computedDates?.startDate)"
                label="Effective Date"
                variant="outlined"
                readonly
                hint="Safe default is auto-computed. No manual date needed."
                persistent-hint
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                :model-value="approvalModeLabel"
                label="Approval Mode"
                variant="outlined"
                readonly
              />
            </v-col>
          </v-row>

          <v-switch
            v-if="canUseOwnerOverride"
            v-model="approveForm.useOwnerOverride"
            color="primary"
            inset
            label="Need owner override?"
            class="mb-2"
          />

          <v-row v-if="approveForm.useOwnerOverride">
            <v-col cols="12" md="6">
              <v-select
                v-model="approveForm.overrideMode"
                label="Owner Override Mode"
                variant="outlined"
                :items="approveModeOptions"
              />
            </v-col>
          </v-row>

          <v-row v-if="approveForm.useOwnerOverride">
            <v-col cols="12" md="6">
              <v-text-field
                v-model="approveForm.manualStartDate"
                label="Manual Start Date (DD/MM/YYYY)"
                variant="outlined"
                placeholder="DD/MM/YYYY"
              />
            </v-col>
            <v-col cols="12" md="6">
              <v-text-field
                v-model="approveForm.manualEndDate"
                label="Manual End Date (DD/MM/YYYY)"
                variant="outlined"
                placeholder="DD/MM/YYYY"
              />
            </v-col>
          </v-row>

          <v-textarea
            v-model="approveForm.overrideReason"
            :label="approveForm.useOwnerOverride ? 'Override Reason' : 'Notes (optional)'"
            variant="outlined"
            rows="3"
            :hint="approveForm.useOwnerOverride ? 'Required for owner override.' : 'No override reason needed for safe approval.'"
            :persistent-hint="approveForm.useOwnerOverride"
          />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="approveDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="processing" @click="confirmApprove">Approve</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="membershipReviewDialog" max-width="820" scrollable>
      <v-card rounded="xl">
        <v-card-title class="d-flex align-center pa-4">
          <div>
            <div class="text-h6">Membership Review</div>
            <div class="text-body-2 text-medium-emphasis">
              {{ selectedMembershipReviewMember?.name || "Member" }}
            </div>
          </div>
          <v-spacer />
          <v-btn icon="mdi-close" variant="text" @click="membershipReviewDialog = false" />
        </v-card-title>
        <v-divider />
        <v-card-text class="pa-4">
          <v-progress-linear
            v-if="loadingMembershipReview"
            color="primary"
            indeterminate
            rounded
            class="mb-4"
          />

          <v-alert
            v-else-if="membershipReviewError"
            type="error"
            variant="tonal"
            class="mb-4"
          >
            {{ membershipReviewError }}
          </v-alert>

          <div v-else-if="selectedMembershipReview.length" class="d-flex flex-column ga-4">
            <v-card
              v-for="membership in selectedMembershipReview"
              :key="membership.id"
              variant="tonal"
              rounded="lg"
            >
              <v-card-text class="pa-4">
                <div class="d-flex justify-space-between align-start mb-3">
                  <div>
                    <div class="text-body-1 font-weight-medium">
                      {{ membership.templateName || "No plan" }}
                    </div>
                    <div class="text-caption text-medium-emphasis">
                      {{ membership.paymentStatus || "unknown" }} payment status
                    </div>
                  </div>
                  <div class="text-right">
                    <div class="text-caption text-medium-emphasis">Membership Status</div>
                    <div class="text-body-2">{{ membership.renewalState || membership.status }}</div>
                  </div>
                </div>

                <div class="review-grid mb-4">
                  <div v-if="membership.startDate">
                    <div class="text-caption text-medium-emphasis">Start</div>
                    <div class="text-body-2">{{ formatDate(membership.startDate) }}</div>
                  </div>
                  <div v-if="membership.endDate">
                    <div class="text-caption text-medium-emphasis">End</div>
                    <div class="text-body-2">{{ formatDate(membership.endDate) }}</div>
                  </div>
                  <div v-if="membership.nextRenewalDate">
                    <div class="text-caption text-medium-emphasis">Next Renewal</div>
                    <div class="text-body-2">{{ formatDate(membership.nextRenewalDate) }}</div>
                  </div>
                  <div v-if="membership.paymentReference">
                    <div class="text-caption text-medium-emphasis">Payment Ref</div>
                    <div class="text-body-2">{{ membership.paymentReference }}</div>
                  </div>
                </div>

                <div>
                  <div class="text-overline text-medium-emphasis">Payment History</div>
                  <v-list
                    v-if="membership.paymentHistory?.length"
                    lines="two"
                    density="comfortable"
                    class="bg-transparent px-0"
                  >
                    <v-list-item
                      v-for="payment in membership.paymentHistory"
                      :key="payment.id"
                      class="px-0"
                    >
                      <template #prepend>
                        <v-avatar color="primary" variant="tonal" size="34">
                          <span class="text-caption">₹</span>
                        </v-avatar>
                      </template>
                      <v-list-item-title>
                        ₹{{ payment.amount }} via {{ formatPaymentMode(payment.mode) }}
                      </v-list-item-title>
                      <v-list-item-subtitle>
                        {{ formatDateTime(payment.recordedAt) }}
                        <span v-if="payment.reference"> • Ref {{ payment.reference }}</span>
                        <span v-if="payment.recordedBy?.name"> • By {{ payment.recordedBy.name }}</span>
                      </v-list-item-subtitle>
                      <template v-if="payment.note" #append>
                        <div class="text-caption text-medium-emphasis review-note">
                          {{ payment.note }}
                        </div>
                      </template>
                    </v-list-item>
                  </v-list>
                  <v-alert v-else type="info" variant="tonal" density="comfortable" class="mt-2">
                    No recorded payments for this membership yet.
                  </v-alert>
                </div>
                <div class="d-flex justify-end mt-4 ga-2 flex-wrap">
                  <v-btn
                    v-if="membership.paymentStatus === 'paid'"
                    color="secondary"
                    variant="tonal"
                    size="small"
                    @click="openReceiptLink(membership)"
                  >
                    Receipt
                  </v-btn>
                  <v-btn
                    v-if="membership.status !== 'canceled' && membership.status !== 'rejected'"
                    color="primary"
                    variant="text"
                    size="small"
                    @click="openPlanChangeDialog(membership)"
                  >
                    Change / Renew Plan
                  </v-btn>
                  <v-btn
                    color="primary"
                    variant="tonal"
                    size="small"
                    @click="openAdjustDialog(membership)"
                  >
                    Adjust Dates
                  </v-btn>
                </div>
              </v-card-text>
            </v-card>
          </div>

          <v-alert v-else type="info" variant="tonal">
            No membership history found for this member.
          </v-alert>
        </v-card-text>
      </v-card>
    </v-dialog>

    <v-dialog v-model="adjustDialog" max-width="640">
      <v-card rounded="xl">
        <v-card-title class="text-h6 pa-4">Manual Membership Adjustment</v-card-title>
        <v-card-text class="pa-4 pt-0">
          <v-select
            v-model="adjustForm.changeType"
            label="Change Type"
            variant="outlined"
            class="mb-4"
            :items="adjustTypeOptions"
          />
          <v-text-field
            v-if="adjustForm.changeType === 'freeze_extension'"
            v-model.number="adjustForm.extensionDays"
            label="Extension Days"
            type="number"
            variant="outlined"
            class="mb-4"
          />
          <v-row v-else>
            <v-col cols="12" md="4">
              <v-text-field
                v-model="adjustForm.startDate"
                label="Start Date (DD/MM/YYYY)"
                variant="outlined"
                placeholder="DD/MM/YYYY"
              />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field
                v-model="adjustForm.endDate"
                label="End Date (DD/MM/YYYY)"
                variant="outlined"
                placeholder="DD/MM/YYYY"
              />
            </v-col>
            <v-col cols="12" md="4">
              <v-text-field
                v-model="adjustForm.nextRenewalDate"
                label="Next Renewal (DD/MM/YYYY)"
                variant="outlined"
                placeholder="DD/MM/YYYY"
              />
            </v-col>
          </v-row>
          <div class="approval-summary admin-surface admin-surface--muted mb-4">
            <div class="text-overline text-medium-emphasis">Change Summary</div>
            <div class="text-body-1 font-weight-medium">{{ adjustSummaryTitle }}</div>
            <div class="text-body-2 text-medium-emphasis">{{ adjustSummaryCopy }}</div>
          </div>
          <v-textarea
            v-model="adjustForm.reason"
            label="Reason"
            variant="outlined"
            rows="3"
          />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="adjustDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="processing" @click="confirmAdjustMembership">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="rejectDialog" max-width="500">
      <v-card rounded="xl">
        <v-card-title class="text-h6 pa-4">Reject Request</v-card-title>
        <v-card-text class="pa-4 pt-0">
          <v-textarea
            v-model="rejectReason"
            label="Rejection Reason (required)"
            variant="outlined"
            rows="3"
            :rules="[v => !!v || 'Rejection reason is required']"
          />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="rejectDialog = false">Cancel</v-btn>
          <v-btn color="error" :loading="processing" @click="confirmReject">Reject</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-dialog v-model="assignDialog" max-width="600">
      <v-card rounded="xl">
        <v-card-title class="text-h6 pa-4">{{ assignDialogTitle }}</v-card-title>
        <v-card-text class="pa-4">
          <div class="approval-summary admin-surface admin-surface--muted mb-4">
            <div class="text-overline text-medium-emphasis">Desk Summary</div>
            <div class="text-body-1 font-weight-medium">{{ assignSummaryTitle }}</div>
            <div class="text-body-2 text-medium-emphasis">{{ assignSummaryCopy }}</div>
          </div>
          <v-autocomplete
            v-if="!assignForm.memberLocked"
            v-model="assignForm.memberId"
            :items="memberOptions"
            label="Member"
            variant="outlined"
            class="mb-4"
          />
          <v-text-field
            v-else
            :model-value="selectedAssignMemberLabel"
            label="Member"
            variant="outlined"
            class="mb-4"
            readonly
          />
          <v-select
            v-model="assignForm.templateId"
            :items="templateOptions"
            label="Plan"
            variant="outlined"
            class="mb-4"
          />
          <v-alert
            v-if="assignForm.flowType === 'manual_change'"
            type="info"
            variant="tonal"
            density="comfortable"
            class="mb-4"
          >
            Same plan means renewal. Different plan means plan change. Safe default queues after the current plan. Turn on immediate replace only when you want the new plan to start now.
          </v-alert>
          <v-select
            v-model="assignForm.paymentStatus"
            :items="paymentStatusOptions"
            label="Payment Status"
            variant="outlined"
            class="mb-4"
          />
          <v-select
            v-model="assignForm.paymentMethod"
            :items="paymentMethodOptions"
            label="Payment Method"
            variant="outlined"
            class="mb-4"
          />
          <v-text-field
            v-model="assignForm.paymentReference"
            label="Payment Reference"
            variant="outlined"
            placeholder="Cash slip / UPI ref"
            class="mb-4"
          />
          <v-text-field
            v-model.number="assignForm.paymentAmount"
            label="Amount To Record (optional)"
            type="number"
            min="0"
            variant="outlined"
            placeholder="Leave blank to use system amount"
            class="mb-4"
          />
          <v-switch
            v-if="assignForm.flowType === 'manual_change'"
            v-model="assignForm.startImmediately"
            color="primary"
            inset
            label="Start new plan immediately"
            class="mb-2"
          />
          <v-textarea
            v-if="assignForm.flowType === 'manual_change' && assignForm.startImmediately"
            v-model="assignForm.overrideReason"
            label="Reason For Immediate Replace"
            variant="outlined"
            rows="2"
            class="mb-4"
          />
          <v-textarea
            v-model="assignForm.notes"
            label="Notes"
            variant="outlined"
            rows="2"
          />
        </v-card-text>
        <v-card-actions class="pa-4 pt-0">
          <v-spacer />
          <v-btn variant="text" @click="assignDialog = false">Cancel</v-btn>
          <v-btn color="primary" :loading="processing" @click="confirmAssign">Assign</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" :timeout="3000">
      {{ snackbar.message }}
    </v-snackbar>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { formatDateUs, formatDateTimeUs } from "../lib/date";
import { apiFetch, clearAdminSession, getAdminRole } from "../lib/api";
import PlansSection from "./membership/PlansSection.vue";
import MembershipsSection from "./membership/MembershipsSection.vue";
import RequestsSection from "./membership/RequestsSection.vue";
import RequestDetailCard from "./membership/RequestDetailCard.vue";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();

const activeTab = ref("memberships");
const error = ref("");
const snackbar = ref({ show: false, message: "", color: "success" });

const templates = ref([]);
const memberships = ref([]);
const members = ref([]);
const requests = ref([]);
const hasLegacyRequests = computed(() => requests.value.length > 0);
const membershipEyebrow = computed(() =>
  hasLegacyRequests.value ? "Plans, Members, Requests" : "Plans and Members",
);
const membershipDescription = computed(() =>
  hasLegacyRequests.value
    ? "Manage member memberships, plan setup, and any existing request queue."
    : "Create plans, assign them to members, and record payment status.",
);

const loadingTemplates = ref(false);
const loadingMemberships = ref(false);
const loadingRequests = ref(false);
const processing = ref(false);

const requestDialog = ref(false);
const selectedRequest = ref(null);
const selectedMemberMembership = ref(null);
const selectedRequestPayments = ref([]);
const selectedMembershipPayments = ref([]);
const selectedDecisionPreview = ref(null);
const approveDialog = ref(false);
const approveForm = ref({
  useOwnerOverride: false,
  overrideMode: "default",
  overrideReason: "",
  manualStartDate: "",
  manualEndDate: "",
});

const membershipReviewDialog = ref(false);
const loadingMembershipReview = ref(false);
const membershipReviewError = ref("");
const selectedMembershipReview = ref([]);
const selectedMembershipReviewMember = ref(null);
const selectedMembershipToAdjust = ref(null);
const adjustDialog = ref(false);
const adjustForm = ref({
  changeType: "freeze_extension",
  extensionDays: 0,
  startDate: "",
  endDate: "",
  nextRenewalDate: "",
  reason: "",
});

const rejectDialog = ref(false);
const rejectReason = ref("");

const assignDialog = ref(false);
const assignForm = ref({
  memberId: null,
  templateId: null,
  paymentStatus: "unpaid",
  paymentMethod: "cash",
  paymentReference: "",
  paymentAmount: null,
  notes: "",
  flowType: "new_assign",
  memberLocked: false,
  currentMembershipId: null,
  startImmediately: false,
  overrideReason: "",
});

const activeMembershipByMemberId = computed(() => {
  const map = new Map();
  memberships.value.forEach((membership) => {
    if (
      membership?.member?.id &&
      membership.isActiveBaseMembership &&
      !["canceled", "rejected", "expired"].includes(membership.status)
    ) {
      map.set(membership.member.id, membership);
    }
  });
  return map;
});

const assignableMembers = computed(() =>
  members.value.filter((member) => !activeMembershipByMemberId.value.has(member.id)),
);

const memberOptions = computed(() =>
  assignableMembers.value.map(m => ({ title: `${m.name} (${m.email})`, value: m.id }))
);

const templateOptions = computed(() =>
  templates.value.map(t => ({ title: `${t.name} - ₹${t.price}`, value: t.id }))
);

const paymentStatusOptions = [
  { title: "Unpaid", value: "unpaid" },
  { title: "Paid", value: "paid" },
];

const paymentMethodOptions = [
  { title: "Cash", value: "cash" },
  { title: "UPI", value: "upi" },
  { title: "Card", value: "card" },
  { title: "Online", value: "online" },
  { title: "Manual", value: "manual" },
  { title: "Waived", value: "waived" },
];
const paymentMethodValues = paymentMethodOptions.map((item) => item.value);
const publicBasePath = String(import.meta.env.BASE_URL || "/").replace(/\/$/, "");

const approveModeOptions = [
  { title: "Start Now", value: "force_immediate" },
  { title: "Queue After Current Plan", value: "force_queue" },
];

const adjustTypeOptions = [
  { title: "Extend Validity", value: "freeze_extension" },
  { title: "Manual Date Edit", value: "manual_date_edit" },
];

const canVerifyPayment = computed(() => {
  if (!selectedRequest.value) return false;
  return ["submitted", "awaiting_payment"].includes(selectedRequest.value.status);
});

const canApprove = computed(() => {
  if (!selectedRequest.value) return false;
  if (selectedDecisionPreview.value?.blockers?.length) return false;
  if (selectedRequest.value.status === "payment_under_review") return true;
  return ["submitted", "awaiting_payment"].includes(selectedRequest.value.status) &&
    selectedRequest.value.paymentMode === "waived";
});

const canReject = computed(() =>
  selectedRequest.value &&
  ["submitted", "awaiting_payment", "payment_under_review"].includes(selectedRequest.value.status),
);
const canUseOwnerOverride = computed(() => getAdminRole() === "owner" && !selectedDecisionPreview.value?.blockers?.length);
const approvalModeLabel = computed(() =>
  approveForm.value.useOwnerOverride
    ? approveModeOptions.find((item) => item.value === approveForm.value.overrideMode)?.title || "Owner Override"
    : "Default Safe Decision",
);
const approvalSummaryTitle = computed(() => {
  const action = selectedDecisionPreview.value?.action;
  if (action === "queue_after_current") return "Keep current plan until it ends. Start next plan after that.";
  if (action === "activate_now") return "Activate requested plan now.";
  if (action === "freeze_extend") return "Extend current plan by freeze days.";
  return "Use safe computed decision.";
});
const approvalSummaryCopy = computed(() => {
  const effectiveDate = formatDate(selectedDecisionPreview.value?.computedDates?.startDate);
  const endDate = formatDate(selectedDecisionPreview.value?.computedDates?.endDate);
  if (selectedDecisionPreview.value?.action === "queue_after_current") {
    return `New plan will start on ${effectiveDate} and run until ${endDate}.`;
  }
  if (selectedDecisionPreview.value?.action === "activate_now") {
    return `Requested plan will start on ${effectiveDate}.`;
  }
  return `Computed effective date: ${effectiveDate}.`;
});
const assignSummaryTitle = computed(() => {
  const template = templates.value.find((item) => item.id === assignForm.value.templateId);
  if (!template) return assignForm.value.flowType === "manual_change" ? "Choose the next plan." : "Choose member and plan.";
  if (assignForm.value.flowType === "manual_change") {
    return `Set up ${template.name} for the current member.`;
  }
  return `Assign ${template.name}.`;
});
const assignSummaryCopy = computed(() => {
  const template = templates.value.find((item) => item.id === assignForm.value.templateId);
  const customAmount =
    assignForm.value.paymentAmount !== null &&
    assignForm.value.paymentAmount !== "" &&
    Number.isFinite(Number(assignForm.value.paymentAmount))
      ? ` Custom amount: ₹${Number(assignForm.value.paymentAmount).toFixed(2)}.`
      : "";
  const payment =
    assignForm.value.paymentStatus === "paid"
      ? "Payment will be recorded now."
      : "Membership will stay unpaid until payment is collected.";
  if (!template) {
    return assignForm.value.flowType === "manual_change"
      ? "Pick the same plan to renew or a different plan to change. Safe default queues after the current plan."
      : "Use this only for members without a current plan.";
  }
  if (assignForm.value.flowType === "manual_change") {
    return assignForm.value.startImmediately
      ? `${template.durationDays || 0} day plan. New plan will replace the current one now.${customAmount} ${payment}`
      : `${template.durationDays || 0} day plan. Safe default queues it after the current plan ends.${customAmount} ${payment}`;
  }
  return `${template.durationDays || 0} day plan for a member without an active plan.${customAmount} ${payment}`;
});
const assignDialogTitle = computed(() =>
  assignForm.value.flowType === "manual_change" ? "Change Or Renew Current Plan" : "Assign New Plan",
);
const selectedAssignMemberLabel = computed(() => {
  const member = members.value.find((item) => item.id === assignForm.value.memberId);
  if (!member) return "Selected member";
  return `${member.name} (${member.email})`;
});
const adjustSummaryTitle = computed(() => {
  if (adjustForm.value.changeType === "freeze_extension") {
    return `Extend validity by ${Number(adjustForm.value.extensionDays || 0)} days.`;
  }
  return "Manually update membership dates.";
});
const adjustSummaryCopy = computed(() => {
  if (adjustForm.value.changeType === "freeze_extension") {
    return "Use for holiday/freeze extension. End date moves forward and next renewal should stay valid.";
  }
  return `Start ${adjustForm.value.startDate || "--"} • End ${adjustForm.value.endDate || "--"} • Renewal ${adjustForm.value.nextRenewalDate || "--"}`;
});

function showSnackbar(message, color = "success") {
  snackbar.value = { show: true, message, color };
}

function receiptUrl(receipt) {
  const path = receipt?.publicPath || (receipt?.publicToken ? `/receipt/${receipt.publicToken}` : "");
  if (!path || typeof window === "undefined") return "";
  return `${window.location.origin}${publicBasePath}${path}`;
}

async function openReceiptLink(membership) {
  if (!membership?.id) {
    showSnackbar("Membership not found for receipt", "error");
    return;
  }

  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/memberships/${membership.id}/receipt`);
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || "Receipt not found");
    const url = receiptUrl(data.receipt);
    if (!url) throw new Error("Receipt link is unavailable");
    await navigator.clipboard?.writeText(url);
    window.open(url, "_blank", "noopener,noreferrer");
    showSnackbar("Receipt link copied and opened");
  } catch (err) {
    showSnackbar(err.message || "Could not open receipt", "error");
  } finally {
    processing.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

async function parseApiJson(response, fallbackMessage) {
  let payload = {};
  try {
    payload = await response.json();
  } catch {
    payload = {};
  }

  if (!response.ok) {
    throw new Error(payload.message || fallbackMessage);
  }

  return payload;
}

async function fetchAll() {
  error.value = "";
  loadingTemplates.value = true;
  loadingMemberships.value = true;
  loadingRequests.value = true;

  try {
    const [templatesRes, membershipsRes, requestsRes, membersRes] = await Promise.all([
      apiFetch("/api/owner/membership-templates"),
      apiFetch("/api/owner/member-memberships"),
      apiFetch("/api/owner/membership-requests-new"),
      apiFetch("/api/owner/member-workspace?limit=100"),
    ]);

    const endpointErrors = [];

    try {
      const templatesData = await parseApiJson(
        templatesRes,
        "Failed to load membership templates",
      );
      templates.value = templatesData.templates || [];
    } catch (err) {
      templates.value = [];
      endpointErrors.push(err.message);
    } finally {
      loadingTemplates.value = false;
    }

    try {
      const membershipsData = await parseApiJson(
        membershipsRes,
        "Failed to load member memberships",
      );
      memberships.value = membershipsData.memberships || [];
    } catch (err) {
      memberships.value = [];
      endpointErrors.push(err.message);
    } finally {
      loadingMemberships.value = false;
    }

    try {
      const requestsData = await parseApiJson(
        requestsRes,
        "Failed to load membership requests",
      );
      requests.value = requestsData.requests || [];
      if (!requests.value.length && activeTab.value === "requests") {
        activeTab.value = "memberships";
      }
    } catch (err) {
      requests.value = [];
      endpointErrors.push(err.message);
    } finally {
      loadingRequests.value = false;
    }

    try {
      const membersData = await parseApiJson(
        membersRes,
        "Failed to load member workspace",
      );
      members.value = membersData.members || [];
    } catch (err) {
      members.value = memberships.value
        .map((membership) => membership.member)
        .filter(Boolean);
      endpointErrors.push(err.message);
    }

    if (endpointErrors.length) {
      error.value = endpointErrors.join(" | ");
    }
  } catch (err) {
    error.value = err?.message || "Failed to load data";
  } finally {
    loadingTemplates.value = false;
    loadingMemberships.value = false;
    loadingRequests.value = false;
  }
}

async function createTemplate(data) {
  processing.value = true;
  try {
    const res = await apiFetch("/api/owner/membership-templates", {
      method: "POST",
      body: JSON.stringify(data),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Plan created successfully");
    await fetchAll();
  } catch (err) {
    error.value = err.message;
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function updateTemplate(id, data) {
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/membership-templates/${id}`, {
      method: "PATCH",
      body: JSON.stringify(data),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Plan updated successfully");
    await fetchAll();
  } catch (err) {
    error.value = err.message;
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function deleteTemplate(id) {
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/membership-templates/${id}`, {
      method: "DELETE",
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Plan archived successfully");
    await fetchAll();
  } catch (err) {
    error.value = err.message;
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function unfreezeMembership(membershipId) {
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/memberships/${membershipId}/unfreeze`, {
      method: "POST",
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Membership unfrozen");
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function cancelMembership(membershipId, reason) {
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/memberships/${membershipId}/cancel`, {
      method: "POST",
      body: JSON.stringify({ reason }),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Membership canceled");
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

function openAssignDialog() {
  if (assignableMembers.value.length === 0) {
    showSnackbar("Every visible member already has a current plan. Use Manage to renew or change an existing membership.", "info");
    return;
  }
  assignForm.value = {
    memberId: null,
    templateId: null,
    paymentStatus: "unpaid",
    paymentMethod: "cash",
    paymentReference: "",
    paymentAmount: null,
    notes: "",
    flowType: "new_assign",
    memberLocked: false,
    currentMembershipId: null,
    startImmediately: false,
    overrideReason: "",
  };
  assignDialog.value = true;
}

function openPlanChangeDialog(membership) {
  if (!membership?.member?.id) {
    showSnackbar("Member not found for plan change", "error");
    return;
  }
  assignForm.value = {
    memberId: membership.member.id,
    templateId: membership.membershipTemplateId?._id || membership.membershipTemplateId || null,
    paymentStatus: "unpaid",
    paymentMethod: "cash",
    paymentReference: "",
    paymentAmount: null,
    notes: "",
    flowType: "manual_change",
    memberLocked: true,
    currentMembershipId: membership.id,
    startImmediately: false,
    overrideReason: "",
  };
  assignDialog.value = true;
}

async function confirmAssign() {
  if (!assignForm.value.memberId || !assignForm.value.templateId) {
    showSnackbar("Please select member and plan", "error");
    return;
  }
  if (
    assignForm.value.flowType === "new_assign" &&
    activeMembershipByMemberId.value.has(assignForm.value.memberId)
  ) {
    showSnackbar("This member already has a current plan. Use Manage to renew or change it.", "error");
    return;
  }
  if (
    assignForm.value.flowType === "manual_change" &&
    assignForm.value.startImmediately &&
    !assignForm.value.overrideReason.trim()
  ) {
    showSnackbar("Reason is required when starting the new plan immediately.", "error");
    return;
  }
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/members/${assignForm.value.memberId}/memberships`, {
      method: "POST",
      body: JSON.stringify({
        templateId: assignForm.value.templateId,
        paymentStatus: assignForm.value.paymentStatus,
        paymentMethod: assignForm.value.paymentMethod,
        paymentReference: assignForm.value.paymentReference || undefined,
        paymentAmount:
          assignForm.value.paymentAmount !== null &&
          assignForm.value.paymentAmount !== "" &&
          Number.isFinite(Number(assignForm.value.paymentAmount))
            ? Number(assignForm.value.paymentAmount)
            : undefined,
        notes: assignForm.value.notes || undefined,
        flowType: assignForm.value.flowType,
        overrideMode:
          assignForm.value.flowType === "manual_change" && assignForm.value.startImmediately
            ? "force_immediate"
            : undefined,
        overrideReason:
          assignForm.value.flowType === "manual_change" && assignForm.value.startImmediately
            ? assignForm.value.overrideReason
            : undefined,
      }),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar(
      assignForm.value.flowType === "manual_change"
        ? "Plan change saved"
        : "Membership assigned successfully",
    );
    assignDialog.value = false;
    if (assignForm.value.flowType === "manual_change" && assignForm.value.memberId) {
      const refreshedMember = members.value.find((item) => item.id === assignForm.value.memberId);
      if (refreshedMember) {
        await openMembershipReview({ member: refreshedMember });
      }
    }
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function verifyPayment(requestId) {
  processing.value = true;
  try {
    const request = requests.value.find(item => item.id === requestId) || selectedRequest.value;
    const paymentMethod = paymentMethodValues.includes(request?.paymentMode) ? request.paymentMode : "cash";
    const res = await apiFetch(`/api/owner/membership-requests-new/${requestId}/verify-payment`, {
      method: "POST",
      body: JSON.stringify({ paymentMethod }),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Payment verified");
    if (selectedRequest.value?.id === requestId) {
      selectedRequest.value = dataRes.request || selectedRequest.value;
    }
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function handleVerifyPayment() {
  if (!selectedRequest.value?.id) return;
  await verifyPayment(selectedRequest.value.id);
}

async function approveRequest(requestId) {
  const payload = {
    acknowledgedWarnings: [
      ...(selectedDecisionPreview.value?.warnings || []).map((item) => item.code),
    ],
  };

  if (approveForm.value.useOwnerOverride) {
    payload.overrideMode = approveForm.value.overrideMode !== "default" ? approveForm.value.overrideMode : undefined;
    payload.overrideReason = approveForm.value.overrideReason || undefined;
    payload.manualStartDate = toIsoDateFromUs(approveForm.value.manualStartDate) || undefined;
    payload.manualEndDate = toIsoDateFromUs(approveForm.value.manualEndDate) || undefined;
    payload.effectiveDate = payload.manualStartDate;
  }

  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/membership-requests-new/${requestId}/approve`, {
      method: "POST",
      body: JSON.stringify(payload),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Request approved");
    approveDialog.value = false;
    requestDialog.value = false;
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

function openApproveDialog() {
  approveForm.value = {
    useOwnerOverride: false,
    overrideMode: "default",
    overrideReason: "",
    manualStartDate: formatDate(selectedDecisionPreview.value?.computedDates?.startDate),
    manualEndDate: formatDate(selectedDecisionPreview.value?.computedDates?.endDate),
  };
  approveDialog.value = true;
}

async function confirmApprove() {
  if (selectedDecisionPreview.value?.blockers?.length) {
    showSnackbar("Resolve blockers before approval", "error");
    return;
  }
  if (approveForm.value.useOwnerOverride && !approveForm.value.overrideReason.trim()) {
    showSnackbar("Override reason is required", "error");
    return;
  }
  await approveRequest(selectedRequest.value.id);
}

function openRejectDialog() {
  rejectReason.value = "";
  rejectDialog.value = true;
}

async function confirmReject() {
  if (!rejectReason.value.trim()) {
    showSnackbar("Rejection reason is required", "error");
    return;
  }
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/membership-requests-new/${selectedRequest.value.id}/reject`, {
      method: "POST",
      body: JSON.stringify({ reason: rejectReason.value }),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Request rejected");
    rejectDialog.value = false;
    requestDialog.value = false;
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function openRequestDetail(request) {
  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/membership-requests-new/${request.id}`);
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    selectedRequest.value = dataRes.request || request;
    selectedMemberMembership.value = dataRes.memberMembership || null;
    selectedRequestPayments.value = dataRes.requestPayments || [];
    selectedMembershipPayments.value = dataRes.membershipPayments || [];
    selectedDecisionPreview.value = dataRes.decisionPreview || null;
    requestDialog.value = true;
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

async function openRequestApproval(requestId) {
  const request = requests.value.find((item) => item.id === requestId);
  if (!request) {
    showSnackbar("Request not found", "error");
    return;
  }
  await openRequestDetail(request);
  if (selectedRequest.value?.id === requestId) {
    openApproveDialog();
  }
}

async function openRequestReject(requestId) {
  const request = requests.value.find((item) => item.id === requestId);
  if (!request) {
    showSnackbar("Request not found", "error");
    return;
  }
  await openRequestDetail(request);
  if (selectedRequest.value?.id === requestId) {
    openRejectDialog();
  }
}

async function openMembershipReview(membership) {
  if (!membership?.member?.id) {
    showSnackbar("Member not found for review", "error");
    return;
  }

  membershipReviewDialog.value = true;
  loadingMembershipReview.value = true;
  membershipReviewError.value = "";
  selectedMembershipReviewMember.value = membership.member;
  selectedMembershipReview.value = [];

  try {
    const res = await apiFetch(`/api/owner/members/${membership.member.id}/memberships`);
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    selectedMembershipReview.value = dataRes.memberships || [];
  } catch (err) {
    membershipReviewError.value = err.message || "Failed to load membership review";
  } finally {
    loadingMembershipReview.value = false;
  }
}

function openAdjustDialog(membership) {
  selectedMembershipToAdjust.value = membership;
  adjustForm.value = {
    changeType: "freeze_extension",
    extensionDays: 0,
    startDate: formatDate(membership.startDate),
    endDate: formatDate(membership.endDate),
    nextRenewalDate: formatDate(membership.nextRenewalDate),
    reason: "",
  };
  adjustDialog.value = true;
}

async function confirmAdjustMembership() {
  if (!selectedMembershipToAdjust.value?.id) return;
  if (!adjustForm.value.reason.trim()) {
    showSnackbar("Adjustment reason is required", "error");
    return;
  }

  processing.value = true;
  try {
    const res = await apiFetch(`/api/owner/memberships/${selectedMembershipToAdjust.value.id}/adjust`, {
      method: "POST",
      body: JSON.stringify({
        changeType: adjustForm.value.changeType,
        extensionDays: adjustForm.value.extensionDays,
        startDate: toIsoDateFromUs(adjustForm.value.startDate) || undefined,
        endDate: toIsoDateFromUs(adjustForm.value.endDate) || undefined,
        nextRenewalDate: toIsoDateFromUs(adjustForm.value.nextRenewalDate) || undefined,
        reason: adjustForm.value.reason,
      }),
    });
    const dataRes = await res.json();
    if (!res.ok) throw new Error(dataRes.message);
    showSnackbar("Membership adjusted");
    adjustDialog.value = false;
    await openMembershipReview({ member: selectedMembershipReviewMember.value });
    await fetchAll();
  } catch (err) {
    showSnackbar(err.message, "error");
  } finally {
    processing.value = false;
  }
}

function formatDate(date) {
  return formatDateUs(date);
}

function formatDateTime(date) {
  return formatDateTimeUs(date);
}

function formatPaymentMode(mode) {
  const map = {
    cash: "Cash",
    upi: "UPI",
    waived: "Waived",
  };
  return map[mode] || mode || "Unknown";
}

function toIsoDateFromUs(value) {
  const normalized = String(value || "").trim();
  const match = normalized.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
  if (!match) return "";
  const [, day, month, year] = match;
  return `${year}-${month}-${day}`;
}

onMounted(fetchAll);
</script>

<style scoped>
.mb-6 {
  margin-bottom: 24px;
}

.review-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 16px;
}

.review-note {
  max-width: 220px;
  white-space: normal;
  text-align: right;
}
</style>
