<script setup lang="ts">
import { Boxes, ArrowLeftRight, PackageSearch, Truck } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

const { activeOrgId, isAdmin, load: loadOrg } = useOrg()
const { activeBranchId, activeBranch, load: loadBranch } = useBranch()
await loadOrg()
await loadBranch()
watch(activeOrgId, () => loadBranch(true))

const { data: role } = await useAsyncData(
  () => `stock-role:${activeBranchId.value}`,
  async () => {
    if (!activeBranchId.value || !user.value) return null as BranchRole | null
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

const canManage = computed(() => isAdmin.value || role.value === 'manager')
const tab = ref<'levels' | 'movements' | 'products' | 'suppliers'>('levels')
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">Magazyn</h1>
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
      <TabsList class="flex-wrap">
        <TabsTrigger value="levels"><Boxes class="mr-1.5 size-4" /> Stany</TabsTrigger>
        <TabsTrigger value="movements">
          <ArrowLeftRight class="mr-1.5 size-4" /> Przyjęcie/Wydanie
        </TabsTrigger>
        <TabsTrigger v-if="canManage" value="products">
          <PackageSearch class="mr-1.5 size-4" /> Produkty
        </TabsTrigger>
        <TabsTrigger v-if="canManage" value="suppliers">
          <Truck class="mr-1.5 size-4" /> Dostawcy
        </TabsTrigger>
      </TabsList>

      <TabsContent value="levels" class="mt-4">
        <StockLevels
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
        />
      </TabsContent>

      <TabsContent value="movements" class="mt-4">
        <StockMovementForm
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
        />
      </TabsContent>

      <TabsContent v-if="canManage" value="products" class="mt-4">
        <StockProducts
          v-if="activeOrgId && activeBranchId"
          :key="activeBranchId"
          :org-id="activeOrgId"
          :branch-id="activeBranchId"
        />
      </TabsContent>

      <TabsContent v-if="canManage" value="suppliers" class="mt-4">
        <StockSuppliers
          v-if="activeOrgId"
          :key="activeOrgId"
          :org-id="activeOrgId"
        />
      </TabsContent>
    </Tabs>
  </div>
</template>
