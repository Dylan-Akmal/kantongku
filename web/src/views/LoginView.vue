<script setup>
import { reactive, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'
import AuthCard from '@/components/AuthCard.vue'
import { useAuthStore } from '@/stores/auth'
import { errorMessage, validationErrors } from '@/api/http'

const auth = useAuthStore()
const router = useRouter()

const form = reactive({ email: '', password: '' })
const loading = ref(false)
const error = ref('')
const errors = ref({})

async function submit() {
  loading.value = true
  error.value = ''
  errors.value = {}

  try {
    await auth.login(form)
    router.push({ name: 'dashboard' })
  } catch (e) {
    error.value = errorMessage(e, 'Gagal masuk. Coba lagi.')
    errors.value = validationErrors(e)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Masuk" subtitle="Masuk untuk melihat dompet dan grup patunganmu.">
    <form class="space-y-4" @submit.prevent="submit">
      <div
        v-if="error"
        class="rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
      >
        {{ error }}
      </div>

      <div>
        <label class="label" for="email">Email</label>
        <input
          id="email"
          v-model="form.email"
          type="email"
          class="input"
          autocomplete="email"
          required
        />
        <p v-if="errors.email" class="field-error">{{ errors.email[0] }}</p>
      </div>

      <div>
        <label class="label" for="password">Kata sandi</label>
        <input
          id="password"
          v-model="form.password"
          type="password"
          class="input"
          autocomplete="current-password"
          required
        />
        <p v-if="errors.password" class="field-error">{{ errors.password[0] }}</p>
      </div>

      <button type="submit" class="btn-primary w-full" :disabled="loading">
        {{ loading ? 'Memproses...' : 'Masuk' }}
      </button>
    </form>

    <template #footer>
      Belum punya akun?
      <RouterLink to="/register" class="font-medium text-emerald-700 hover:underline">
        Daftar
      </RouterLink>
    </template>
  </AuthCard>
</template>