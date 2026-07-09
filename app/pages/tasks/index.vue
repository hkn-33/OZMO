<script setup lang="ts">
import { Plus, List, LayoutGrid, ClipboardList } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import type { TaskMember } from '~/components/tasks/NewDialog.vue'
import type { TaskRow } from '~/components/tasks/ListView.vue'
import type { ChecklistTemplate } from '~/components/tasks/TemplatesManager.vue'

type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const route = useRoute()
const router = useRouter()

const { activeOrgId, isAdmin, load: loadOrg } = useOrg()
const { activeBranchId, activeBranch, load: loadBranch } = useBranch()
const { guard } = useDemoGuard()
await loadOrg()
await loadBranch()
watch(activeOrgId, () => loadBranch(true))

const { data, refresh, pending } = await useAsyncData(
  () => `tasks:${activeBranchId.value}`,
  async () => {
    const empty = { tasks: [] as TaskRow[], members: [] as TaskMember[], templates: [] as ChecklistTemplate[], myRole: null as BranchRole | null }
    if (!activeBranchId.value || !activeOrgId.value) return empty
    const [tasks, members, templates] = await Promise.all([
      supabase
        .from('tasks')
        .select('id, title, status, priority, due_at, position, task_assignees(user_id), task_checklist_items(id, done)')
        .eq('branch_id', activeBranchId.value)
        .order('position'),
      supabase
        .from('branch_members')
        .select('user_id, role, profiles(full_name, avatar_url)')
        .eq('branch_id', activeBranchId.value),
      supabase
        .from('checklist_templates')
        .select('id, name, description, items')
        .eq('org_id', activeOrgId.value)
        .order('name'),
    ])
    const mem = (members.data ?? []) as unknown as (TaskMember & { role: BranchRole })[]
    const myRole = mem.find((m) => m.user_id === user.value?.id)?.role ?? null
    return {
      tasks: (tasks.data ?? []) as unknown as TaskRow[],
      members: mem as TaskMember[],
      templates: (templates.data ?? []) as unknown as ChecklistTemplate[],
      myRole,
    }
  },
  { watch: [activeBranchId] },
)

const canManage = computed(() => isAdmin.value || data.value?.myRole === 'manager')

const view = ref<'list' | 'kanban' | 'templates'>('list')
const newOpen = ref(false)

// Szczegóły zadania (sheet) + deep-link z powiadomień (?task=)
const selectedTaskId = ref<string | null>(null)
const detailOpen = ref(false)

function openTask(id: string) {
  selectedTaskId.value = id
  detailOpen.value = true
}
watch(
  () => route.query.task,
  (t) => {
    if (typeof t === 'string' && t) openTask(t)
  },
  { immediate: true },
)
watch(detailOpen, (v) => {
  if (!v && route.query.task) router.replace({ query: {} })
})
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">Zadania</h1>
        <p class="text-muted-foreground">{{ activeBranch?.name ?? 'Wybierz oddział' }}</p>
      </div>
      <Button v-if="view !== 'templates' && activeBranchId" @click="guard(() => (newOpen = true))">
        <Plus class="mr-2 size-4" /> Nowe zadanie
      </Button>
    </div>

    <p
      v-if="!activeBranchId"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Nie masz dostępu do żadnego oddziału. Poproś administratora o przypisanie
      lub utwórz oddział w zakładce „Oddziały".
    </p>

    <Tabs v-else v-model="view">
      <TabsList>
        <TabsTrigger value="list"><List class="mr-1.5 size-4" /> Lista</TabsTrigger>
        <TabsTrigger value="kanban"><LayoutGrid class="mr-1.5 size-4" /> Kanban</TabsTrigger>
        <TabsTrigger value="templates"><ClipboardList class="mr-1.5 size-4" /> Szablony</TabsTrigger>
      </TabsList>

      <p v-if="pending" class="py-6 text-sm text-muted-foreground">Ładowanie…</p>

      <template v-else>
        <TabsContent value="list">
          <TasksListView
            :tasks="data!.tasks"
            :members="data!.members"
            @open="openTask"
            @create="guard(() => (newOpen = true))"
          />
        </TabsContent>
        <TabsContent value="kanban">
          <TasksKanban
            :tasks="data!.tasks"
            :members="data!.members"
            @open="openTask"
            @changed="refresh"
          />
        </TabsContent>
        <TabsContent value="templates">
          <TasksTemplatesManager
            :org-id="activeOrgId!"
            :templates="data!.templates"
            :can-manage="canManage"
            @changed="refresh"
          />
        </TabsContent>
      </template>
    </Tabs>

    <TasksNewDialog
      v-if="activeBranchId && activeOrgId"
      v-model:open="newOpen"
      :org-id="activeOrgId"
      :branch-id="activeBranchId"
      :members="data?.members ?? []"
      :templates="data?.templates ?? []"
      @created="refresh"
    />

    <TasksDetailSheet
      v-if="activeOrgId && activeBranchId"
      v-model:open="detailOpen"
      :task-id="selectedTaskId"
      :org-id="activeOrgId"
      :branch-id="activeBranchId"
      :members="data?.members ?? []"
      :can-manage="canManage"
      @changed="refresh"
      @open="openTask"
    />
  </div>
</template>
