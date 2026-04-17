<template>
  <AdminShell
    :is-dark="isDark"
    title="Brand Studio"
    eyebrow="Gym Identity"
    description="Shape the gym name and logo your members see throughout GymMate."
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
              Add your gym name and logo to personalize the experience for your members.
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
              <div class="field-label">Logo</div>
              <div class="logo-upload">
                <input
                  ref="logoInput"
                  type="file"
                  accept="image/png,image/jpeg,image/webp"
                  class="logo-upload__input"
                  @change="handleLogoUpload"
                />
                <div
                  v-if="!form.logoUrl"
                  class="logo-upload__placeholder"
                  @click="logoInput?.click()"
                >
                  <v-icon size="32" color="grey">mdi-image-plus</v-icon>
                  <span>Click to add logo</span>
                </div>
                <div v-else class="logo-upload__preview">
                  <img :src="form.logoUrl" alt="Logo preview" class="logo-upload__image" />
                  <button type="button" class="logo-upload__remove" @click="removeLogo">
                    <v-icon size="16">mdi-close</v-icon>
                  </button>
                </div>
              </div>
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
        <div v-else class="brand-preview">
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
import { apiFetch, clearAdminSession, getAdminSession, setAdminSession } from "../lib/api";

const router = useRouter();
const { isDark, toggleTheme } = useAdminTheme();
const loading = ref(false);
const saving = ref(false);
const error = ref("");
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("success");
const logoInput = ref(null);
const form = ref({
  gymName: "",
  logoUrl: "",
});
const BRANDING_UPDATED_EVENT = "gymmate-branding-updated";
const maxLogoBytes = 1024 * 1024;
const allowedLogoExtensions = new Set([
  "png",
  "jpg",
  "jpeg",
  "jfif",
  "pjpeg",
  "pjp",
  "webp",
]);

const initials = computed(() =>
  String(form.value.gymName || "GymMate")
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() || "")
    .join(""),
);

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

function clearLogoInput(event) {
  if (event?.target) {
    event.target.value = "";
  }
}

function handleLogoUpload(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  if (file.size > maxLogoBytes) {
    clearLogoInput(event);
    showMessage("Please keep the logo under 1 MB.", "error");
    return;
  }

  const extension = file.name.split(".").pop()?.toLowerCase() || "";
  const isAllowedExtension = allowedLogoExtensions.has(extension);
  const isAllowedMimeType = ["image/png", "image/jpeg", "image/webp"].includes(
    file.type.toLowerCase(),
  );
  if (!isAllowedExtension && !isAllowedMimeType) {
    clearLogoInput(event);
    showMessage(
      "Please choose an image file like PNG, JPG, JPEG, JFIF, or WebP.",
      "error",
    );
    return;
  }

  const reader = new FileReader();
  reader.onload = (e) => {
    form.value.logoUrl = e.target?.result || "";
  };
  reader.onerror = () => {
    showMessage("Failed to read image file.", "error");
  };
  reader.readAsDataURL(file);
}

function removeLogo() {
  form.value.logoUrl = "";
  if (logoInput.value) {
    logoInput.value.value = "";
  }
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
        logoScale: 1,
        logoOffsetX: 0,
        logoOffsetY: 0,
      }),
    });
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "We could not save branding right now.");
    }

    const branding = data.branding || {};
    form.value = {
      gymName: branding.gymName || form.value.gymName.trim(),
      logoUrl: branding.logoUrl || "",
    };

    const session = getAdminSession();
    if (session?.user) {
      setAdminSession({
        ...session,
        user: {
          ...session.user,
          gymName: form.value.gymName,
          name: session.user.name || form.value.gymName,
          branding,
        },
      });
    }

    window.dispatchEvent(
      new CustomEvent(BRANDING_UPDATED_EVENT, { detail: { branding } }),
    );
    showMessage("Branding updated successfully.");
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

<style scoped>
.logo-upload {
  position: relative;
}

.logo-upload__input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
  overflow: hidden;
}

.logo-upload__placeholder {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 120px;
  border: 2px dashed var(--gm-border, #e0dcd6);
  border-radius: 8px;
  cursor: pointer;
  color: #6b6560;
  transition: border-color 0.2s, background-color 0.2s;
}

.logo-upload__placeholder:hover {
  border-color: var(--gm-primary, #b59f5b);
  background-color: rgba(181, 159, 91, 0.05);
}

.logo-upload__preview {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 120px;
  border: 1px solid var(--gm-border, #e0dcd6);
  border-radius: 8px;
  background: var(--gm-surface-muted, #f7f5f1);
  overflow: hidden;
}

.logo-upload__image {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
}

.logo-upload__remove {
  position: absolute;
  top: 8px;
  right: 8px;
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.6);
  border: none;
  border-radius: 50%;
  color: white;
  cursor: pointer;
}

.logo-upload__remove:hover {
  background: rgba(0, 0, 0, 0.8);
}
</style>
