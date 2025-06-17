import { createRouter, createWebHistory } from 'vue-router'
import HomePage from '../views/HomePage.vue'
import LoginPage from '../views/LoginPage.vue'
import RegisterGym from '../views/RegisterGym.vue'
import AdminDashboard from '../views/AdminDashboard.vue'


const routes = [
  {
    path: '/',
    name: 'Home',
    component: HomePage
  },
  {
    path: '/login',
    name: 'Login',
    component: LoginPage
  },
  {
    path: '/register-gym',
    name: 'RegisterGym',
    component: RegisterGym
  },
  {
    path: '/admin',
    name: 'AdminDashboard',
    component: () => import('../views/AdminDashboard.vue')
  },
  {
  path: '/manage-members',
  name: 'ManageMembers',
  component: () => import('../views/ManageMembers.vue')
}
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router