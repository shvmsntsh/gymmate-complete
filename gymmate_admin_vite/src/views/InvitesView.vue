<template>
  <AdminShell
    :is-dark="isDark"
    :title="pageTitle"
    :eyebrow="pageEyebrow"
    :description="pageDescription"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <div class="overview-grid invites-grid">
      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Create Invite</div>
            <h2 class="section-title">Share the next access code quickly</h2>
            <p class="section-copy">
              Pick the role, add contact details if you have them, and GymMate
              will create a clean code ready to share right away.
            </p>
          </div>
        </div>

        <v-form class="stack" @submit.prevent="submitInvite">
          <div class="form-grid">
            <div>
              <div class="field-label">Role</div>
              <v-select
                v-model="form.role"
                :items="roleOptions"
                density="comfortable"
                hide-details="auto"
                item-title="label"
                item-value="value"
                variant="outlined"
              />
            </div>
            <div>
              <div class="field-label">Phone Number</div>
              <v-text-field
                v-model="form.phone_number"
                density="comfortable"
                hide-details="auto"
                placeholder="Optional"
                variant="outlined"
              />
            </div>
            <div>
              <div class="field-label">Name</div>
              <v-text-field
                v-model="form.name"
                density="comfortable"
                hide-details="auto"
                placeholder="Optional"
                variant="outlined"
              />
            </div>
            <div>
              <div class="field-label">Email</div>
              <v-text-field
                v-model="form.email"
                density="comfortable"
                hide-details="auto"
                placeholder="Optional"
                variant="outlined"
              />
            </div>
          </div>

          <div class="cta-row">
            <v-btn
              color="primary"
              size="large"
              type="submit"
              :loading="submitting"
            >
              Create invite
            </v-btn>
            <v-btn size="large" variant="tonal" @click="fetchInvites">
              Refresh list
            </v-btn>
          </div>
        </v-form>
      </section>

      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Invite Pulse</div>
            <h2 class="section-title">What is still open, and what has moved</h2>
            <p class="section-copy">
              Keep open codes visible, spot fresh claims quickly, and follow up
              without hunting through a long flat list.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="error"
          title="Could not load invites"
          :copy="error"
          icon="mdi-ticket-alert-outline"
          tone="error"
        />
        <StateBlock
          v-else-if="loading"
          title="Loading invites"
          copy="Pulling the latest invite activity now."
          icon="mdi-timer-sand"
        />
        <template v-else>
          <div class="invite-metrics">
            <div class="invite-metric">
              <div class="invite-metric__value">{{ invites.length }}</div>
              <div class="invite-metric__label">Total invites</div>
            </div>
            <div class="invite-metric">
              <div class="invite-metric__value">{{ openInvites.length }}</div>
              <div class="invite-metric__label">Open now</div>
            </div>
            <div class="invite-metric">
              <div class="invite-metric__value">{{ usedInvites.length }}</div>
              <div class="invite-metric__label">Claimed</div>
            </div>
          </div>

          <div class="invite-highlight admin-surface admin-surface--muted">
            <div>
              <div class="invite-highlight__eyebrow">
                {{ latestOpenInvite ? "Latest open invite" : "No open invites" }}
              </div>
              <div class="invite-highlight__title">
                {{ latestOpenInvite ? latestOpenInvite.code : "Create a fresh code when you need one" }}
              </div>
              <div class="invite-highlight__copy">
                {{
                  latestOpenInvite
                    ? `${latestOpenInvite.roleLabel} invite created ${latestOpenInvite.createdDateLabel || "recently"}`
                    : "New invites will appear here with the role and timing at a glance."
                }}
              </div>
            </div>

            <v-btn
              v-if="latestOpenInvite"
              color="primary"
              variant="tonal"
              @click="copyInviteCode(latestOpenInvite)"
            >
              Copy code
            </v-btn>
          </div>
        </template>
      </section>
    </div>

    <div class="overview-grid invites-list-grid">
      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Open Invites</div>
            <h2 class="section-title">Ready to share</h2>
            <p class="section-copy">
              These codes are still available and can be shared right away.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="!loading && !error && openInvites.length === 0"
          title="No open invites"
          copy="Once you create a code, it will stay here until someone uses it."
          icon="mdi-ticket-outline"
        />
        <div v-else class="invite-list">
          <article
            v-for="invite in openInvites"
            :key="invite.id"
            class="invite-card"
          >
            <div class="invite-card__header">
              <div>
                <div class="invite-card__code">{{ invite.code }}</div>
                <div class="invite-card__meta">
                  {{ invite.roleLabel }} · {{ invite.createdDateLabel || "Created recently" }}
                </div>
              </div>
              <span class="invite-card__status">{{ invite.status }}</span>
            </div>

            <div class="invite-card__copy">
              {{ invite.summary }}
            </div>

            <div class="invite-card__actions">
              <v-btn
                color="primary"
                variant="tonal"
                size="small"
                @click="copyInviteCode(invite)"
              >
                Copy code
              </v-btn>
            </div>
          </article>
        </div>
      </section>

      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Claimed Invites</div>
            <h2 class="section-title">Who has already joined</h2>
            <p class="section-copy">
              Keep a quick view of who claimed access and when the invite moved.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="!loading && !error && usedInvites.length === 0"
          title="No claimed invites yet"
          copy="Claimed member, trainer, or owner invites will appear here with the joined profile details."
          icon="mdi-account-check-outline"
        />
        <div v-else class="invite-list">
          <article
            v-for="invite in usedInvites"
            :key="invite.id"
            class="invite-card invite-card--claimed"
          >
            <div class="invite-card__header">
              <div>
                <div class="invite-card__code">{{ invite.code }}</div>
                <div class="invite-card__meta">
                  {{ invite.roleLabel }} · {{ invite.usedDateLabel || "Claimed recently" }}
                </div>
              </div>
              <span class="invite-card__status invite-card__status--claimed">
                {{ invite.status }}
              </span>
            </div>

            <div class="invite-card__copy">
              {{ invite.summary }}
            </div>

            <div v-if="invite.claimedBy" class="invite-card__claimed">
              <div class="invite-card__claimed-name">{{ invite.claimedBy.name }}</div>
              <div class="invite-card__claimed-copy">
                {{ invite.claimedBy.email || invite.claimedBy.phone_number || "Joined profile" }}
              </div>
            </div>
          </article>
        </div>
      </section>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="3500">
      {{ snackbarText }}
    </v-snackbar>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import {
  apiFetch,
  clearAdminSession,
  getAdminRole,
  isOwnerSession,
} from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const role = computed(() => getAdminRole());
const loading = ref(false);
const submitting = ref(false);
const error = ref("");
const invites = ref([]);
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("success");
const form = ref({
  role: isOwnerSession() ? "gym_member" : "gym_owner",
  phone_number: "",
  name: "",
  email: "",
});

