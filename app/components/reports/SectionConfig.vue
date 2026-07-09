<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Trash2, ArrowUp, ArrowDown, GripVertical, Star } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{ orgId: string }>()

const supabase = useSupabaseClient<Database>()
const { isDemo, upgradeOpen } = useDemoGuard()
function blockDemo() {
  if (isDemo.value) { upgradeOpen.value = true; return true }
  return false
}

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

const FIELD_TYPES: { value: FieldType; label: string }[] = [
  { value: 'money', label: 'Kwota (zł)' },
  { value: 'number', label: 'Liczba' },
  { value: 'text', label: 'Tekst' },
  { value: 'boolean', label: 'Tak / Nie' },
]

const defs = ref<SectionDef[]>([])
const loading = ref(false)
const savingId = ref<string | null>(null)

function slugify(s: string) {
  return s
    .toLowerCase()
    .replace(/[ąćęłńóśźż]/g, (c) => ({ ą: 'a', ć: 'c', ę: 'e', ł: 'l', ń: 'n', ó: 'o', ś: 's', ź: 'z', ż: 'z' }[c] ?? c))
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('report_section_defs')
    .select('id, name, sort, fields, required, is_revenue_source')
    .eq('org_id', props.orgId)
    .order('sort', { ascending: true })
  defs.value = ((data ?? []) as unknown as SectionDef[]).map((d) => ({
    ...d,
    fields: Array.isArray(d.fields) ? d.fields : [],
  }))
  loading.value = false
}

watch(() => props.orgId, load, { immediate: true })

async function addDef() {
  if (blockDemo()) return
  const sort = defs.value.length ? Math.max(...defs.value.map((d) => d.sort)) + 1 : 0
  const { error } = await supabase
    .from('report_section_defs')
    .insert({ org_id: props.orgId, name: 'Nowa sekcja', sort, fields: [], required: true })
  if (error) {
    toast.error('Nie udało się dodać sekcji', { description: error.message })
    return
  }
  await load()
}

async function saveDef(d: SectionDef) {
  if (blockDemo()) return
  if (!d.name.trim()) {
    toast.error('Podaj nazwę sekcji')
    return
  }
  // Klucze pól: uzupełnij ze slug etykiety, jeśli puste.
  const fields = d.fields.map((f) => ({
    key: f.key.trim() || slugify(f.label) || 'pole',
    label: f.label.trim() || f.key,
    type: f.type,
  }))
  savingId.value = d.id
  const { error } = await supabase
    .from('report_section_defs')
    .update({ name: d.name.trim(), required: d.required, is_revenue_source: d.is_revenue_source, fields })
    .eq('id', d.id)
  // Tylko jedno źródło przychodu w organizacji.
  if (!error && d.is_revenue_source) {
    await supabase
      .from('report_section_defs')
      .update({ is_revenue_source: false })
      .eq('org_id', props.orgId)
      .neq('id', d.id)
  }
  savingId.value = null
  if (error) {
    toast.error('Nie udało się zapisać sekcji', { description: error.message })
    return
  }
  toast.success('Zapisano sekcję')
  await load()
}

async function removeDef(d: SectionDef) {
  if (blockDemo()) return
  if (!confirm(`Usunąć sekcję „${d.name}"? Usuwa też jej dane w istniejących raportach.`)) return
  const { error } = await supabase.from('report_section_defs').delete().eq('id', d.id)
  if (error) {
    toast.error('Nie udało się usunąć sekcji', { description: error.message })
    return
  }
  await load()
}

async function move(d: SectionDef, dir: -1 | 1) {
  if (blockDemo()) return
  const idx = defs.value.findIndex((x) => x.id === d.id)
  const other = defs.value[idx + dir]
  if (!other) return
  await supabase.from('report_section_defs').update({ sort: other.sort }).eq('id', d.id)
  await supabase.from('report_section_defs').update({ sort: d.sort }).eq('id', other.id)
  await load()
}

