<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Trash2, Send, X, Plus, Check } from '@lucide/vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import type { Database } from '~~/shared/types/database.types'
import { formatRelative, formatDateTime } from '~/lib/utils'
import type { TaskMember } from '~/components/tasks/NewDialog.vue'
import type { Attachment } from '~/composables/useAttachments'

type TaskStatus = Database['public']['Enums']['task_status']
type TaskPriority = Database['public']['Enums']['task_priority']

const props = defineProps<{
  taskId: string | null
  orgId: string
  branchId: string
  members: TaskMember[]
  canManage: boolean
}>()

const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ changed: []; open: [id: string] }>()

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { isDemo, upgradeOpen } = useDemoGuard()
function blockDemo() {
  if (isDemo.value) {
    upgradeOpen.value = true
    return true
  }
  return false
}

const statusLabels: Record<TaskStatus, string> = {
  todo: 'Do zrobienia',
  in_progress: 'W trakcie',
  done: 'Zrobione',
}
const priorityLabels: Record<TaskPriority, string> = {
  low: 'Niski',
  normal: 'Normalny',
  high: 'Wysoki',
  urgent: 'Pilny',
}

type TaskFull = {
  id: string
  title: string
  description: string | null
  status: TaskStatus
  priority: TaskPriority
  due_at: string | null
}
type ChecklistItem = {
  id: string
  label: string
  done: boolean
  done_by: string | null
  done_at: string | null
  sort: number
}
type Comment = {
  id: string
  author_id: string
  body: string
  mentions: string[]
  created_at: string
  attachments: Attachment[]
}

type LinkedTask = { id: string; title: string; status: TaskStatus }

const task = ref<TaskFull | null>(null)
const assignees = ref<string[]>([])
const checklist = ref<ChecklistItem[]>([])
const comments = ref<Comment[]>([])
const loading = ref(false)

// Powiązane zadania
const linkedTasks = ref<LinkedTask[]>([])
const branchTasks = ref<LinkedTask[]>([])
const linkQuery = ref('')
const linkPickerOpen = ref(false)

const edit = reactive({ title: '', description: '', due: '' })
const savingDetails = ref(false)

let channel: RealtimeChannel | null = null

function memberName(id: string) {
  const m = props.members.find((x) => x.user_id === id)
  return m?.profiles?.full_name?.trim() || 'Użytkownik'
}
const unassignedMembers = computed(() =>
  props.members.filter((m) => !assignees.value.includes(m.user_id)),
)

function toLocalInput(iso: string | null) {
  if (!iso) return ''
  const d = new Date(iso)
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 16)
}

async function loadTask(id: string) {
  loading.value = true
  const [t, a, c, cm] = await Promise.all([
    supabase.from('tasks').select('id, title, description, status, priority, due_at').eq('id', id).single(),
    supabase.from('task_assignees').select('user_id').eq('task_id', id),
    supabase.from('task_checklist_items').select('*').eq('task_id', id).order('sort'),
    supabase.from('task_comments').select('id, author_id, body, mentions, created_at, attachments').eq('task_id', id).order('created_at'),
  ])
  task.value = (t.data as TaskFull) ?? null
  assignees.value = (a.data ?? []).map((x) => x.user_id)
  checklist.value = (c.data ?? []) as ChecklistItem[]
  comments.value = (cm.data ?? []) as unknown as Comment[]
  if (task.value) {
    edit.title = task.value.title
    edit.description = task.value.description ?? ''
    edit.due = toLocalInput(task.value.due_at)
  }
  loading.value = false
}

async function loadLinks(id: string) {
  const { data: links } = await supabase
    .from('task_links')
    .select('task_id, linked_task_id')
    .or(`task_id.eq.${id},linked_task_id.eq.${id}`)
  const otherIds = [
    ...new Set((links ?? []).map((l) => (l.task_id === id ? l.linked_task_id : l.task_id))),
  ]
  if (otherIds.length) {
    const { data } = await supabase.from('tasks').select('id, title, status').in('id', otherIds)
    linkedTasks.value = (data ?? []) as LinkedTask[]
  } else {
    linkedTasks.value = []
  }
  const { data: bt } = await supabase
    .from('tasks')
    .select('id, title, status')
    .eq('branch_id', props.branchId)
    .order('created_at', { ascending: false })
  branchTasks.value = (bt ?? []) as LinkedTask[]
}

