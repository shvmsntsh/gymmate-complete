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
          background: '#f4efe6',
          surface: '#fffaf3',
          'surface-bright': '#ffffff',
          primary: '#b58b4d',
          secondary: '#244645',
          accent: '#eecc75',
          error: '#c25c4a',
          success: '#2f7c63',
          warning: '#d89e45',
          info: '#366f7d',
          outline: '#d9c7ab',
          'on-surface': '#201a15',
        },
      },
      dark: {
        dark: true,
        colors: {
          background: '#120f0c',
          surface: '#1b1714',
          'surface-bright': '#231f1b',
          primary: '#e0ba73',
          secondary: '#7dc8bf',
          accent: '#f0ce7a',
          error: '#f08b73',
          success: '#73d3ae',
          warning: '#f3b968',
          info: '#8ecfe0',
          outline: '#4d4339',
          'on-surface': '#f8f1e6',
        },
      },
    },
  },
})

export default vuetify
