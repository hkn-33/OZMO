<script setup lang="ts">
import { toast } from 'vue-sonner'
import {
  ChevronLeft, ChevronRight, Plus, Pencil, Trash2, Copy, Send, CalendarDays, TriangleAlert,
} from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { zonedTimeToIso, tzDateKey, tzTime } from '~/lib/tz'
import {
  WEEKDAYS_FULL, weekdayIndex, buildPositionColors, positionColor, shiftCardStyle,
} from '~/lib/schedule'
import type {
  ScheduleMember, ShiftTemplateLite, AvailabilityLite, EditingShift,
} from '~/components/schedule/ShiftDialog.vue'

const props = defineProps<{
  orgId: string
  branchId: string
  canManage: boolean
  timezone: string
}>()

const supabase = useSupabaseClient<Database>()
const { block } = useDemoGuard()
const user = useSupabaseUser()

interface ShiftRow {
  id: string
  user_id: string
  starts_at: string
  ends_at: string
  position: string | null
  published: boolean
  note: string | null
}

function localKey(d: Date) {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}
function mondayOf(date: Date) {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate())
  d.setDate(d.getDate() - weekdayIndex(d))
  return d
}

const cursor = ref(mondayOf(new Date()))
const weekStart = computed(() => mondayOf(cursor.value))
const days = computed(() =>
  Array.from({ length: 7 }, (_, i) => {
    const d = new Date(weekStart.value)
    d.setDate(d.getDate() + i)
    return { date: d, key: localKey(d), label: WEEKDAYS_FULL[i]! }
  }),
)
const weekLabel = computed(() => {
  const end = days.value[6]!.date
  const fmt = new Intl.DateTimeFormat('pl-PL', { day: 'numeric', month: 'short' })
  return `${fmt.format(weekStart.value)} – ${fmt.format(end)}`
})

function prevWeek() {
  const d = new Date(cursor.value); d.setDate(d.getDate() - 7); cursor.value = d
}
function nextWeek() {
  const d = new Date(cursor.value); d.setDate(d.getDate() + 7); cursor.value = d
}
function today() {
  cursor.value = mondayOf(new Date())
}

const rangeStart = computed(() => zonedTimeToIso(days.value[0]!.key, '00:00', props.timezone))
const rangeEnd = computed(() => {
  const d = new Date(weekStart.value); d.setDate(d.getDate() + 7)
  return zonedTimeToIso(localKey(d), '00:00', props.timezone)
})

const { data, refresh, pending } = await useAsyncData(
  () => `schedule:${props.branchId}:${weekStart.value.getTime()}`,
  async () => {
    const [shifts, members, templates, avail] = await Promise.all([
      supabase
        .from('shifts')
        .select('id, user_id, starts_at, ends_at, position, published, note')
        .eq('branch_id', props.branchId)
        .gte('starts_at', rangeStart.value)
        .lt('starts_at', rangeEnd.value)
        .order('starts_at'),
      supabase
        .from('branch_members')
        .select('user_id, profiles(full_name)')
        .eq('branch_id', props.branchId),
      supabase
        .from('shift_templates')
        .select('weekday, needed, position')
        .eq('branch_id', props.branchId),
      supabase
        .from('availability')
        .select('user_id, weekday, from_time, to_time')
        .eq('branch_id', props.branchId),
    ])
    const mem = (members.data ?? []) as unknown as {
      user_id: string
      profiles: { full_name: string | null } | null
    }[]
    return {
      shifts: (shifts.data ?? []) as ShiftRow[],
      members: mem.map((m) => ({
        user_id: m.user_id,
        name: m.profiles?.full_name?.trim() || 'Bez nazwy',
      })) as ScheduleMember[],
      templates: (templates.data ?? []) as ShiftTemplateLite[],
      availability: (avail.data ?? []) as AvailabilityLite[],
    }
  },
  { watch: [() => props.branchId, weekStart] },
)

