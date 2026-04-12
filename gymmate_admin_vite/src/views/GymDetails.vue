<template>
  <AdminShell
    :is-dark="isDark"
    title="Gym Details"
    eyebrow="Gym Profile"
    description="See the key details, services, and contact info for this gym."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <div class="overview-grid">
      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Gym Record</div>
            <h2 class="section-title">Registered gym information</h2>
            <p class="section-copy">
              Keep the core profile readable before deeper admin work.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="error"
          title="Gym not found"
          :copy="error"
          icon="mdi-domain-off"
          tone="error"
        />
        <StateBlock
          v-else-if="loading"
          title="Loading gym details"
          copy="Loading the selected gym profile."
          icon="mdi-timer-sand"
        />
        <div v-else-if="gym" class="gym-hero admin-surface admin-surface--muted">
          <div class="gym-hero__badge">{{ initials }}</div>
          <div>
            <div class="gym-hero__title">{{ gym.name || "Gym" }}</div>
            <div class="gym-hero__copy">
              {{ gym.address || "Address not added yet" }}
            </div>
          </div>
          <div class="gym-hero__meta">
            <span class="gym-pill">{{ gym.status || "Active" }}</span>
            <span class="gym-pill" v-if="createdDateLabel">
              Added {{ createdDateLabel }}
            </span>
          </div>
        </div>
      </section>

      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">At A Glance</div>
            <h2 class="section-title">Fast admin scan</h2>
            <p class="section-copy">
              These quick markers show completeness fast.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="error"
          title="Details unavailable"
          :copy="error"
          icon="mdi-alert-circle-outline"
          tone="error"
        />
        <StateBlock
          v-else-if="loading"
          title="Loading scan view"
          copy="Preparing the quick summary now."
          icon="mdi-timer-sand"
        />
        <div v-else-if="gym" class="gym-metrics">
          <div class="gym-metric">
            <div class="gym-metric__value">{{ serviceCount }}</div>
            <div class="gym-metric__label">Services listed</div>
          </div>
          <div class="gym-metric">
            <div class="gym-metric__value">{{ hasAddress ? "Yes" : "No" }}</div>
            <div class="gym-metric__label">Address saved</div>
          </div>
          <div class="gym-metric">
            <div class="gym-metric__value">{{ hasContact ? "Yes" : "No" }}</div>
            <div class="gym-metric__label">Contact saved</div>
          </div>
        </div>
      </section>
    </div>

    <section class="admin-surface admin-panel" style="margin-top: 20px">
      <div class="section-header">
        <div>
          <div class="table-overline">Profile Fields</div>
          <h2 class="section-title">Everything currently on file</h2>
        </div>
      </div>

      <StateBlock
        v-if="!loading && !error && !gym"
        title="No gym loaded"
        copy="Pick a valid gym from the dashboard to view its details here."
        icon="mdi-domain"
      />
      <div v-else-if="gym" class="detail-grid">
        <div class="detail-card">
          <div class="detail-card__label">Name</div>
          <div class="detail-card__value">{{ gym.name || "Not provided" }}</div>
        </div>
        <div class="detail-card">
          <div class="detail-card__label">Email</div>
          <div class="detail-card__value">{{ gym.email || "Not provided" }}</div>
        </div>
        <div class="detail-card">
          <div class="detail-card__label">Address</div>
          <div class="detail-card__value">{{ gym.address || "Not provided" }}</div>
        </div>
        <div class="detail-card">
          <div class="detail-card__label">Contact</div>
          <div class="detail-card__value">
            {{ gym.contactNumber || gym.phone || "Not provided" }}
          </div>
        </div>
        <div class="detail-card detail-card--wide">
          <div class="detail-card__label">Services</div>
          <div class="detail-card__value">{{ formattedServices }}</div>
        </div>
      </div>
    </section>
  </AdminShell>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import AdminShell from "../components/AdminShell.vue";
import StateBlock from "../components/StateBlock.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, clearAdminSession } from "../lib/api";

const route = useRoute();
const router = useRouter();
const gym = ref(null);
const loading = ref(false);
const error = ref("");
const { isDark, toggleTheme } = useAdminTheme();

const formattedServices = computed(() => {
  if (!gym.value?.services?.length) {
    return "Not provided";
  }

  return Array.isArray(gym.value.services)
    ? gym.value.services.join(", ")
    : gym.value.services;
});

const serviceCount = computed(() =>
  Array.isArray(gym.value?.services) ? gym.value.services.length : 0,
);
const hasAddress = computed(() => Boolean(gym.value?.address));
const hasContact = computed(() =>
  Boolean(gym.value?.contactNumber || gym.value?.phone),
);
const initials = computed(() =>
  String(gym.value?.name || "GymMate")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || "")
    .join(""),
);
const createdDateLabel = computed(() => {
  const raw = gym.value?.createdAt;
  if (!raw) return "";
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleDateString("en-GB");
});

async function fetchGym() {
  loading.value = true;
  error.value = "";
  gym.value = null;

  try {
    const id = route.params.id;
    const res = await apiFetch(`/api/gym/${id}`);
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Gym not found");
    }
    gym.value = data;
  } catch (err) {
    error.value = err?.message || "We could not load this gym right now.";
  } finally {
    loading.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(fetchGym);
</script>

<style scoped>
.gym-hero {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 18px;
  align-items: center;
  padding: 22px;
  border-radius: 28px;
}

.gym-hero__badge {
  width: 68px;
  height: 68px;
  border-radius: 22px;
  display: grid;
  place-items: center;
  background: linear-gradient(135deg, rgba(248, 216, 75, 0.9), rgba(181, 159, 91, 0.8));
  color: #1f1406;
  font-size: 1.25rem;
  font-weight: 800;
}

.gym-hero__title {
  font-size: 1.6rem;
  font-weight: 700;
}

.gym-hero__copy {
  margin-top: 6px;
  color: var(--gm-text-muted);
}

.gym-hero__meta {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
}

.gym-pill {
  padding: 8px 14px;
  border-radius: 999px;
  background: rgba(248, 216, 75, 0.12);
  color: var(--gm-accent);
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.gym-metrics {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.gym-metric {
  padding: 18px;
  border-radius: 24px;
  border: 1px solid rgba(181, 159, 91, 0.16);
  background: rgba(255, 255, 255, 0.02);
}

.gym-metric__value {
  font-size: 1.8rem;
  font-weight: 700;
}

.gym-metric__label {
  margin-top: 8px;
  color: var(--gm-text-muted);
}

.detail-card--wide {
  grid-column: 1 / -1;
}

@media (max-width: 960px) {
  .gym-hero {
    grid-template-columns: 1fr;
  }

  .gym-hero__meta {
    justify-content: flex-start;
  }

  .gym-metrics {
    grid-template-columns: 1fr;
  }
}
</style>
