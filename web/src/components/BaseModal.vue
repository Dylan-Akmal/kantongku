<script setup>
import { onMounted, onUnmounted } from 'vue'

const props = defineProps({
  open: { type: Boolean, default: false },
  title: { type: String, required: true },
})

const emit = defineEmits(['close'])

function onKeydown(event) {
  if (event.key === 'Escape' && props.open) {
    emit('close')
  }
}

onMounted(() => window.addEventListener('keydown', onKeydown))
onUnmounted(() => window.removeEventListener('keydown', onKeydown))
</script>

<template>
  <Teleport to="body">
    <div
      v-if="open"
      class="fixed inset-0 z-50 flex items-end justify-center bg-slate-900/50 p-4 sm:items-center"
      @click.self="emit('close')"
    >
      <div class="w-full max-w-md rounded-xl bg-white p-5 shadow-xl">
        <div class="flex items-start justify-between gap-4">
          <h2 class="text-lg font-semibold text-slate-800">{{ title }}</h2>
          <button
            type="button"
            class="text-slate-400 transition hover:text-slate-600"
            aria-label="Tutup"
            @click="emit('close')"
          >
            ✕
          </button>
        </div>
        <div class="mt-4">
          <slot />
        </div>
      </div>
    </div>
  </Teleport>
</template>