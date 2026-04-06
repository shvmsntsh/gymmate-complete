<template>
  <AdminShell
    :is-dark="isDark"
    :title="pageTitle"
    :eyebrow="pageEyebrow"
    :description="pageDescription"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <section v-if="isWorkspaceRole" class="admin-surface admin-panel">
      <div class="section-header">
        <div>
          <div class="table-overline">Member Workspace</div>
          <h2 class="section-title">Members, plans, and request activity</h2>
          <p class="section-copy">
            Track member state, current plan status, and request activity without loading a heavy dashboard.
          </p>
        </div>
      </div>

      <StateBlock
        v-if="error"
        :title="'Could not load the owner workspace'"
        :copy="error"
        icon="mdi-account-alert-outline"
        tone="error"
      />

      <template v-else>
        <div class="owner-summary-grid">
          <div class="summary-pill">
            <div class="summary-label">Active Members</div>
            <div class="summary-value">{{ summary.activeCount }}</div>
          </div>
          <div class="summary-pill">
            <div class="summary-label">Inactive Members</div>
            <div class="summary-value">{{ summary.inactiveCount }}</div>
          </div>
          <div class="summary-pill">
            <div class="summary-label">Pending Requests</div>
            <div class="summary-value">{{ summary.pendingRequestCount }}</div>
          </div>
        </div>

        <div class="owner-toolbar">
          <v-btn
            :variant="filterMode === 'all' ? 'flat' : 'outlined'"
            color="primary"
            @click="filterMode = 'all'"
          >
            All Clients
          </v-btn>
          <v-btn
            :variant="filterMode === 'active' ? 'flat' : 'outlined'"
            color="primary"
            @click="filterMode = 'active'"
          >
            Active
          </v-btn>
          <v-btn
            :variant="filterMode === 'inactive' ? 'flat' : 'outlined'"
            color="primary"
            @click="filterMode = 'inactive'"
          >
            Inactive
          </v-btn>
          <v-btn
            :variant="filterMode === 'expiring' ? 'flat' : 'outlined'"
            color="primary"
            @click="filterMode = 'expiring'"
          >
            Expiring
          </v-btn>
        </div>

        <v-data-table
          class="admin-table"
          :headers="ownerHeaders"
          :items="visibleMembers"
          :loading="loading"
          density="comfortable"
          item-value="id"
        >
          <template #item.goal="{ item }">
            {{ goalLabel(item.raw || item) }}
          </template>

          <template #item.membership="{ item }">
            <v-chip
              :color="membershipTone((item.raw || item).membership?.status)"
              variant="tonal"
              size="small"
            >
              {{ membershipLabel((item.raw || item).membership) }}
            </v-chip>
          </template>

          <template #item.pendingRequestCount="{ item }">
            {{ (item.raw || item).pendingRequestCount || 0 }}
          </template>

          <template #item.assignedTrainer="{ item }">
            <div v-if="isOwner" class="assignment-cell">
              <v-select
                :items="trainerOptions"
                item-title="label"
                item-value="value"
                :model-value="draftAssignments[(item.raw || item).id] ?? (item.raw || item).assignedTrainerId"
                density="compact"
                hide-details
                variant="outlined"
                placeholder="Select trainer"
                @update:model-value="(value) => updateDraftAssignment((item.raw || item).id, value)"
              />
              <div class="assignment-actions">
                <v-btn
                  size="small"
                  color="primary"
                  :loading="Boolean(assignmentBusy[(item.raw || item).id])"
                  @click="applyAssignment(item.raw || item)"
                >
                  Save
                </v-btn>
                <v-btn
                  v-if="(item.raw || item).assignedTrainerId"
                  size="small"
                  variant="text"
                  @click="clearAssignment(item.raw || item)"
                >
                  Unassign
                </v-btn>
              </div>
            </div>
            <div v-else>-</div>
          </template>

          <template #item.lastActivity="{ item }">
            {{ lastActivityLabel(item.raw || item) }}
          </template>

          <template #item.todayCompletion="{ item }">
            {{ completionLabel(item.raw || item) }}
          </template>

          <template #item.actions="{ item }">
            <div class="row-actions">
              <v-btn
                size="small"
                variant="text"
                color="primary"
                :disabled="!isOwner || !(item.raw || item).assignedTrainerId"
                @click="openTrainerConversation((item.raw || item).assignedTrainerId)"
              >
                Message Trainer
              </v-btn>
            </div>
          </template>
        </v-data-table>

        <div v-if="isOwner" class="section-header trainer-inbox-header">
          <div>
            <div class="table-overline">Trainer Inbox</div>
            <h2 class="section-title">Owner to trainer conversations</h2>
            <p class="section-copy">
              Reply to trainers here without leaving the workspace.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="isOwner && !loading && ownerConversations.length === 0"
          title="No trainer threads yet"
          copy="Once trainer conversations begin, they will appear here with unread counts and the latest reply."
          icon="mdi-forum-outline"
        />
        <div v-if="isOwner" class="conversation-list">
          <button
            v-for="conversation in ownerConversations"
            :key="conversation.id"
            class="conversation-card"
            type="button"
            @click="openConversationById(conversation.id)"
          >
            <div class="conversation-topline">
              <span class="conversation-name">
                {{ conversation.participant?.name || "Trainer" }}
              </span>
              <v-chip
                v-if="conversation.unreadCount"
                color="primary"
                size="x-small"
                variant="tonal"
              >
                {{ conversation.unreadCount }} unread
              </v-chip>
            </div>
            <div class="conversation-preview">
              {{ conversation.lastMessagePreview || "Open the thread to start the conversation." }}
            </div>
          </button>
        </div>
      </template>
    </section>

    <section v-else class="admin-surface admin-panel">
      <div class="section-header">
        <div>
          <div class="table-overline">{{ listEyebrow }}</div>
          <h2 class="section-title">{{ listTitle }}</h2>
          <p class="section-copy">{{ listCopy }}</p>
        </div>
      </div>

      <StateBlock
        v-if="error"
        :title="errorTitle"
        :copy="error"
        icon="mdi-account-alert-outline"
        tone="error"
      />
      <StateBlock
        v-else-if="!loading && members.length === 0"
        :title="emptyTitle"
        :copy="emptyCopy"
        icon="mdi-account-off-outline"
      />
      <v-data-table
        v-else
        class="admin-table"
        :headers="adminHeaders"
        :items="members"
        :loading="loading"
        density="comfortable"
        item-value="_id"
      />
    </section>

    <v-dialog v-model="messageDialog" max-width="760">
      <v-card rounded="xl">
        <v-card-title class="dialog-title">
          {{ activeConversationTitle }}
        </v-card-title>
        <v-card-text>
          <StateBlock
            v-if="messageError"
            title="Could not load this conversation"
            :copy="messageError"
            icon="mdi-alert-circle-outline"
            tone="error"
          />
          <div v-else-if="messagesLoading" class="dialog-loading">
            <v-progress-circular indeterminate color="primary" />
          </div>
          <div v-else class="message-thread">
            <div
              v-for="message in activeMessages"
              :key="message.id"
              :class="['message-bubble', { 'message-bubble--mine': message.isMine }]"
            >
              <div>{{ message.body }}</div>
              <div class="message-time">
                {{ formatTime(message.createdAt) }}
              </div>
            </div>
          </div>

          <v-textarea
            v-model="draftMessage"
            class="message-input"
            label="Reply"
            variant="outlined"
            auto-grow
            rows="2"
            :disabled="messageSending || activeConversationStatus !== 'active'"
          />
        </v-card-text>
        <v-card-actions class="dialog-actions">
          <v-spacer />
          <v-btn variant="text" @click="messageDialog = false">Close</v-btn>
          <v-btn
            color="primary"
            :loading="messageSending"
            :disabled="!draftMessage.trim() || activeConversationStatus !== 'active'"
            @click="sendConversationMessage"
          >
            Send
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, clearAdminSession, getAdminRole } from "../lib/api";

