<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Pencil, Trash2, X, ListChecks } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

export interface ChecklistTemplate {
  id: string
  name: string
  description: string | null
  items: { label: string }[]
}

const props = defineProps<{
  orgId: string
  templates: ChecklistTemplate[]
  canManage: boolean
}>()
const emit = defineEmits<{ changed: [] }>()

const supabase = useSupabaseClient<Database>()
const { block } = useDemoGuard()
const user = useSupabaseUser()

const dialogOpen = ref(false)
const editing = ref<ChecklistTemplate | null>(null)
const form = reactive({ name: '', description: '', items: [''] as string[] })
const saving = ref(false)

function openCreate() {
  editing.value = null
  form.name = ''
  form.description = ''
  form.items = ['']
  dialogOpen.value = true
}
function openEdit(t: ChecklistTemplate) {
  editing.value = t
  form.name = t.name
  form.description = t.description ?? ''
  form.items = t.items.length ? t.items.map((i) => i.label) : ['']
  dialogOpen.value = true
}
function addItem() {
  form.items.push('')
}
function removeItem(i: number) {
  form.items.splice(i, 1)
  if (!form.items.length) form.items.push('')
}

async function save() {
  if (block()) return
  if (!form.name.trim()) return
  saving.value = true
  const items = form.items.map((l) => l.trim()).filter(Boolean).map((label) => ({ label }))
  const payload = {
    org_id: props.orgId,
    name: form.name.trim(),
    description: form.description.trim() || null,
    items,
  }
  const { error } = editing.value
    ? await supabase.from('checklist_templates').update(payload).eq('id', editing.value.id)
    : await supabase.from('checklist_templates').insert({ ...payload, created_by: user.value?.id ?? null })
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać szablonu', { description: error.message })
    return
  }
  dialogOpen.value = false
  toast.success(editing.value ? 'Szablon zaktualizowany' : 'Szablon utworzony')
  emit('changed')
}

async function remove(t: ChecklistTemplate) {
  if (block()) return
  if (!confirm(`Usunąć szablon „${t.name}"?`)) return
  const { error } = await supabase.from('checklist_templates').delete().eq('id', t.id)
  if (error) {
    toast.error('Nie udało się usunąć szablonu', { description: error.message })
    return
  }
  toast.success('Szablon usunięty')
  emit('changed')
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <p class="text-sm text-muted-foreground">
        Szablony checklist wykorzystywane przy tworzeniu zadań.
      </p>
      <Button v-if="canManage" size="sm" @click="openCreate">
        <Plus class="mr-2 size-4" /> Nowy szablon
      </Button>
    </div>

    <p
      v-if="!templates.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak szablonów.
    </p>

    <div v-else class="grid gap-3 sm:grid-cols-2">
      <Card v-for="t in templates" :key="t.id">
        <CardHeader class="pb-3">
          <div class="flex items-start justify-between gap-2">
            <CardTitle class="flex items-center gap-2 text-base">
              <ListChecks class="size-4" /> {{ t.name }}
            </CardTitle>
            <div v-if="canManage" class="flex shrink-0 gap-1">
              <Button variant="ghost" size="icon" class="size-8" @click="openEdit(t)">
                <Pencil class="size-4" />
              </Button>
              <Button variant="ghost" size="icon" class="size-8 text-destructive" @click="remove(t)">
                <Trash2 class="size-4" />
              </Button>
            </div>
          </div>
          <CardDescription v-if="t.description">{{ t.description }}</CardDescription>
        </CardHeader>
        <CardContent>
          <ul class="space-y-1 text-sm text-muted-foreground">
            <li v-for="(it, i) in t.items" :key="i" class="flex gap-2">
              <span class="text-muted-foreground/50">·</span> {{ it.label }}
            </li>
          </ul>
        </CardContent>
      </Card>
    </div>

    <Dialog v-model:open="dialogOpen">
      <DialogScrollContent class="max-h-[90svh]">
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Edytuj szablon' : 'Nowy szablon' }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="save">
          <div class="space-y-2">
            <Label for="tpl-name">Nazwa</Label>
            <Input id="tpl-name" v-model="form.name" placeholder="np. Otwarcie oddziału" required />
          </div>
          <div class="space-y-2">
            <Label for="tpl-desc">Opis (opcjonalnie)</Label>
            <Input id="tpl-desc" v-model="form.description" />
          </div>
          <div class="space-y-2">
            <Label>Pozycje checklisty</Label>
            <div class="space-y-2">
              <div v-for="(_, i) in form.items" :key="i" class="flex gap-2">
                <Input v-model="form.items[i]" :placeholder="`Pozycja ${i + 1}`" />
                <Button type="button" variant="ghost" size="icon" @click="removeItem(i)">
                  <X class="size-4" />
                </Button>
              </div>
            </div>
            <Button type="button" variant="outline" size="sm" @click="addItem">
              <Plus class="mr-2 size-4" /> Dodaj pozycję
            </Button>
          </div>
          <DialogFooter>
            <Button type="submit" :disabled="saving || !form.name.trim()">
              {{ saving ? 'Zapisywanie…' : 'Zapisz' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogScrollContent>
    </Dialog>
  </div>
</template>
