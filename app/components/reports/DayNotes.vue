<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Trash2, Pencil, X, Check } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { formatDateTime } from '~/lib/utils'
import type { Attachment } from '~/composables/useAttachments'

type Severity = Database['public']['Enums']['day_note_severity']

const props = defineProps<{
  orgId: string
  branchId: string
  isBranchManager: boolean
}>()

const supabase = useSupabaseClient<Database>()
const { isDemo, upgradeOpen } = useDemoGuard()
function blockDemo() {
  if (isDemo.value) { upgradeOpen.value = true; return true }
  return false
}
const user = useSupabaseUser()

interface Note {
  id: string
  author_id: string
  date: string
  body: string
  severity: Severity
  created_at: string
  attachments: Attachment[]
}

function todayStr() {
  const d = new Date()
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 10)
}

const date = ref(todayStr())
const notes = ref<Note[]>([])
const names = ref<Record<string, string>>({})
const loading = ref(false)

const newBody = ref('')
const newSeverity = ref<Severity>('info')
const newAttachments = ref<Attachment[]>([])
const saving = ref(false)

const editingId = ref<string | null>(null)
const editBody = ref('')

const isToday = computed(() => date.value === todayStr())

function nameOf(id: string) {
  return names.value[id] ?? 'Użytkownik'
}

async function resolveNames(ids: string[]) {
  const missing = [...new Set(ids)].filter((id) => !(id in names.value))
  if (!missing.length) return
  const { data } = await supabase.from('profiles').select('id, full_name').in('id', missing)
  const next = { ...names.value }
  for (const id of missing) next[id] = 'Użytkownik'
  for (const p of data ?? []) next[p.id] = p.full_name?.trim() || 'Użytkownik'
  names.value = next
}

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('day_notes')
    .select('id, author_id, date, body, severity, created_at, attachments')
    .eq('branch_id', props.branchId)
    .eq('date', date.value)
    .order('created_at', { ascending: false })
  notes.value = (data ?? []) as unknown as Note[]
  await resolveNames(notes.value.map((n) => n.author_id))
  loading.value = false
}

watch([() => props.branchId, date], load, { immediate: true })

async function addNote() {
  if (blockDemo()) return
  const text = newBody.value.trim()
  if (!text || !user.value) return
  saving.value = true
  const { data, error } = await supabase
    .from('day_notes')
    .insert({
      org_id: props.orgId,
      branch_id: props.branchId,
      author_id: user.value.id,
      date: date.value,
      body: text,
      severity: newSeverity.value,
      attachments: newAttachments.value,
    })
    .select('id, author_id, date, body, severity, created_at, attachments')
    .single()
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać wpisu', { description: error.message })
    return
  }
  if (data) {
    notes.value.unshift(data as unknown as Note)
    await resolveNames([data.author_id])
  }
  newBody.value = ''
  newSeverity.value = 'info'
  newAttachments.value = []
}

function canEdit(n: Note) {
  return props.isBranchManager || (n.author_id === user.value?.id && n.date === todayStr())
}

function startEdit(n: Note) {
  editingId.value = n.id
  editBody.value = n.body
}
function cancelEdit() {
  editingId.value = null
  editBody.value = ''
}
async function saveEdit(n: Note) {
  if (blockDemo()) return
  const text = editBody.value.trim()
  if (!text) return
  const { error } = await supabase.from('day_notes').update({ body: text }).eq('id', n.id)
  if (error) {
    toast.error('Nie udało się zapisać', { description: error.message })
    return
  }
  n.body = text
  cancelEdit()
}
async function remove(n: Note) {
  if (blockDemo()) return
  if (!confirm('Usunąć ten wpis?')) return
  const { error } = await supabase.from('day_notes').delete().eq('id', n.id)
  if (error) {
    toast.error('Nie udało się usunąć', { description: error.message })
    return
  }
  notes.value = notes.value.filter((x) => x.id !== n.id)
}
</script>

<template>
  <div class="space-y-5">
    <!-- Data -->
    <div class="flex items-center gap-3">
      <Label for="dn-date" class="text-sm text-muted-foreground">Data</Label>
      <Input id="dn-date" v-model="date" type="date" class="w-auto" />
    </div>

    <!-- Szybki wpis (tylko dla dzisiejszej daty) -->
    <Card v-if="isToday">
      <CardContent class="space-y-3 pt-6">
        <Textarea
          v-model="newBody"
          rows="2"
          placeholder="Co się wydarzyło na zmianie? (np. awaria ekspresu, brak dostawy)"
        />
        <AttachmentInput
          v-model="newAttachments"
          :org-id="orgId"
          :branch-id="branchId"
          context="day-note"
        />
        <div class="flex items-center justify-between gap-3">
          <div class="flex gap-1.5">
            <Button
              size="sm"
              :variant="newSeverity === 'info' ? 'default' : 'outline'"
              @click="newSeverity = 'info'"
            >
              Info
            </Button>
            <Button
              size="sm"
              :variant="newSeverity === 'issue' ? 'destructive' : 'outline'"
              @click="newSeverity = 'issue'"
            >
              Problem
            </Button>
          </div>
          <Button :disabled="saving || !newBody.trim()" @click="addNote">Dodaj wpis</Button>
        </div>
      </CardContent>
    </Card>

    <!-- Feed -->
    <p v-if="loading" class="text-sm text-muted-foreground">Ładowanie…</p>
    <p
      v-else-if="!notes.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak wpisów na ten dzień.
    </p>
    <ul v-else class="space-y-2">
      <li v-for="n in notes" :key="n.id" class="rounded-lg border p-3">
        <div class="flex items-start justify-between gap-3">
          <div class="flex items-center gap-2">
            <Badge :variant="n.severity === 'issue' ? 'danger' : 'info'">
              {{ n.severity === 'issue' ? 'Problem' : 'Info' }}
            </Badge>
            <span class="text-sm font-medium">{{ nameOf(n.author_id) }}</span>
            <span class="text-[11px] text-muted-foreground">{{ formatDateTime(n.created_at) }}</span>
          </div>
          <div v-if="canEdit(n) && editingId !== n.id" class="flex gap-1">
            <Button variant="ghost" size="icon" class="size-7" @click="startEdit(n)">
              <Pencil class="size-3.5" />
            </Button>
            <Button variant="ghost" size="icon" class="size-7 text-destructive" @click="remove(n)">
              <Trash2 class="size-3.5" />
            </Button>
          </div>
        </div>

        <div v-if="editingId === n.id" class="mt-2 space-y-2">
          <Textarea v-model="editBody" rows="2" />
          <div class="flex justify-end gap-1.5">
            <Button variant="ghost" size="sm" @click="cancelEdit"><X class="mr-1 size-4" /> Anuluj</Button>
            <Button size="sm" @click="saveEdit(n)"><Check class="mr-1 size-4" /> Zapisz</Button>
          </div>
        </div>
        <template v-else>
          <p class="mt-1.5 whitespace-pre-wrap text-sm">{{ n.body }}</p>
          <AttachmentList :attachments="n.attachments" />
        </template>
      </li>
    </ul>
  </div>
</template>