const nameById = computed(() =>
  Object.fromEntries((data.value?.members ?? []).map((m) => [m.user_id, m.name])),
)

// shifts bucketed by branch-tz calendar day
const shiftsByDay = computed(() => {
  const map: Record<string, ShiftRow[]> = {}
  for (const s of data.value?.shifts ?? []) {
    const k = tzDateKey(s.starts_at, props.timezone)
    ;(map[k] ??= []).push(s)
  }
  return map
})
const dayCounts = computed(() =>
  Object.fromEntries(days.value.map((d) => [d.key, (shiftsByDay.value[d.key] ?? []).length])),
)

// Per-day staffing hint from shift_templates: scheduled vs needed (amber when under).
function staffing(dayIndex: number, dayKey: string) {
  const forDay = (data.value?.templates ?? []).filter((t) => t.weekday === dayIndex)
  if (!forDay.length) return null
  const needed = forDay.reduce((s, t) => s + (t.needed ?? 0), 0)
  const scheduled = dayCounts.value[dayKey] ?? 0
  return { needed, scheduled, under: scheduled < needed }
}

const hasDrafts = computed(() => (data.value?.shifts ?? []).some((s) => !s.published))

// Today highlight (branch-local calendar day).
const todayKey = tzDateKey(new Date().toISOString(), props.timezone)

const positionColors = computed(() =>
  buildPositionColors((data.value?.shifts ?? []).map((s) => s.position)),
)
function shiftColor(position: string | null) {
  return positionColor(positionColors.value, position)
}
// Legend: distinct positions present in the visible week (auto-derived) + a neutral
// entry when some shifts have no position.
const legendPositions = computed(() =>
  [...positionColors.value.entries()].map(([name, color]) => ({ name, color })),
)
const hasUnpositioned = computed(() =>
  (data.value?.shifts ?? []).some((s) => !s.position?.trim()),
)

const dialogOpen = ref(false)
const editing = ref<EditingShift | null>(null)
const defaultDate = ref(localKey(new Date()))

function openAdd(dayKey: string) {
  editing.value = null
  defaultDate.value = dayKey
  dialogOpen.value = true
}
function openEdit(s: ShiftRow) {
  editing.value = {
    id: s.id,
    user_id: s.user_id,
    date: tzDateKey(s.starts_at, props.timezone),
    from: tzTime(s.starts_at, props.timezone),
    to: tzTime(s.ends_at, props.timezone),
    position: s.position,
    note: s.note,
  }
  defaultDate.value = editing.value.date
  dialogOpen.value = true
}

async function removeShift(s: ShiftRow) {
  if (block()) return
  const { error } = await supabase.from('shifts').delete().eq('id', s.id)
  if (error) {
    toast.error('Nie udało się usunąć zmiany', { description: error.message })
    return
  }
  toast.success('Zmiana usunięta')
  refresh()
}

const publishing = ref(false)
async function publishWeek() {
  if (block()) return
  publishing.value = true
  const { error } = await supabase
    .from('shifts')
    .update({ published: true })
    .eq('branch_id', props.branchId)
    .eq('published', false)
    .gte('starts_at', rangeStart.value)
    .lt('starts_at', rangeEnd.value)
  publishing.value = false
  if (error) {
    toast.error('Nie udało się opublikować', { description: error.message })
    return
  }
  toast.success('Grafik opublikowany')
  refresh()
}

const copying = ref(false)
async function copyPrevWeek() {
  if (block()) return
  copying.value = true
  const prev = new Date(weekStart.value); prev.setDate(prev.getDate() - 7)
  const { data: count, error } = await supabase.rpc('copy_week_shifts', {
    p_branch_id: props.branchId,
    from_week_start: localKey(prev),
    to_week_start: localKey(weekStart.value),
  })
  copying.value = false
  if (error) {
    toast.error('Nie udało się skopiować tygodnia', { description: error.message })
    return
  }
  toast.success(`Skopiowano zmian: ${count ?? 0}`)
  refresh()
}
</script>

