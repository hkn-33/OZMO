<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Trash2 } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { WEEKDAYS_FULL } from '~/lib/schedule'

const props = defineProps<{
  orgId: string
  branchId: string
  canManage: boolean
}>()

const supabase = useSupabaseClient<Database>()
const { isDemo, upgradeOpen } = useDemoGuard()
function blockDemo() {
  if (isDemo.value) { upgradeOpen.value = true; return true }
  return false
}
const user = useSupabaseUser()

interface AvailRow {
  id: string
  user_id: string
  weekday: number
  from_time: string
  to_time: string
  note: string | null
}

const { data, refresh, pending } = await useAsyncData(
  () => `availability:${props.branchId}`,
  async () => {
    const [avail, members] = await Promise.all([
      supabase
        .from('availability')
        .select('id, user_id, weekday, from_time, to_time, note')
        .eq('branch_id', props.branchId)
        .order('weekday'),
      supabase
        .from('branch_members')
        .select('user_id, profiles(full_name)')
        .eq('branch_id', props.branchId),
    ])
    const mem = (members.data ?? []) as unknown as {
      user_id: string
      profiles: { full_name: string | null } | null
    }[]
    return {
      rows: (avail.data ?? []) as AvailRow[],
      names: Object.fromEntries(
        mem.map((m) => [m.user_id, m.profiles?.full_name?.trim() || 'Bez nazwy']),
      ) as Record<string, string>,
    }
  },
  { watch: [() => props.branchId] },
)

const myRows = computed(() =>
  (data.value?.rows ?? []).filter((r) => r.user_id === user.value?.id),
)
const teamByUser = computed(() => {
  const map: Record<string, AvailRow[]> = {}
  for (const r of data.value?.rows ?? []) {
    if (r.user_id === user.value?.id) continue
    ;(map[r.user_id] ??= []).push(r)
  }
  return map
})

function hm(t: string) {
  return t.slice(0, 5)
}

// Add form
const form = reactive({ weekday: '0', from: '08:00', to: '16:00', note: '' })
const saving = ref(false)

async function add() {
  if (blockDemo()) return
  if (!user.value) return
  if (form.to <= form.from) {
    toast.error('Godzina zakończenia musi być późniejsza niż rozpoczęcia')
    return
  }
  saving.value = true
  const { error } = await supabase.from('availability').insert({
    org_id: props.orgId,
    branch_id: props.branchId,
    user_id: user.value.id,
    weekday: Number(form.weekday),
    from_time: form.from,
    to_time: form.to,
    note: form.note.trim() || null,
  })
  saving.value = false
  if (error) {
    toast.error('Nie udało się dodać dostępności', { description: error.message })
    return
  }
  form.note = ''
  toast.success('Dostępność dodana')
  refresh()
}

async function remove(r: AvailRow) {
  if (blockDemo()) return
  const { error } = await supabase.from('availability').delete().eq('id', r.id)
  if (error) {
    toast.error('Nie udało się usunąć', { description: error.message })
    return
  }
  refresh()
}
</script>

<template>
  <div class="space-y-6">
    <!-- Moja dostępność -->
    <Card>
      <CardHeader>
        <CardTitle class="text-base">Moja dostępność</CardTitle>
        <CardDescription>Cotygodniowa dostępność, którą uwzględnia menadżer.</CardDescription>
      </CardHeader>
      <CardContent class="space-y-4">
        <form class="flex flex-wrap items-end gap-2" @submit.prevent="add">
          <div class="space-y-1.5">
            <Label class="text-xs">Dzień</Label>
            <Select v-model="form.weekday">
              <SelectTrigger class="w-40"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="(d, i) in WEEKDAYS_FULL" :key="i" :value="String(i)">
                  {{ d }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-1.5">
            <Label class="text-xs">Od</Label>
            <Input v-model="form.from" type="time" class="w-28" />
          </div>
          <div class="space-y-1.5">
            <Label class="text-xs">Do</Label>
            <Input v-model="form.to" type="time" class="w-28" />
          </div>
          <div class="min-w-40 flex-1 space-y-1.5">
            <Label class="text-xs">Notatka</Label>
            <Input v-model="form.note" placeholder="opcjonalnie" />
          </div>
          <Button type="submit" :disabled="saving">
            <Plus class="mr-1.5 size-4" /> Dodaj
          </Button>
        </form>

        <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>
        <p v-else-if="!myRows.length" class="text-sm text-muted-foreground">
          Nie zadeklarowano jeszcze dostępności.
        </p>
        <ul v-else class="divide-y rounded-md border">
          <li v-for="r in myRows" :key="r.id" class="flex items-center justify-between gap-3 px-3 py-2 text-sm">
            <span>
              <span class="font-medium">{{ WEEKDAYS_FULL[r.weekday] }}</span>
              <span class="text-muted-foreground"> · {{ hm(r.from_time) }}–{{ hm(r.to_time) }}</span>
              <span v-if="r.note" class="text-muted-foreground"> · {{ r.note }}</span>
            </span>
            <Button variant="ghost" size="icon" class="size-7 text-destructive" @click="remove(r)">
              <Trash2 class="size-3.5" />
            </Button>
          </li>
        </ul>
      </CardContent>
    </Card>

    <!-- Dostępność zespołu (menadżer) -->
    <Card v-if="canManage">
      <CardHeader>
        <CardTitle class="text-base">Dostępność zespołu</CardTitle>
        <CardDescription>Zadeklarowana dostępność pozostałych pracowników.</CardDescription>
      </CardHeader>
      <CardContent>
        <p v-if="!Object.keys(teamByUser).length" class="text-sm text-muted-foreground">
          Brak zadeklarowanej dostępności zespołu.
        </p>
        <div v-else class="space-y-4">
          <div v-for="(rows, uid) in teamByUser" :key="uid">
            <p class="mb-1.5 text-sm font-medium">{{ data?.names[uid] ?? 'Bez nazwy' }}</p>
            <div class="flex flex-wrap gap-1.5">
              <Badge v-for="r in rows" :key="r.id" variant="secondary" class="font-normal">
                {{ WEEKDAYS_FULL[r.weekday] }} {{ hm(r.from_time) }}–{{ hm(r.to_time) }}
              </Badge>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  </div>
</template>
