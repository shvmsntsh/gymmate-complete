<template>
  <PublicAuthShell :is-dark="isDark" variant="login" @toggle-theme="toggleTheme">
    <template #hero>
      <h1 class="display-headline">
        Run every gym day clearly.
      </h1>
      <p class="lead-copy">
        Front desk, memberships, payments, attendance, staff, and classes in one workspace.
      </p>
    </template>
    <template #hero-meta>
      <div class="login-hero-chips" aria-label="GymMate admin focus areas">
        <span>Front desk</span>
        <span>Memberships</span>
        <span>Payments</span>
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
          <div class="field-label">Email or Indian phone number</div>
          <v-text-field
            v-model="form.email"
            density="comfortable"
            hide-details="auto"
            placeholder="admin@gymmate.com or +919876543210"
            type="text"
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
        <div class="login-helper-row">
          <v-btn variant="text" size="small" @click="router.push('/forgot-password')">
            Forgot password?
          </v-btn>
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
import { apiFetch, getAdminDefaultRoute, hasWorkspaceAccess, setAdminSession } from "../lib/api";

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
      if (!hasWorkspaceAccess(data)) {
        showMessage(
          "This login does not have access to the web workspace.",
          "error",
        );
        return;
      }

      setAdminSession(data);
      showMessage("Login successful");
      router.push(getAdminDefaultRoute(data));
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

<style scoped>
.login-helper-row {
  display: flex;
  justify-content: flex-end;
  margin-top: -6px;
}
</style>
