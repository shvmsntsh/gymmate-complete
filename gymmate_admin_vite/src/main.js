import { createApp } from 'vue'
import App from './App.vue'
import vuetify from './plugins/vuetify'

// 👇 Import your router (make sure the file exists)
import router from './router'

const app = createApp(App)
app.use(vuetify)
app.use(router) // 👈 Mount the router
app.mount('#app')