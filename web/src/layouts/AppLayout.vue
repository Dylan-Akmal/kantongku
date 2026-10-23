<script setup>
import { onMounted } from 'vue'
import { RouterLink, RouterView, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const navItems = [
  { to: '/', label: 'Dashboard' },
  { to: '/transactions', label: 'Transaksi' },
  { to: '/wallets', label: 'Dompet' },
  { to: '/categories', label: 'Kategori' },
]

function isActive(item) {
  return item.to === '/' ? route.path === '/' : route.path.startsWith(item.to)
}

onMounted(() => {
  // Segarkan data pengguna; bila token sudah tidak berlaku, klien HTTP otomatis mengarahkan ke login.
  auth.fetchMe().catch(() => {})
})

async function logout() {
  await auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 text-slate-800">
    <header class="border-b border-slate-200 bg-white">
      <div class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 py-3">
        <RouterLink to="/" class="flex items-center gap-2 text-lg font-bold text-emerald-700">
          <span>👛</span>
          Kantongku
        </RouterLink>

        <div class="flex items-center gap-3 text-sm">
          <span class="hidden text-slate-500 sm:inline">{{ auth.user?.name }}</span>
          <button class="btn-secondary" @click="logout">Keluar</button>
        </div>
      </div>

      <nav class="border-t border-slate-100">
        <div class="mx-auto flex max-w-6xl gap-1 overflow-x-auto px-4 text-sm">
          <RouterLink
            v-for="item in navItems"
            :key="item.to"
            :to="item.to"
            class="whitespace-nowrap border-b-2 px-3 py-2.5 font-medium transition"
            :class="
              isActive(item)
                ? 'border-emerald-600 text-emerald-700'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            "
          >
            {{ item.label }}
          </RouterLink>
        </div>
      </nav>
    </header>

    <main class="mx-auto max-w-6xl px-4 py-6">
      <RouterView />
    </main>
  </div>
</template>