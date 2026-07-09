<script setup lang="ts">
import { Plus, Pencil, Trash2, Network, Store } from '@lucide/vue'
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'
import { formatDate } from '~/lib/utils'

type CostCategory = Database['public']['Enums']['cost_category']
type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

const { activeOrgId, isAdmin, load: loadOrg } = useOrg()
const { branches, activeBranchId, activeBranch, load: loadBranch } = useBranch()
await loadOrg()
await loadBranch()
watch(activeOrgId, () => loadBranch(true))

const CATEGORIES: { value: CostCategory; label: string }[] = [
  { value: 'food', label: 'Żywność' },
  { value: 'beverage', label: 'Napoje' },
  { value: 'labor', label: 'Praca' },
  { value: 'other', label: 'Inne' },
]
const catLabel = (c: CostCategory) => CATEGORIES.find((x) => x.value === c)?.label ?? c

const money = new Intl.NumberFormat('pl-PL', { style: 'currency', currency: 'PLN', maximumFractionDigits: 0 })
const pct = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 1000) / 10 : 0)

// ---- Date range ----
function localDate(d: Date) {
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 10)
}
type Preset = 'week' | 'month' | 'prevMonth' | 'd30'
const preset = ref<Preset>('month')
const from = ref('')
const to = ref('')

function applyPreset(p: Preset) {
  preset.value = p
  const now = new Date()
  if (p === 'week') {
    const day = (now.getDay() + 6) % 7 // 0 = Monday
    const mon = new Date(now)
    mon.setDate(now.getDate() - day)
    from.value = localDate(mon)
    to.value = localDate(now)
  } else if (p === 'month') {
    from.value = localDate(new Date(now.getFullYear(), now.getMonth(), 1))
    to.value = localDate(new Date(now.getFullYear(), now.getMonth() + 1, 0))
  } else if (p === 'prevMonth') {
    from.value = localDate(new Date(now.getFullYear(), now.getMonth() - 1, 1))
    to.value = localDate(new Date(now.getFullYear(), now.getMonth(), 0))
  } else {
    const start = new Date(now)
    start.setDate(now.getDate() - 29)
    from.value = localDate(start)
    to.value = localDate(now)
  }
}
applyPreset('month')

const presetLabels: Record<Preset, string> = {
  week: 'Ten tydzień',
  month: 'Ten miesiąc',
  prevMonth: 'Poprzedni miesiąc',
  d30: '30 dni',
}

// ---- Scope ----
const scope = ref<'branch' | 'network'>('branch')
const scopeBranchIds = computed(() =>
  scope.value === 'network'
    ? branches.value.map((b) => b.id)
    : activeBranchId.value
      ? [activeBranchId.value]
      : [],
)