const router = useRouter();
const members = ref([]);
const trainers = ref([]);
const ownerConversations = ref([]);
const loading = ref(false);
const error = ref("");
const filterMode = ref("all");
const summary = ref({
  activeCount: 0,
  inactiveCount: 0,
  pendingRequestCount: 0,
});
const draftAssignments = ref({});
const assignmentBusy = ref({});
const messageDialog = ref(false);
const messagesLoading = ref(false);
const messageSending = ref(false);
const messageError = ref("");
const activeConversationId = ref("");
const activeConversationTitle = ref("Conversation");
const activeConversationStatus = ref("active");
const activeMessages = ref([]);
const draftMessage = ref("");
const { isDark, toggleTheme } = useAdminTheme();
const role = computed(() => getAdminRole());
const isOwner = computed(() => role.value === "owner");
const isWorkspaceRole = computed(() => role.value === "owner" || role.value === "staff");

const pageTitle = computed(() =>
  isWorkspaceRole.value ? "Manage Members" : "Manage Members",
);
const pageEyebrow = computed(() =>
  isWorkspaceRole.value ? "Member Operations" : "Operations",
);
const pageDescription = computed(() =>
  isWorkspaceRole.value
    ? "Filter members, review membership state, and keep request traffic visible."
    : "Review members, their roles, and the gyms they belong to in one clean directory.",
);
const listEyebrow = computed(() => "Member Directory");
const listTitle = computed(() => "Current Members");
const listCopy = computed(() => "Browse your members by name, email, and role.");
const errorTitle = computed(() => "Could not load members");
const emptyTitle = computed(() => "No members found");
const emptyCopy = computed(() => "Members will appear here as soon as they join a gym in GymMate.");

