<script setup lang="ts">
import { toast } from 'vue-sonner'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient()
const route = useRoute()
const identifier = ref('')
const password = ref('')
const loading = ref(false)

async function onSubmit() {
  loading.value = true
  // Nazwa użytkownika (bez @) → wewnętrzny e-mail; e-mail przechodzi bez zmian.
  const input = identifier.value.trim()
  const email = input.includes('@') ? input : `${input.toLowerCase()}@users.ozmo.local`
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password: password.value,
  })
  loading.value = false

  if (error) {
    toast.error('Nie udało się zalogować', { description: error.message })
    return
  }
  // Pierwsze logowanie (konto założone przez menadżera) → zmiana hasła.
  if (data.user?.user_metadata?.must_change_password) {
    await navigateTo('/auth/change-password')
    return
  }
  await navigateTo((route.query.next as string) || '/')
}
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Zaloguj się</CardTitle>
      <CardDescription>Wpisz nazwę użytkownika lub e-mail i hasło.</CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="onSubmit">
        <div class="space-y-2">
          <Label for="email">Nazwa użytkownika lub e-mail</Label>
          <Input
            id="email"
            v-model="identifier"
            autocomplete="username"
            placeholder="jan.kowalski"
            required
          />
        </div>
        <div class="space-y-2">
          <Label for="password">Hasło</Label>
          <Input
            id="password"
            v-model="password"
            type="password"
            autocomplete="current-password"
            required
          />
        </div>
        <Button type="submit" class="w-full" :disabled="loading">
          {{ loading ? 'Logowanie…' : 'Zaloguj się' }}
        </Button>
      </form>
    </CardContent>
    <CardFooter class="justify-center text-sm text-muted-foreground">
      Nie masz konta?
      <NuxtLink
        :to="{ path: '/auth/register', query: route.query }"
        class="ml-1 font-medium text-primary hover:underline"
      >
        Zarejestruj się
      </NuxtLink>
    </CardFooter>
  </Card>
</template>
