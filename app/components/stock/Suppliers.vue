<script setup lang="ts">
import { toast } from 'vue-sonner'
import { Plus, Pencil, Trash2 } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

const props = defineProps<{ orgId: string }>()

const supabase = useSupabaseClient<Database>()

interface Supplier {
  id: string
  name: string
  contact_name: string | null
  phone: string | null
  email: string | null
  note: string | null
}

const { data, pending, refresh } = await useAsyncData(
  () => `stock-suppliers:${props.orgId}`,
  async () => {
    const { data } = await supabase
      .from('suppliers')
      .select('id, name, contact_name, phone, email, note')
      .eq('org_id', props.orgId)
      .order('name')
    return (data ?? []) as Supplier[]
  },
)

const dialogOpen = ref(false)
const editing = ref<Supplier | null>(null)
const form = reactive({ name: '', contact_name: '', phone: '', email: '', note: '' })

function openCreate() {
  editing.value = null
  Object.assign(form, { name: '', contact_name: '', phone: '', email: '', note: '' })
  dialogOpen.value = true
}
function openEdit(s: Supplier) {
  editing.value = s
  Object.assign(form, {
    name: s.name,
    contact_name: s.contact_name ?? '',
    phone: s.phone ?? '',
    email: s.email ?? '',
    note: s.note ?? '',
  })
  dialogOpen.value = true
}

const saving = ref(false)
async function save() {
  if (!form.name.trim()) {
    toast.error('Podaj nazwę dostawcy')
    return
  }
  saving.value = true
  const payload = {
    name: form.name.trim(),
    contact_name: form.contact_name.trim() || null,
    phone: form.phone.trim() || null,
    email: form.email.trim() || null,
    note: form.note.trim() || null,
  }
  const { error } = editing.value
    ? await supabase.from('suppliers').update(payload).eq('id', editing.value.id)
    : await supabase.from('suppliers').insert({ ...payload, org_id: props.orgId })
  saving.value = false
  if (error) {
    toast.error('Nie udało się zapisać dostawcy', { description: error.message })
    return
  }
  toast.success(editing.value ? 'Zaktualizowano dostawcę' : 'Dodano dostawcę')
  dialogOpen.value = false
  await refresh()
}

async function remove(s: Supplier) {
  const { error } = await supabase.from('suppliers').delete().eq('id', s.id)
  if (error) {
    toast.error('Nie udało się usunąć dostawcy', { description: error.message })
    return
  }
  toast.success('Usunięto dostawcę')
  await refresh()
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <p class="text-sm text-muted-foreground">Dostawcy sieci</p>
      <Button size="sm" @click="openCreate"><Plus class="mr-1.5 size-4" /> Dodaj dostawcę</Button>
    </div>

    <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>
    <p
      v-else-if="!data?.length"
      class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
    >
      Brak dostawców. Dodaj pierwszego dostawcę.
    </p>

    <div v-else class="overflow-x-auto rounded-lg border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Nazwa</TableHead>
            <TableHead class="hidden sm:table-cell">Kontakt</TableHead>
            <TableHead class="hidden md:table-cell">Telefon</TableHead>
            <TableHead class="hidden md:table-cell">E-mail</TableHead>
            <TableHead class="text-right">Akcje</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          <TableRow v-for="s in data" :key="s.id">
            <TableCell class="font-medium">{{ s.name }}</TableCell>
            <TableCell class="hidden text-muted-foreground sm:table-cell">{{ s.contact_name ?? '—' }}</TableCell>
            <TableCell class="hidden text-muted-foreground md:table-cell">{{ s.phone ?? '—' }}</TableCell>
            <TableCell class="hidden text-muted-foreground md:table-cell">{{ s.email ?? '—' }}</TableCell>
            <TableCell class="text-right">
              <Button size="icon" variant="ghost" class="size-8" @click="openEdit(s)">
                <Pencil class="size-4" />
              </Button>
              <Button size="icon" variant="ghost" class="size-8 text-destructive" @click="remove(s)">
                <Trash2 class="size-4" />
              </Button>
            </TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </div>

    <Dialog v-model:open="dialogOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{{ editing ? 'Edytuj dostawcę' : 'Nowy dostawca' }}</DialogTitle>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="save">
          <div class="space-y-2">
            <Label for="s-name">Nazwa</Label>
            <Input id="s-name" v-model="form.name" placeholder="np. Hurtownia Smak" />
          </div>
          <div class="space-y-2">
            <Label for="s-contact">Osoba kontaktowa (opcjonalnie)</Label>
            <Input id="s-contact" v-model="form.contact_name" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div class="space-y-2">
              <Label for="s-phone">Telefon (opcjonalnie)</Label>
              <Input id="s-phone" v-model="form.phone" />
            </div>
            <div class="space-y-2">
              <Label for="s-email">E-mail (opcjonalnie)</Label>
              <Input id="s-email" v-model="form.email" type="email" />
            </div>
          </div>
          <div class="space-y-2">
            <Label for="s-note">Notatka (opcjonalnie)</Label>
            <Textarea id="s-note" v-model="form.note" rows="2" />
          </div>
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
