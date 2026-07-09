<script setup lang="ts">
import { toast } from 'vue-sonner'
import { CheckCircle2, Circle, Lock } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { formatDateTime } from '~/lib/utils'

type SectionKey = Database['public']['Enums']['report_section']

const props = defineProps<{
  orgId: string
  branchId: string
  canManage: boolean
}>()

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

type FieldType = 'number' | 'textarea' | 'bool'
interface FieldDef {
  key: string
  label: string
  type: FieldType
}
const SECTION_ORDER: SectionKey[] = ['utarg', 'kasa', 'sanepid', 'magazyn', 'zmiana']
const CONFIG: Record<SectionKey, { title: string; fields: FieldDef[] }> = {
  utarg: {
    title: 'Utarg',
    fields: [
      { key: 'gotowka', label: 'Gotówka (zł)', type: 'number' },
      { key: 'karta', label: 'Karta (zł)', type: 'number' },
      { key: 'inne', label: 'Inne (zł)', type: 'number' },
    ],
  },
  kasa: {
    title: 'Kasa',
    fields: [
      { key: 'stan_poczatkowy', label: 'Stan początkowy (zł)', type: 'number' },
      { key: 'stan_koncowy', label: 'Stan końcowy (zł)', type: 'number' },
      { key: 'uwagi', label: 'Uwagi', type: 'textarea' },
    ],
  },
  sanepid: {
    title: 'Sanepid',
    fields: [
      { key: 'zgodnosc', label: 'Zgodność z wymogami', type: 'bool' },
      { key: 'uwagi', label: 'Uwagi', type: 'textarea' },
    ],
  },
  magazyn: {
    title: 'Magazyn',
    fields: [
      { key: 'braki', label: 'Braki', type: 'textarea' },
      { key: 'zamowienia', label: 'Zamówienia', type: 'textarea' },
    ],
  },
  zmiana: {
    title: 'Zmiana',
    fields: [
      { key: 'obsada', label: 'Obsada (liczba osób)', type: 'number' },
      { key: 'problemy', label: 'Problemy', type: 'textarea' },
      { key: 'notatki', label: 'Notatki', type: 'textarea' },
    ],
  },
}

interface ReportRow {
  id: string
  date: string
  status: 'draft' | 'closed'
  closed_by: string | null
  closed_at: string | null
}
interface SectionRow {
  id: string
  section: SectionKey
  data: Record<string, unknown>
  completed: boolean
}

function todayStr() {
  const d = new Date()
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 10)
}

const date = ref(todayStr())
const report = ref<ReportRow | null>(null)
const sections = ref<SectionRow[]>([])
const loading = ref(false)
const creating = ref(false)
const closing = ref(false)
const closedByName = ref<string>('')
// lokalne edytowalne kopie: sectionId -> { fields..., completed }
// (luźne typowanie, by v-model bindował pola bez rzutowań w szablonie)
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const forms = ref<Record<string, any>>({})

const editable = computed(() => props.canManage && report.value?.status === 'draft')
const orderedSections = computed(() =>
  [...sections.value].sort(
    (a, b) => SECTION_ORDER.indexOf(a.section) - SECTION_ORDER.indexOf(b.section),
  ),
)
const completedCount = computed(() => sections.value.filter((s) => s.completed).length)
const allComplete = computed(() => sections.value.length === 5 && completedCount.value === 5)

async function load() {
  loading.value = true
  report.value = null
  sections.value = []
  forms.value = {}
  closedByName.value = ''
  const { data: rep } = await supabase
    .from('manager_reports')
    .select('id, date, status, closed_by, closed_at')
    .eq('branch_id', props.branchId)
    .eq('date', date.value)
    .maybeSingle()
  report.value = (rep as ReportRow) ?? null
  if (report.value) {
    const { data: secs } = await supabase
      .from('manager_report_sections')
      .select('id, section, data, completed')
      .eq('report_id', report.value.id)
    sections.value = (secs ?? []) as SectionRow[]
    for (const s of sections.value) {
      forms.value[s.id] = { ...(s.data as Record<string, unknown>), completed: s.completed }
    }
    if (report.value.closed_by) {
      const { data: p } = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', report.value.closed_by)
        .maybeSingle()
      closedByName.value = p?.full_name?.trim() || 'Menadżer'
    }
  }
  loading.value = false
}

watch([() => props.branchId, date], load, { immediate: true })

async function createReport() {
  if (!user.value) return
  creating.value = true
  const { data, error } = await supabase
    .from('manager_reports')
    .insert({ org_id: props.orgId, branch_id: props.branchId, date: date.value, created_by: user.value.id })
    .select('id, date, status, closed_by, closed_at')
    .single()
  creating.value = false
  if (error) {
    toast.error('Nie udało się utworzyć raportu', { description: error.message })
    return
  }
  report.value = data as ReportRow
  await load()
}

async function saveSection(s: SectionRow) {
  const form = forms.value[s.id]!
  const { completed, ...rest } = form
  // konwersja pól liczbowych
  const cfg = CONFIG[s.section]
  const data: Record<string, unknown> = {}
  for (const f of cfg.fields) {
    const v = rest[f.key]
    if (f.type === 'number') data[f.key] = v === '' || v == null ? null : Number(v)
    else if (f.type === 'bool') data[f.key] = !!v
    else data[f.key] = v ?? ''
  }
  const { error } = await supabase
    .from('manager_report_sections')
    .update({ data, completed })
    .eq('id', s.id)
  if (error) {
    toast.error('Nie udało się zapisać sekcji', { description: error.message })
    return
  }
  s.data = data
  s.completed = completed
  toast.success('Zapisano sekcję')
}