const ownerHeaders = [
  { title: "Client", key: "name" },
  { title: "Email", key: "email" },
  { title: "Goal", key: "goal" },
  { title: "Membership", key: "membership" },
  { title: "Pending", key: "pendingRequestCount" },
  { title: "Trainer", key: "assignedTrainer" },
  { title: "Last Activity", key: "lastActivity" },
  { title: "Actions", key: "actions", sortable: false },
];

const adminHeaders = [
  { title: "Name", key: "name" },
  { title: "Email", key: "email" },
  { title: "Role", key: "role" },
];

const trainerOptions = computed(() =>
  [...trainers.value]
    .sort((a, b) => {
      const countDiff = Number(b.clientCount || 0) - Number(a.clientCount || 0);
      if (countDiff !== 0) return countDiff;
      return String(a.name || "").localeCompare(String(b.name || ""));
    })
    .map((trainer) => ({
      label: `${trainer.name} (${trainer.clientCount} clients)`,
      value: trainer.id,
    })),
);

const visibleMembers = computed(() => {
  const scopedMembers =
    filterMode.value === "active"
      ? members.value.filter((member) => member.activeState === "active")
      : filterMode.value === "inactive"
        ? members.value.filter((member) => member.activeState === "inactive")
        : filterMode.value === "expiring"
          ? members.value.filter((member) => member.membership?.status === "expiring")
        : members.value;

  return [...scopedMembers].sort((a, b) => {
    const pendingDiff =
      Number(b.pendingRequestCount || 0) - Number(a.pendingRequestCount || 0);
    if (pendingDiff !== 0) {
      return pendingDiff;
    }

    const expiringRankA = a.membership?.status === "expiring" ? 0 : 1;
    const expiringRankB = b.membership?.status === "expiring" ? 0 : 1;
    if (expiringRankA !== expiringRankB) {
      return expiringRankA - expiringRankB;
    }

    const lastActivityA = a.lastAttendanceAt
      ? new Date(a.lastAttendanceAt).getTime()
      : 0;
    const lastActivityB = b.lastAttendanceAt
      ? new Date(b.lastAttendanceAt).getTime()
      : 0;
    if (lastActivityA !== lastActivityB) {
      return lastActivityB - lastActivityA;
    }

    return String(a.name || "").localeCompare(String(b.name || ""));
  });
});

function goalLabel(item) {
  const goals = Array.isArray(item.fitnessGoals) ? item.fitnessGoals : [];
  if (!goals.length) return "General fitness";
  return String(goals[0]).replaceAll("_", " ");
}

function membershipLabel(membership) {
  if (!membership) return "No plan";
  return membership.planName || membership.status || "No plan";
}

function membershipTone(status) {
  if (status === "active") return "primary";
  if (status === "expiring") return "warning";
  if (status === "payment_pending") return "secondary";
  return "default";
}