const linkCandidates = computed(() => {
  const linkedIds = new Set(linkedTasks.value.map((t) => t.id))
  const q = linkQuery.value.toLowerCase()
  return branchTasks.value
    .filter((t) => t.id !== task.value?.id && !linkedIds.has(t.id))
    .filter((t) => !q || t.title.toLowerCase().includes(q))
    .slice(0, 8)
})

async function addLink(otherId: string) {
  if (!task.value) return
  if (blockDemo()) return
  const { error } = await supabase
    .from('task_links')
    .insert({ task_id: task.value.id, linked_task_id: otherId })
  if (error) {
    toast.error('Nie udało się powiązać', { description: error.message })
    return
  }
  linkQuery.value = ''
  linkPickerOpen.value = false
  await loadLinks(task.value.id)
}

async function removeLink(otherId: string) {
  if (!task.value) return
  if (blockDemo()) return
  const id = task.value.id
  const { error } = await supabase
    .from('task_links')
    .delete()
    .or(
      `and(task_id.eq.${id},linked_task_id.eq.${otherId}),and(task_id.eq.${otherId},linked_task_id.eq.${id})`,
    )
  if (error) {
    toast.error('Nie udało się usunąć powiązania', { description: error.message })
    return
  }
  await loadLinks(id)
}

async function subscribeComments(id: string) {
  const { data } = await supabase.auth.getSession()
  if (data.session) await supabase.realtime.setAuth(data.session.access_token)
  channel = supabase
    .channel(`task:${id}`, { config: { private: true } })
    .on('broadcast', { event: 'new_comment' }, (msg) => {
      const p = msg.payload as Comment
      if (!comments.value.some((c) => c.id === p.id)) {
        comments.value.push({
          id: p.id,
          author_id: p.author_id,
          body: p.body,
          mentions: p.mentions ?? [],
          created_at: p.created_at,
          attachments: p.attachments ?? [],
        })
      }
    })
  channel.subscribe()
}

function teardown() {
  if (channel) {
    supabase.removeChannel(channel)
    channel = null
  }
  task.value = null
  comments.value = []
  checklist.value = []
  assignees.value = []
  linkedTasks.value = []
  branchTasks.value = []
  linkQuery.value = ''
  linkPickerOpen.value = false
}

// Fallback: odśwież komentarze po powrocie fokusu do okna.
function onFocus() {
  if (open.value && props.taskId) {
    supabase
      .from('task_comments')
      .select('id, author_id, body, mentions, created_at, attachments')
      .eq('task_id', props.taskId)
      .order('created_at')
      .then(({ data }) => {
        if (data) comments.value = data as unknown as Comment[]
      })
  }
}
onMounted(() => window.addEventListener('focus', onFocus))
onBeforeUnmount(() => {
  window.removeEventListener('focus', onFocus)
  teardown()
})

watch(
  () => [open.value, props.taskId] as const,
  async ([isOpen, id], _prev, onCleanup) => {
    teardown()
    if (isOpen && id) {
      await loadTask(id)
      await subscribeComments(id)
      await loadLinks(id)
      onCleanup(() => teardown())
    }
  },
)

async function updateTaskField(patch: Partial<TaskFull>) {
  if (!task.value) return
  if (blockDemo()) return false
  const { error } = await supabase.from('tasks').update(patch).eq('id', task.value.id)
  if (error) {
    toast.error('Nie udało się zapisać', { description: error.message })
    return false
  }
  Object.assign(task.value, patch)
  emit('changed')
  return true
}

async function setStatus(status: TaskStatus) {
  await updateTaskField({ status })
}
async function setPriority(priority: TaskPriority) {
  await updateTaskField({ priority })
}
async function saveDetails() {
  savingDetails.value = true
  await updateTaskField({
    title: edit.title.trim() || task.value!.title,
    description: edit.description.trim() || null,
    due_at: edit.due ? new Date(edit.due).toISOString() : null,
  })
  savingDetails.value = false
  toast.success('Zapisano zmiany')
}

