<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Pencil, Check } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{ orgId: string; branchId: string }>()

const supabase = useSupabaseClient<Database>()

const UNITS = ['szt', 'kg', 'l', 'opak']

interface Product {
  id: string
  name: string
  unit: string
  category: string | null
  active: boolean
  min_stock: number
}

const { data, pending, refresh } = await useAsyncData(
  () => `stock-products:${props.orgId}:${props.branchId}`,
  async () => {
    const [products, settings] = await Promise.all([
      supabase.from('products').select('id, name, unit, category, active').eq('org_id', props.orgId).order('name'),
      supabase.from('branch_product_settings').select('product_id, min_stock').eq('branch_id', props.branchId),
    ])
    const minMap = new Map((settings.data ?? []).map((s) => [s.product_id, Number(s.min_stock)]))
    return (products.data ?? []).map<Product>((p) => ({ ...p, min_stock: minMap.get(p.id) ?? 0 }))
  },
  { watch: [() => props.branchId] },
)

// create/edit dialog
const dialogOpen = ref(false)
const editing = ref<Product | null>(null)
const form = reactive({ name: '', unit: 'szt', category: '', active: true })

function openCreate() {
  editing.value = null
  form.name = ''
  form.unit = 'szt'
  form.category = ''
  form.active = true
  dialogOpen.value = true
}
function openEdit(p: Product) {
  editing.value = p
  form.name = p.name
  form.unit = p.unit
  form.category = p.category ?? ''
  form.active = p.active
  dialogOpen.value = true
}

const saving = ref(false)
async function save() {
  if (!form.name.trim()) {
    toast.error('Podaj nazwę produktu')
    return
  }
  saving.value = true
  const payload = {
    name: form.name.trim(),
    unit: form.unit,
    category: form.category.trim() || null,
    active: form.active,
  }
  const { error } = editing.value
    ? await supabase.from('products').update(payload).eq('id', editing.value.id)
    : await supabase.from('products').insert({ ...payload, org_id: props.orgId })
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać produktu', { description: error.message })
    return
  }
  toast.success(editing.value ? 'Zaktualizowano produkt' : 'Dodano produkt')
  dialogOpen.value = false
  await refresh()
}

// inline min_stock editing
const minDrafts = reactive<Record<string, string>>({})
async function saveMin(p: Product) {
  const raw = minDrafts[p.id]
  if (raw == null) return
  const val = Number(raw)
  if (!Number.isFinite(val) || val < 0) {
    toast.error('Minimum musi być liczbą ≥ 0')
    return
  }
  const { error } = await supabase
    .from('branch_product_settings')
    .upsert(
      { org_id: props.orgId, branch_id: props.branchId, product_id: p.id, min_stock: val },
      { onConflict: 'branch_id,product_id' },
    )
  if (error) {
    toast.error('Nie udało się zapisać minimum', { description: error.message })
    return
  }
  p.min_stock = val
  delete minDrafts[p.id]
  toast.success('Zapisano minimum')
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <p class="text-sm text-muted-foreground">Katalog produktów sieci · minimum liczone dla oddziału</p>
      <Button size="sm" @click="openCreate"><Plus class="mr-1.5 size-4" /> Dodaj produkt</Button>
    </div>

    <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>
    <p
      v-else-if="!data?.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak produktów. Dodaj pierwszy produkt.
    </p>

    <div v-else class="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Nazwa</TableHead>
            <TableHead>Jedn.</TableHead>
            <TableHead class="hidden sm:table-cell">Kategoria</TableHead>
            <TableHead>Min. (oddział)</TableHead>
            <TableHead>Aktywny</TableHead>
            <TableHead class="text-right">Akcje</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="p in data" :key="p.id">
            <TableCell class="font-medium">{{ p.name }}</TableCell>
            <TableCell class="text-muted-foreground">{{ p.unit }}</TableCell>
            <TableCell class="hidden text-muted-foreground sm:table-cell">{{ p.category ?? '—' }}</TableCell>
            <TableCell>
              <div class="flex items-center gap-1">
                <Input
                  :model-value="minDrafts[p.id] ?? String(p.min_stock)"
                  type="number"
                  step="0.01"
                  min="0"
                  class="h-8 w-20"
                  @update:model-value="(v) => (minDrafts[p.id] = String(v))"
                />
                <Button
                  v-if="minDrafts[p.id] != null && Number(minDrafts[p.id]) !== p.min_stock"
                  size="icon"
                  variant="ghost"
                  class="size-8"
                  @click="saveMin(p)"
                >
                  <Check class="size-4" />
                </Button>
              </div>
            </TableCell>
            <TableCell>
              <Badge :variant="p.active ? 'secondary' : 'outline'">
                {{ p.active ? 'Tak' : 'Nie' }}
              </Badge>
            </TableCell>
            <TableCell class="text-right">
              <Button size="icon" variant="ghost" class="size-8" @click="openEdit(p)">
                <Pencil class="size-4" />
              </Button>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <Dialog v-model:open="dialogOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Edytuj produkt' : 'Nowy produkt' }}</DialogTitle>
          <DialogDescription>Produkt jest wspólny dla całej sieci.</DialogDescription>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="save">
          <div class="space-y-2">
            <Label for="p-name">Nazwa</Label>
            <Input id="p-name" v-model="form.name" placeholder="np. Pomidory" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div class="space-y-2">
              <Label>Jednostka</Label>
              <Select v-model="form.unit">
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem v-for="u in UNITS" :key="u" :value="u">{{ u }}</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div class="space-y-2">
              <Label for="p-cat">Kategoria</Label>
              <Input id="p-cat" v-model="form.category" placeholder="np. Warzywa" />
            </div>
          </div>
          <label class="flex items-center gap-2 text-sm">
            <Checkbox v-model="form.active" /> Aktywny
          </label>
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
