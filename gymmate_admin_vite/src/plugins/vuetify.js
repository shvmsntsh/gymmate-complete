import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import { aliases, mdi } from 'vuetify/iconsets/mdi'

const saved = localStorage.getItem('gymmate_theme')
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
const defaultTheme = saved || (prefersDark ? 'dark' : 'light')

const vuetify = createVuetify({
  icons: { defaultSet: 'mdi', aliases, sets: { mdi } },
  theme: {
    defaultTheme,
    themes: {
      light: {
        dark: false,
        colors: {
          background: '#FDF8F6',
          surface: '#FFFFFF',
          'surface-bright': '#ffffff',
          primary: '#FF5200',
          secondary: '#2C2C2E',
          accent: '#FFB59D',
          error: '#BA1A1A',
          success: '#1E8E4E',
          warning: '#B86B00',
          info: '#2563EB',
          outline: '#E7D9D4',
          'on-surface': '#2C2C2E',
        },
      },
      dark: {
        dark: true,
        colors: {
          background: '#131314',
          surface: '#201F20',
          'surface-bright': '#2A2A2B',
          primary: '#FFB59D',
          secondary: '#E5E2E3',
          accent: '#FF5200',
          error: '#FFB4AB',
          success: '#7DDC9A',
          warning: '#FFD08A',
          info: '#A7C7FF',
          outline: '#5C4037',
          'on-surface': '#E5E2E3',
        },
      },
    },
  },
})

export default vuetify
