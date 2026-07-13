<script setup lang="ts">
import { toast } from 'vue-sonner'
import { CheckCircle2, Circle, Lock } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { formatDateTime, localDateKey } from '~/lib/utils'

const props = defineProps<{
  orgId: string
  branchId: string
  canManage: boolean
}>()

const supabase = useSupabaseClient<Database>()
const { block } = useDemoGuard()
const user = useSupabaseUser()

type FieldType = 'money' | 'number' | 'text' | 'boolean'
interface FieldDef {
  key: string
  label: string
  type: FieldType
}
interface SectionDef {
  id: string
  name: string
  sort: number
  fields: FieldDef[]
  required: boolean
  is_revenue_source: boolean
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
  section_def_id: string
  data: Record<string, unknown>
  completed: boolean
  def: SectionDef | null
}

function moneyLabel(f: FieldDef) {
  return f.type === 'money' ? `${f.label} (zł)` : f.label
}

const date = ref(localDateKey())
const report = ref<ReportRow | null>(null)
const sections = ref<SectionRow[]>([])
const loading = ref(false)
const creating = ref(false)
const closing = ref(false)
const closedByName = ref<string>('')
// lokalne edytowalne kopie: sectionId -> { fields..., completed }
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const forms = ref<Record<string, any>>({})

const editable = computed(() => props.canManage && report.value?.status === 'draft')
const orderedSections = computed(() =>
  [...sections.value].sort((a, b) => (a.def?.sort ?? 0) - (b.def?.sort ?? 0)),
)
const requiredSections = computed(() => sections.value.filter((s) => s.def?.required))
const completedRequired = computed(() => requiredSections.value.filter((s) => s.completed).length)
const requiredCount = computed(() => requiredSections.value.length)
const allComplete = computed(
  () => requiredCount.value > 0 && completedRequired.value === requiredCount.value,
)

async function load() {
  loading.value = true
  report.value = null
  sections.value = []
  forms.value = {}
  closedByName.value = ''

  // Definicje sekcji organizacji (mapa po id).
  const { data: defsData } = await supabase
    .from('report_section_defs')
    .select('id, name, sort, fields, required, is_revenue_source')
    .eq('org_id', props.orgId)
    .order('sort', { ascending: true })
  const defs = new Map<string, SectionDef>()
  for (const d of (defsData ?? []) as unknown as SectionDef[]) {
    defs.set(d.id, { ...d, fields: Array.isArray(d.fields) ? d.fields : [] })
  }

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
      .select('id, section_def_id, data, completed')
      .eq('report_id', report.value.id)
    sections.value = ((secs ?? []) as Omit<SectionRow, 'def'>[]).map((s) => ({
      ...s,
      def: defs.get(s.section_def_id) ?? null,
    }))
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

watch([() => props.branchId, () => props.orgId, date], load, { immediate: true })

async function createReport() {
  if (block()) return
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
  if (block()) return
  const form = forms.value[s.id]!
  const { completed, ...rest } = form
  const fields = s.def?.fields ?? []
  const data: Record<string, unknown> = {}
  for (const f of fields) {
    const v = rest[f.key]
    if (f.type === 'money' || f.type === 'number') data[f.key] = v === '' || v == null ? null : Number(v)
    else if (f.type === 'boolean') data[f.key] = !!v
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
  if (block()) return
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
  if (f.type === 'boolean') return v ? 'Tak' : 'Nie'
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
      <div class="flex flex-wrap items-center justify-between gap-3 rounded-lg border p-4">
        <div class="flex items-center gap-2">
          <Badge :variant="report.status === 'closed' ? 'success' : 'warning'" class="gap-1">
            <Lock v-if="report.status === 'closed'" class="size-3" />
            {{ report.status === 'closed' ? 'Zamknięty' : 'Szkic' }}
          </Badge>
          <span v-if="report.status === 'closed' && report.closed_at" class="text-xs text-muted-foreground">
            {{ closedByName }} · {{ formatDateTime(report.closed_at) }}
          </span>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span class="text-muted-foreground">Ukończono (wymagane)</span>
          <span class="font-semibold">{{ completedRequired }}/{{ requiredCount }}</span>
        </div>
      </div>

      <Accordion type="multiple" class="rounded-lg border">
        <AccordionItem
          v-for="s in orderedSections"
          :key="s.id"
          :value="s.id"
          class="px-4 last:border-b-0"
        >
          <AccordionTrigger class="hover:no-underline">
            <span class="flex items-center gap-2">
              <CheckCircle2 v-if="s.completed" class="size-4 text-primary" />
              <Circle v-else class="size-4 text-muted-foreground" />
              {{ s.def?.name ?? 'Sekcja' }}
              <Badge v-if="s.def && !s.def.required" variant="secondary" class="text-xs">opcjonalna</Badge>
            </span>
          </AccordionTrigger>
          <AccordionContent>
            <div v-if="editable && s.def" class="space-y-3 pb-2">
              <div v-for="f in s.def.fields" :key="f.key" class="space-y-1.5">
                <template v-if="f.type === 'boolean'">
                  <label class="flex items-center gap-2 text-sm">
                    <Checkbox v-model="forms[s.id][f.key]" />
                    {{ f.label }}
                  </label>
                </template>
                <template v-else>
                  <Label class="text-xs text-muted-foreground">{{ moneyLabel(f) }}</Label>
                  <Textarea v-if="f.type === 'text'" v-model="forms[s.id][f.key]" rows="2" />
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

            <dl v-else-if="s.def" class="space-y-2 pb-2 text-sm">
              <div v-for="f in s.def.fields" :key="f.key" class="flex justify-between gap-4">
                <dt class="text-muted-foreground">{{ moneyLabel(f) }}</dt>
                <dd class="text-right font-medium">{{ displayValue(s, f) }}</dd>
              </div>
            </dl>
          </AccordionContent>
        </AccordionItem>
      </Accordion>

      <div v-if="editable" class="space-y-2">
        <Button class="w-full" :disabled="!allComplete || closing" @click="closeReport">
          {{ closing ? 'Zamykanie…' : 'Zamknij raport' }}
        </Button>
        <p v-if="!allComplete" class="text-center text-xs text-muted-foreground">
          Aby zamknąć raport, uzupełnij i oznacz jako gotowe wszystkie wymagane sekcje
          ({{ completedRequired }}/{{ requiredCount }}).
        </p>
      </div>
    </template>
  </div>
</template>
