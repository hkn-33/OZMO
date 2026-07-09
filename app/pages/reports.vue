<script setup lang="ts">
import { FileText, ClipboardCheck, SlidersHorizontal } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

const { activeOrgId, isAdmin, load: loadOrg } = useOrg()
const { activeBranchId, activeBranch, load: loadBranch } = useBranch()
await loadOrg()
await loadBranch()
watch(activeOrgId, () => loadBranch(true))

const { data: myRole } = await useAsyncData(
  () => `report-role:${activeBranchId.value}`,
  async () => {
    if (!activeBranchId.value || !user.value) return null
    const { data } = await supabase
      .from('branch_members')
      .select('role')
      .eq('branch_id', activeBranchId.value)
      .eq('user_id', user.value.id)
      .maybeSingle()
    return (data?.role ?? null) as BranchRole | null
  },
  { watch: [activeBranchId] },
)

const isBranchManager = computed(() => isAdmin.value || myRole.value === 'manager')
const tab = ref<'day' | 'manager' | 'sections'>('day')
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">Raporty</h1>
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
        <TabsTrigger value="day"><FileText class="mr-1.5 size-4" /> Raport dnia</TabsTrigger>
        <TabsTrigger value="manager">
          <ClipboardCheck class="mr-1.5 size-4" /> Raport menadżerski
        </TabsTrigger>
        <TabsTrigger v-if="isAdmin" value="sections">
          <SlidersHorizontal class="mr-1.5 size-4" /> Sekcje raportu
        </TabsTrigger>
      </TabsList>

      <TabsContent value="day" class="mt-4">
        <ReportsDayNotes
          v-if="activeOrgId && activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
          :is-branch-manager="isBranchManager"
        />
      </TabsContent>

      <TabsContent value="manager" class="mt-4">
        <ReportsManagerReport
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
          :can-manage="isBranchManager"
        />
      </TabsContent>

      <TabsContent v-if="isAdmin" value="sections" class="mt-4">
        <ReportsSectionConfig v-if="activeOrgId" :org-id="activeOrgId" />
      </TabsContent>
    </Tabs>
  </div>
</template>
