<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Trash2 } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

type MovementType = Database['public']['Enums']['stock_movement_type']

const props = defineProps<{ orgId: string; branchId: string }>()

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { block } = useDemoGuard()

const typeLabel: Record<MovementType, string> = {
  delivery: 'Dostawa',
  usage: 'Zużycie',
  waste: 'Strata',
  correction: 'Korekta',
  transfer: 'Transfer',
}

interface ProductLite { id: string; name: string; unit: string }
interface SupplierLite { id: string; name: string }

const products = ref<ProductLite[]>([])
const suppliers = ref<SupplierLite[]>([])

async function loadRefs() {
  const [p, s] = await Promise.all([
    supabase.from('products').select('id, name, unit').eq('org_id', props.orgId).eq('active', true).order('name'),
    supabase.from('suppliers').select('id, name').eq('org_id', props.orgId).order('name'),
  ])
  products.value = (p.data ?? []) as ProductLite[]
  suppliers.value = (s.data ?? []) as SupplierLite[]
}
await loadRefs()

const form = reactive({
  type: 'delivery' as MovementType,
  productId: '',
  qty: '',
  direction: 'minus' as 'plus' | 'minus', // only for correction/transfer
  supplierId: '',
  docRef: '',
  note: '',
})

const showSupplier = computed(() => form.type === 'delivery')
const showDirection = computed(() => form.type === 'correction' || form.type === 'transfer')

interface Line {
  type: MovementType
  productId: string
  productName: string
  unit: string
  qtyDelta: number
  supplierId: string | null
  docRef: string | null
  note: string | null
}
const lines = ref<Line[]>([])

function computeDelta(): number | null {
  const q = Number(form.qty)
  if (!Number.isFinite(q) || q <= 0) return null
  if (form.type === 'delivery') return q
  if (form.type === 'usage' || form.type === 'waste') return -q
  return form.direction === 'plus' ? q : -q // correction/transfer
}

function addLine() {
  if (!form.productId) {
    toast.error('Wybierz produkt')
    return
  }
  const delta = computeDelta()
  if (delta === null) {
    toast.error('Podaj dodatnią ilość')
    return
  }
  const p = products.value.find((x) => x.id === form.productId)!
  lines.value.push({
    type: form.type,
    productId: form.productId,
    productName: p.name,
    unit: p.unit,
    qtyDelta: delta,
    supplierId: showSupplier.value && form.supplierId ? form.supplierId : null,
    docRef: form.docRef.trim() || null,
    note: form.note.trim() || null,
  })
  form.productId = ''
  form.qty = ''
  form.docRef = ''
  form.note = ''
}

function removeLine(i: number) {
  lines.value.splice(i, 1)
}

const saving = ref(false)
async function submitAll() {
  if (!lines.value.length || !user.value) return
  if (block()) return
  saving.value = true
  const rows = lines.value.map((l) => ({
    org_id: props.orgId,
    branch_id: props.branchId,
    product_id: l.productId,
    qty_delta: l.qtyDelta,
    type: l.type,
    supplier_id: l.supplierId,
    doc_ref: l.docRef,
    note: l.note,
    // created_by pochodzi z DEFAULT auth.uid() (bulk insert nie może polegać na
    // pominięciu undefined jak insert pojedynczego wiersza).
  }))
  const { error } = await supabase.from('stock_movements').insert(rows)
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać ruchów', { description: error.message })
    return
  }
  toast.success(`Zapisano ${rows.length} ${rows.length === 1 ? 'ruch' : 'ruchy/ów'}`)
  lines.value = []
}
</script>

<template>
  <div class="grid gap-6 lg:grid-cols-2">
    <div class="space-y-4 rounded-lg border p-4">
      <h2 class="font-semibold">Nowa pozycja</h2>

      <div class="space-y-2">
        <Label>Typ ruchu</Label>
        <Select v-model="form.type">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="(label, t) in typeLabel" :key="t" :value="t">{{ label }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div class="space-y-2">
        <Label>Produkt</Label>
        <Select v-model="form.productId">
          <SelectTrigger><SelectValue placeholder="Wybierz produkt" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="p in products" :key="p.id" :value="p.id">
              {{ p.name }} ({{ p.unit }})
            </SelectItem>
          </SelectContent>
        </Select>
        <p v-if="!products.length" class="text-xs text-muted-foreground">
          Brak produktów — dodaj je w zakładce „Produkty".
        </p>
      </div>

      <div class="grid gap-3" :class="showDirection ? 'grid-cols-2' : 'grid-cols-1'">
        <div class="space-y-2">
          <Label for="mv-qty">Ilość</Label>
          <Input id="mv-qty" v-model="form.qty" type="number" step="0.01" min="0" inputmode="decimal" placeholder="0" />
        </div>
        <div v-if="showDirection" class="space-y-2">
          <Label>Kierunek</Label>
          <Select v-model="form.direction">
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="plus">Dodaj (+)</SelectItem>
              <SelectItem value="minus">Odejmij (−)</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div v-if="showSupplier" class="space-y-2">
        <Label>Dostawca (opcjonalnie)</Label>
        <Select v-model="form.supplierId">
          <SelectTrigger><SelectValue placeholder="Wybierz dostawcę" /></SelectTrigger>
          <SelectContent>
            <SelectItem v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.name }}</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div v-if="showSupplier" class="space-y-2">
        <Label for="mv-doc">Nr dokumentu / WZ (opcjonalnie)</Label>
        <Input id="mv-doc" v-model="form.docRef" placeholder="np. WZ/123/2026" />
      </div>

      <div class="space-y-2">
        <Label for="mv-note">Notatka (opcjonalnie)</Label>
        <Textarea id="mv-note" v-model="form.note" rows="2" />
      </div>

      <Button class="w-full" variant="secondary" @click="addLine">
        <Plus class="mr-1.5 size-4" /> Dodaj do listy
      </Button>
    </div>

    <div class="space-y-3 rounded-lg border p-4">
      <div class="flex items-center justify-between">
        <h2 class="font-semibold">Do zapisania</h2>
        <span class="text-sm text-muted-foreground">{{ lines.length }} poz.</span>
      </div>

      <p v-if="!lines.length" class="py-8 text-center text-sm text-muted-foreground">
        Dodaj pozycje po lewej, a następnie zapisz je zbiorczo.
      </p>

      <ul v-else class="space-y-2">
        <li
          v-for="(l, i) in lines"
          :key="i"
          class="flex items-center justify-between gap-3 rounded-md border p-2.5 text-sm"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <Badge variant="outline">{{ typeLabel[l.type] }}</Badge>
              <span class="truncate font-medium">{{ l.productName }}</span>
            </div>
            <p v-if="l.docRef || l.note" class="mt-0.5 truncate text-xs text-muted-foreground">
              {{ [l.docRef, l.note].filter(Boolean).join(' · ') }}
            </p>
          </div>
          <div class="flex items-center gap-2">
            <span
              class="font-semibold tabular-nums"
              :class="l.qtyDelta > 0 ? 'text-success' : 'text-destructive'"
            >
              {{ l.qtyDelta > 0 ? '+' : '' }}{{ l.qtyDelta }} {{ l.unit }}
            </span>
            <Button variant="ghost" size="icon" class="size-7" @click="removeLine(i)">
              <Trash2 class="size-4" />
            </Button>
          </div>
        </li>
      </ul>

      <Button class="w-full" :disabled="!lines.length || saving" @click="submitAll">
        {{ saving ? 'Zapisywanie…' : `Zapisz wszystkie (${lines.length})` }}
      </Button>
    </div>
  </div>
</template>