const roleOptions = computed(() =>
  role.value === "owner"
    ? [
        { label: "Member", value: "gym_member" },
        { label: "Trainer", value: "gym_trainer" },
      ]
    : [{ label: "Gym Owner", value: "gym_owner" }],
);

const pageTitle = computed(() =>
  role.value === "owner" ? "Invites" : "Network Invites",
);
const pageEyebrow = computed(() =>
  role.value === "owner" ? "Growth Tools" : "Access Control",
);
const pageDescription = computed(() =>
  role.value === "owner"
    ? "Create member and trainer invites, keep open codes visible, and see which joins have already landed."
    : "Create owner invites for new gyms and keep the network access flow easy to scan.",
);

const openInvites = computed(() => invites.value.filter((invite) => !invite.used));
const usedInvites = computed(() => invites.value.filter((invite) => invite.used));
const latestOpenInvite = computed(() => openInvites.value[0] || null);

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

function formatRole(roleValue) {
  return String(roleValue || "")
    .replace("gym_", "")
    .replace("_", " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function buildInviteSummary(invite) {
  if (invite.usedByUser?.name || invite.usedByUser?.email) {
    const person = invite.usedByUser.name || invite.usedByUser.email;
    return `${person} claimed this ${formatRole(invite.role).toLowerCase()} invite${invite.usedDateLabel ? ` on ${invite.usedDateLabel}` : ""}.`;
  }

  if (invite.usedBy) {
    return `${invite.usedBy} claimed this ${formatRole(invite.role).toLowerCase()} invite${invite.usedDateLabel ? ` on ${invite.usedDateLabel}` : ""}.`;
  }

  if (invite.phone_number || invite.email || invite.name) {
    return `Prepared for ${invite.name || invite.email || invite.phone_number}.`;
  }

  return role.value === "owner"
    ? "Ready to share with your next member or trainer."
    : "Ready to share with the next owner account.";
}

async function fetchInvites() {
  loading.value = true;
  error.value = "";

  try {
    const res = await apiFetch("/api/invite/list");
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "We could not load invites right now.");
    }

    invites.value = (data.codes || []).map((invite) => ({
      id: invite._id || invite.code,
      code: invite.code,
      used: Boolean(invite.used),
      role: invite.role,
      roleLabel: formatRole(invite.role),
      status: invite.statusLabel || (invite.used ? "Used" : "Open"),
      createdDateLabel: invite.createdDateLabel || null,
      usedDateLabel: invite.usedDateLabel || null,
      usedBy: invite.usedBy || "",
      claimedBy: invite.usedByUser || null,
      name: invite.name || invite.invitee?.name || "",
      email: invite.email || invite.invitee?.email || "",
      phone_number: invite.phone_number || invite.invitee?.phone_number || "",
      summary: buildInviteSummary(invite),
    }));
  } catch (err) {
    error.value = err?.message || "We could not load invites right now.";
  } finally {
    loading.value = false;
  }
}