<template>
  <div class="space-y-4">
    <div
      class="sticky top-0 z-20 -mx-1 flex flex-wrap items-center justify-between gap-3 bg-background/95 px-1 py-2 backdrop-blur supports-[backdrop-filter]:bg-background/80 lg:static lg:mx-0 lg:bg-transparent lg:px-0 lg:py-0 lg:backdrop-blur-none"
    >
      <div class="flex items-center gap-1">
        <Button variant="outline" size="icon" aria-label="Poprzedni tydzień" @click="prevWeek">
          <ChevronLeft class="size-4" />
        </Button>
        <Button variant="outline" size="sm" @click="today">
          <CalendarDays class="mr-1.5 size-4" /> Dziś
        </Button>
        <Button variant="outline" size="icon" aria-label="Następny tydzień" @click="nextWeek">
          <ChevronRight class="size-4" />
        </Button>
        <span class="ml-2 text-sm font-semibold tabular-nums">{{ weekLabel }}</span>
      </div>
      <div v-if="canManage" class="flex flex-wrap items-center gap-2">
        <Button variant="outline" size="sm" :disabled="copying" @click="copyPrevWeek">
          <Copy class="mr-1.5 size-4" /> Kopiuj poprzedni tydzień
        </Button>
        <Button size="sm" :disabled="publishing || !hasDrafts" @click="publishWeek">
          <Send class="mr-1.5 size-4" /> Opublikuj tydzień
        </Button>
      </div>
    </div>

    <p v-if="pending" class="py-6 text-sm text-muted-foreground">Ładowanie…</p>

    <template v-else>
      <div
        class="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-lg border bg-card px-3 py-2 text-xs"
      >
        <span class="font-medium text-muted-foreground">Stanowiska:</span>
        <template v-if="legendPositions.length || hasUnpositioned">
          <span
            v-for="p in legendPositions"
            :key="p.name"
            class="inline-flex items-center gap-1.5"
          >
            <span class="size-2.5 rounded-full" :style="{ backgroundColor: p.color }" />
            <span>{{ p.name }}</span>
          </span>
          <span v-if="hasUnpositioned" class="inline-flex items-center gap-1.5">
            <span class="size-2.5 rounded-full bg-muted-foreground/40" />
            <span>Bez stanowiska</span>
          </span>
        </template>
        <span v-else class="text-muted-foreground">Brak zmian w tym tygodniu</span>

        <template v-if="canManage">
          <span class="mx-1 hidden h-3.5 w-px bg-border sm:block" />
          <span class="inline-flex items-center gap-1.5">
            <span class="h-3.5 w-5 rounded-sm border-2 border-dashed border-muted-foreground/50 opacity-60" />
            <span>Szkic</span>
          </span>
          <span class="inline-flex items-center gap-1.5">
            <span class="h-3.5 w-5 rounded-sm border border-border bg-card" />
            <span>Opublikowane</span>
          </span>
        </template>
      </div>

      <div class="grid gap-3 lg:grid-cols-7">
        <div
          v-for="(day, i) in days"
          :key="day.key"
          class="rounded-lg border p-2"
          :class="day.key === todayKey ? 'bg-card ring-1 ring-primary/40' : 'bg-card'"
        >
          <div
            class="mb-2 flex items-center justify-between gap-2 rounded-md px-1.5 py-1"
            :class="day.key === todayKey ? 'bg-primary/10' : ''"
          >
            <div>
              <p
                class="text-sm font-semibold leading-tight"
                :class="day.key === todayKey ? 'text-primary' : ''"
              >
                {{ day.label }}
              </p>
              <p class="text-xs text-muted-foreground tabular-nums">
                {{ new Intl.DateTimeFormat('pl-PL', { day: 'numeric', month: 'short' }).format(day.date) }}
              </p>
            </div>
            <Button
              v-if="canManage && shiftsByDay[day.key]?.length"
              variant="ghost"
              size="icon"
              class="size-8 shrink-0"
              aria-label="Dodaj zmianę"
              @click="openAdd(day.key)"
            >
              <Plus class="size-4" />
            </Button>
          </div>

          <p
            v-if="staffing(i, day.key)"
            class="mb-2 inline-flex items-center gap-1.5 rounded px-2 py-1 text-[11px] font-medium"
            :class="staffing(i, day.key)!.under
              ? 'bg-warning-soft text-warning-soft-foreground'
              : 'bg-muted text-muted-foreground'"
          >
            <TriangleAlert v-if="staffing(i, day.key)!.under" class="size-3" />
            {{ staffing(i, day.key)!.scheduled }}/{{ staffing(i, day.key)!.needed }} obsadzone
          </p>

          <div class="space-y-2">
            <div
              v-for="s in shiftsByDay[day.key] ?? []"
              :key="s.id"
              class="min-h-[44px] rounded-md border border-l-[3px] p-2"
              :style="shiftCardStyle(shiftColor(s.position))"
              :class="[
                !s.published ? 'border-dashed opacity-60' : '',
                s.user_id === user?.id ? 'ring-1 ring-primary/50' : '',
              ]"
            >
              <div class="flex items-start justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-medium leading-tight">
                    {{ nameById[s.user_id] ?? 'Bez nazwy' }}
                  </p>
                  <p class="mt-0.5 text-sm font-semibold tabular-nums leading-tight">
                    {{ tzTime(s.starts_at, timezone) }}–{{ tzTime(s.ends_at, timezone) }}
                  </p>
                </div>
                <div v-if="canManage" class="flex shrink-0 gap-0.5">
                  <Button variant="ghost" size="icon" class="size-8" aria-label="Edytuj" @click="openEdit(s)">
                    <Pencil class="size-3.5" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    class="size-8 text-destructive"
                    aria-label="Usuń"
                    @click="removeShift(s)"
                  >
                    <Trash2 class="size-3.5" />
                  </Button>
                </div>
              </div>
              <div class="mt-1.5 flex flex-wrap items-center gap-1.5">
                <span
                  v-if="s.position"
                  class="inline-flex items-center gap-1 text-[11px] font-medium text-foreground/80"
                >
                  <span
                    class="size-1.5 rounded-full"
                    :style="{ backgroundColor: shiftColor(s.position) ?? 'var(--border)' }"
                  />
                  {{ s.position }}
                </span>
                <Badge v-if="!s.published" variant="outline" class="text-[10px]">Szkic</Badge>
              </div>
              <p v-if="s.note" class="mt-1 text-xs text-muted-foreground">{{ s.note }}</p>
            </div>

            <button
              v-if="canManage && !(shiftsByDay[day.key]?.length)"
              type="button"
              class="flex min-h-[44px] w-full items-center justify-center gap-1.5 rounded-md border border-dashed text-xs text-muted-foreground transition-colors hover:bg-muted/50 hover:text-foreground"
              @click="openAdd(day.key)"
            >
              <Plus class="size-3.5" /> Dodaj zmianę
            </button>
            <p
              v-else-if="!(shiftsByDay[day.key]?.length)"
              class="px-1 py-2 text-xs text-muted-foreground/70"
            >
              Brak zmian
            </p>
          </div>
        </div>
      </div>
    </template>

    <ScheduleShiftDialog
      v-model:open="dialogOpen"
      :org-id="orgId"
      :branch-id="branchId"
      :timezone="timezone"
      :members="data?.members ?? []"
      :templates="data?.templates ?? []"
      :availability="data?.availability ?? []"
      :day-counts="dayCounts"
      :default-date="defaultDate"
      :editing="editing"
      @saved="refresh"
    />
  </div>
</template>
