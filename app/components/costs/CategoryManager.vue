<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Pencil, Trash2, Check, X } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{ orgId: string }>()
const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ changed: [] }>()

const supabase = useSupabaseClient<Database>()
const { block } = useDemoGuard()

interface Category { id: string; name: string; sort: number }
const categories = ref<Category[]>([])
const loading = ref(false)

async function load() {
  loading.value = true
  const { data } = await supabase
    .from('cost_categories')
    .select('id, name, sort')
    .eq('org_id', props.orgId)
    .order('sort')
  categories.value = (data ?? []) as Category[]
  loading.value = false
}

watch(open, (v) => { if (v) { resetState(); load() } })

const newName = ref('')
async function add() {
  if (block()) return
  const name = newName.value.trim()
  if (!name) return
  const sort = categories.value.reduce((m, c) => Math.max(m, c.sort), -1) + 1
  const { error } = await supabase.from('cost_categories').insert({ org_id: props.orgId, name, sort })
  if (error) {
    toast.error('Nie udało się dodać kategorii', { description: error.message })
    return
  }
  newName.value = ''
  await load()
  emit('changed')
}

const editingId = ref<string | null>(null)
const editName = ref('')
function startEdit(c: Category) {
  editingId.value = c.id
  editName.value = c.name
}
async function saveEdit(c: Category) {
  if (block()) return
  const name = editName.value.trim()
  if (!name) return
  const { error } = await supabase.from('cost_categories').update({ name }).eq('id', c.id)
  if (error) {
    toast.error('Nie udało się zmienić nazwy', { description: error.message })
    return
  }
  editingId.value = null
  await load()
  emit('changed')
}

const deleting = ref<Category | null>(null)
const deleteCount = ref(0)
const reassignTo = ref('')
async function startDelete(c: Category) {
  const { count } = await supabase
    .from('cost_entries')
    .select('id', { count: 'exact', head: true })
    .eq('category_id', c.id)
  deleteCount.value = count ?? 0
  deleting.value = c
  reassignTo.value = ''
}
const reassignOptions = computed(() => categories.value.filter((c) => c.id !== deleting.value?.id))

async function confirmDelete() {
  if (block()) return
  const cat = deleting.value
  if (!cat) return
  if (deleteCount.value > 0) {
    if (!reassignTo.value) {
      toast.error('Wybierz kategorię, do której przenieść wpisy')
      return
    }
    const { error: rErr } = await supabase
      .from('cost_entries')
      .update({ category_id: reassignTo.value })
      .eq('category_id', cat.id)
    if (rErr) {
      toast.error('Nie udało się przenieść wpisów', { description: rErr.message })
      return
    }
  }
  const { error } = await supabase.from('cost_categories').delete().eq('id', cat.id)
  if (error) {
    toast.error('Nie udało się usunąć kategorii', { description: error.message })
    return
  }
  toast.success('Usunięto kategorię')
  deleting.value = null
  await load()
  emit('changed')
}

function resetState() {
  editingId.value = null
  deleting.value = null
  newName.value = ''
}
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent>
      <DialogHeader>
        <DialogTitle>Kategorie kosztów</DialogTitle>
        <DialogDescription>Dodawaj, zmieniaj nazwy i usuwaj kategorie kosztów firmy.</DialogDescription>
      </DialogHeader>

      <div class="space-y-2">
        <p v-if="loading" class="text-sm text-muted-foreground">Ładowanie…</p>
        <p v-else-if="!categories.length" class="text-sm text-muted-foreground">Brak kategorii.</p>

        <div v-for="c in categories" :key="c.id" class="flex items-center gap-2 rounded-md border p-2">
          <template v-if="editingId === c.id">
            <Input v-model="editName" class="h-8" @keyup.enter="saveEdit(c)" />
            <Button size="icon" variant="ghost" class="size-8" @click="saveEdit(c)"><Check class="size-4" /></Button>
            <Button size="icon" variant="ghost" class="size-8" @click="editingId = null"><X class="size-4" /></Button>
          </template>
          <template v-else>
            <span class="flex-1 text-sm font-medium">{{ c.name }}</span>
            <Button size="icon" variant="ghost" class="size-8" @click="startEdit(c)"><Pencil class="size-4" /></Button>
            <Button size="icon" variant="ghost" class="size-8 text-destructive" @click="startDelete(c)">
              <Trash2 class="size-4" />
            </Button>
          </template>
        </div>
      </div>

      <form class="flex items-center gap-2" @submit.prevent="add">
        <Input v-model="newName" placeholder="Nowa kategoria…" class="h-9" />
        <Button type="submit" size="sm" :disabled="!newName.trim()">Dodaj</Button>
      </form>

      <div v-if="deleting" class="space-y-3 rounded-md border border-destructive/40 bg-destructive/5 p-3">
        <p class="text-sm font-medium">Usuń kategorię „{{ deleting.name }}"</p>
        <template v-if="deleteCount > 0">
          <p class="text-sm text-muted-foreground">
            Ta kategoria ma {{ deleteCount }} przypisanych wpisów. Przenieś je do innej kategorii przed usunięciem.
          </p>
          <div v-if="reassignOptions.length" class="space-y-2">
            <Label class="text-xs">Przenieś wpisy do</Label>
            <Select v-model="reassignTo">
              <SelectTrigger><SelectValue placeholder="Wybierz kategorię" /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="o in reassignOptions" :key="o.id" :value="o.id">{{ o.name }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <p v-else class="text-sm text-destructive">
            Brak innej kategorii — najpierw dodaj kategorię, do której przeniesiesz wpisy.
          </p>
        </template>
        <p v-else class="text-sm text-muted-foreground">Kategoria nie ma wpisów — można ją usunąć.</p>
        <div class="flex justify-end gap-2">
          <Button size="sm" variant="outline" @click="deleting = null">Anuluj</Button>
          <Button
            size="sm"
            variant="destructive"
            :disabled="deleteCount > 0 && !reassignOptions.length"
            @click="confirmDelete"
          >
            {{ deleteCount > 0 ? 'Przenieś i usuń' : 'Usuń' }}
          </Button>
        </div>
      </div>

      <DialogFooter>
        <Button variant="outline" @click="open = false">Zamknij</Button>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
