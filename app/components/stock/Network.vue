<script setup lang="ts">
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{ orgId: string }>()
const supabase = useSupabaseClient<Database>()

type Product = { id: string; name: string; unit: string; category: string | null }
type Branch = { id: string; name: string }

const { data, pending } = await useAsyncData(
  () => `stock-network:${props.orgId}`,
  async () => {
    const [products, branches, levels, settings] = await Promise.all([
      supabase.from('products').select('id, name, unit, category').eq('org_id', props.orgId).eq('active', true).order('name'),
      supabase.from('branches').select('id, name').eq('org_id', props.orgId).eq('active', true).order('name'),
      supabase.from('stock_levels').select('branch_id, product_id, qty').eq('org_id', props.orgId),
      supabase.from('branch_product_settings').select('branch_id, product_id, min_stock').eq('org_id', props.orgId),
    ])
    const qty = new Map<string, number>()
    for (const l of levels.data ?? []) qty.set(`${l.product_id}:${l.branch_id}`, Number(l.qty))
    const min = new Map<string, number>()
    for (const s of settings.data ?? []) min.set(`${s.product_id}:${s.branch_id}`, Number(s.min_stock))
    return {
      products: (products.data ?? []) as Product[],
      branches: (branches.data ?? []) as Branch[],
      qty,
      min,
    }
  },
  { watch: [() => props.orgId] },
)

function cellQty(productId: string, branchId: string) {
  return data.value?.qty.get(`${productId}:${branchId}`) ?? 0
}
function cellMin(productId: string, branchId: string) {
  return data.value?.min.get(`${productId}:${branchId}`) ?? 0
}
function isLow(productId: string, branchId: string) {
  const m = cellMin(productId, branchId)
  return m > 0 && cellQty(productId, branchId) < m
}
function rowTotal(productId: string) {
  return (data.value?.branches ?? []).reduce((sum, b) => sum + cellQty(productId, b.id), 0)
}
</script>

<template>
  <div>
    <p v-if="pending" class="py-6 text-sm text-muted-foreground">Ładowanie…</p>

    <template v-else-if="data">
      <p
        v-if="!data.products.length"
        class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
      >
        Brak produktów w sieci.
      </p>

      <template v-else>
        <div class="hidden overflow-x-auto rounded-lg border sm:block">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead class="sticky left-0 bg-card">Produkt</TableHead>
                <TableHead v-for="b in data.branches" :key="b.id" class="text-right">
                  {{ b.name }}
                </TableHead>
                <TableHead class="text-right font-semibold">Razem</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              <TableRow v-for="p in data.products" :key="p.id">
                <TableCell class="sticky left-0 bg-card font-medium">
                  {{ p.name }}
                  <span class="text-xs text-muted-foreground">({{ p.unit }})</span>
                </TableCell>
                <TableCell
                  v-for="b in data.branches"
                  :key="b.id"
                  class="text-right tabular-nums"
                  :class="isLow(p.id, b.id) ? 'font-semibold text-destructive' : ''"
                >
                  {{ cellQty(p.id, b.id) }}
                </TableCell>
                <TableCell class="text-right font-semibold tabular-nums">
                  {{ rowTotal(p.id) }}
                </TableCell>
              </TableRow>
            </TableBody>
          </Table>
        </div>

        <Accordion type="multiple" class="sm:hidden">
          <AccordionItem v-for="p in data.products" :key="p.id" :value="p.id">
            <AccordionTrigger>
              <span class="flex w-full items-center justify-between pr-2">
                <span>{{ p.name }}</span>
                <span class="tabular-nums text-muted-foreground">
                  Razem: {{ rowTotal(p.id) }} {{ p.unit }}
                </span>
              </span>
            </AccordionTrigger>
            <AccordionContent>
              <ul class="space-y-1">
                <li
                  v-for="b in data.branches"
                  :key="b.id"
                  class="flex items-center justify-between text-sm"
                >
                  <span class="text-muted-foreground">{{ b.name }}</span>
                  <span
                    class="tabular-nums"
                    :class="isLow(p.id, b.id) ? 'font-semibold text-destructive' : ''"
                  >
                    {{ cellQty(p.id, b.id) }}
                    <span v-if="cellMin(p.id, b.id) > 0" class="text-xs text-muted-foreground">
                      / min {{ cellMin(p.id, b.id) }}
                    </span>
                  </span>
                </li>
              </ul>
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </template>
    </template>
  </div>
</template>
