<template>
  <v-app :theme="isDark ? 'dark' : 'light'">
    <div :class="['public-shell', `public-shell--${variant}`]">
      <v-container class="public-shell__container">
        <header class="public-shell__nav">
          <button class="public-shell__home" type="button" @click="router.push('/')">
            <AdminBrand
              :tone="isDark ? 'light' : 'default'"
              :wordmark-url="brandWordmark"
              brand-name="GymMate"
              compact
              hide-glyph
            />
          </button>

          <div class="public-shell__nav-actions">
            <div class="public-shell__nav-links">
              <v-btn class="admin-nav-link" variant="text" @click="router.push('/login')">Login</v-btn>
              <v-btn class="admin-nav-link" variant="text" @click="router.push('/register-gym')">Register Gym</v-btn>
            </div>
            <div class="public-shell__nav-tools">
              <v-menu location="bottom end">
                <template #activator="{ props: menuProps }">
                  <v-btn
                    class="public-shell__menu-btn"
                    icon="mdi-menu"
                    variant="text"
                    v-bind="menuProps"
                  />
                </template>
                <v-list class="public-shell__menu" density="comfortable">
                  <v-list-item title="Login" @click="router.push('/login')" />
                  <v-list-item title="Register Gym" @click="router.push('/register-gym')" />
                </v-list>
              </v-menu>
            </div>
          </div>
        </header>

        <div class="public-shell__grid">
          <section class="public-shell__panel admin-surface admin-surface--panel">
            <slot></slot>
          </section>

          <section class="public-shell__hero admin-surface admin-surface--hero">
            <div class="eyebrow">GymMate Admin</div>
            <slot name="hero">
              <h1 class="display-headline">Run your gym clearly.</h1>
              <p class="lead-copy">
                Members, plans, staff, and daily operations in one focused workspace.
              </p>
            </slot>
            <slot name="hero-meta"></slot>
          </section>
        </div>
      </v-container>
    </div>
  </v-app>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import AdminBrand from './AdminBrand.vue'

const props = defineProps({
  isDark: {
    type: Boolean,
    default: false,
  },
  variant: {
    type: String,
    default: 'standard',
  },
})

const router = useRouter()
const assetBase = import.meta.env.BASE_URL
const brandWordmark = computed(() =>
  `${assetBase}images/${props.isDark ? 'gymmate_logo_light.png' : 'gymmate_logo_dark.png'}`,
)
</script>