function lastActivityLabel(item) {
  return item.lastAttendanceAt
    ? new Date(item.lastAttendanceAt).toLocaleDateString()
    : "No attendance yet";
}

function updateDraftAssignment(memberId, trainerId) {
  draftAssignments.value = {
    ...draftAssignments.value,
    [memberId]: trainerId || null,
  };
}

async function fetchOwnerWorkspace() {
  const requests = [apiFetch("/api/owner/member-workspace?limit=50")];
  if (isOwner.value) {
    requests.push(apiFetch("/api/owner/assignments"));
    requests.push(apiFetch("/api/messages/conversations"));
  }
  const responses = await Promise.all(requests);
  const payloads = await Promise.all(responses.map((response) => response.json()));
  const memberWorkspace = payloads[0];

  if (!responses[0].ok) {
    throw new Error(memberWorkspace.message || "We could not load the owner workspace.");
  }

  let assignmentWorkspace = { trainers: [], members: [] };
  let conversationsPayload = { conversations: [] };
  if (isOwner.value) {
    if (!responses[1].ok) {
      throw new Error(payloads[1].message || "We could not load assignments.");
    }
    if (!responses[2].ok) {
      throw new Error(payloads[2].message || "We could not load trainer conversations.");
    }
    assignmentWorkspace = payloads[1];
    conversationsPayload = payloads[2];
  }

  const memberRows = memberWorkspace.members || [];
  const assignmentMap = new Map(
    (assignmentWorkspace.members || []).map((member) => [member.id, member]),
  );

  trainers.value = assignmentWorkspace.trainers || [];
  members.value = memberRows.map((member) => ({
    ...assignmentMap.get(member.id),
    ...member,
    assignedTrainerId: assignmentMap.get(member.id)?.assignedTrainerId || null,
  }));
  summary.value = memberWorkspace.summary || summary.value;
  ownerConversations.value = (conversationsPayload.conversations || []).filter(
    (conversation) => conversation.section === "owner",
  );
  draftAssignments.value = Object.fromEntries(
    (assignmentWorkspace.members || []).map((member) => [
      member.id,
      member.assignedTrainerId || null,
    ]),
  );
}

async function fetchAdminMembers() {
  const res = await apiFetch("/api/gym/members");
  const data = await res.json();
  if (!res.ok) {
    throw new Error(data.message || "We could not load the member list right now.");
  }
  members.value = data.members || [];
}

async function fetchMembers() {
  loading.value = true;
  error.value = "";

  try {
    if (isOwner.value) {
      await fetchOwnerWorkspace();
    } else if (isWorkspaceRole.value) {
      await fetchOwnerWorkspace();
    } else {
      await fetchAdminMembers();
    }
  } catch (err) {
    error.value = err?.message || "We could not load this workspace right now.";
  } finally {
    loading.value = false;
  }
}

async function applyAssignment(member) {
  const trainerId = draftAssignments.value[member.id] || null;
  assignmentBusy.value = { ...assignmentBusy.value, [member.id]: true };

  try {
    const res = trainerId
      ? await apiFetch(`/api/owner/members/${member.id}/assignment`, {
          method: "PUT",
          body: JSON.stringify({ trainerId, notes: member.assignment?.notes || "" }),
        })
      : await apiFetch(`/api/owner/members/${member.id}/assignment`, {
          method: "DELETE",
        });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "We could not update the assignment.");
    }
    members.value = data.workspace?.members || members.value;
    trainers.value = data.workspace?.trainers || trainers.value;
    summary.value = data.workspace?.summary || summary.value;
    draftAssignments.value = Object.fromEntries(
      (data.workspace?.members || members.value).map((entry) => [
        entry.id,
        entry.assignedTrainerId || null,
      ]),
    );
  } catch (err) {
    error.value = err?.message || "We could not update the assignment.";
  } finally {
    assignmentBusy.value = { ...assignmentBusy.value, [member.id]: false };
  }
}

function clearAssignment(member) {
  updateDraftAssignment(member.id, null);
  applyAssignment(member);
}

