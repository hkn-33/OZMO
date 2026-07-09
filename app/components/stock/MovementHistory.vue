<script setup lang="ts">
import type { Database } from '~~/shared/types/database.types'
import { formatDateTime } from '~/lib/utils'

type MovementType = Database['public']['Enums']['stock_movement_type']

const props = defineProps<{
  branchId: string
  productId: string
  productName: string
  unit: string
}>()
const open = defineModel<boolean>('open', { default: false })

const supabase = useSupabaseClient<Database>()

const PAGE = 20
export interface MovementRow {
  id: string
  qty_delta: number
  type: MovementType
  doc_ref: string | null
  note: string | null
  created_at: string
  suppliers: { name: string } | null
}

const typeLabel: Record<MovementType, string> = {
  delivery: 'Dostawa',
  usage: 'Zużycie',
  waste: 'Strata',
  correction: 'Korekta',
  transfer: 'Transfer',
}

const items = ref<MovementRow[]>([])
const loading = ref(false)
const done = ref(false)

async function loadMore() {
  if (loading.value || done.value) return
  loading.value = true
  const { data } = await supabase
    .from('stock_movements')
    .select('id, qty_delta, type, doc_ref, note, created_at, suppliers(name)')
    .eq('branch_id', props.branchId)
    .eq('product_id', props.productId)
    .order('created_at', { ascending: false })
    .range(items.value.length, items.value.length + PAGE - 1)
  const rows = (data ?? []) as unknown as MovementRow[]
  items.value.push(...rows)
  if (rows.length < PAGE) done.value = true
  loading.value = false
}

watch(open, (v) => {
  if (v) {
    items.value = []
    done.value = false
    loadMore()
  }
})
</script>

<template>
  <Sheet v-model:open="open">
    <SheetContent side="right" class="flex w-full flex-col sm:max-w-md">
      <SheetHeader>
        <SheetTitle>{{ productName }}</SheetTitle>
        <SheetDescription>Historia ruchów magazynowych</SheetDescription>
      </SheetHeader>

      <div class="mt-2 flex-1 space-y-2 overflow-y-auto px-4 pb-4">
        <p
          v-if="!items.length && !loading"
          class="py-8 text-center text-sm text-muted-foreground"
        >
          Brak ruchów dla tego produktu.
        </p>
        <div
          v-for="m in items"
          :key="m.id"
          class="flex items-start justify-between gap-3 rounded-md border p-3 text-sm"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <Badge variant="outline">{{ typeLabel[m.type] }}</Badge>
              <span v-if="m.suppliers" class="truncate text-xs text-muted-foreground">
                {{ m.suppliers.name }}
              </span>
            </div>
            <p v-if="m.doc_ref" class="mt-1 text-xs text-muted-foreground">Nr: {{ m.doc_ref }}</p>
            <p v-if="m.note" class="mt-0.5 text-xs text-muted-foreground">{{ m.note }}</p>
            <p class="mt-0.5 text-xs text-muted-foreground">{{ formatDateTime(m.created_at) }}</p>
          </div>
          <span
            class="shrink-0 font-semibold tabular-nums"
            :class="Number(m.qty_delta) > 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-destructive'"
          >
            {{ Number(m.qty_delta) > 0 ? '+' : '' }}{{ m.qty_delta }} {{ unit }}
          </span>
        </div>

        <Button
          v-if="!done && items.length"
          variant="outline"
          class="w-full"
          :disabled="loading"
          @click="loadMore"
        >
          {{ loading ? 'Ładowanie…' : 'Pokaż starsze' }}
        </Button>
      </div>
    </SheetContent>
  </Sheet>
</template>
