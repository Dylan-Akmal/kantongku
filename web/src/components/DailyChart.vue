<script setup>
import { computed } from 'vue'
import { formatCompact, formatDate, formatRupiah } from '@/utils/format'

const props = defineProps({
  days: { type: Array, required: true },
})

const GROUP_WIDTH = 22
const HEIGHT = 170
const PAD_TOP = 8
const PAD_BOTTOM = 22
const PAD_LEFT = 46

const plotHeight = HEIGHT - PAD_TOP - PAD_BOTTOM

const maxValue = computed(() =>
  Math.max(1, ...props.days.map((day) => Math.max(day.income, day.expense))),
)

const width = computed(() => PAD_LEFT + props.days.length * GROUP_WIDTH)

const ticks = computed(() =>
  [0, 0.5, 1].map((ratio) => ({
    y: PAD_TOP + plotHeight - ratio * plotHeight,
    label: formatCompact(maxValue.value * ratio),
  })),
)

function barHeight(value) {
  if (value <= 0) return 0
  return Math.max(2, (value / maxValue.value) * plotHeight)
}

function barY(value) {
  return PAD_TOP + plotHeight - barHeight(value)
}

function groupX(index) {
  return PAD_LEFT + index * GROUP_WIDTH
}

function dayNumber(date) {
  return Number(date.slice(8, 10))
}

function tooltip(day) {
  return `${formatDate(day.date)}: pemasukan ${formatRupiah(day.income)}, pengeluaran ${formatRupiah(day.expense)}`
}
</script>

<template>
  <div>
    <div class="overflow-x-auto">
      <svg
        :viewBox="`0 0 ${width} ${HEIGHT}`"
        :style="{ minWidth: `${width}px` }"
        class="h-auto w-full"
        role="img"
        aria-label="Grafik pemasukan dan pengeluaran harian"
      >
        <g v-for="tick in ticks" :key="tick.y">
          <line
            :x1="PAD_LEFT"
            :x2="width"
            :y1="tick.y"
            :y2="tick.y"
            class="stroke-slate-200"
            stroke-width="1"
          />
          <text
            :x="PAD_LEFT - 6"
            :y="tick.y + 3"
            text-anchor="end"
            font-size="9"
            class="fill-slate-400"
          >
            {{ tick.label }}
          </text>
        </g>

        <g v-for="(day, index) in days" :key="day.date">
          <rect
            :x="groupX(index) + 3"
            :y="barY(day.income)"
            width="7"
            :height="barHeight(day.income)"
            rx="1.5"
            class="fill-emerald-500"
          />
          <rect
            :x="groupX(index) + 11"
            :y="barY(day.expense)"
            width="7"
            :height="barHeight(day.expense)"
            rx="1.5"
            class="fill-rose-500"
          />
          <text
            :x="groupX(index) + 11"
            :y="HEIGHT - 8"
            text-anchor="middle"
            font-size="9"
            class="fill-slate-500"
          >
            {{ dayNumber(day.date) }}
          </text>
          <title>{{ tooltip(day) }}</title>
        </g>
      </svg>
    </div>

    <div class="mt-2 flex gap-4 text-xs text-slate-500">
      <span class="flex items-center gap-1.5">
        <span class="inline-block h-2.5 w-2.5 rounded-sm bg-emerald-500"></span>
        Pemasukan
      </span>
      <span class="flex items-center gap-1.5">
        <span class="inline-block h-2.5 w-2.5 rounded-sm bg-rose-500"></span>
        Pengeluaran
      </span>
    </div>
  </div>
</template>