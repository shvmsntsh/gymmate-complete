import { computed, reactive } from "vue";
import { apiFetch, getAdminRole, getAdminSession } from "../lib/api";

const STORAGE_PREFIX = "gymmate_onboarding_";

const DEFAULT_STORAGE = () => ({
  dismissedAt: null,
  completedSteps: [],
  attendanceMethod: null,
});

const state = reactive({
  loaded: false,
  loading: false,
  kpis: {},
  planCount: 0,
  inviteCount: 0,
  storage: DEFAULT_STORAGE(),
});

function storageKey() {
  const session = getAdminSession();
  const gymId = session?.user?.gymId || session?.user?.id || "anon";
  return `${STORAGE_PREFIX}${gymId}`;
}

function loadStorage() {
  try {
    const raw = JSON.parse(localStorage.getItem(storageKey()) || "{}");
    state.storage = { ...DEFAULT_STORAGE(), ...raw };
  } catch {
    state.storage = DEFAULT_STORAGE();
  }
}

function saveStorage() {
  try {
    localStorage.setItem(storageKey(), JSON.stringify(state.storage));
  } catch {
    // ignore quota errors
  }
}

const ONBOARDING_STEPS = [
  {
    id: "create_plan",
    title: "Create your first plan",
    copy: "Start with Monthly, Quarterly, or PT Pass. Tweak the price and save.",
    icon: "mdi-card-account-details-outline",
    to: "/membership?tab=plans&action=create-plan",
    quickAction: "create-plan",
    route: "MembershipOps",
    check: () => state.planCount > 0,
  },
  {
    id: "add_staff",
    title: "Add front desk staff",
    copy: "Create logins for the people running the gym today.",
    icon: "mdi-badge-account-horizontal-outline",
    to: "/staff?action=add-staff",
    quickAction: "add-staff",
    route: "StaffWorkspace",
    check: () => Number(state.kpis.staffCount || 0) > 0,
  },
  {
    id: "invite_member",
    title: "Invite your first member",
    copy: "Share a member invite code. Trainers use the same flow.",
    icon: "mdi-account-multiple-plus-outline",
    to: "/invites?role=gym_member&focus=create",
    quickAction: "invite-member",
    route: "Invites",
    check: () =>
      state.inviteCount > 0 || Number(state.kpis.activeMembers || 0) > 0,
  },
  {
    id: "assign_plan",
    title: "Assign a plan to a member",
    copy: "Open Plans & Memberships and pick a member + plan.",
    icon: "mdi-clipboard-account-outline",
    to: "/membership?tab=memberships&action=assign-plan",
    quickAction: "assign-plan",
    route: "MembershipOps",
    check: () => Number(state.kpis.activeMembers || 0) > 0,
  },
  {
    id: "record_payment",
    title: "Record your first payment",
    copy: "Cash or UPI. The receipt is generated automatically.",
    icon: "mdi-cash-register",
    to: "/payments?action=record-payment",
    quickAction: "record-payment",
    route: "PaymentWorkspace",
    check: () =>
      Number(state.kpis.paymentsToday || 0) > 0 ||
      Number(state.kpis.revenueToday || 0) > 0,
  },
  {
    id: "attendance_method",
    title: "Choose attendance method",
    copy: "Pick manual, QR, or biometric. Start simple — switch later.",
    icon: "mdi-calendar-check-outline",
    to: "/attendance?action=choose-method",
    quickAction: "mark-attendance",
    route: "AttendanceWorkspace",
    check: () =>
      Boolean(state.storage.attendanceMethod) ||
      Number(state.kpis.todayCheckIns || 0) > 0,
  },
];

let activeFetch = null;

async function refresh() {
  if (state.loading) return activeFetch;
  state.loading = true;
  activeFetch = (async () => {
    try {
      const [dashRes, plansRes, invitesRes] = await Promise.all([
        apiFetch("/api/workspace/dashboard").catch(() => null),
        apiFetch("/api/owner/membership-templates").catch(() => null),
        apiFetch("/api/invite/list").catch(() => null),
      ]);
      if (dashRes?.ok) {
        const data = await dashRes.json().catch(() => ({}));
        state.kpis = data?.kpis || {};
      }
      if (plansRes?.ok) {
        const data = await plansRes.json().catch(() => ({}));
        state.planCount = (data?.templates || data?.plans || []).length;
      }
      if (invitesRes?.ok) {
        const data = await invitesRes.json().catch(() => ({}));
        state.inviteCount = (data?.codes || []).length;
      }
      state.loaded = true;
    } catch {
      // composable degrades silently
    } finally {
      state.loading = false;
    }
  })();
  return activeFetch;
}

export function useOnboarding({ autoLoad = true } = {}) {
  loadStorage();
  if (autoLoad && !state.loaded && !state.loading) {
    refresh();
  }

  const isOwner = computed(() => getAdminRole() === "owner");

  const steps = computed(() =>
    ONBOARDING_STEPS.map((step) => ({
      ...step,
      done: step.check() || state.storage.completedSteps.includes(step.id),
    })),
  );

  const completedCount = computed(
    () => steps.value.filter((step) => step.done).length,
  );
  const totalCount = computed(() => steps.value.length);
  const isComplete = computed(
    () => completedCount.value === totalCount.value,
  );
  const isDismissed = computed(() => Boolean(state.storage.dismissedAt));
  const visible = computed(
    () => isOwner.value && !isDismissed.value && !isComplete.value,
  );

  function markStepComplete(stepId) {
    if (!state.storage.completedSteps.includes(stepId)) {
      state.storage.completedSteps = [
        ...state.storage.completedSteps,
        stepId,
      ];
      saveStorage();
    }
  }

  function setAttendanceMethod(method) {
    state.storage.attendanceMethod = method || null;
    saveStorage();
    if (method) markStepComplete("attendance_method");
  }

  function dismiss() {
    state.storage.dismissedAt = new Date().toISOString();
    saveStorage();
  }

  function restore() {
    state.storage.dismissedAt = null;
    saveStorage();
  }

  return {
    steps,
    completedCount,
    totalCount,
    isComplete,
    isDismissed,
    visible,
    isOwner,
    state,
    refresh,
    dismiss,
    restore,
    markStepComplete,
    setAttendanceMethod,
  };
}
