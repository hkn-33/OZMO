<script setup lang="ts">
import { Building2, CalendarClock } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { tzTime } from '~/lib/tz'

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

type NextShift = {
  id: string
  starts_at: string
  ends_at: string
  position: string | null
  branches: { name: string; timezone: string } | null
}

const { data: nextShift } = await useAsyncData(
  () => `next-shift:${user.value?.id}`,
  async () => {
    if (!user.value?.id) return null
    const { data } = await supabase
      .from('shifts')
      .select('id, starts_at, ends_at, position, branches(name, timezone)')
      .eq('user_id', user.value.id)
      .eq('published', true)
      .gte('starts_at', new Date().toISOString())
      .order('starts_at', { ascending: true })
      .limit(1)
      .maybeSingle()
    return (data ?? null) as unknown as NextShift | null
  },
  { watch: [user] },
)

const nextShiftLabel = computed(() => {
  const s = nextShift.value
  if (!s) return null
  const tz = s.branches?.timezone ?? 'Europe/Warsaw'
  const day = new Intl.DateTimeFormat('pl-PL', {
    weekday: 'long', day: 'numeric', month: 'long', timeZone: tz,
  }).format(new Date(s.starts_at))
  return `${day}, ${tzTime(s.starts_at, tz)}–${tzTime(s.ends_at, tz)}`
})
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

    <NuxtLink v-if="nextShiftLabel" to="/schedule" class="block">
      <Card class="transition-colors hover:bg-accent">
        <CardHeader class="pb-3">
          <CardTitle class="flex items-center gap-2 text-base">
            <CalendarClock class="size-4" /> Twoja najbliższa zmiana
          </CardTitle>
          <CardDescription class="text-foreground">
            {{ nextShiftLabel }}
            <template v-if="nextShift?.position"> · {{ nextShift.position }}</template>
            <template v-if="nextShift?.branches?.name"> · {{ nextShift.branches.name }}</template>
          </CardDescription>
        </CardHeader>
      </Card>
    </NuxtLink>

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
