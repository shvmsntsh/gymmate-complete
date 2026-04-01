<template>
  <AdminShell
    :is-dark="isDark"
    title="Brand Studio"
    eyebrow="Gym Identity"
    description="Shape the gym name, logo, and accent colors your members see throughout GymMate."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <div class="overview-grid">
      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Brand Details</div>
            <h2 class="section-title">Keep your gym identity polished</h2>
            <p class="section-copy">
              A few small adjustments here give your members a more familiar,
              more personal experience every time they open the app.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="error"
          title="Could not load branding"
          :copy="error"
          icon="mdi-palette-outline"
          tone="error"
        />

        <v-form v-else class="stack" @submit.prevent="saveBranding">
          <div class="form-grid">
            <div class="form-grid__full">
              <div class="field-label">Gym Name</div>
              <v-text-field
                v-model="form.gymName"
                density="comfortable"
                hide-details="auto"
                placeholder="Your gym name"
                variant="outlined"
              />
            </div>
            <div class="form-grid__full">
              <div class="field-label">Logo URL</div>
              <v-text-field
                v-model="form.logoUrl"
                density="comfortable"
                hide-details="auto"
                placeholder="Optional logo image URL"
                variant="outlined"
              />
            </div>
            <div>
              <div class="field-label">Primary Color</div>
              <v-text-field
                v-model="form.primaryColor"
                density="comfortable"
                hide-details="auto"
                placeholder="#B59F5B"
                variant="outlined"
              />
            </div>
            <div>
              <div class="field-label">Secondary Color</div>
              <v-text-field
                v-model="form.secondaryColor"
                density="comfortable"
                hide-details="auto"
                placeholder="#F8D84B"
                variant="outlined"
              />
            </div>
          </div>

          <div class="cta-row">
            <v-btn
              color="primary"
              size="large"
              type="submit"
              :loading="saving || loading"
              >Save branding</v-btn
            >
            <v-btn size="large" variant="tonal" @click="fetchBranding"
              >Refresh</v-btn
            >
          </div>
        </v-form>
      </section>

      <section class="admin-surface admin-panel overview-card">
        <div class="section-header">
          <div>
            <div class="table-overline">Preview</div>
            <h2 class="section-title">How your gym comes through</h2>
            <p class="section-copy">
              This preview keeps the shared GymMate system in place while
              letting your gym identity carry the accent.
            </p>
          </div>
        </div>

        <StateBlock
          v-if="loading"
          title="Loading preview"
          copy="Pulling your current branding now."
          icon="mdi-timer-sand"
        />
        <div v-else class="brand-preview" :style="previewStyle">
          <div class="brand-preview__badge">{{ initials }}</div>
          <div>
            <div class="brand-preview__title">
              {{ form.gymName || "Your Gym" }}
            </div>
            <div class="brand-preview__copy">
              A cleaner, calmer GymMate experience with your gym identity on
              top.
            </div>
          </div>
          <div class="brand-preview__swatches">
            <span :style="{ background: sanitizedPrimaryColor }"></span>
            <span :style="{ background: sanitizedSecondaryColor }"></span>
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
import { apiFetch, clearAdminSession } from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const loading = ref(false);
const saving = ref(false);
const error = ref("");
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("success");
const form = ref({
  gymName: "",
  logoUrl: "",
  primaryColor: "#B59F5B",
  secondaryColor: "#F8D84B",
});

const hexPattern = /^#?[0-9A-Fa-f]{6}$/;

const sanitizedPrimaryColor = computed(() => {
  const value = form.value.primaryColor || "#B59F5B";
  return hexPattern.test(value)
    ? value.startsWith("#")
      ? value
      : `#${value}`
    : "#B59F5B";
});

const sanitizedSecondaryColor = computed(() => {
  const value = form.value.secondaryColor || "#F8D84B";
  return hexPattern.test(value)
    ? value.startsWith("#")
      ? value
      : `#${value}`
    : "#F8D84B";
});

const initials = computed(() =>
  String(form.value.gymName || "GymMate")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || "")
    .join(""),
);

const previewStyle = computed(() => ({
  background: `linear-gradient(135deg, ${sanitizedPrimaryColor.value}22, ${sanitizedSecondaryColor.value}18), var(--gm-surface-muted)`,
  borderColor: `${sanitizedPrimaryColor.value}55`,
}));

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

async function fetchBranding() {
  loading.value = true;
  error.value = "";

  try {
    const res = await apiFetch("/api/gym/self");
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "We could not load branding right now.");
    }

    const gym = data.gym || data.member || {};
    form.value = {
      gymName: gym.gymName || gym.name || "",
      logoUrl: gym.branding?.logoUrl || "",
      primaryColor: gym.branding?.primaryColor || "#B59F5B",
      secondaryColor: gym.branding?.secondaryColor || "#F8D84B",
    };
  } catch (err) {
    error.value = err?.message || "We could not load branding right now.";
  } finally {
    loading.value = false;
  }
}

async function saveBranding() {
  if (!form.value.gymName.trim()) {
    showMessage("Add your gym name before saving.", "error");
    return;
  }

  saving.value = true;

  try {
    const res = await apiFetch("/api/gym/branding", {
      method: "PUT",
      body: JSON.stringify({
        gymName: form.value.gymName.trim(),
        logoUrl: form.value.logoUrl.trim(),
        primaryColor: sanitizedPrimaryColor.value,
        secondaryColor: sanitizedSecondaryColor.value,
        logoScale: 1,
        logoOffsetX: 0,
        logoOffsetY: 0,
      }),
    });
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "We could not save branding right now.");
    }

    showMessage("Branding updated successfully.");
    await fetchBranding();
  } catch (err) {
    showMessage(
      err?.message || "We could not save branding right now.",
      "error",
    );
  } finally {
    saving.value = false;
  }
}

function logout() {
  clearAdminSession();
  router.push("/login");
}

onMounted(fetchBranding);
</script>
