<script setup lang="ts">
import { Search } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{ orgId: string; branchId: string }>()

const supabase = useSupabaseClient<Database>()

interface Row {
  product_id: string
  name: string
  unit: string
  category: string | null
  qty: number
  min_stock: number
}

const search = ref('')
const categoryFilter = ref<string>('all')

const { data, pending, refresh } = await useAsyncData(
  () => `stock-levels:${props.branchId}`,
  async () => {
    const [products, levels, settings] = await Promise.all([
      supabase
        .from('products')
        .select('id, name, unit, category')
        .eq('org_id', props.orgId)
        .eq('active', true)
        .order('name'),
      supabase
        .from('stock_levels')
        .select('product_id, qty')
        .eq('branch_id', props.branchId),
      supabase
        .from('branch_product_settings')
        .select('product_id, min_stock')
        .eq('branch_id', props.branchId),
    ])
    const qtyMap = new Map((levels.data ?? []).map((l) => [l.product_id, Number(l.qty)]))
    const minMap = new Map((settings.data ?? []).map((s) => [s.product_id, Number(s.min_stock)]))
    return (products.data ?? []).map<Row>((p) => ({
      product_id: p.id,
      name: p.name,
      unit: p.unit,
      category: p.category,
      qty: qtyMap.get(p.id) ?? 0,
      min_stock: minMap.get(p.id) ?? 0,
    }))
  },
  { watch: [() => props.branchId] },
)

const categories = computed(() => {
  const set = new Set<string>()
  for (const r of data.value ?? []) if (r.category) set.add(r.category)
  return [...set].sort()
})

function status(r: Row): 'brak' | 'niski' | 'ok' {
  if (r.qty <= 0) return 'brak'
  if (r.qty < r.min_stock) return 'niski'
  return 'ok'
}
const statusRank = { brak: 0, niski: 1, ok: 2 }

const rows = computed(() => {
  const q = search.value.trim().toLowerCase()
  return (data.value ?? [])
    .filter((r) => (categoryFilter.value === 'all' || r.category === categoryFilter.value))
    .filter((r) => !q || r.name.toLowerCase().includes(q))
    .sort((a, b) => {
      const s = statusRank[status(a)] - statusRank[status(b)]
      return s !== 0 ? s : a.name.localeCompare(b.name)
    })
})

// history drawer
const historyOpen = ref(false)
const historyProduct = ref<Row | null>(null)
function openHistory(r: Row) {
  historyProduct.value = r
  historyOpen.value = true
}

defineExpose({ refresh })
</script>

<template>
  <div class="space-y-4">
    <div class="flex flex-col gap-2 sm:flex-row sm:items-center">
      <div class="relative flex-1">
        <Search class="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
        <Input v-model="search" placeholder="Szukaj produktu…" class="pl-8" />
      </div>
      <Select v-model="categoryFilter">
        <SelectTrigger class="sm:w-52"><SelectValue placeholder="Kategoria" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="all">Wszystkie kategorie</SelectItem>
          <SelectItem v-for="c in categories" :key="c" :value="c">{{ c }}</SelectItem>
        </SelectContent>
      </Select>
    </div>

    <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>
    <p
      v-else-if="!rows.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak produktów. Dodaj produkty w zakładce „Produkty".
    </p>

    <div v-else class="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Produkt</TableHead>
            <TableHead class="hidden sm:table-cell">Kategoria</TableHead>
            <TableHead class="text-right">Stan</TableHead>
            <TableHead class="text-right">Min.</TableHead>
            <TableHead class="text-right">Status</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow
            v-for="r in rows"
            :key="r.product_id"
            class="cursor-pointer"
            @click="openHistory(r)"
          >
            <TableCell class="font-medium">{{ r.name }}</TableCell>
            <TableCell class="hidden text-muted-foreground sm:table-cell">
              {{ r.category ?? '—' }}
            </TableCell>
            <TableCell class="text-right tabular-nums">{{ r.qty }} {{ r.unit }}</TableCell>
            <TableCell class="text-right tabular-nums text-muted-foreground">{{ r.min_stock }}</TableCell>
            <TableCell class="text-right">
              <Badge v-if="status(r) === 'brak'" variant="destructive">Brak</Badge>
              <Badge
                v-else-if="status(r) === 'niski'"
                class="border-amber-500/30 bg-amber-500/15 text-amber-700 dark:text-amber-400"
                variant="outline"
              >
                Niski stan
              </Badge>
              <Badge v-else variant="secondary">OK</Badge>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <StockMovementHistory
      v-if="historyProduct"
      v-model:open="historyOpen"
      :branch-id="branchId"
      :product-id="historyProduct.product_id"
      :product-name="historyProduct.name"
      :unit="historyProduct.unit"
    />
  </div>
</template>
