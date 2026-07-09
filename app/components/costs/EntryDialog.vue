<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

type CostCategory = Database['public']['Enums']['cost_category']

const props = defineProps<{
  orgId: string
  branchId: string
  editing: {
    id: string
    date: string
    category: CostCategory
    amount: number
    note: string | null
  } | null
  defaultDate: string
}>()
const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ saved: [] }>()

const supabase = useSupabaseClient<Database>()
const { isDemo, upgradeOpen } = useDemoGuard()
const user = useSupabaseUser()

const CATEGORIES: { value: CostCategory; label: string }[] = [
  { value: 'food', label: 'Żywność' },
  { value: 'beverage', label: 'Napoje' },
  { value: 'labor', label: 'Praca' },
  { value: 'other', label: 'Inne' },
]

const form = reactive({ date: props.defaultDate, category: 'food' as CostCategory, amount: '', note: '' })

watch(open, (v) => {
  if (!v) return
  if (props.editing) {
    form.date = props.editing.date
    form.category = props.editing.category
    form.amount = String(props.editing.amount)
    form.note = props.editing.note ?? ''
  } else {
    form.date = props.defaultDate
    form.category = 'food'
    form.amount = ''
    form.note = ''
  }
})

const saving = ref(false)
async function save() {
  if (isDemo.value) { upgradeOpen.value = true; return }
  const amount = Number(form.amount)
  if (!Number.isFinite(amount) || amount < 0) {
    toast.error('Podaj kwotę ≥ 0')
    return
  }
  if (!user.value) return
  saving.value = true
  const payload = {
    date: form.date,
    category: form.category,
    amount,
    note: form.note.trim() || null,
  }
  const { error } = props.editing
    ? await supabase.from('cost_entries').update(payload).eq('id', props.editing.id)
    : await supabase.from('cost_entries').insert({
        ...payload,
        org_id: props.orgId,
        branch_id: props.branchId,
        created_by: user.value.id,
      })
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać kosztu', { description: error.message })
    return
  }
  toast.success(props.editing ? 'Zaktualizowano koszt' : 'Dodano koszt')
  open.value = false
  emit('saved')
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>{{ editing ? 'Edytuj koszt' : 'Nowy koszt' }}</DialogTitle>
      </DialogHeader>
      <form class="space-y-4" @submit.prevent="save">
        <div class="space-y-2">
          <Label for="c-date">Data</Label>
          <Input id="c-date" v-model="form.date" type="date" />
        </div>
        <div class="space-y-2">
          <Label>Kategoria</Label>
          <Select v-model="form.category">
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="c in CATEGORIES" :key="c.value" :value="c.value">{{ c.label }}</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div class="space-y-2">
          <Label for="c-amount">Kwota (zł)</Label>
          <Input id="c-amount" v-model="form.amount" type="number" step="0.01" min="0" inputmode="decimal" />
        </div>
        <div class="space-y-2">
          <Label for="c-note">Notatka (opcjonalnie)</Label>
          <Textarea id="c-note" v-model="form.note" rows="2" />
        </div>
        <DialogFooter>
          <Button type="submit" :disabled="saving">{{ saving ? 'Zapisywanie…' : 'Zapisz' }}</Button>
        </DialogFooter>
      </form>
    </DialogContent>
  </Dialog>
</template>
