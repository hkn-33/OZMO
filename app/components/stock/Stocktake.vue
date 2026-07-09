<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, ClipboardCheck, ArrowLeft, Lock } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { formatDate, formatDateTime } from '~/lib/utils'

const props = defineProps<{ orgId: string; branchId: string; canManage: boolean }>()

const supabase = useSupabaseClient<Database>()
const { isDemo, upgradeOpen } = useDemoGuard()
function blockDemo() {
  if (isDemo.value) { upgradeOpen.value = true; return true }
  return false
}

interface StocktakeRow {
  id: string
  status: 'draft' | 'closed'
  note: string | null
  created_at: string
  closed_at: string | null
}
interface ItemRow {
  id: string
  product_id: string
  expected_qty: number
  counted_qty: number | null
  products: { name: string; unit: string } | null
}
interface ProductRow {
  id: string
  name: string
  unit: string
}

function fmt(n: number | null | undefined) {
  if (n == null) return '—'
  return Number(n).toLocaleString('pl-PL', { maximumFractionDigits: 2 })
}

// ---------------------------------------------------------------
// History list
// ---------------------------------------------------------------
const { data: list, pending, refresh } = await useAsyncData(
  () => `stocktakes:${props.branchId}`,
  async () => {
    const { data } = await supabase
      .from('stocktakes')
      .select('id, status, note, created_at, closed_at')
      .eq('branch_id', props.branchId)
      .order('created_at', { ascending: false })
    return (data ?? []) as StocktakeRow[]
  },
  { watch: [() => props.branchId] },
)

// ---------------------------------------------------------------
// Detail view (open one stocktake for counting / read-only)
// ---------------------------------------------------------------
const selected = ref<StocktakeRow | null>(null)
const items = ref<ItemRow[]>([])
const drafts = reactive<Record<string, string>>({})
const loadingItems = ref(false)

async function openStocktake(st: StocktakeRow) {
  selected.value = st
  loadingItems.value = true
  items.value = []
  for (const k of Object.keys(drafts)) delete drafts[k]
  const { data } = await supabase
    .from('stocktake_items')
    .select('id, product_id, expected_qty, counted_qty, products(name, unit)')
    .eq('stocktake_id', st.id)
    .order('created_at')
  items.value = ((data ?? []) as unknown as ItemRow[])
  for (const it of items.value) {
    drafts[it.id] = it.counted_qty == null ? '' : String(it.counted_qty)
  }
  loadingItems.value = false
}

function backToList() {
  selected.value = null
  items.value = []
}

const editable = computed(() => props.canManage && selected.value?.status === 'draft')
const countedCount = computed(() => items.value.filter((i) => i.counted_qty != null).length)
const diffItems = computed(() =>
  items.value
    .filter((i) => i.counted_qty != null && Number(i.counted_qty) !== Number(i.expected_qty))
    .map((i) => ({
      name: i.products?.name ?? '—',
      unit: i.products?.unit ?? '',
      expected: Number(i.expected_qty),
      counted: Number(i.counted_qty),
      delta: Number(i.counted_qty) - Number(i.expected_qty),
    })),
)

async function saveCount(it: ItemRow) {
  if (!editable.value) return
  const raw = drafts[it.id]
  const val = raw === '' || raw == null ? null : Number(raw)
  if (val != null && (!Number.isFinite(val) || val < 0)) {
    toast.error('Ilość musi być liczbą ≥ 0')
    return
  }
  if (val === it.counted_qty) return
  if (blockDemo()) return
  const { error } = await supabase
    .from('stocktake_items')
    .update({ counted_qty: val })
    .eq('id', it.id)
  if (error) {
    toast.error('Nie udało się zapisać', { description: error.message })
    return
  }
  it.counted_qty = val
}

// ---------------------------------------------------------------
// Start a new stocktake (manager only)
// ---------------------------------------------------------------
const startOpen = ref(false)
const startNote = ref('')
const products = ref<ProductRow[]>([])
const levelMap = ref<Map<string, number>>(new Map())
const selectedProducts = reactive<Record<string, boolean>>({})
const starting = ref(false)

async function openStart() {
  if (blockDemo()) return
  startNote.value = ''
  const [prodRes, lvlRes] = await Promise.all([
    supabase.from('products').select('id, name, unit').eq('org_id', props.orgId).eq('active', true).order('name'),
    supabase.from('stock_levels').select('product_id, qty').eq('branch_id', props.branchId),
  ])
  products.value = (prodRes.data ?? []) as ProductRow[]
  levelMap.value = new Map((lvlRes.data ?? []).map((l) => [l.product_id, Number(l.qty)]))
  for (const p of products.value) selectedProducts[p.id] = true
  startOpen.value = true
}

const allSelected = computed(() => products.value.every((p) => selectedProducts[p.id]))
function toggleAll() {
  const v = !allSelected.value
  for (const p of products.value) selectedProducts[p.id] = v
}