async function openTrainerConversation(trainerId) {
  if (!trainerId) return;
  try {
    const res = await apiFetch("/api/messages/conversations", {
      method: "POST",
      body: JSON.stringify({ type: "owner_trainer", trainerId }),
    });
    const payload = await res.json();
    if (!res.ok) {
      throw new Error(payload.message || "We could not open this conversation.");
    }
    await openConversationById(payload.conversation.id, payload.conversation.participant?.name);
  } catch (err) {
    error.value = err?.message || "We could not open the conversation.";
  }
}

async function openConversationById(conversationId, fallbackTitle = "Trainer conversation") {
  messageDialog.value = true;
  messagesLoading.value = true;
  messageError.value = "";
  draftMessage.value = "";
  activeConversationId.value = conversationId;

  try {
    const res = await apiFetch(`/api/messages/conversations/${conversationId}/messages`);
    const payload = await res.json();
    if (!res.ok) {
      throw new Error(payload.message || "We could not load the conversation.");
    }
    activeConversationTitle.value =
      payload.conversation?.participant?.name || fallbackTitle;
    activeConversationStatus.value = payload.conversation?.status || "active";
    activeMessages.value = payload.messages || [];
  } catch (err) {
    messageError.value = err?.message || "We could not load the conversation.";
  } finally {
    messagesLoading.value = false;
  }
}

async function sendConversationMessage() {
  if (!draftMessage.value.trim()) return;
  messageSending.value = true;

  try {
    const res = await apiFetch(
      `/api/messages/conversations/${activeConversationId.value}/messages`,
      {
        method: "POST",
        body: JSON.stringify({ body: draftMessage.value }),
      },
    );
    const payload = await res.json();
    if (!res.ok) {
      throw new Error(payload.message || "We could not send the message.");
    }
    activeMessages.value = [...activeMessages.value, payload.message];
    draftMessage.value = "";
    await fetchOwnerWorkspace();
  } catch (err) {
    messageError.value = err?.message || "We could not send the message.";
  } finally {
    messageSending.value = false;
  }
}

function formatTime(value) {
  if (!value) return "";
  const date = new Date(value);
  return date.toLocaleTimeString([], {
    hour: "numeric",
    minute: "2-digit",
  });
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(fetchMembers);
</script>

<style scoped>
.owner-summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 20px;
}

.summary-pill {
  border: 1px solid rgba(201, 177, 92, 0.2);
  border-radius: 20px;
  padding: 16px;
  background: rgba(255, 255, 255, 0.02);
}

.summary-label {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  opacity: 0.7;
}

.summary-value {
  margin-top: 6px;
  font-size: 28px;
  font-weight: 700;
}

.owner-toolbar {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 18px;
}

.assignment-cell {
  display: grid;
  gap: 8px;
  min-width: 220px;
}

.assignment-actions {
  display: flex;
  gap: 8px;
}

.row-actions {
  display: flex;
  justify-content: flex-start;
}

.trainer-inbox-header {
  margin-top: 28px;
}

.conversation-list {
  display: grid;
  gap: 12px;
}

.conversation-card {
  width: 100%;
  text-align: left;
  padding: 16px;
  border-radius: 18px;
  border: 1px solid rgba(201, 177, 92, 0.18);
  background: rgba(255, 255, 255, 0.02);
  cursor: pointer;
}

.conversation-topline {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  align-items: center;
}

.conversation-name {
  font-weight: 700;
}

.conversation-preview {
  margin-top: 8px;
  opacity: 0.8;
}

.dialog-title {
  font-weight: 700;
}

.dialog-loading {
  display: flex;
  justify-content: center;
  padding: 24px 0;
}

.message-thread {
  max-height: 420px;
  overflow: auto;
  display: grid;
  gap: 12px;
}

.message-bubble {
  max-width: 75%;
  padding: 12px 14px;
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.06);
}

.message-bubble--mine {
  margin-left: auto;
  background: rgba(201, 177, 92, 0.18);
}

.message-time {
  margin-top: 8px;
  font-size: 12px;
  opacity: 0.7;
}

.message-input {
  margin-top: 18px;
}

.dialog-actions {
  padding: 0 24px 20px;
}

@media (max-width: 900px) {
  .owner-summary-grid {
    grid-template-columns: 1fr;
  }
}
</style>
