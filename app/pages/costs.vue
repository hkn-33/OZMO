<script setup lang="ts">
import { Plus, Pencil, Trash2, Network, Store, Tags } from '@lucide/vue'
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'
import { formatDate } from '~/lib/utils'

type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

const { activeOrgId, isAdmin, load: loadOrg } = useOrg()
const { branches, activeBranchId, activeBranch, load: loadBranch } = useBranch()
await loadOrg()
await loadBranch()
watch(activeOrgId, () => loadBranch(true))

const money = new Intl.NumberFormat('pl-PL', { style: 'currency', currency: 'PLN', maximumFractionDigits: 0 })
const pct = (part: number, total: number) => (total > 0 ? Math.round((part / total) * 1000) / 10 : 0)

// ---- Cost categories (per org) ----
interface Category { id: string; name: string; sort: number }
const { data: categoriesData, refresh: refreshCats } = await useAsyncData(
  () => `cost-cats:${activeOrgId.value}`,
  async () => {
    if (!activeOrgId.value) return [] as Category[]
    const { data } = await supabase
      .from('cost_categories')
      .select('id, name, sort')
      .eq('org_id', activeOrgId.value)
      .order('sort')
    return (data ?? []) as Category[]
  },
  { watch: [activeOrgId] },
)
const catList = computed(() => categoriesData.value ?? [])
const catName = (id: string) => catList.value.find((c) => c.id === id)?.name ?? '—'

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
interface CostRow { id: string; branch_id: string; date: string; category_id: string; amount: number; note: string | null }

const { data, pending, refresh } = await useAsyncData(
  () => `costs:${scope.value}:${from.value}:${to.value}:${scopeBranchIds.value.join(',')}`,
  async () => {
    const ids = scopeBranchIds.value
    if (!ids.length) return { revenue: [] as RevRow[], costs: [] as CostRow[] }
    const [rev, cost] = await Promise.all([
      supabase.from('revenue_entries').select('branch_id, amount').in('branch_id', ids).gte('date', from.value).lte('date', to.value),
      supabase.from('cost_entries').select('id, branch_id, date, category_id, amount, note').in('branch_id', ids).gte('date', from.value).lte('date', to.value).order('date', { ascending: false }),
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
  const m: Record<string, number> = {}
  for (const cat of catList.value) m[cat.id] = 0
  for (const c of data.value?.costs ?? []) m[c.category_id] = (m[c.category_id] ?? 0) + c.amount
  return m
})
const costTotal = computed(() => (data.value?.costs ?? []).reduce((s, c) => s + c.amount, 0))

// per-branch comparison (network) — dynamic categories
interface BranchAgg { branch_id: string; name: string; revenue: number; cost: number; costs: Record<string, number> }
const perBranch = computed<BranchAgg[]>(() => {
  const map = new Map<string, BranchAgg>()
  for (const b of branches.value) {
    map.set(b.id, { branch_id: b.id, name: b.name, revenue: 0, cost: 0, costs: {} })
  }
  for (const r of data.value?.revenue ?? []) {
    const a = map.get(r.branch_id)
    if (a) a.revenue += r.amount
  }
  for (const c of data.value?.costs ?? []) {
    const a = map.get(c.branch_id)
    if (a) {
      a.costs[c.category_id] = (a.costs[c.category_id] ?? 0) + c.amount
      a.cost += c.amount
    }
  }
  return [...map.values()].filter((a) => scopeBranchIds.value.includes(a.branch_id))
})

const kpis = computed(() => [
  { label: 'Przychód', value: money.format(revenueTotal.value), sub: null as string | null },
  ...catList.value.map((cat) => ({
    label: cat.name,
    value: `${pct(costByCat.value[cat.id] ?? 0, revenueTotal.value)}%`,
    sub: money.format(costByCat.value[cat.id] ?? 0),
  })),
  { label: 'Koszty razem', value: `${pct(costTotal.value, revenueTotal.value)}%`, sub: money.format(costTotal.value) },
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

// category management (org admins)
const catMgrOpen = ref(false)
async function onCategoriesChanged() {
  await refreshCats()
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
      <div class="flex items-center gap-2">
        <Button v-if="isAdmin" size="sm" variant="outline" @click="catMgrOpen = true">
          <Tags class="mr-1.5 size-4" /> Kategorie kosztów
        </Button>
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
          <p v-if="!catList.length" class="text-sm text-muted-foreground">
            Brak kategorii kosztów.
            <button v-if="isAdmin" class="text-primary underline" @click="catMgrOpen = true">Dodaj kategorie</button>
          </p>
          <div v-for="c in catList" :key="c.id" class="space-y-1">
            <div class="flex items-center justify-between text-sm">
              <span>{{ c.name }}</span>
              <span class="tabular-nums text-muted-foreground">
                {{ money.format(costByCat[c.id] ?? 0) }} · {{ pct(costByCat[c.id] ?? 0, revenueTotal) }}%
              </span>
            </div>
            <div class="h-2 overflow-hidden rounded-full bg-muted">
              <div
                class="h-full rounded-full bg-primary"
                :style="{ width: Math.min(pct(costByCat[c.id] ?? 0, revenueTotal), 100) + '%' }"
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
                  <TableHead v-for="c in catList" :key="c.id" class="text-right whitespace-nowrap">{{ c.name }}</TableHead>
                  <TableHead class="text-right">Koszty razem</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow v-for="b in perBranch" :key="b.branch_id">
                  <TableCell class="font-medium">{{ b.name }}</TableCell>
                  <TableCell class="text-right tabular-nums">{{ money.format(b.revenue) }}</TableCell>
                  <TableCell v-for="c in catList" :key="c.id" class="text-right tabular-nums">
                    {{ pct(b.costs[c.id] ?? 0, b.revenue) }}%
                  </TableCell>
                  <TableCell class="text-right tabular-nums font-medium">{{ pct(b.cost, b.revenue) }}%</TableCell>
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
                  <TableCell><Badge variant="outline">{{ catName(c.category_id) }}</Badge></TableCell>
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
        :categories="catList"
        :editing="editing"
        :default-date="to"
        @saved="refresh"
      />

      <CostsCategoryManager
        v-if="activeOrgId && isAdmin"
        v-model:open="catMgrOpen"
        :org-id="activeOrgId"
        @changed="onCategoriesChanged"
      />
    </template>
  </div>
</template>