async function createStocktake() {
  if (blockDemo()) return
  const chosen = products.value.filter((p) => selectedProducts[p.id])
  if (!chosen.length) {
    toast.error('Wybierz przynajmniej jeden produkt')
    return
  }
  starting.value = true
  const { data: st, error } = await supabase
    .from('stocktakes')
    .insert({ org_id: props.orgId, branch_id: props.branchId, note: startNote.value.trim() || null })
    .select('id, status, note, created_at, closed_at')
    .single()
  if (error || !st) {
    starting.value = false
    toast.error('Nie udało się utworzyć inwentaryzacji', { description: error?.message })
    return
  }
  const rows = chosen.map((p) => ({
    stocktake_id: st.id,
    org_id: props.orgId,
    branch_id: props.branchId,
    product_id: p.id,
    expected_qty: levelMap.value.get(p.id) ?? 0,
  }))
  const { error: itErr } = await supabase.from('stocktake_items').insert(rows)
  starting.value = false
  if (itErr) {
    toast.error('Nie udało się dodać pozycji', { description: itErr.message })
    return
  }
  startOpen.value = false
  toast.success('Rozpoczęto inwentaryzację')
  await refresh()
  await openStocktake(st as StocktakeRow)
}

// ---------------------------------------------------------------
// Close (manager only) — confirm shows diff summary
// ---------------------------------------------------------------
const closeOpen = ref(false)
const closing = ref(false)
function openClose() {
  if (blockDemo()) return
  closeOpen.value = true
}
async function confirmClose() {
  if (!selected.value) return
  closing.value = true
  const { error } = await supabase.rpc('close_stocktake', { _stocktake_id: selected.value.id })
  closing.value = false
  if (error) {
    toast.error('Nie udało się zamknąć', { description: error.message })
    return
  }
  closeOpen.value = false
  toast.success('Inwentaryzacja zamknięta, stany skorygowane')
  await refresh()
  const updated = (list.value ?? []).find((s) => s.id === selected.value?.id)
  if (updated) await openStocktake(updated)
}
</script>

