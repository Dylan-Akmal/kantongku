<script setup>
import { onMounted } from 'vue'
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()

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
    </header>

    <main class="mx-auto max-w-6xl px-4 py-6">
      <RouterView />
    </main>
  </div>
</template>