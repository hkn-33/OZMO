<script setup lang="ts">
import { toast } from 'vue-sonner'
import {
  ChevronLeft, ChevronRight, Plus, Pencil, Trash2, Copy, Send, CalendarDays,
} from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { zonedTimeToIso, tzDateKey, tzTime } from '~/lib/tz'
import { WEEKDAYS_FULL, weekdayIndex } from '~/lib/schedule'
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

// --- Week navigation (Monday-start) ---
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

// --- Data ---
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
function templateNeeded(dayIndex: number) {
  const forDay = (data.value?.templates ?? []).filter((t) => t.weekday === dayIndex)
  if (!forDay.length) return null
  return forDay.reduce((s, t) => s + (t.needed ?? 0), 0)
}

const hasDrafts = computed(() => (data.value?.shifts ?? []).some((s) => !s.published))

// --- Dialog ---
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
    <!-- Toolbar -->
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex items-center gap-1">
        <Button variant="outline" size="icon" @click="prevWeek">
          <ChevronLeft class="size-4" />
        </Button>
        <Button variant="outline" size="sm" @click="today">
          <CalendarDays class="mr-1.5 size-4" /> Dziś
        </Button>
        <Button variant="outline" size="icon" @click="nextWeek">
          <ChevronRight class="size-4" />
        </Button>
        <span class="ml-2 text-sm font-medium">{{ weekLabel }}</span>
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

    <!-- Week grid: 7 columns on desktop, day list on mobile -->
    <div v-else class="grid gap-3 lg:grid-cols-7">
      <div
        v-for="(day, i) in days"
        :key="day.key"
        class="rounded-lg border bg-card p-2"
      >
        <div class="mb-2 flex items-center justify-between gap-2 px-1">
          <div>
            <p class="text-sm font-semibold leading-tight">{{ day.label }}</p>
            <p class="text-xs text-muted-foreground">
              {{ new Intl.DateTimeFormat('pl-PL', { day: 'numeric', month: 'short' }).format(day.date) }}
            </p>
          </div>
          <Button
            v-if="canManage"
            variant="ghost"
            size="icon"
            class="size-7 shrink-0"
            @click="openAdd(day.key)"
          >
            <Plus class="size-4" />
          </Button>
        </div>

        <p
          v-if="templateNeeded(i) != null"
          class="mb-2 rounded bg-muted px-2 py-1 text-[11px] text-muted-foreground"
        >
          Obsada wg szablonu: {{ templateNeeded(i) }}, zaplanowane: {{ dayCounts[day.key] ?? 0 }}
        </p>

        <div class="space-y-2">
          <p
            v-if="!(shiftsByDay[day.key]?.length)"
            class="px-1 py-2 text-xs text-muted-foreground/70"
          >
            Brak zmian
          </p>
          <div
            v-for="s in shiftsByDay[day.key] ?? []"
            :key="s.id"
            class="rounded-md border p-2 text-sm"
            :class="[
              s.published ? 'bg-card' : 'border-dashed bg-muted/40',
              s.user_id === user?.id ? 'ring-1 ring-primary/40' : '',
            ]"
          >
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="truncate font-medium">{{ nameById[s.user_id] ?? 'Bez nazwy' }}</p>
                <p class="text-xs text-muted-foreground">
                  {{ tzTime(s.starts_at, timezone) }}–{{ tzTime(s.ends_at, timezone) }}
                </p>
              </div>
              <div v-if="canManage" class="flex shrink-0 gap-0.5">
                <Button variant="ghost" size="icon" class="size-7" @click="openEdit(s)">
                  <Pencil class="size-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  class="size-7 text-destructive"
                  @click="removeShift(s)"
                >
                  <Trash2 class="size-3.5" />
                </Button>
              </div>
            </div>
            <div class="mt-1 flex flex-wrap items-center gap-1">
              <Badge v-if="s.position" variant="secondary" class="text-[10px]">
                {{ s.position }}
              </Badge>
              <Badge v-if="!s.published" variant="outline" class="text-[10px]">Szkic</Badge>
            </div>
            <p v-if="s.note" class="mt-1 text-xs text-muted-foreground">{{ s.note }}</p>
          </div>
        </div>
      </div>
    </div>

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
