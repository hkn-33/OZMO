<script setup lang="ts">
import { CalendarDays, CalendarClock, LayoutTemplate } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

const { activeOrgId, isAdmin, load: loadOrg } = useOrg()
const { activeBranchId, activeBranch, load: loadBranch } = useBranch()
await loadOrg()
await loadBranch()
watch(activeOrgId, () => loadBranch(true))

const { data: branchInfo } = await useAsyncData(
  () => `schedule-branch:${activeBranchId.value}`,
  async () => {
    if (!activeBranchId.value || !user.value) {
      return { role: null as BranchRole | null, timezone: 'Europe/Warsaw' }
    }
    const [role, branch] = await Promise.all([
      supabase
        .from('branch_members')
        .select('role')
        .eq('branch_id', activeBranchId.value)
        .eq('user_id', user.value.id)
        .maybeSingle(),
      supabase
        .from('branches')
        .select('timezone')
        .eq('id', activeBranchId.value)
        .maybeSingle(),
    ])
    return {
      role: (role.data?.role ?? null) as BranchRole | null,
      timezone: branch.data?.timezone ?? 'Europe/Warsaw',
    }
  },
  { watch: [activeBranchId] },
)

const canManage = computed(() => isAdmin.value || branchInfo.value?.role === 'manager')
const timezone = computed(() => branchInfo.value?.timezone ?? 'Europe/Warsaw')
const tab = ref<'week' | 'availability' | 'templates'>('week')
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">Grafik</h1>
      <p class="text-muted-foreground">{{ activeBranch?.name ?? 'Wybierz oddział' }}</p>
    </div>

    <p
      v-if="!activeBranchId"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Nie masz dostępu do żadnego oddziału. Poproś administratora o przypisanie
      lub utwórz oddział w zakładce „Oddziały".
    </p>

    <Tabs v-else v-model="tab">
      <TabsList>
        <TabsTrigger value="week"><CalendarDays class="mr-1.5 size-4" /> Grafik</TabsTrigger>
        <TabsTrigger value="availability">
          <CalendarClock class="mr-1.5 size-4" /> Dostępność
        </TabsTrigger>
        <TabsTrigger v-if="canManage" value="templates">
          <LayoutTemplate class="mr-1.5 size-4" /> Szablony
        </TabsTrigger>
      </TabsList>

      <TabsContent value="week" class="mt-4">
        <ScheduleWeekView
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
          :can-manage="canManage"
          :timezone="timezone"
        />
      </TabsContent>

      <TabsContent value="availability" class="mt-4">
        <ScheduleAvailability
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
          :can-manage="canManage"
        />
      </TabsContent>

      <TabsContent v-if="canManage" value="templates" class="mt-4">
        <ScheduleTemplates
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
        />
      </TabsContent>
    </Tabs>
  </div>
</template>
