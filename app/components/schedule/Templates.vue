<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Trash2 } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { WEEKDAYS_FULL } from '~/lib/schedule'

const props = defineProps<{
  orgId: string
  branchId: string
}>()

const supabase = useSupabaseClient<Database>()

interface TemplateRow {
  id: string
  weekday: number
  position: string | null
  needed: number
  from_time: string
  to_time: string
}

const { data, refresh, pending } = await useAsyncData(
  () => `shift-templates:${props.branchId}`,
  async () => {
    const { data } = await supabase
      .from('shift_templates')
      .select('id, weekday, position, needed, from_time, to_time')
      .eq('branch_id', props.branchId)
      .order('weekday')
    return (data ?? []) as TemplateRow[]
  },
  { watch: [() => props.branchId] },
)

function hm(t: string) {
  return t.slice(0, 5)
}

const byWeekday = computed(() => {
  const map: Record<number, TemplateRow[]> = {}
  for (const r of data.value ?? []) (map[r.weekday] ??= []).push(r)
  return map
})

const form = reactive({ weekday: '0', position: '', needed: '1', from: '08:00', to: '16:00' })
const saving = ref(false)

async function add() {
  if (form.to <= form.from) {
    toast.error('Godzina zakończenia musi być późniejsza niż rozpoczęcia')
    return
  }
  saving.value = true
  const { error } = await supabase.from('shift_templates').insert({
    org_id: props.orgId,
    branch_id: props.branchId,
    weekday: Number(form.weekday),
    position: form.position.trim() || null,
    needed: Math.max(1, Number(form.needed) || 1),
    from_time: form.from,
    to_time: form.to,
  })
  saving.value = false
  if (error) {
    toast.error('Nie udało się dodać szablonu', { description: error.message })
    return
  }
  form.position = ''
  toast.success('Szablon dodany')
  refresh()
}

async function remove(r: TemplateRow) {
  const { error } = await supabase.from('shift_templates').delete().eq('id', r.id)
  if (error) {
    toast.error('Nie udało się usunąć', { description: error.message })
    return
  }
  refresh()
}
</script>

<template>
  <div class="space-y-6">
    <Card>
      <CardHeader>
        <CardTitle class="text-base">Szablon obsady</CardTitle>
        <CardDescription>Typowa obsada na dzień tygodnia — podpowiedzi przy planowaniu.</CardDescription>
      </CardHeader>
      <CardContent>
        <form class="flex flex-wrap items-end gap-2" @submit.prevent="add">
          <div class="space-y-1.5">
            <Label class="text-xs">Dzień</Label>
            <Select v-model="form.weekday">
              <SelectTrigger class="w-40"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="(d, i) in WEEKDAYS_FULL" :key="i" :value="String(i)">
                  {{ d }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="min-w-32 space-y-1.5">
            <Label class="text-xs">Stanowisko</Label>
            <Input v-model="form.position" placeholder="np. Kelner" />
          </div>
          <div class="w-24 space-y-1.5">
            <Label class="text-xs">Obsada</Label>
            <Input v-model="form.needed" type="number" min="1" />
          </div>
          <div class="space-y-1.5">
            <Label class="text-xs">Od</Label>
            <Input v-model="form.from" type="time" class="w-28" />
          </div>
          <div class="space-y-1.5">
            <Label class="text-xs">Do</Label>
            <Input v-model="form.to" type="time" class="w-28" />
          </div>
          <Button type="submit" :disabled="saving">
            <Plus class="mr-1.5 size-4" /> Dodaj
          </Button>
        </form>
      </CardContent>
    </Card>

    <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>
    <p v-else-if="!data?.length" class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">
      Brak szablonów obsady.
    </p>
    <div v-else class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <Card v-for="(rows, wd) in byWeekday" :key="wd">
        <CardHeader class="pb-2">
          <CardTitle class="text-sm">{{ WEEKDAYS_FULL[wd] }}</CardTitle>
        </CardHeader>
        <CardContent>
          <ul class="divide-y">
            <li v-for="r in rows" :key="r.id" class="flex items-center justify-between gap-2 py-1.5 text-sm">
              <span>
                <span class="font-medium">{{ r.position || 'Dowolne' }}</span>
                <span class="text-muted-foreground">
                  · {{ r.needed }} os. · {{ hm(r.from_time) }}–{{ hm(r.to_time) }}
                </span>
              </span>
              <Button variant="ghost" size="icon" class="size-7 text-destructive" @click="remove(r)">
                <Trash2 class="size-3.5" />
              </Button>
            </li>
          </ul>
        </CardContent>
      </Card>
    </div>
  </div>
</template>
