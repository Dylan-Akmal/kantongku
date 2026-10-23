<script setup>
import { onMounted, ref, watch } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import http, { errorMessage } from '@/api/http'
import GroupMembersPanel from '@/components/GroupMembersPanel.vue'
import { roleLabels } from '@/utils/groups'

const route = useRoute()

const group = ref(null)
const loading = ref(true)
const notFound = ref(false)
const error = ref('')

async function load() {
  if (!route.params.id) return

  // Spinner hanya pada pemuatan pertama, supaya panel tidak berkedip saat data disegarkan.
  if (!group.value) loading.value = true
  error.value = ''
  notFound.value = false

  try {
    const { data } = await http.get(`/groups/${route.params.id}`)
    group.value = data.data
  } catch (e) {
    group.value = null
    if (e.response?.status === 404) {
      notFound.value = true
    } else {
      error.value = errorMessage(e, 'Gagal memuat grup.')
    }
  } finally {
    loading.value = false
  }
}

onMounted(load)

watch(
  () => route.params.id,
  () => {
    group.value = null
    load()
  },
)
</script>

<template>
  <div>
    <RouterLink to="/groups" class="text-sm text-slate-500 hover:text-emerald-700">
      ← Semua grup
    </RouterLink>

    <p v-if="loading" class="mt-5 text-sm text-slate-500">Memuat...</p>

    <div v-else-if="notFound" class="card mt-5">
      <p class="font-medium">Grup tidak ditemukan</p>
      <p class="mt-1 text-sm text-slate-500">
        Grup ini tidak ada, atau kamu bukan anggotanya.
      </p>
    </div>

    <p
      v-else-if="error"
      class="mt-5 rounded-lg border border-rose-200 bg-rose-50 px-3 py-2 text-sm text-rose-700"
    >
      {{ error }}
    </p>

    <template v-else-if="group">
      <div class="mt-3 flex flex-wrap items-center gap-3">
        <h1 class="text-xl font-bold">{{ group.name }}</h1>
        <span class="badge">{{ roleLabels[group.my_role] }}</span>
      </div>
      <p class="text-sm text-slate-500">
        {{ group.member_count }} anggota · Pemilik: {{ group.owner?.name }}
      </p>

      <div class="mt-5">
        <GroupMembersPanel :group="group" @changed="load" />
      </div>
    </template>
  </div>
</template>