async function copyInviteCode(invite) {
  try {
    await navigator.clipboard.writeText(invite.code);
    showMessage(`Copied ${invite.code}`);
  } catch (_) {
    showMessage("We could not copy that code right now.", "error");
  }
}

async function submitInvite() {
  if (form.value.phone_number && (!form.value.name || !form.value.email)) {
    showMessage(
      "Add both name and email when you include a phone number.",
      "error",
    );
    return;
  }

  submitting.value = true;

  try {
    const payload = {
      role: form.value.role,
      ...(form.value.phone_number
        ? { phone_number: form.value.phone_number.trim() }
        : {}),
      ...(form.value.name ? { name: form.value.name.trim() } : {}),
      ...(form.value.email ? { email: form.value.email.trim() } : {}),
    };

    const res = await apiFetch("/api/invite/generate", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    const data = await res.json();

    if (!res.ok) {
      throw new Error(
        data.message ||
          data.error ||
          "We could not create the invite right now.",
      );
    }

    form.value = {
      role: role.value === "owner" ? "gym_member" : "gym_owner",
      phone_number: "",
      name: "",
      email: "",
    };
    showMessage("Invite created successfully.");
    await fetchInvites();
  } catch (err) {
    showMessage(
      err?.message || "We could not create the invite right now.",
      "error",
    );
  } finally {
    submitting.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(fetchInvites);
</script>

<style scoped>
.invites-grid,
.invites-list-grid {
  gap: 20px;
}

.invite-metrics {
  display: grid;
  gap: 14px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.invite-metric {
  padding: 18px;
  border-radius: 24px;
  border: 1px solid rgba(181, 159, 91, 0.16);
  background: rgba(255, 255, 255, 0.02);
}

.invite-metric__value {
  font-size: 2rem;
  font-weight: 700;
  line-height: 1;
}

.invite-metric__label {
  margin-top: 8px;
  color: var(--gm-text-muted);
}

.invite-highlight {
  margin-top: 16px;
  padding: 20px;
  border-radius: 28px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.invite-highlight__eyebrow {
  color: var(--gm-accent);
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.invite-highlight__title {
  margin-top: 8px;
  font-size: 1.35rem;
  font-weight: 700;
}

.invite-highlight__copy {
  margin-top: 6px;
  color: var(--gm-text-muted);
}

.invite-list {
  display: grid;
  gap: 16px;
}

.invite-card {
  padding: 20px;
  border-radius: 28px;
  border: 1px solid rgba(181, 159, 91, 0.14);
  background: rgba(255, 255, 255, 0.02);
}

.invite-card--claimed {
  border-color: rgba(181, 159, 91, 0.22);
}

.invite-card__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
}

.invite-card__code {
  font-size: 1.25rem;
  font-weight: 700;
  letter-spacing: 0.05em;
}

.invite-card__meta,
.invite-card__copy,
.invite-card__claimed-copy {
  color: var(--gm-text-muted);
}

.invite-card__meta {
  margin-top: 4px;
}

.invite-card__status {
  padding: 6px 12px;
  border-radius: 999px;
  background: rgba(248, 216, 75, 0.12);
  color: var(--gm-accent);
  font-size: 0.82rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  white-space: nowrap;
}

.invite-card__status--claimed {
  background: rgba(181, 159, 91, 0.18);
}

.invite-card__copy {
  margin-top: 14px;
}

.invite-card__actions {
  margin-top: 16px;
}

.invite-card__claimed {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid rgba(181, 159, 91, 0.12);
}

.invite-card__claimed-name {
  font-weight: 700;
}

@media (max-width: 960px) {
  .invite-metrics {
    grid-template-columns: 1fr;
  }

  .invite-highlight {
    flex-direction: column;
    align-items: flex-start;
  }

  .invite-card__header {
    flex-direction: column;
  }
}
</style>
