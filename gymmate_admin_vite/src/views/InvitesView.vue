<template>
  <AdminShell
    :is-dark="isDark"
    :title="pageTitle"
    :eyebrow="pageEyebrow"
    :description="pageDescription"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <div class="overview-grid">
      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">New Invite</div>
            <h2 class="section-title">Create an invite in a few seconds</h2>
            <p class="section-copy">
              Pick the role, add optional contact details if you have them, and
              GymMate will generate a code ready to share.
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
              >Create invite</v-btn
            >
            <v-btn size="large" variant="tonal" @click="fetchInvites"
              >Refresh list</v-btn
            >
          </div>
        </v-form>
      </section>

      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Invite List</div>
            <h2 class="section-title">Recent invite codes</h2>
            <p class="section-copy">
              Keep the latest codes close so you can copy, share, and follow up
              without digging around.
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
          copy="Pulling the latest invite codes now."
          icon="mdi-timer-sand"
        />
        <StateBlock
          v-else-if="invites.length === 0"
          title="No invites yet"
          copy="Create your first invite and it will appear here with its current status."
          icon="mdi-ticket-outline"
        />
        <div v-else class="partner-list">
          <div
            v-for="invite in invites"
            :key="invite.id"
            class="partner-item partner-item--static"
          >
            <div>
              <div class="partner-item__title">{{ invite.code }}</div>
              <div class="partner-item__copy">{{ invite.copy }}</div>
            </div>
            <div class="partner-item__status">{{ invite.status }}</div>
          </div>
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
    ? "Create member and trainer invites without losing track of what is still open."
    : "Keep new-owner invitations moving smoothly as the network grows.",
);

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

function formatRole(roleValue) {
  return String(roleValue || "")
    .replace("gym_", "")
    .replace("_", " ");
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
      copy: invite.gymName || invite.usedBy || "Ready to share",
      status: invite.used
        ? `${formatRole(invite.role)} claimed`
        : `${formatRole(invite.role)} open`,
    }));
  } catch (err) {
    error.value = err?.message || "We could not load invites right now.";
  } finally {
    loading.value = false;
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
