<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient<Database>()
const { load } = useOrg()

const name = ref('')
const loading = ref(false)

async function onSubmit() {
  if (!name.value.trim()) return
  loading.value = true
  // Slug generowany wewnętrznie w RPC (nie w UI).
  const { error } = await supabase.rpc('create_organization', {
    _name: name.value.trim(),
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
          <Button type="submit" class="w-full" :disabled="loading">
            {{ loading ? 'Tworzenie…' : 'Utwórz organizację' }}
          </Button>
        </form>
      </CardContent>
    </Card>
  </div>
</template>