<template>
  <div class="space-y-4">
    <!-- ============ LIST VIEW ============ -->
    <template v-if="!selected">
      <div class="flex items-center justify-between">
        <p class="text-sm text-muted-foreground">Spis z natury — porównanie stanu policzonego z systemowym</p>
        <Button v-if="canManage" size="sm" @click="openStart">
          <Plus class="mr-1.5 size-4" /> Nowa inwentaryzacja
        </Button>
      </div>

      <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>
      <p
        v-else-if="!list?.length"
        class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
      >
        Brak inwentaryzacji. {{ canManage ? 'Rozpocznij pierwszą.' : '' }}
      </p>

      <div v-else class="space-y-2">
        <button
          v-for="st in list"
          :key="st.id"
          class="flex w-full items-center justify-between gap-3 rounded-lg border p-3 text-left transition-colors hover:bg-muted"
          @click="openStocktake(st)"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <ClipboardCheck class="size-4 shrink-0 text-muted-foreground" />
              <span class="font-medium">{{ formatDate(st.created_at) }}</span>
              <Badge :variant="st.status === 'closed' ? 'success' : 'warning'" class="gap-1">
                <Lock v-if="st.status === 'closed'" class="size-3" />
                {{ st.status === 'closed' ? 'Zamknięty' : 'Szkic' }}
              </Badge>
            </div>
            <p v-if="st.note" class="truncate text-xs text-muted-foreground">{{ st.note }}</p>
          </div>
          <span v-if="st.status === 'closed' && st.closed_at" class="shrink-0 text-xs text-muted-foreground">
            {{ formatDateTime(st.closed_at) }}
          </span>
        </button>
      </div>
    </template>

    <!-- ============ DETAIL VIEW ============ -->
    <template v-else>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-2">
          <Button size="icon" variant="ghost" class="size-8" @click="backToList">
            <ArrowLeft class="size-4" />
          </Button>
          <div>
            <div class="flex items-center gap-2">
              <span class="font-semibold">{{ formatDate(selected.created_at) }}</span>
              <Badge :variant="selected.status === 'closed' ? 'success' : 'warning'" class="gap-1">
                <Lock v-if="selected.status === 'closed'" class="size-3" />
                {{ selected.status === 'closed' ? 'Zamknięty' : 'Szkic' }}
              </Badge>
            </div>
            <p v-if="selected.note" class="text-xs text-muted-foreground">{{ selected.note }}</p>
          </div>
        </div>
        <div v-if="selected.status === 'draft'" class="flex items-center gap-3">
          <span class="text-sm text-muted-foreground">Policzono {{ countedCount }} / {{ items.length }}</span>
          <Button v-if="editable" :disabled="closing" @click="openClose">Zamknij</Button>
        </div>
      </div>

      <p v-if="loadingItems" class="text-sm text-muted-foreground">Ładowanie…</p>

      <!-- Count mode (editable draft) -->
      <div v-else-if="editable" class="space-y-2">
        <div
          v-for="it in items"
          :key="it.id"
          class="flex items-center justify-between gap-3 rounded-lg border p-3"
        >
          <div class="min-w-0">
            <p class="truncate font-medium">{{ it.products?.name ?? '—' }}</p>
            <p class="text-xs text-muted-foreground">
              Oczekiwano: {{ fmt(it.expected_qty) }} {{ it.products?.unit }}
            </p>
          </div>
          <Input
            v-model="drafts[it.id]"
            type="number"
            step="0.01"
            min="0"
            inputmode="decimal"
            class="h-12 w-28 text-lg"
            placeholder="—"
            @change="saveCount(it)"
          />
        </div>
      </div>

      <!-- Read-only diff report (closed, or employee view of draft) -->
      <div v-else class="space-y-4">
        <div class="overflow-x-auto rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Produkt</TableHead>
                <TableHead class="text-right">Oczekiwano</TableHead>
                <TableHead class="text-right">Policzono</TableHead>
                <TableHead class="text-right">Różnica</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-for="it in items" :key="it.id">
                <TableCell class="font-medium">{{ it.products?.name ?? '—' }}</TableCell>
                <TableCell class="text-right tabular-nums">{{ fmt(it.expected_qty) }}</TableCell>
                <TableCell class="text-right tabular-nums">{{ fmt(it.counted_qty) }}</TableCell>
                <TableCell class="text-right tabular-nums">
                  <span
                    v-if="it.counted_qty != null && Number(it.counted_qty) !== Number(it.expected_qty)"
                    :class="Number(it.counted_qty) - Number(it.expected_qty) < 0 ? 'text-destructive' : 'text-success'"
                  >
                    {{ Number(it.counted_qty) - Number(it.expected_qty) > 0 ? '+' : '' }}{{ fmt(Number(it.counted_qty) - Number(it.expected_qty)) }}
                  </span>
                  <span v-else class="text-muted-foreground">—</span>
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
      </div>
    </template>

    <!-- Start dialog -->
    <Dialog v-model:open="startOpen">
      <DialogContent class="max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Nowa inwentaryzacja</DialogTitle>
          <DialogDescription>
            Stan systemowy zostanie zapisany jako oczekiwany. Wybierz produkty do policzenia.
          </DialogDescription>
        </DialogHeader>
        <div class="space-y-3">
          <div class="space-y-2">
            <Label for="st-note">Notatka (opcjonalnie)</Label>
            <Input id="st-note" v-model="startNote" placeholder="np. Inwentaryzacja miesięczna" />
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm font-medium">Produkty</span>
            <Button size="sm" variant="ghost" @click="toggleAll">
              {{ allSelected ? 'Odznacz wszystkie' : 'Zaznacz wszystkie' }}
            </Button>
          </div>
          <div class="max-h-64 space-y-1 overflow-y-auto rounded-lg border p-2">
            <label
              v-for="p in products"
              :key="p.id"
              class="flex items-center justify-between gap-2 rounded px-2 py-1.5 text-sm hover:bg-muted"
            >
              <span class="flex items-center gap-2">
                <Checkbox v-model="selectedProducts[p.id]" />
                {{ p.name }}
              </span>
              <span class="text-xs text-muted-foreground">
                stan: {{ fmt(levelMap.get(p.id) ?? 0) }} {{ p.unit }}
              </span>
            </label>
            <p v-if="!products.length" class="p-2 text-sm text-muted-foreground">
              Brak aktywnych produktów.
            </p>
          </div>
        </div>
        <DialogFooter>
          <Button :disabled="starting" @click="createStocktake">
            {{ starting ? 'Tworzenie…' : 'Rozpocznij' }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>

    <!-- Close confirm dialog with diff -->
    <Dialog v-model:open="closeOpen">
      <DialogContent class="max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Zamknąć inwentaryzację?</DialogTitle>
          <DialogDescription>
            Dla każdej różnicy zostanie utworzona korekta stanu. Operacja jest nieodwracalna.
          </DialogDescription>
        </DialogHeader>
        <p v-if="countedCount < items.length" class="text-sm text-warning-foreground">
          Uwaga: {{ items.length - countedCount }} pozycji nie policzono — zostaną pominięte.
        </p>
        <div v-if="diffItems.length" class="overflow-x-auto rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Produkt</TableHead>
                <TableHead class="text-right">Oczek.</TableHead>
                <TableHead class="text-right">Policz.</TableHead>
                <TableHead class="text-right">Różnica</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-for="d in diffItems" :key="d.name">
                <TableCell class="font-medium">{{ d.name }}</TableCell>
                <TableCell class="text-right tabular-nums">{{ fmt(d.expected) }}</TableCell>
                <TableCell class="text-right tabular-nums">{{ fmt(d.counted) }}</TableCell>
                <TableCell
                  class="text-right tabular-nums"
                  :class="d.delta < 0 ? 'text-destructive' : 'text-success'"
                >
                  {{ d.delta > 0 ? '+' : '' }}{{ fmt(d.delta) }}
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>
        <p v-else class="text-sm text-muted-foreground">Brak różnic — stany się zgadzają.</p>
        <DialogFooter>
          <Button variant="outline" :disabled="closing" @click="closeOpen = false">Anuluj</Button>
          <Button :disabled="closing" @click="confirmClose">
            {{ closing ? 'Zamykanie…' : 'Zamknij i skoryguj' }}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  </div>
</template>
