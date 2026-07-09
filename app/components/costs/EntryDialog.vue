<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{
  orgId: string
  branchId: string
  categories: { id: string; name: string }[]
  editing: {
    id: string
    date: string
    category_id: string
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

const form = reactive({ date: props.defaultDate, categoryId: '', amount: '', note: '' })

watch(open, (v) => {
  if (!v) return
  const firstCat = props.categories[0]?.id ?? ''
  if (props.editing) {
    form.date = props.editing.date
    form.categoryId = props.editing.category_id
    form.amount = String(props.editing.amount)
    form.note = props.editing.note ?? ''
  } else {
    form.date = props.defaultDate
    form.categoryId = firstCat
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
  if (!form.categoryId) {
    toast.error('Wybierz kategorię')
    return
  }
  if (!user.value) return
  saving.value = true
  const payload = {
    date: form.date,
    category_id: form.categoryId,
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
          <Select v-model="form.categoryId">
            <SelectTrigger><SelectValue placeholder="Wybierz kategorię" /></SelectTrigger>
            <SelectContent>
              <SelectItem v-for="c in categories" :key="c.id" :value="c.id">{{ c.name }}</SelectItem>
            </SelectContent>
          </Select>
          <p v-if="!categories.length" class="text-xs text-muted-foreground">
            Brak kategorii kosztów — dodaj je w sekcji „Kategorie kosztów".
          </p>
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
