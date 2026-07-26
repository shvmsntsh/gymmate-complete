import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vuetify from 'vite-plugin-vuetify'

export default defineConfig({
  base: process.env.VITE_PUBLIC_BASE || '/',
  define: {
    __APP_BUILD_TIME__: JSON.stringify(process.env.VITE_BUILD_TIME || new Date().toISOString()),
  },
  plugins: [
    vue(),
    vuetify({
      autoImport: true,
      styles: 'expose',
    }),
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('chart.js')) {
            return 'charts'
          }

          if (id.includes('vuetify')) {
            return 'vuetify'
          }

          if (id.includes('node_modules/vue') || id.includes('node_modules/vue-router')) {
            return 'vue-core'
          }
        },
      },
    },
  },
})
