import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { guest: true },
  },
  {
    path: '/register',
    name: 'register',
    component: () => import('@/views/RegisterView.vue'),
    meta: { guest: true },
  },
  {
    path: '/',
    component: () => import('@/layouts/AppLayout.vue'),
    meta: { auth: true },
    children: [
      {
        path: '',
        name: 'dashboard',
        component: () => import('@/views/DashboardView.vue'),
      },
      {
        path: 'transactions',
        name: 'transactions',
        component: () => import('@/views/TransactionsView.vue'),
      },
      {
        path: 'budgets',
        name: 'budgets',
        component: () => import('@/views/BudgetsView.vue'),
      },
      {
        path: 'reports',
        name: 'reports',
        component: () => import('@/views/ReportsView.vue'),
      },
      {
        path: 'wallets',
        name: 'wallets',
        component: () => import('@/views/WalletsView.vue'),
      },
      {
        path: 'categories',
        name: 'categories',
        component: () => import('@/views/CategoriesView.vue'),
      },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach((to) => {
  const auth = useAuthStore()

  if (to.meta.auth && !auth.isLoggedIn) {
    return { name: 'login' }
  }

  if (to.meta.guest && auth.isLoggedIn) {
    return { name: 'dashboard' }
  }
})

export default router