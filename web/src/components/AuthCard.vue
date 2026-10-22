<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
})
</script>

<template>
  <div class="flex min-h-screen items-center justify-center bg-slate-50 px-4 py-10">
    <div class="w-full max-w-md">
      <div class="mb-6 text-center">
        <div class="text-4xl">👛</div>
        <h1 class="mt-2 text-2xl font-bold text-emerald-700">Kantongku</h1>
        <p class="mt-1 text-sm text-slate-500">Catat keuangan, patungan jadi mudah</p>
      </div>

      <div class="card">
        <h2 class="text-lg font-semibold text-slate-800">{{ title }}</h2>
        <p v-if="subtitle" class="mt-1 text-sm text-slate-500">{{ subtitle }}</p>
        <div class="mt-5">
          <slot />
        </div>
      </div>

      <p class="mt-4 text-center text-sm text-slate-500">
        <slot name="footer" />
      </p>
    </div>
  </div>
</template>