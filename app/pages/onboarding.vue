<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient<Database>()
const { load } = useOrg()

const INDUSTRIES = [
  { value: 'gastronomia', label: 'Gastronomia' },
  { value: 'kawiarnia', label: 'Kawiarnia' },
  { value: 'hotel', label: 'Hotel' },
  { value: 'sklep', label: 'Sklep / Handel' },
  { value: 'magazyn', label: 'Magazyn / Hurtownia' },
  { value: 'inna', label: 'Inna' },
] as const

const step = ref<1 | 2>(1)
const name = ref('')
const industry = ref<string>('gastronomia')
const loading = ref(false)

function next() {
  if (!name.value.trim()) return
  step.value = 2
}

async function onSubmit() {
  if (!name.value.trim()) return
  loading.value = true
  const { error } = await supabase.rpc('create_organization', {
    _name: name.value.trim(),
    _industry: industry.value,
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
        <CardTitle>Utwórz firmę</CardTitle>
        <CardDescription>
          {{ step === 1
            ? 'Zacznij od utworzenia firmy. Oddziały i zespół dodasz później.'
            : 'Czym zajmuje się Twoja firma? Dobierzemy startowe checklisty, kategorie kosztów i sekcje raportów.' }}
        </CardDescription>
      </CardHeader>
      <CardContent>
        <!-- Krok 1: nazwa -->
        <form v-if="step === 1" class="space-y-4" @submit.prevent="next">
          <div class="space-y-2">
            <Label for="name">Nazwa firmy</Label>
            <Input id="name" v-model="name" placeholder="Moja Firma" required />
          </div>
          <Button type="submit" class="w-full">Dalej</Button>
        </form>

        <!-- Krok 2: branża -->
        <form v-else class="space-y-4" @submit.prevent="onSubmit">
          <div class="grid grid-cols-2 gap-2">
            <button
              v-for="ind in INDUSTRIES"
              :key="ind.value"
              type="button"
              class="rounded-lg border p-3 text-sm font-medium transition-colors"
              :class="industry === ind.value
                ? 'border-primary bg-primary/10 text-primary'
                : 'hover:bg-muted'"
              @click="industry = ind.value"
            >
              {{ ind.label }}
            </button>
          </div>
          <div class="flex gap-2">
            <Button type="button" variant="outline" class="flex-1" :disabled="loading" @click="step = 1">
              Wstecz
            </Button>
            <Button type="submit" class="flex-1" :disabled="loading">
              {{ loading ? 'Tworzenie…' : 'Utwórz firmę' }}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  </div>
</template>
