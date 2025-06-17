import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import { aliases, mdi } from 'vuetify/iconsets/mdi'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'

// ---------- Add / replace after imports ----------
const saved = localStorage.getItem('theme')
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
const defaultTheme = saved || (prefersDark ? 'dark' : 'light')

const vuetify = createVuetify({
  components,
  directives,
  icons: { defaultSet: 'mdi', aliases, sets: { mdi } },
  theme: {
    defaultTheme,
    themes: {
      light: { dark: false, colors: { background: '#fff', surface: '#fff', primary: '#4A90E2', secondary: '#03DAC6' }},
      dark:  { dark:  true, colors: { background: '#121212', surface: '#1E1E1E', primary: '#BB86FC', secondary: '#03DAC6' }},
    },
  },
})

export default vuetify