function addField(d: SectionDef) {
  d.fields.push({ key: '', label: '', type: 'text' })
}
function removeField(d: SectionDef, i: number) {
  d.fields.splice(i, 1)
}
function moveField(d: SectionDef, i: number, dir: -1 | 1) {
  const j = i + dir
  if (j < 0 || j >= d.fields.length) return
  const [f] = d.fields.splice(i, 1)
  d.fields.splice(j, 0, f!)
}
</script>

<template>
  <div class="space-y-5">
    <div class="flex items-center justify-between">
      <p class="text-sm text-muted-foreground">
        Definicje sekcji raportu menadżerskiego dla całej organizacji. Zmiany dotyczą
        nowych raportów.
      </p>
      <Button size="sm" @click="addDef"><Plus class="mr-1 size-4" /> Dodaj sekcję</Button>
    </div>

    <p v-if="loading" class="text-sm text-muted-foreground">Ładowanie…</p>
    <p
      v-else-if="!defs.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak sekcji. Dodaj pierwszą, aby menadżerowie mogli uzupełniać raport.
    </p>

    <Card v-for="(d, di) in defs" :key="d.id">
      <CardContent class="space-y-4 pt-6">
        <div class="flex flex-wrap items-center gap-2">
          <Input v-model="d.name" class="max-w-xs font-medium" placeholder="Nazwa sekcji" />
          <div class="ml-auto flex items-center gap-1">
            <Button variant="ghost" size="icon" :disabled="di === 0" @click="move(d, -1)">
              <ArrowUp class="size-4" />
            </Button>
            <Button variant="ghost" size="icon" :disabled="di === defs.length - 1" @click="move(d, 1)">
              <ArrowDown class="size-4" />
            </Button>
            <Button variant="ghost" size="icon" @click="removeDef(d)">
              <Trash2 class="size-4 text-destructive" />
            </Button>
          </div>
        </div>

        <div class="flex flex-wrap gap-4">
          <label class="flex items-center gap-2 text-sm">
            <Checkbox v-model="d.required" /> Wymagana do zamknięcia raportu
          </label>
          <label class="flex items-center gap-2 text-sm">
            <Checkbox v-model="d.is_revenue_source" />
            <Star class="size-3.5 text-warning" /> Źródło przychodu (sumuje pola kwotowe)
          </label>
        </div>

        <!-- Edytor pól -->
        <div class="space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Pola</span>
            <Button variant="outline" size="sm" @click="addField(d)">
              <Plus class="mr-1 size-3.5" /> Pole
            </Button>
          </div>
          <p v-if="!d.fields.length" class="text-xs text-muted-foreground">Brak pól.</p>
          <div
            v-for="(f, fi) in d.fields"
            :key="fi"
            class="flex flex-wrap items-center gap-2 rounded-md border p-2"
          >
            <GripVertical class="size-4 text-muted-foreground" />
            <Input v-model="f.label" placeholder="Etykieta pola" class="w-44" />
            <Input v-model="f.key" placeholder="klucz (auto)" class="w-32 font-mono text-xs" />
            <Select v-model="f.type">
              <SelectTrigger class="w-36"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="t in FIELD_TYPES" :key="t.value" :value="t.value">{{ t.label }}</SelectItem>
              </SelectContent>
            </Select>
            <div class="ml-auto flex items-center gap-1">
              <Button variant="ghost" size="icon" :disabled="fi === 0" @click="moveField(d, fi, -1)">
                <ArrowUp class="size-4" />
              </Button>
              <Button variant="ghost" size="icon" :disabled="fi === d.fields.length - 1" @click="moveField(d, fi, 1)">
                <ArrowDown class="size-4" />
              </Button>
              <Button variant="ghost" size="icon" @click="removeField(d, fi)">
                <Trash2 class="size-4 text-destructive" />
              </Button>
            </div>
          </div>
        </div>

        <div class="flex justify-end border-t pt-3">
          <Button size="sm" :disabled="savingId === d.id" @click="saveDef(d)">
            {{ savingId === d.id ? 'Zapisywanie…' : 'Zapisz sekcję' }}
          </Button>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
