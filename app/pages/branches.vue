<script setup lang="ts">
import { toast } from 'vue-sonner'
import { MapPin, Users as UsersIcon, Plus, Pencil } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const supabase = useSupabaseClient<Database>()
const { block } = useDemoGuard()
const { activeOrgId, activeOrg, isAdmin, load } = useOrg()
await load()

type BranchRow = {
  id: string
  name: string
  address: string | null
  timezone: string
  active: boolean
  branch_members: { count: number }[]
}

const { data: branches, refresh, pending } = await useAsyncData(
  () => `branches:${activeOrgId.value}`,
  async () => {
    if (!activeOrgId.value) return []
    const { data, error } = await supabase
      .from('branches')
      .select('id, name, address, timezone, active, branch_members(count)')
      .eq('org_id', activeOrgId.value)
      .order('name')
    if (error) throw error
    return (data ?? []) as BranchRow[]
  },
  { watch: [activeOrgId] },
)

function memberCount(b: BranchRow) {
  return b.branch_members?.[0]?.count ?? 0
}

const dialogOpen = ref(false)
const editing = ref<BranchRow | null>(null)
const form = reactive({ name: '', address: '', timezone: 'Europe/Warsaw' })
const saving = ref(false)

function openCreate() {
  editing.value = null
  form.name = ''
  form.address = ''
  form.timezone = 'Europe/Warsaw'
  dialogOpen.value = true
}

function openEdit(b: BranchRow) {
  editing.value = b
  form.name = b.name
  form.address = b.address ?? ''
  form.timezone = b.timezone
  dialogOpen.value = true
}

async function save() {
  if (block()) return
  if (!form.name.trim() || !activeOrgId.value) return
  saving.value = true
  const payload = {
    name: form.name.trim(),
    address: form.address.trim() || null,
    timezone: form.timezone.trim() || 'Europe/Warsaw',
  }
  const { error } = editing.value
    ? await supabase.from('branches').update(payload).eq('id', editing.value.id)
    : await supabase.from('branches').insert({ ...payload, org_id: activeOrgId.value })
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać oddziału', { description: error.message })
    return
  }
  dialogOpen.value = false
  toast.success(editing.value ? 'Oddział zaktualizowany' : 'Oddział dodany')
  await refresh()
}

async function toggleActive(b: BranchRow) {
  if (block()) return
  const { error } = await supabase
    .from('branches')
    .update({ active: !b.active })
    .eq('id', b.id)
  if (error) {
    toast.error('Nie udało się zmienić statusu', { description: error.message })
    return
  }
  await refresh()
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">Oddziały</h1>
        <p class="text-muted-foreground">
          {{ activeOrg?.name ?? '' }} — oddziały w Twojej firmie.
        </p>
      </div>
      <Button v-if="isAdmin" @click="openCreate">
        <Plus class="mr-2 size-4" />
        Dodaj oddział
      </Button>
    </div>

    <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>

    <p
      v-else-if="!branches?.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak oddziałów.
      <template v-if="isAdmin">Dodaj pierwszy, aby zacząć.</template>
    </p>

    <div v-else class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <Card v-for="b in branches" :key="b.id" :class="{ 'opacity-60': !b.active }">
        <CardHeader>
          <div class="flex items-start justify-between gap-2">
            <CardTitle class="flex items-center gap-2">
              {{ b.name }}
              <Badge v-if="!b.active" variant="secondary">nieaktywny</Badge>
            </CardTitle>
            <Button
              v-if="isAdmin"
              variant="ghost"
              size="icon"
              class="-mt-1 -mr-2 shrink-0"
              @click="openEdit(b)"
            >
              <Pencil class="size-4" />
            </Button>
          </div>
        </CardHeader>
        <CardContent class="space-y-2 text-sm text-muted-foreground">
          <p v-if="b.address" class="flex items-center gap-2">
            <MapPin class="size-4 shrink-0" /> {{ b.address }}
          </p>
          <p class="flex items-center gap-2">
            <UsersIcon class="size-4 shrink-0" />
            {{ memberCount(b) }} {{ memberCount(b) === 1 ? 'osoba' : 'osób' }}
          </p>
        </CardContent>
        <CardFooter v-if="isAdmin">
          <Button variant="outline" size="sm" @click="toggleActive(b)">
            {{ b.active ? 'Dezaktywuj' : 'Aktywuj' }}
          </Button>
        </CardFooter>
      </Card>
    </div>

    <Dialog v-model:open="dialogOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Edytuj oddział' : 'Nowy oddział' }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="save">
          <div class="space-y-2">
            <Label for="b-name">Nazwa</Label>
            <Input id="b-name" v-model="form.name" placeholder="Oddział Centrum" required />
          </div>
          <div class="space-y-2">
            <Label for="b-address">Adres</Label>
            <Input id="b-address" v-model="form.address" placeholder="ul. Główna 1, Warszawa" />
          </div>
          <div class="space-y-2">
            <Label for="b-tz">Strefa czasowa</Label>
            <Input id="b-tz" v-model="form.timezone" placeholder="Europe/Warsaw" />
          </div>
          <DialogFooter>
            <Button type="submit" :disabled="saving">
              {{ saving ? 'Zapisywanie…' : 'Zapisz' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
