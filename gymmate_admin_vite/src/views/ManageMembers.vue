<template>
  <AdminShell
    :is-dark="isDark"
    :title="pageTitle"
    :eyebrow="pageEyebrow"
    :description="pageDescription"
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <section class="admin-surface admin-panel">
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
        :headers="headers"
        :items="members"
        :loading="loading"
        density="comfortable"
        item-value="_id"
      >
      </v-data-table>
    </section>
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
const loading = ref(false);
const error = ref("");
const { isDark, toggleTheme } = useAdminTheme();
const role = computed(() => getAdminRole());

const pageTitle = computed(() =>
  role.value === "owner" ? "Member Roster" : "Manage Members",
);
const pageEyebrow = computed(() =>
  role.value === "owner" ? "Gym Floor" : "Operations",
);
const pageDescription = computed(() =>
  role.value === "owner"
    ? "Review the members and coaches attached to your gym in one clean roster."
    : "Review members, their roles, and the gyms they belong to in one clean directory.",
);
const listEyebrow = computed(() =>
  role.value === "owner" ? "Current Roster" : "Member Directory",
);
const listTitle = computed(() =>
  role.value === "owner" ? "People in your gym" : "Current Members",
);
const listCopy = computed(() =>
  role.value === "owner"
    ? "Browse the people currently tied to your gym by name, email, and role."
    : "Browse your members by name, email, and role.",
);
const errorTitle = computed(() =>
  role.value === "owner"
    ? "Could not load your roster"
    : "Could not load members",
);
const emptyTitle = computed(() =>
  role.value === "owner" ? "No roster yet" : "No members found",
);
const emptyCopy = computed(() =>
  role.value === "owner"
    ? "Members and coaches will appear here as soon as they join your gym in GymMate."
    : "Members will appear here as soon as they join a gym in GymMate.",
);

const headers = [
  { title: "Name", key: "name" },
  { title: "Email", key: "email" },
  { title: "Role", key: "role" },
];

async function fetchMembers() {
  loading.value = true;
  error.value = "";

  try {
    const res = await apiFetch("/api/gym/members");
    const data = await res.json();
    members.value = data.members || [];
  } catch (err) {
    error.value = "We could not load the member list right now.";
  } finally {
    loading.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(fetchMembers);
</script>
