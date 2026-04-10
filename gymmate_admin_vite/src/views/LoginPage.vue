<template>
  <PublicAuthShell :is-dark="isDark" @toggle-theme="toggleTheme">
    <template #hero>
      <div class="stack">
        <div>
          <div class="eyebrow">Owner & Admin Login</div>
          <h1 class="display-headline">
            Step into your GymMate workspace.
          </h1>
          <p class="lead-copy">
            Sign in to review your gym, support members, or manage the network.
          </p>
        </div>

        <div class="landing-media">
          <video
            autoplay
            muted
            loop
            playsinline
            :poster="`${assetBase}images/gymbghomepagelight.png`"
          >
            <source
              :src="`${assetBase}videos/gym_pool_cafe.mp4`"
              type="video/mp4"
            />
          </video>
        </div>
      </div>
    </template>

    <div class="stack">
      <div>
        <div class="eyebrow">Login</div>
        <h2 class="section-title">Welcome back</h2>
        <p class="section-copy">
          Use your account details to enter the dashboard.
        </p>
      </div>

      <v-form class="stack" @submit.prevent="submit">
        <div>
          <div class="field-label">Email</div>
          <v-text-field
            v-model="form.email"
            density="comfortable"
            hide-details="auto"
            placeholder="admin@gymmate.com"
            type="email"
            variant="outlined"
            required
          />
        </div>

        <div>
          <div class="field-label">Password</div>
          <v-text-field
            v-model="form.password"
            :append-inner-icon="showPassword ? 'mdi-eye-off' : 'mdi-eye'"
            :type="showPassword ? 'text' : 'password'"
            density="comfortable"
            hide-details="auto"
            placeholder="Enter your password"
            variant="outlined"
            @click:append-inner="showPassword = !showPassword"
            required
          />
        </div>

        <div class="cta-row">
          <v-btn
            color="primary"
            size="large"
            type="submit"
            :loading="submitting"
            >Login</v-btn
          >
          <v-btn
            size="large"
            variant="tonal"
            @click="router.push('/register-gym')"
            >Register Gym</v-btn
          >
        </div>
      </v-form>
    </div>

    <v-snackbar v-model="snackbar" :color="snackbarColor" timeout="4000">
      {{ snackbarText }}
    </v-snackbar>
  </PublicAuthShell>
</template>

<script setup>
import { onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import PublicAuthShell from "../components/PublicAuthShell.vue";
import { useAdminTheme } from "../composables/useAdminTheme";
import { apiFetch, hasWorkspaceAccess, normalizeRole, setAdminSession } from "../lib/api";

const assetBase = import.meta.env.BASE_URL;
const route = useRoute();
const router = useRouter();
const form = ref({ email: "", password: "" });
const showPassword = ref(false);
const snackbar = ref(false);
const snackbarText = ref("");
const snackbarColor = ref("");
const submitting = ref(false);
const { isDark, toggleTheme } = useAdminTheme();

function showMessage(message, color = "success") {
  snackbarText.value = message;
  snackbarColor.value = color;
  snackbar.value = true;
}

async function submit() {
  submitting.value = true;

  try {
    const res = await apiFetch("/api/auth/login", {
      method: "POST",
      body: JSON.stringify(form.value),
      skipAuth: true,
    });
    const data = await res.json();

    if (res.ok) {
      const normalizedRole = normalizeRole(
        data.user?.normalizedRole || data.user?.role,
      );
      if (!hasWorkspaceAccess(normalizedRole)) {
        showMessage(
          "This login does not have access to the web workspace.",
          "error",
        );
        return;
      }

      setAdminSession(data);
      showMessage("Login successful");
      router.push("/dashboard");
    } else {
      showMessage(data.message || "Login failed", "error");
    }
  } catch {
    showMessage("Something went wrong. Please try again.", "error");
  } finally {
    submitting.value = false;
  }
}

onMounted(() => {
  const presetEmail = String(route.query.email || "").trim();
  if (presetEmail && !form.value.email) {
    form.value.email = presetEmail;
  }
});
</script>
