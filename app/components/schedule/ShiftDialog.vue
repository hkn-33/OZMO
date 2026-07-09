<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Info, TriangleAlert } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { zonedTimeToIso } from '~/lib/tz'
import { weekdayIndex } from '~/lib/schedule'

export interface ScheduleMember {
  user_id: string
  name: string
}
export interface ShiftTemplateLite {
  weekday: number
  needed: number
  position: string | null
}
export interface AvailabilityLite {
  user_id: string
  weekday: number
  from_time: string
  to_time: string
}
export interface EditingShift {
  id: string
  user_id: string
  date: string
  from: string
  to: string
  position: string | null
  note: string | null
}

const props = defineProps<{
  orgId: string
  branchId: string
  timezone: string
  members: ScheduleMember[]
  templates: ShiftTemplateLite[]
  availability: AvailabilityLite[]
  /** number of shifts already scheduled per day key (YYYY-MM-DD) */
  dayCounts: Record<string, number>
  defaultDate: string
  editing: EditingShift | null
}>()

const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ saved: [] }>()

const supabase = useSupabaseClient<Database>()
const { isDemo, upgradeOpen } = useDemoGuard()
const user = useSupabaseUser()

const form = reactive({
  userId: '',
  date: props.defaultDate,
  from: '08:00',
  to: '16:00',
  position: '',
  note: '',
})
const saving = ref(false)

watch(open, (v) => {
  if (!v) return
  if (props.editing) {
    form.userId = props.editing.user_id
    form.date = props.editing.date
    form.from = props.editing.from
    form.to = props.editing.to
    form.position = props.editing.position ?? ''
    form.note = props.editing.note ?? ''
  } else {
    form.userId = ''
    form.date = props.defaultDate
    form.from = '08:00'
    form.to = '16:00'
    form.position = ''
    form.note = ''
  }
})

const selectedWeekday = computed(() => {
  if (!form.date) return null
  const [y, m, d] = form.date.split('-').map(Number)
  return weekdayIndex(new Date(y!, m! - 1, d!))
})

// Podpowiedź obsady wg szablonu vs zaplanowane
const templateHint = computed(() => {
  if (selectedWeekday.value == null) return null
  const forDay = props.templates.filter((t) => t.weekday === selectedWeekday.value)
  if (!forDay.length) return null
  const needed = forDay.reduce((s, t) => s + (t.needed ?? 0), 0)
  const scheduled = props.dayCounts[form.date] ?? 0
  return { needed, scheduled }
})

function toMin(t: string) {
  const [h, m] = t.split(':').map(Number)
  return h! * 60 + (m ?? 0)
}

// Ostrzeżenie o dostępności (miękkie, nie blokuje)
const availabilityWarning = computed(() => {
  if (!form.userId || selectedWeekday.value == null) return false
  const rows = props.availability.filter(
    (a) => a.user_id === form.userId && a.weekday === selectedWeekday.value,
  )
  const from = toMin(form.from)
  const to = toMin(form.to)
  const covered = rows.some((a) => toMin(a.from_time) <= from && toMin(a.to_time) >= to)
  return !covered
})

async function save() {
  if (isDemo.value) { upgradeOpen.value = true; return }
  if (!form.userId || !user.value) return
  if (toMin(form.to) <= toMin(form.from)) {
    toast.error('Godzina zakończenia musi być późniejsza niż rozpoczęcia')
    return
  }
  saving.value = true
  const starts_at = zonedTimeToIso(form.date, form.from, props.timezone)
  const ends_at = zonedTimeToIso(form.date, form.to, props.timezone)
  const payload = {
    starts_at,
    ends_at,
    position: form.position.trim() || null,
    note: form.note.trim() || null,
  }
  const { error } = props.editing
    ? await supabase.from('shifts').update({ ...payload, user_id: form.userId }).eq('id', props.editing.id)
    : await supabase.from('shifts').insert({
        ...payload,
        org_id: props.orgId,
        branch_id: props.branchId,
        user_id: form.userId,
        published: false,
        created_by: user.value.id,
      })
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać zmiany', { description: error.message })
    return
  }
  toast.success(props.editing ? 'Zmiana zaktualizowana' : 'Zmiana dodana')
  open.value = false
  emit('saved')
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogScrollContent class="max-h-[90svh]">
      <DialogHeader>
        <DialogTitle>{{ editing ? 'Edytuj zmianę' : 'Nowa zmiana' }}</DialogTitle>
        <DialogDescription>Przypisz pracownika do zmiany w tym oddziale.</DialogDescription>
      </DialogHeader>
      <form class="space-y-4" @submit.prevent="save">
        <div class="space-y-2">
          <Label>Pracownik</Label>
          <Select v-model="form.userId">
            <SelectTrigger><SelectValue placeholder="Wybierz pracownika" /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="m in members" :key="m.user_id" :value="m.user_id">
                {{ m.name }}
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div class="space-y-2">
          <Label for="s-date">Data</Label>
          <Input id="s-date" v-model="form.date" type="date" />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-2">
            <Label for="s-from">Od</Label>
            <Input id="s-from" v-model="form.from" type="time" />
          </div>
          <div class="space-y-2">
            <Label for="s-to">Do</Label>
            <Input id="s-to" v-model="form.to" type="time" />
          </div>
        </div>

        <div class="space-y-2">
          <Label for="s-pos">Stanowisko (opcjonalnie)</Label>
          <Input id="s-pos" v-model="form.position" placeholder="np. Kelner, Kucharz" />
        </div>

        <div class="space-y-2">
          <Label for="s-note">Notatka (opcjonalnie)</Label>
          <Textarea id="s-note" v-model="form.note" rows="2" />
        </div>

        <p
          v-if="templateHint"
          class="flex items-center gap-2 rounded-md bg-muted px-3 py-2 text-xs text-muted-foreground"
        >
          <Info class="size-3.5 shrink-0" />
          Obsada wg szablonu: {{ templateHint.needed }}, zaplanowane: {{ templateHint.scheduled }}
        </p>
        <p
          v-if="availabilityWarning"
          class="flex items-center gap-2 rounded-md bg-amber-500/10 px-3 py-2 text-xs text-amber-700 dark:text-amber-400"
        >
          <TriangleAlert class="size-3.5 shrink-0" />
          Pracownik nie ma zadeklarowanej dostępności obejmującej ten czas.
        </p>

        <DialogFooter>
          <Button type="submit" :disabled="saving || !form.userId">
            {{ saving ? 'Zapisywanie…' : 'Zapisz' }}
          </Button>
        </DialogFooter>
      </form>
    </DialogScrollContent>
  </Dialog>
</template>
