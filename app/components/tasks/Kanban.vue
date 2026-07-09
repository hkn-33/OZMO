<script setup lang="ts">
import { toast } from 'vue-sonner'
import { CalendarClock, ListChecks } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { formatDateTime } from '~/lib/utils'
import type { TaskMember } from '~/components/tasks/NewDialog.vue'
import type { TaskRow } from '~/components/tasks/ListView.vue'

type TaskStatus = Database['public']['Enums']['task_status']
type TaskPriority = Database['public']['Enums']['task_priority']

const props = defineProps<{ tasks: TaskRow[]; members: TaskMember[] }>()
const emit = defineEmits<{ open: [id: string]; changed: [] }>()

const supabase = useSupabaseClient<Database>()

const columns: { key: TaskStatus; label: string }[] = [
  { key: 'todo', label: 'Do zrobienia' },
  { key: 'in_progress', label: 'W trakcie' },
  { key: 'done', label: 'Zrobione' },
]
const priorityLabels: Record<TaskPriority, string> = {
  low: 'Niski',
  normal: 'Normalny',
  high: 'Wysoki',
  urgent: 'Pilny',
}
const priorityVariant: Record<TaskPriority, 'default' | 'secondary' | 'outline' | 'destructive' | 'warning'> = {
  low: 'outline',
  normal: 'secondary',
  high: 'warning',
  urgent: 'destructive',
}

function memberName(id: string) {
  const m = props.members.find((x) => x.user_id === id)
  return m?.profiles?.full_name?.trim() || 'Użytkownik'
}
function columnTasks(status: TaskStatus) {
  return props.tasks
    .filter((t) => t.status === status)
    .sort((a, b) => a.position - b.position)
}
function doneCount(t: TaskRow) {
  return t.task_checklist_items.filter((i) => i.done).length
}

const draggingId = ref<string | null>(null)
const overColumn = ref<TaskStatus | null>(null)

function onDragStart(id: string) {
  draggingId.value = id
}
async function onDrop(status: TaskStatus) {
  overColumn.value = null
  const id = draggingId.value
  draggingId.value = null
  if (!id) return
  const task = props.tasks.find((t) => t.id === id)
  if (!task || task.status === status) return
  // optymistycznie
  task.status = status
  task.position = Date.now()
  const { error } = await supabase
    .from('tasks')
    .update({ status, position: task.position })
    .eq('id', id)
  if (error) {
    toast.error('Nie udało się przenieść zadania', { description: error.message })
    emit('changed')
    return
  }
  emit('changed')
}
</script>

<template>
  <div class="grid gap-3 sm:grid-cols-3">
    <div
      v-for="col in columns"
      :key="col.key"
      class="flex flex-col rounded-lg border bg-muted/30 transition-colors"
      :class="{ 'ring-2 ring-primary': overColumn === col.key }"
      @dragover.prevent="overColumn = col.key"
      @dragleave="overColumn = null"
      @drop="onDrop(col.key)"
    >
      <div class="flex items-center justify-between border-b px-3 py-2">
        <span class="text-sm font-semibold">{{ col.label }}</span>
        <Badge variant="secondary">{{ columnTasks(col.key).length }}</Badge>
      </div>
      <div class="min-h-24 flex-1 space-y-2 p-2">
        <div
          v-for="t in columnTasks(col.key)"
          :key="t.id"
          draggable="true"
          class="cursor-grab rounded-md border bg-card p-2.5 shadow-sm active:cursor-grabbing"
          :class="{ 'opacity-50': draggingId === t.id }"
          @dragstart="onDragStart(t.id)"
          @click="emit('open', t.id)"
        >
          <p class="text-sm font-medium" :class="{ 'line-through': col.key === 'done' }">
            {{ t.title }}
          </p>
          <div class="mt-1.5 flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
            <Badge :variant="priorityVariant[t.priority]" class="text-[10px]">
              {{ priorityLabels[t.priority] }}
            </Badge>
            <span v-if="t.due_at" class="flex items-center gap-1">
              <CalendarClock class="size-3" /> {{ formatDateTime(t.due_at) }}
            </span>
            <span v-if="t.task_checklist_items.length" class="flex items-center gap-1">
              <ListChecks class="size-3" /> {{ doneCount(t) }}/{{ t.task_checklist_items.length }}
            </span>
          </div>
          <div v-if="t.task_assignees.length" class="mt-2 flex -space-x-2">
            <Avatar v-for="a in t.task_assignees.slice(0, 3)" :key="a.user_id" class="size-6 border-2 border-card">
              <AvatarFallback class="text-[10px]">
                {{ (memberName(a.user_id)[0] ?? '?').toUpperCase() }}
              </AvatarFallback>
            </Avatar>
          </div>
        </div>
        <p
          v-if="!columnTasks(col.key).length"
          class="py-6 text-center text-xs text-muted-foreground"
        >
          Przeciągnij tutaj
        </p>
      </div>
    </div>
  </div>
</template>