// role in active branch (for cost management)
const { data: role } = await useAsyncData(
  () => `costs-role:${activeBranchId.value}`,
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

// ---- Data ----
interface RevRow { branch_id: string; amount: number }
interface CostRow { id: string; branch_id: string; date: string; category: CostCategory; amount: number; note: string | null }

const { data, pending, refresh } = await useAsyncData(
  () => `costs:${scope.value}:${from.value}:${to.value}:${scopeBranchIds.value.join(',')}`,
  async () => {
    const ids = scopeBranchIds.value
    if (!ids.length) return { revenue: [] as RevRow[], costs: [] as CostRow[] }
    const [rev, cost] = await Promise.all([
      supabase.from('revenue_entries').select('branch_id, amount').in('branch_id', ids).gte('date', from.value).lte('date', to.value),
      supabase.from('cost_entries').select('id, branch_id, date, category, amount, note').in('branch_id', ids).gte('date', from.value).lte('date', to.value).order('date', { ascending: false }),
    ])
    return {
      revenue: (rev.data ?? []).map((r) => ({ branch_id: r.branch_id, amount: Number(r.amount) })),
      costs: (cost.data ?? []).map((c) => ({ ...c, amount: Number(c.amount) })) as CostRow[],
    }
  },
  { watch: [scope, from, to, activeBranchId, () => branches.value.length] },
)

const revenueTotal = computed(() => (data.value?.revenue ?? []).reduce((s, r) => s + r.amount, 0))
const costByCat = computed(() => {
  const m: Record<CostCategory, number> = { food: 0, beverage: 0, labor: 0, other: 0 }
  for (const c of data.value?.costs ?? []) m[c.category] += c.amount
  return m
})
const costTotal = computed(() => Object.values(costByCat.value).reduce((s, v) => s + v, 0))

// per-branch comparison (network)
interface BranchAgg { branch_id: string; name: string; revenue: number; food: number; beverage: number; labor: number; other: number }
const perBranch = computed<BranchAgg[]>(() => {
  const map = new Map<string, BranchAgg>()
  for (const b of branches.value) {
    map.set(b.id, { branch_id: b.id, name: b.name, revenue: 0, food: 0, beverage: 0, labor: 0, other: 0 })
  }
  for (const r of data.value?.revenue ?? []) {
    const a = map.get(r.branch_id)
    if (a) a.revenue += r.amount
  }
  for (const c of data.value?.costs ?? []) {
    const a = map.get(c.branch_id)
    if (a) a[c.category] += c.amount
  }
  return [...map.values()].filter((a) => scopeBranchIds.value.includes(a.branch_id))
})

const kpis = computed(() => [
  { label: 'Przychód', value: money.format(revenueTotal.value), sub: null },
  { label: 'Food Cost', value: `${pct(costByCat.value.food, revenueTotal.value)}%`, sub: money.format(costByCat.value.food) },
  { label: 'Beverage Cost', value: `${pct(costByCat.value.beverage, revenueTotal.value)}%`, sub: money.format(costByCat.value.beverage) },
  { label: 'Labor Cost', value: `${pct(costByCat.value.labor, revenueTotal.value)}%`, sub: money.format(costByCat.value.labor) },
])

// cost entry management (single branch)
const dialogOpen = ref(false)
const editing = ref<CostRow | null>(null)
function openCreate() {
  editing.value = null
  dialogOpen.value = true
}
function openEdit(c: CostRow) {
  editing.value = c
  dialogOpen.value = true
}
async function removeEntry(c: CostRow) {
  const { error } = await supabase.from('cost_entries').delete().eq('id', c.id)
  if (error) {
    toast.error('Nie udało się usunąć kosztu', { description: error.message })
    return
  }
  toast.success('Usunięto koszt')
  await refresh()
}
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">Koszty</h1>
        <p class="text-muted-foreground">
          {{ scope === 'network' ? 'Cała sieć' : (activeBranch?.name ?? 'Wybierz oddział') }}
        </p>
      </div>
      <div v-if="isAdmin" class="flex rounded-md border p-0.5 text-sm">
        <button
          class="flex items-center gap-1.5 rounded px-3 py-1.5"
          :class="scope === 'branch' ? 'bg-accent text-accent-foreground' : 'text-muted-foreground'"
          @click="scope = 'branch'"
        >
          <Store class="size-4" /> Oddział
        </button>
        <button
          class="flex items-center gap-1.5 rounded px-3 py-1.5"
          :class="scope === 'network' ? 'bg-accent text-accent-foreground' : 'text-muted-foreground'"
          @click="scope = 'network'"
        >
          <Network class="size-4" /> Cała sieć
        </button>
      </div>
    </div>

    <p
      v-if="!activeBranchId"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Nie masz dostępu do żadnego oddziału.
    </p>

    <template v-else>
      <!-- Zakres dat -->
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="flex flex-wrap gap-1.5">
          <Button
            v-for="(label, p) in presetLabels"
            :key="p"
            size="sm"
            :variant="preset === p ? 'default' : 'outline'"
            @click="applyPreset(p as any)"
          >
            {{ label }}
          </Button>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <Input v-model="from" type="date" class="w-auto" />
          <span class="text-muted-foreground">–</span>
          <Input v-model="to" type="date" class="w-auto" />
        </div>
      </div>

      <!-- KPI -->
      <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Card v-for="k in kpis" :key="k.label">
          <CardHeader class="pb-2">
            <CardDescription>{{ k.label }}</CardDescription>
            <CardTitle class="text-2xl tabular-nums">{{ k.value }}</CardTitle>
          </CardHeader>
          <CardContent v-if="k.sub" class="pt-0 text-xs text-muted-foreground">{{ k.sub }}</CardContent>
        </Card>
      </div>

      <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>

      <!-- Rozbicie kosztów -->
      <Card>
        <CardHeader>
          <CardTitle class="text-base">Rozbicie kosztów wg kategorii</CardTitle>
          <CardDescription>Udział w przychodzie: {{ money.format(revenueTotal) }}</CardDescription>
        </CardHeader>
        <CardContent class="space-y-3">
          <div v-for="c in CATEGORIES" :key="c.value" class="space-y-1">
            <div class="flex items-center justify-between text-sm">
              <span>{{ c.label }}</span>
              <span class="tabular-nums text-muted-foreground">
                {{ money.format(costByCat[c.value]) }} · {{ pct(costByCat[c.value], revenueTotal) }}%
              </span>
            </div>
            <div class="h-2 overflow-hidden rounded-full bg-muted">
              <div
                class="h-full rounded-full bg-primary"
                :style="{ width: Math.min(pct(costByCat[c.value], revenueTotal), 100) + '%' }"
              />
            </div>
          </div>
          <div class="flex items-center justify-between border-t pt-3 text-sm font-medium">
            <span>Koszty razem</span>
            <span class="tabular-nums">{{ money.format(costTotal) }} · {{ pct(costTotal, revenueTotal) }}%</span>
          </div>
        </CardContent>
      </Card>

      <!-- Porównanie oddziałów (sieć) -->
      <Card v-if="scope === 'network'">
        <CardHeader>
          <CardTitle class="text-base">Porównanie oddziałów</CardTitle>
        </CardHeader>
        <CardContent>
          <div class="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Oddział</TableHead>
                  <TableHead class="text-right">Przychód</TableHead>
                  <TableHead class="text-right">Food</TableHead>
                  <TableHead class="text-right">Beverage</TableHead>
                  <TableHead class="text-right">Labor</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow v-for="b in perBranch" :key="b.branch_id">
                  <TableCell class="font-medium">{{ b.name }}</TableCell>
                  <TableCell class="text-right tabular-nums">{{ money.format(b.revenue) }}</TableCell>
                  <TableCell class="text-right tabular-nums">{{ pct(b.food, b.revenue) }}%</TableCell>
                  <TableCell class="text-right tabular-nums">{{ pct(b.beverage, b.revenue) }}%</TableCell>
                  <TableCell class="text-right tabular-nums">{{ pct(b.labor, b.revenue) }}%</TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      <!-- Wpisy kosztów (pojedynczy oddział) -->
      <Card v-if="scope === 'branch'">
        <CardHeader class="flex-row items-center justify-between space-y-0">
          <CardTitle class="text-base">Wpisy kosztów</CardTitle>
          <Button v-if="canManage" size="sm" @click="openCreate">
            <Plus class="mr-1.5 size-4" /> Dodaj koszt
          </Button>
        </CardHeader>
        <CardContent>
          <p
            v-if="!data?.costs.length"
            class="py-6 text-center text-sm text-muted-foreground"
          >
            Brak wpisów kosztów w tym zakresie.
          </p>
          <div v-else class="overflow-x-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Data</TableHead>
                  <TableHead>Kategoria</TableHead>
                  <TableHead class="hidden sm:table-cell">Notatka</TableHead>
                  <TableHead class="text-right">Kwota</TableHead>
                  <TableHead v-if="canManage" class="text-right">Akcje</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow v-for="c in data.costs" :key="c.id">
                  <TableCell class="whitespace-nowrap">{{ formatDate(c.date) }}</TableCell>
                  <TableCell><Badge variant="outline">{{ catLabel(c.category) }}</Badge></TableCell>
                  <TableCell class="hidden max-w-[16rem] truncate text-muted-foreground sm:table-cell">
                    {{ c.note ?? '—' }}
                  </TableCell>
                  <TableCell class="text-right tabular-nums">{{ money.format(c.amount) }}</TableCell>
                  <TableCell v-if="canManage" class="text-right">
                    <Button size="icon" variant="ghost" class="size-8" @click="openEdit(c)">
                      <Pencil class="size-4" />
                    </Button>
                    <Button size="icon" variant="ghost" class="size-8 text-destructive" @click="removeEntry(c)">
                      <Trash2 class="size-4" />
                    </Button>
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>

      <CostsEntryDialog
        v-if="activeOrgId && activeBranchId"
        v-model:open="dialogOpen"
        :org-id="activeOrgId"
        :branch-id="activeBranchId"
        :editing="editing"
        :default-date="to"
        @saved="refresh"
      />
    </template>
  </div>
</template>
