<script setup lang="ts">
import { CalendarClock, ListChecks, Plus } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { formatDateTime } from '~/lib/utils'
import type { TaskMember } from '~/components/tasks/NewDialog.vue'

type TaskStatus = Database['public']['Enums']['task_status']
type TaskPriority = Database['public']['Enums']['task_priority']

export interface TaskRow {
  id: string
  title: string
  status: TaskStatus
  priority: TaskPriority
  due_at: string | null
  position: number
  task_assignees: { user_id: string }[]
  task_checklist_items: { id: string; done: boolean }[]
}

const props = defineProps<{ tasks: TaskRow[]; members: TaskMember[] }>()
const emit = defineEmits<{ open: [id: string]; create: [] }>()

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
type BadgeVariant = 'default' | 'secondary' | 'outline' | 'destructive' | 'success' | 'warning' | 'info'
const priorityVariant: Record<TaskPriority, BadgeVariant> = {
  low: 'outline',
  normal: 'secondary',
  high: 'warning',
  urgent: 'destructive',
}
const statusVariant: Record<TaskStatus, BadgeVariant> = {
  todo: 'info',
  in_progress: 'warning',
  done: 'success',
}
const priorityWeight: Record<TaskPriority, number> = { urgent: 0, high: 1, normal: 2, low: 3 }

const filters = reactive({ status: 'all', priority: 'all', assignee: 'all' })

function memberName(id: string) {
  const m = props.members.find((x) => x.user_id === id)
  return m?.profiles?.full_name?.trim() || 'Użytkownik'
}

const filtered = computed(() => {
  let rows = [...props.tasks]
  if (filters.status !== 'all') rows = rows.filter((t) => t.status === filters.status)
  if (filters.priority !== 'all') rows = rows.filter((t) => t.priority === filters.priority)
  if (filters.assignee !== 'all')
    rows = rows.filter((t) => t.task_assignees.some((a) => a.user_id === filters.assignee))
  // sort: termin rosnąco (null na końcu), potem priorytet
  rows.sort((a, b) => {
    const at = a.due_at ? new Date(a.due_at).getTime() : Infinity
    const bt = b.due_at ? new Date(b.due_at).getTime() : Infinity
    if (at !== bt) return at - bt
    return priorityWeight[a.priority] - priorityWeight[b.priority]
  })
  return rows
})

function doneCount(t: TaskRow) {
  return t.task_checklist_items.filter((i) => i.done).length
}
function isOverdue(t: TaskRow) {
  return !!t.due_at && t.status !== 'done' && new Date(t.due_at).getTime() < Date.now()
}
function resetFilters() {
  filters.status = 'all'
  filters.priority = 'all'
  filters.assignee = 'all'
}
</script>

<template>
  <div class="space-y-4">
    <!-- Filtry -->
    <div class="flex flex-wrap gap-2">
      <Select v-model="filters.status">
        <SelectTrigger class="w-40"><SelectValue placeholder="Status" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Wszystkie statusy</SelectItem>
          <SelectItem v-for="(l, k) in statusLabels" :key="k" :value="k">{{ l }}</SelectItem>
        </SelectContent>
      </Select>
      <Select v-model="filters.priority">
        <SelectTrigger class="w-40"><SelectValue placeholder="Priorytet" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Wszystkie priorytety</SelectItem>
          <SelectItem v-for="(l, k) in priorityLabels" :key="k" :value="k">{{ l }}</SelectItem>
        </SelectContent>
      </Select>
      <Select v-model="filters.assignee">
        <SelectTrigger class="w-44"><SelectValue placeholder="Przypisany" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Wszyscy przypisani</SelectItem>
          <SelectItem v-for="m in members" :key="m.user_id" :value="m.user_id">
            {{ memberName(m.user_id) }}
          </SelectItem>
        </SelectContent>
      </Select>
    </div>

    <div
      v-if="!filtered.length"
      class="rounded-lg border border-dashed p-8 text-center"
    >
      <template v-if="!tasks.length">
        <p class="text-sm font-medium">Brak zadań w tym oddziale</p>
        <p class="mx-auto mt-1 max-w-sm text-sm text-muted-foreground">
          Dodaj pierwsze zadanie, aby zacząć organizować pracę zespołu.
        </p>
        <Button size="sm" class="mt-4" @click="emit('create')">
          <Plus class="mr-1.5 size-4" /> Dodaj zadanie
        </Button>
      </template>
      <template v-else>
        <p class="text-sm text-muted-foreground">Brak zadań pasujących do filtrów.</p>
        <Button variant="outline" size="sm" class="mt-3" @click="resetFilters">
          Wyczyść filtry
        </Button>
      </template>
    </div>

    <div v-else class="space-y-2">
      <button
        v-for="t in filtered"
        :key="t.id"
        class="flex w-full items-center gap-3 rounded-lg border p-3 text-left transition-colors hover:bg-accent"
        @click="emit('open', t.id)"
      >
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="truncate font-medium" :class="{ 'text-muted-foreground line-through': t.status === 'done' }">
              {{ t.title }}
            </span>
          </div>
          <div class="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
            <Badge :variant="priorityVariant[t.priority]" class="text-[10px]">
              {{ priorityLabels[t.priority] }}
            </Badge>
            <Badge :variant="statusVariant[t.status]" class="text-[10px]">{{ statusLabels[t.status] }}</Badge>
            <Badge v-if="t.due_at && isOverdue(t)" variant="warning" class="gap-1 text-[10px]">
              <CalendarClock class="size-3" /> {{ formatDateTime(t.due_at) }}
            </Badge>
            <span v-else-if="t.due_at" class="flex items-center gap-1">
              <CalendarClock class="size-3" /> {{ formatDateTime(t.due_at) }}
            </span>
            <span v-if="t.task_checklist_items.length" class="flex items-center gap-1">
              <ListChecks class="size-3" /> {{ doneCount(t) }}/{{ t.task_checklist_items.length }}
            </span>
          </div>
        </div>
        <div class="flex -space-x-2">
          <Avatar v-for="a in t.task_assignees.slice(0, 3)" :key="a.user_id" class="size-7 border-2 border-background">
            <AvatarFallback class="text-[10px]">
              {{ (memberName(a.user_id)[0] ?? '?').toUpperCase() }}
            </AvatarFallback>
          </Avatar>
        </div>
      </button>
    </div>
  </div>
</template>
