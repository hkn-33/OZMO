<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient<Database>()
const { load } = useOrg()

const name = ref('')
const slug = ref('')
const slugEdited = ref(false)
const loading = ref(false)

function slugify(v: string) {
  return v
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/ł/g, 'l')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

watch(name, (v) => {
  if (!slugEdited.value) slug.value = slugify(v)
})

async function onSubmit() {
  if (!name.value.trim() || !slug.value.trim()) return
  loading.value = true
  const { error } = await supabase.rpc('create_organization', {
    _name: name.value.trim(),
    _slug: slug.value.trim(),
  })
  loading.value = false

  if (error) {
    toast.error('Nie udało się utworzyć organizacji', { description: error.message })
    return
  }
  await load(true)
  toast.success('Organizacja utworzona')
  await navigateTo('/')
}
</script>

<template>
  <div>
    <Card class="w-full">
      <CardHeader>
        <CardTitle>Utwórz organizację</CardTitle>
        <CardDescription>
          Zacznij od utworzenia firmy (sieci). Oddziały i zespół dodasz później.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form class="space-y-4" @submit.prevent="onSubmit">
          <div class="space-y-2">
            <Label for="name">Nazwa</Label>
            <Input
              id="name"
              v-model="name"
              placeholder="Moja Sieć Lokali"
              required
            />
          </div>
          <div class="space-y-2">
            <Label for="slug">Identyfikator (slug)</Label>
            <Input
              id="slug"
              v-model="slug"
              placeholder="moja-siec"
              required
              @input="slugEdited = true"
            />
            <p class="text-xs text-muted-foreground">
              Używany w adresach. Tylko małe litery, cyfry i myślniki.
            </p>
          </div>
          <Button type="submit" class="w-full" :disabled="loading">
            {{ loading ? 'Tworzenie…' : 'Utwórz organizację' }}
          </Button>
        </form>
      </CardContent>
    </Card>
  </div>
</template>
