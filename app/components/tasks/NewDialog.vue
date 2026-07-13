<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

type TaskPriority = Database['public']['Enums']['task_priority']

export interface TaskMember {
  user_id: string
  profiles: { full_name: string | null; avatar_url: string | null } | null
}
interface TaskTemplate {
  id: string
  name: string
  items: { label: string }[]
}

const props = defineProps<{
  orgId: string
  branchId: string
  members: TaskMember[]
  templates: TaskTemplate[]
}>()

const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ created: [] }>()

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

const priorityLabels: Record<TaskPriority, string> = {
  low: 'Niski',
  normal: 'Normalny',
  high: 'Wysoki',
  urgent: 'Pilny',
}

const form = reactive({
  title: '',
  description: '',
  priority: 'normal' as TaskPriority,
  due: '',
  templateId: '',
})
const selectedAssignees = ref<Set<string>>(new Set())
const saving = ref(false)

watch(open, (v) => {
  if (v) {
    form.title = ''
    form.description = ''
    form.priority = 'normal'
    form.due = ''
    form.templateId = ''
    selectedAssignees.value = new Set()
  }
})

function toggleAssignee(userId: string) {
  const next = new Set(selectedAssignees.value)
  if (next.has(userId)) next.delete(userId)
  else next.add(userId)
  selectedAssignees.value = next
}

function memberName(m: TaskMember) {
  return m.profiles?.full_name?.trim() || 'Bez nazwy'
}

async function save() {
  if (!form.title.trim() || !user.value) return
  saving.value = true
  try {
    const { data: task, error } = await supabase
      .from('tasks')
      .insert({
        org_id: props.orgId,
        branch_id: props.branchId,
        title: form.title.trim(),
        description: form.description.trim() || null,
        priority: form.priority,
        due_at: form.due ? new Date(form.due).toISOString() : null,
        created_by: user.value.id,
        position: Date.now(),
      })
      .select('id')
      .single()
    if (error || !task) throw error ?? new Error('Brak zadania')

    const assignees = [...selectedAssignees.value]
    if (assignees.length) {
      const { error: aErr } = await supabase
        .from('task_assignees')
        .insert(assignees.map((uid) => ({ task_id: task.id, user_id: uid })))
      if (aErr) throw aErr
    }

    if (form.templateId) {
      const tpl = props.templates.find((t) => t.id === form.templateId)
      if (tpl?.items?.length) {
        const { error: cErr } = await supabase.from('task_checklist_items').insert(
          tpl.items.map((it, i) => ({ task_id: task.id, label: it.label, sort: i })),
        )
        if (cErr) throw cErr
      }
    }

    toast.success('Zadanie utworzone')
    open.value = false
    emit('created')
  } catch (e: any) {
    toast.error('Nie udało się utworzyć zadania', { description: e?.message })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogScrollContent class="max-h-[90svh]">
      <DialogHeader>
        <DialogTitle>Nowe zadanie</DialogTitle>
        <DialogDescription>Utwórz zadanie dla wybranego oddziału.</DialogDescription>
      </DialogHeader>
      <form class="space-y-4" @submit.prevent="save">
        <div class="space-y-2">
          <Label for="t-title">Tytuł</Label>
          <Input id="t-title" v-model="form.title" placeholder="np. Otwarcie zmiany" required />
        </div>
        <div class="space-y-2">
          <Label for="t-desc">Opis (opcjonalnie)</Label>
          <Textarea id="t-desc" v-model="form.description" rows="3" />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-2">
            <Label>Priorytet</Label>
            <Select v-model="form.priority">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="(label, key) in priorityLabels" :key="key" :value="key">
                  {{ label }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-2">
            <Label for="t-due">Termin (opcjonalnie)</Label>
            <Input id="t-due" v-model="form.due" type="datetime-local" />
          </div>
        </div>

        <div v-if="templates.length" class="space-y-2">
          <Label>Szablon checklisty (opcjonalnie)</Label>
          <Select v-model="form.templateId">
            <SelectTrigger><SelectValue placeholder="Bez szablonu" /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="t in templates" :key="t.id" :value="t.id">
                {{ t.name }} ({{ t.items?.length ?? 0 }})
              </SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div v-if="members.length" class="space-y-2">
          <Label>Przypisani</Label>
          <div class="max-h-40 space-y-1 overflow-y-auto rounded-md border p-2">
            <label
              v-for="m in members"
              :key="m.user_id"
              class="flex cursor-pointer items-center gap-2 rounded px-2 py-1.5 text-sm hover:bg-accent"
            >
              <Checkbox
                :model-value="selectedAssignees.has(m.user_id)"
                @update:model-value="toggleAssignee(m.user_id)"
              />
              {{ memberName(m) }}
            </label>
          </div>
        </div>

        <DialogFooter>
          <Button type="submit" :disabled="saving || !form.title.trim()">
            {{ saving ? 'Tworzenie…' : 'Utwórz zadanie' }}
          </Button>
        </DialogFooter>
      </form>
    </DialogScrollContent>
  </Dialog>
</template>
