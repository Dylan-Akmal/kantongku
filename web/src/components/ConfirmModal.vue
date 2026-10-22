<script setup>
import BaseModal from '@/components/BaseModal.vue'

defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, default: 'Konfirmasi' },
  message: { type: String, required: true },
  confirmText: { type: String, default: 'Ya, lanjutkan' },
  loading: { type: Boolean, default: false },
})

const emit = defineEmits(['confirm', 'cancel'])
</script>

<template>
  <BaseModal :open="open" :title="title" @close="emit('cancel')">
    <p class="text-sm text-slate-600">{{ message }}</p>
    <div class="mt-5 flex justify-end gap-2">
      <button type="button" class="btn-secondary" :disabled="loading" @click="emit('cancel')">
        Batal
      </button>
      <button type="button" class="btn-danger" :disabled="loading" @click="emit('confirm')">
        {{ loading ? 'Memproses...' : confirmText }}
      </button>
    </div>
  </BaseModal>
</template>