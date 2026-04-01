import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useTheme } from 'vuetify'

const THEME_KEY = 'gymmate_theme'

function getPreferredTheme() {
  if (typeof window === 'undefined') {
    return 'light'
  }

  const saved = localStorage.getItem(THEME_KEY)
  if (saved === 'light' || saved === 'dark') {
    return saved
  }

  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}

export function useAdminTheme() {
  const theme = useTheme()
  const themeName = ref(getPreferredTheme())
  let mediaQuery = null
  let mediaListener = null

  const isDark = computed(() => themeName.value === 'dark')

  const setTheme = (nextTheme, { persist = true } = {}) => {
    themeName.value = nextTheme
    theme.global.name.value = nextTheme

    if (persist && typeof window !== 'undefined') {
      localStorage.setItem(THEME_KEY, nextTheme)
    }
  }

  const toggleTheme = () => {
    setTheme(isDark.value ? 'light' : 'dark')
  }

  onMounted(() => {
    setTheme(themeName.value, { persist: false })

    if (typeof window === 'undefined') {
      return
    }

    mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
    mediaListener = (event) => {
      const saved = localStorage.getItem(THEME_KEY)
      if (!saved) {
        setTheme(event.matches ? 'dark' : 'light', { persist: false })
      }
    }

    if (mediaQuery.addEventListener) {
      mediaQuery.addEventListener('change', mediaListener)
    } else {
      mediaQuery.addListener(mediaListener)
    }
  })

  onBeforeUnmount(() => {
    if (!mediaQuery || !mediaListener) {
      return
    }

    if (mediaQuery.removeEventListener) {
      mediaQuery.removeEventListener('change', mediaListener)
    } else {
      mediaQuery.removeListener(mediaListener)
    }
  })

  return {
    isDark,
    setTheme,
    themeName,
    toggleTheme,
  }
}