async function toggleChecklist(item: ChecklistItem) {
  if (blockDemo()) return
  const done = !item.done
  const { error } = await supabase
    .from('task_checklist_items')
    .update({
      done,
      done_by: done ? user.value?.id ?? null : null,
      done_at: done ? new Date().toISOString() : null,
    })
    .eq('id', item.id)
  if (error) {
    toast.error('Nie udało się zaktualizować', { description: error.message })
    return
  }
  item.done = done
  item.done_by = done ? user.value?.id ?? null : null
  item.done_at = done ? new Date().toISOString() : null
}

async function addAssignee(userId: string) {
  if (!task.value) return
  if (blockDemo()) return
  const { error } = await supabase
    .from('task_assignees')
    .insert({ task_id: task.value.id, user_id: userId })
  if (error) {
    toast.error('Nie udało się przypisać', { description: error.message })
    return
  }
  assignees.value.push(userId)
  emit('changed')
}
async function removeAssignee(userId: string) {
  if (!task.value) return
  if (blockDemo()) return
  const { error } = await supabase
    .from('task_assignees')
    .delete()
    .eq('task_id', task.value.id)
    .eq('user_id', userId)
  if (error) {
    toast.error('Nie udało się odpiąć', { description: error.message })
    return
  }
  assignees.value = assignees.value.filter((id) => id !== userId)
  emit('changed')
}

async function deleteTask() {
  if (!task.value) return
  if (blockDemo()) return
  if (!confirm(`Usunąć zadanie „${task.value.title}"? Tej operacji nie można cofnąć.`)) return
  const { error } = await supabase.from('tasks').delete().eq('id', task.value.id)
  if (error) {
    toast.error('Nie udało się usunąć zadania', { description: error.message })
    return
  }
  toast.success('Zadanie usunięte')
  open.value = false
  emit('changed')
}

// --- komentarze + @wzmianki ---
const commentBody = ref('')
const commentAttachments = ref<Attachment[]>([])
const mentionOpen = ref(false)
const mentionQuery = ref('')
const mentionMap = ref<Record<string, string>>({})
const sending = ref(false)

function onCommentInput() {
  const m = commentBody.value.match(/@([\p{L}]*)$/u)
  if (m) {
    mentionQuery.value = m[1].toLowerCase()
    mentionOpen.value = true
  } else {
    mentionOpen.value = false
  }
}
const mentionCandidates = computed(() =>
  props.members
    .filter((m) => (m.profiles?.full_name ?? '').toLowerCase().includes(mentionQuery.value))
    .slice(0, 6),
)
function pickMention(m: TaskMember) {
  const name = m.profiles?.full_name?.trim() || 'Użytkownik'
  commentBody.value = commentBody.value.replace(/@[\p{L}]*$/u, `@${name} `)
  mentionMap.value[name] = m.user_id
  mentionOpen.value = false
}

async function sendComment() {
  if ((!commentBody.value.trim() && !commentAttachments.value.length) || !task.value || !user.value) return
  if (blockDemo()) return
  const ids = new Set<string>()
  for (const [name, id] of Object.entries(mentionMap.value)) {
    if (commentBody.value.includes(`@${name}`)) ids.add(id)
  }
  sending.value = true
  const { data, error } = await supabase
    .from('task_comments')
    .insert({
      task_id: task.value.id,
      org_id: props.orgId,
      branch_id: props.branchId,
      author_id: user.value.id,
      body: commentBody.value.trim(),
      mentions: [...ids],
      attachments: commentAttachments.value,
    })
    .select('id, author_id, body, mentions, created_at, attachments')
    .single()
  sending.value = false
  if (error) {
    toast.error('Nie udało się wysłać komentarza', { description: error.message })
    return
  }
  if (data && !comments.value.some((c) => c.id === data.id)) {
    comments.value.push(data as unknown as Comment)
  }
  commentBody.value = ''
  commentAttachments.value = []
  mentionMap.value = {}
}

const doneCount = computed(() => checklist.value.filter((i) => i.done).length)
</script>

