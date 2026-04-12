<template>
  <AdminShell
    :is-dark="isDark"
    title="Announcements"
    eyebrow="Member Communication"
    description="Send low-cost in-app announcements with one shared image asset."
    @toggle-theme="toggleTheme"
    @logout="logout"
  >
    <section class="admin-surface admin-panel">
      <div class="section-header">
        <div>
          <div class="table-overline">Broadcast Composer</div>
          <h2 class="section-title">Offers, holiday notes, and updates</h2>
          <p class="section-copy">
            Images are deduplicated and stored once, then reused for all member deliveries.
          </p>
        </div>
      </div>

      <StateBlock
        v-if="error"
        title="Could not load announcements"
        :copy="error"
        icon="mdi-alert-circle-outline"
        tone="error"
      />

      <div class="announcement-form-grid">
        <v-text-field v-model="form.title" label="Title" variant="outlined" />
        <v-select
          v-model="form.type"
          :items="typeOptions"
          label="Type"
          variant="outlined"
        />
        <v-select
          v-model="form.audienceScope"
          :items="audienceOptions"
          label="Audience"
          variant="outlined"
        />
        <v-file-input
          v-model="selectedImage"
          accept="image/*"
          label="Image (optional, max 1 MB)"
          variant="outlined"
          prepend-icon="mdi-image-outline"
        />
      </div>

      <v-textarea
        v-model="form.body"
        label="Message"
        variant="outlined"
        auto-grow
        rows="4"
      />

      <div class="cta-row">
        <v-btn color="primary" :loading="saving" @click="submitAnnouncement">
          Send announcement
        </v-btn>
        <v-btn variant="tonal" @click="fetchAnnouncements">Refresh</v-btn>
      </div>

      <div class="section-header section-header--spaced">
        <div>
          <div class="table-overline">Recent Broadcasts</div>
          <h2 class="section-title">Sent announcements</h2>
        </div>
      </div>

      <StateBlock
        v-if="!loading && announcements.length === 0"
        title="No announcements yet"
        copy="Your sent campaigns will appear here with audience and delivery counts."
        icon="mdi-bullhorn-outline"
      />

      <div v-else class="conversation-list">
        <div
          v-for="announcement in announcements"
          :key="announcement.id"
          class="conversation-card"
        >
          <div class="conversation-topline">
            <span class="conversation-name">{{ announcement.title }}</span>
            <v-chip size="small" variant="tonal" color="primary">
              {{ announcement.type }}
            </v-chip>
          </div>
          <div class="conversation-preview">{{ announcement.body }}</div>
          <div v-if="announcement.mediaAssetId && getAnnouncementImageUrl(announcement.mediaAssetId)" class="announcement-image-preview">
            <img :src="getAnnouncementImageUrl(announcement.mediaAssetId)" :alt="announcement.title" />
          </div>
          <div class="announcement-meta">
            <span>{{ formatAudience(announcement.audience?.scope) }}</span>
            <span>{{ announcement.deliverySummary?.targetedCount || 0 }} members</span>
            <span>{{ formatDate(announcement.sentAt) }}</span>
          </div>
        </div>
      </div>
    </section>
  </AdminShell>
</template>

<script setup>
import { onMounted, ref } from "vue";
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
const selectedImage = ref(null);
const announcements = ref([]);
const imageCache = ref({});
const form = ref({
  title: "",
  body: "",
  type: "general",
  audienceScope: "all",
});

const typeOptions = [
  { title: "General", value: "general" },
  { title: "Offer", value: "offer" },
  { title: "Holiday", value: "holiday" },
];

const audienceOptions = [
  { title: "All members", value: "all" },
  { title: "Active members", value: "active" },
  { title: "Inactive members", value: "inactive" },
];

function logout() {
  clearAdminSession();
  router.push("/login");
}

function formatAudience(scope) {
  return {
    all: "All members",
    active: "Active members",
    inactive: "Inactive members",
    selected: "Selected members",
  }[scope] || "Audience";
}

function formatDate(value) {
  if (!value) return "Just now";
  return new Date(value).toLocaleString("en-GB");
}

async function fileToPayload(file) {
  if (!file) return {};
  const buffer = await file.arrayBuffer();
  let binary = "";
  const bytes = new Uint8Array(buffer);
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return {
    imageBase64: btoa(binary),
    imageContentType: file.type || "image/png",
    imageFileName: file.name || "announcement-image",
  };
}

async function fetchAnnouncements() {
  loading.value = true;
  error.value = "";
  try {
    const res = await apiFetch("/api/owner/announcements");
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Could not load announcements.");
    }
    announcements.value = data.announcements || [];
    for (const ann of data.announcements || []) {
      if (ann.mediaAssetId && !imageCache.value[ann.mediaAssetId]) {
        loadAnnouncementImage(ann.mediaAssetId);
      }
    }
  } catch (err) {
    error.value = err?.message || "Could not load announcements.";
  } finally {
    loading.value = false;
  }
}

async function loadAnnouncementImage(assetId) {
  if (imageCache.value[assetId]) return;
  try {
    const res = await apiFetch(`/api/owner/assets/${assetId}`);
    if (res.ok) {
      const blob = await res.blob();
      imageCache.value[assetId] = URL.createObjectURL(blob);
    }
  } catch {
    imageCache.value[assetId] = null;
  }
}

function getAnnouncementImageUrl(assetId) {
  return imageCache.value[assetId] || null;
}

async function submitAnnouncement() {
  saving.value = true;
  error.value = "";
  try {
    const imageFile = Array.isArray(selectedImage.value)
      ? selectedImage.value[0]
      : selectedImage.value;
    const imagePayload = await fileToPayload(imageFile);
    const res = await apiFetch("/api/owner/announcements", {
      method: "POST",
      body: JSON.stringify({
        ...form.value,
        ...imagePayload,
      }),
    });
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.message || "Could not send announcement.");
    }
    form.value = {
      title: "",
      body: "",
      type: "general",
      audienceScope: "all",
    };
    selectedImage.value = null;
    await fetchAnnouncements();
  } catch (err) {
    error.value = err?.message || "Could not send announcement.";
  } finally {
    saving.value = false;
  }
}

onMounted(fetchAnnouncements);
</script>

<style scoped>
.announcement-form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 12px;
}

.announcement-meta {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  margin-top: 10px;
  font-size: 13px;
  opacity: 0.78;
}

.announcement-image-preview {
  margin-top: 12px;
  max-width: 200px;
  border-radius: 8px;
  overflow: hidden;
}

.announcement-image-preview img {
  width: 100%;
  height: auto;
  display: block;
  object-fit: cover;
}

.section-header--spaced {
  margin-top: 28px;
}

@media (max-width: 820px) {
  .announcement-form-grid {
    grid-template-columns: 1fr;
  }
}
</style>