async function closeReport() {
  if (!report.value) return
  closing.value = true
  const { error } = await supabase
    .from('manager_reports')
    .update({ status: 'closed' })
    .eq('id', report.value.id)
  closing.value = false
  if (error) {
    toast.error('Nie można zamknąć raportu', { description: error.message })
    return
  }
  toast.success('Raport zamknięty')
  await load()
}

function displayValue(s: SectionRow, f: FieldDef) {
  const v = (s.data as Record<string, unknown>)[f.key]
  if (f.type === 'bool') return v ? 'Tak' : 'Nie'
  if (v == null || v === '') return '—'
  return String(v)
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center gap-3">
      <Label for="mr-date" class="text-sm text-muted-foreground">Data</Label>
      <Input id="mr-date" v-model="date" type="date" class="w-auto" />
    </div>

    <p v-if="loading" class="text-sm text-muted-foreground">Ładowanie…</p>

    <!-- Brak raportu -->
    <div
      v-else-if="!report"
      class="rounded-lg border border-dashed p-8 text-center"
    >
      <p class="text-sm text-muted-foreground">Brak raportu menadżerskiego na ten dzień.</p>
      <Button v-if="canManage" class="mt-4" :disabled="creating" @click="createReport">
        {{ creating ? 'Tworzenie…' : 'Utwórz raport' }}
      </Button>
    </div>

    <template v-else>
      <!-- Nagłówek: status + postęp -->
      <div class="flex flex-wrap items-center justify-between gap-3 rounded-lg border p-4">
        <div class="flex items-center gap-2">
          <Badge :variant="report.status === 'closed' ? 'default' : 'secondary'" class="gap-1">
            <Lock v-if="report.status === 'closed'" class="size-3" />
            {{ report.status === 'closed' ? 'Zamknięty' : 'Szkic' }}
          </Badge>
          <span v-if="report.status === 'closed' && report.closed_at" class="text-xs text-muted-foreground">
            {{ closedByName }} · {{ formatDateTime(report.closed_at) }}
          </span>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span class="text-muted-foreground">Ukończono</span>
          <span class="font-semibold">{{ completedCount }}/5</span>
        </div>
      </div>

      <!-- Sekcje -->
      <Accordion type="multiple" class="rounded-lg border">
        <AccordionItem
          v-for="s in orderedSections"
          :key="s.id"
          :value="s.section"
          class="px-4 last:border-b-0"
        >
          <AccordionTrigger class="hover:no-underline">
            <span class="flex items-center gap-2">
              <CheckCircle2 v-if="s.completed" class="size-4 text-primary" />
              <Circle v-else class="size-4 text-muted-foreground" />
              {{ CONFIG[s.section].title }}
            </span>
          </AccordionTrigger>
          <AccordionContent>
            <!-- Edytowalny formularz -->
            <div v-if="editable" class="space-y-3 pb-2">
              <div v-for="f in CONFIG[s.section].fields" :key="f.key" class="space-y-1.5">
                <template v-if="f.type === 'bool'">
                  <label class="flex items-center gap-2 text-sm">
                    <Checkbox v-model="forms[s.id][f.key]" />
                    {{ f.label }}
                  </label>
                </template>
                <template v-else>
                  <Label class="text-xs text-muted-foreground">{{ f.label }}</Label>
                  <Textarea v-if="f.type === 'textarea'" v-model="forms[s.id][f.key]" rows="2" />
                  <Input
                    v-else
                    v-model="forms[s.id][f.key]"
                    type="number"
                    step="0.01"
                    inputmode="decimal"
                  />
                </template>
              </div>
              <div class="flex items-center justify-between border-t pt-3">
                <label class="flex items-center gap-2 text-sm font-medium">
                  <Checkbox v-model="forms[s.id].completed" />
                  Sekcja gotowa
                </label>
                <Button size="sm" @click="saveSection(s)">Zapisz sekcję</Button>
              </div>
            </div>

            <!-- Widok tylko do odczytu -->
            <dl v-else class="space-y-2 pb-2 text-sm">
              <div v-for="f in CONFIG[s.section].fields" :key="f.key" class="flex justify-between gap-4">
                <dt class="text-muted-foreground">{{ f.label }}</dt>
                <dd class="text-right font-medium">{{ displayValue(s, f) }}</dd>
              </div>
            </dl>
          </AccordionContent>
        </AccordionItem>
      </Accordion>

      <!-- Zamknięcie -->
      <div v-if="editable" class="space-y-2">
        <Button class="w-full" :disabled="!allComplete || closing" @click="closeReport">
          {{ closing ? 'Zamykanie…' : 'Zamknij raport' }}
        </Button>
        <p v-if="!allComplete" class="text-center text-xs text-muted-foreground">
          Aby zamknąć raport, uzupełnij i oznacz jako gotowe wszystkie 5 sekcji ({{ completedCount }}/5).
        </p>
      </div>
    </template>
  </div>
</template>
