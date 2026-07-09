<script setup lang="ts">
import { Building2 } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { activeOrgId, activeOrg, role, load } = useOrg()
await load()

const roleLabels: Record<string, string> = {
  owner: 'Właściciel',
  admin: 'Administrator',
  member: 'Członek',
}

type MyBranch = {
  branch_id: string
  role: Database['public']['Enums']['branch_role']
  position: string | null
  branches: { id: string; name: string; address: string | null } | null
}

const { data: myBranches } = await useAsyncData(
  () => `my-branches:${activeOrgId.value}:${user.value?.id}`,
  async () => {
    if (!activeOrgId.value || !user.value) return []
    const { data } = await supabase
      .from('branch_members')
      .select('branch_id, role, position, branches!inner(id, name, address, org_id)')
      .eq('user_id', user.value.id)
      .eq('branches.org_id', activeOrgId.value)
    return (data ?? []) as unknown as MyBranch[]
  },
  { watch: [activeOrgId] },
)
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">
        {{ activeOrg?.name ?? 'OZMO' }}
      </h1>
      <p class="text-muted-foreground">
        Witaj{{ user?.email ? `, ${user.email}` : '' }}.
        <span v-if="role">Twoja rola: {{ roleLabels[role] }}.</span>
      </p>
    </div>

    <div>
      <h2 class="mb-3 text-lg font-semibold">Moje oddziały</h2>
      <p
        v-if="!myBranches?.length"
        class="rounded-lg border border-dashed p-6 text-center text-sm text-muted-foreground"
      >
        Nie jesteś przypisany do żadnego oddziału.
      </p>
      <div v-else class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <NuxtLink
          v-for="b in myBranches"
          :key="b.branch_id"
          to="/branches"
          class="block"
        >
          <Card class="h-full transition-colors hover:bg-accent">
            <CardHeader>
              <CardTitle class="flex items-center gap-2 text-base">
                <Building2 class="size-4" /> {{ b.branches?.name }}
              </CardTitle>
              <CardDescription v-if="b.branches?.address">
                {{ b.branches.address }}
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Badge variant="secondary">
                {{ b.role === 'manager' ? 'Menadżer' : 'Pracownik' }}
                <template v-if="b.position"> · {{ b.position }}</template>
              </Badge>
            </CardContent>
          </Card>
        </NuxtLink>
      </div>
    </div>
  </div>
</template>