<template>
  <Sheet v-model:open="open">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-lg">
      <SheetHeader class="border-b p-4">
        <SheetTitle class="pr-6">{{ task?.title ?? 'Zadanie' }}</SheetTitle>
        <SheetDescription class="sr-only">Szczegóły zadania</SheetDescription>
      </SheetHeader>

      <div v-if="loading" class="p-4 text-sm text-muted-foreground">Ładowanie…</div>

      <div v-else-if="task" class="flex-1 space-y-6 overflow-y-auto p-4">
        <!-- Status + priorytet -->
        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-1.5">
            <Label class="text-xs text-muted-foreground">Status</Label>
            <Select :model-value="task.status" @update:model-value="(v) => setStatus(v as TaskStatus)">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="(l, k) in statusLabels" :key="k" :value="k">{{ l }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-1.5">
            <Label class="text-xs text-muted-foreground">Priorytet</Label>
            <Select :model-value="task.priority" @update:model-value="(v) => setPriority(v as TaskPriority)">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="(l, k) in priorityLabels" :key="k" :value="k">{{ l }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>

        <!-- Edycja pól -->
        <div class="space-y-3">
          <div class="space-y-1.5">
            <Label for="d-title" class="text-xs text-muted-foreground">Tytuł</Label>
            <Input id="d-title" v-model="edit.title" />
          </div>
          <div class="space-y-1.5">
            <Label for="d-desc" class="text-xs text-muted-foreground">Opis</Label>
            <Textarea id="d-desc" v-model="edit.description" rows="3" />
          </div>
          <div class="space-y-1.5">
            <Label for="d-due" class="text-xs text-muted-foreground">Termin</Label>
            <Input id="d-due" v-model="edit.due" type="datetime-local" />
          </div>
          <Button size="sm" variant="outline" :disabled="savingDetails" @click="saveDetails">
            {{ savingDetails ? 'Zapisywanie…' : 'Zapisz zmiany' }}
          </Button>
        </div>

        <!-- Przypisani -->
        <div class="space-y-2">
          <Label class="text-xs text-muted-foreground">Przypisani</Label>
          <div class="flex flex-wrap items-center gap-1.5">
            <Badge v-for="id in assignees" :key="id" variant="secondary" class="gap-1">
              {{ memberName(id) }}
              <button class="opacity-60 hover:opacity-100" @click="removeAssignee(id)">
                <X class="size-3" />
              </button>
            </Badge>
            <DropdownMenu v-if="unassignedMembers.length">
              <DropdownMenuTrigger as-child>
                <Button variant="outline" size="sm" class="h-6 gap-1 px-2 text-xs">
                  <Plus class="size-3" /> Dodaj
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start">
                <DropdownMenuItem
                  v-for="m in unassignedMembers"
                  :key="m.user_id"
                  @select="addAssignee(m.user_id)"
                >
                  {{ memberName(m.user_id) }}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </div>

        <!-- Checklista -->
        <div v-if="checklist.length" class="space-y-2">
          <Label class="text-xs text-muted-foreground">
            Checklista ({{ doneCount }}/{{ checklist.length }})
          </Label>
          <ul class="space-y-1">
            <li
              v-for="item in checklist"
              :key="item.id"
              class="flex items-start gap-2 rounded px-1 py-1"
            >
              <Checkbox
                :model-value="item.done"
                class="mt-0.5"
                @update:model-value="toggleChecklist(item)"
              />
              <div class="min-w-0 flex-1">
                <span class="text-sm" :class="{ 'text-muted-foreground line-through': item.done }">
                  {{ item.label }}
                </span>
                <p v-if="item.done && item.done_by" class="text-[11px] text-muted-foreground">
                  {{ memberName(item.done_by) }} · {{ formatDateTime(item.done_at) }}
                </p>
              </div>
            </li>
          </ul>
        </div>

        <!-- Powiązane zadania -->
        <div class="space-y-2">
          <Label class="text-xs text-muted-foreground">Powiązane zadania</Label>
          <ul v-if="linkedTasks.length" class="space-y-1">
            <li
              v-for="lt in linkedTasks"
              :key="lt.id"
              class="flex items-center gap-2 rounded border px-2 py-1.5"
            >
              <button
                data-testid="linked-task"
                class="min-w-0 flex-1 truncate text-left text-sm hover:underline"
                @click="emit('open', lt.id)"
              >
                {{ lt.title }}
              </button>
              <Badge variant="secondary" class="shrink-0 text-[10px]">
                {{ statusLabels[lt.status] }}
              </Badge>
              <button class="shrink-0 opacity-60 hover:opacity-100" @click="removeLink(lt.id)">
                <X class="size-3.5" />
              </button>
            </li>
          </ul>
          <div class="relative">
            <Button
              variant="outline"
              size="sm"
              class="h-7 gap-1 px-2 text-xs"
              @click="linkPickerOpen = !linkPickerOpen"
            >
              <Plus class="size-3" /> Powiąż zadanie
            </Button>
            <div
              v-if="linkPickerOpen"
              class="absolute left-0 top-full z-10 mt-1 w-full overflow-hidden rounded-md border bg-popover shadow-md"
            >
              <Input
                v-model="linkQuery"
                placeholder="Szukaj zadania…"
                class="rounded-none border-0 border-b focus-visible:ring-0"
              />
              <div class="max-h-48 overflow-y-auto">
                <button
                  v-for="c in linkCandidates"
                  :key="c.id"
                  data-testid="link-candidate"
                  class="flex w-full items-center justify-between gap-2 px-3 py-1.5 text-left text-sm hover:bg-accent"
                  @click="addLink(c.id)"
                >
                  <span class="min-w-0 flex-1 truncate">{{ c.title }}</span>
                  <Badge variant="secondary" class="shrink-0 text-[10px]">
                    {{ statusLabels[c.status] }}
                  </Badge>
                </button>
                <p v-if="!linkCandidates.length" class="px-3 py-2 text-xs text-muted-foreground">
                  Brak zadań do powiązania.
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Komentarze -->
        <div class="space-y-3">
          <Label class="text-xs text-muted-foreground">Komentarze</Label>
          <div v-if="!comments.length" class="text-sm text-muted-foreground">
            Brak komentarzy. Napisz pierwszy.
          </div>
          <ul v-else class="space-y-3">
            <li v-for="c in comments" :key="c.id" class="flex gap-2">
              <Avatar class="size-7 shrink-0">
                <AvatarFallback class="text-xs">
                  {{ (memberName(c.author_id)[0] ?? '?').toUpperCase() }}
                </AvatarFallback>
              </Avatar>
              <div class="min-w-0 flex-1">
                <div class="flex items-baseline gap-2">
                  <span class="text-sm font-medium">{{ memberName(c.author_id) }}</span>
                  <span class="text-[11px] text-muted-foreground">{{ formatRelative(c.created_at) }}</span>
                </div>
                <p v-if="c.body" class="whitespace-pre-wrap text-sm">{{ c.body }}</p>
                <AttachmentList :attachments="c.attachments" />
              </div>
            </li>
          </ul>
        </div>
      </div>

      <!-- Stopka: nowy komentarz + usuwanie -->
      <div v-if="task" class="border-t p-3">
        <div class="relative">
          <div
            v-if="mentionOpen && mentionCandidates.length"
            class="absolute bottom-full left-0 mb-1 w-full overflow-hidden rounded-md border bg-popover shadow-md"
          >
            <button
              v-for="m in mentionCandidates"
              :key="m.user_id"
              class="flex w-full items-center gap-2 px-3 py-1.5 text-left text-sm hover:bg-accent"
              @click="pickMention(m)"
            >
              <span>{{ m.profiles?.full_name?.trim() || 'Użytkownik' }}</span>
            </button>
          </div>
          <AttachmentInput
            v-model="commentAttachments"
            :org-id="orgId"
            :branch-id="branchId"
            context="task-comment"
            class="mb-1.5"
          />
          <div class="flex items-end gap-2">
            <Textarea
              v-model="commentBody"
              rows="1"
              placeholder="Napisz komentarz… (@ aby wspomnieć)"
              class="min-h-9 resize-none"
              @input="onCommentInput"
              @keydown.enter.exact.prevent="sendComment"
            />
            <Button
              size="icon"
              :disabled="sending || (!commentBody.trim() && !commentAttachments.length)"
              @click="sendComment"
            >
              <Send class="size-4" />
            </Button>
          </div>
        </div>
        <div v-if="canManage" class="mt-2 flex justify-end">
          <Button variant="ghost" size="sm" class="text-destructive" @click="deleteTask">
            <Trash2 class="mr-1.5 size-4" /> Usuń zadanie
          </Button>
        </div>
      </div>
    </SheetContent>
  </Sheet>
</template>
