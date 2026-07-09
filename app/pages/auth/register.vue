<script setup lang="ts">
import { toast } from 'vue-sonner'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient()
const route = useRoute()
const email = ref('')
const password = ref('')
const loading = ref(false)

async function onSubmit() {
  loading.value = true
  const { data, error } = await supabase.auth.signUp({
    email: email.value,
    password: password.value,
  })
  loading.value = false

  if (error) {
    toast.error('Nie udało się zarejestrować', { description: error.message })
    return
  }

  // Lokalnie potwierdzenia e-mail są wyłączone — użytkownik jest od razu zalogowany.
  if (data.session) {
    await navigateTo((route.query.next as string) || '/')
    return
  }

  toast.success('Konto utworzone', {
    description: 'Sprawdź e-mail, aby potwierdzić konto.',
  })
  await navigateTo('/auth/login')
}
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Zarejestruj się</CardTitle>
      <CardDescription>
        Załóż konto i przetestuj OZMO w trybie demo.
      </CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="onSubmit">
        <div class="space-y-2">
          <Label for="email">E-mail</Label>
          <Input
            id="email"
            v-model="email"
            type="email"
            autocomplete="email"
            placeholder="ty@firma.pl"
            required
          />
        </div>
        <div class="space-y-2">
          <Label for="password">Hasło</Label>
          <Input
            id="password"
            v-model="password"
            type="password"
            autocomplete="new-password"
            minlength="6"
            required
          />
        </div>
        <Button type="submit" class="w-full" :disabled="loading">
          {{ loading ? 'Rejestracja…' : 'Zarejestruj się' }}
        </Button>
      </form>
    </CardContent>
    <CardFooter class="justify-center text-sm text-muted-foreground">
      Masz już konto?
      <NuxtLink
        :to="{ path: '/auth/login', query: route.query }"
        class="ml-1 font-medium text-primary hover:underline"
      >
        Zaloguj się
      </NuxtLink>
    </CardFooter>
  </Card>
</template>
