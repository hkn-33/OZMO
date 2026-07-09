<script setup lang="ts">
import { toast } from 'vue-sonner'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient()
const email = ref('')
const password = ref('')
const loading = ref(false)

async function onSubmit() {
  loading.value = true
  const { error } = await supabase.auth.signInWithPassword({
    email: email.value,
    password: password.value,
  })
  loading.value = false

  if (error) {
    toast.error('Nie udało się zalogować', { description: error.message })
    return
  }
  await navigateTo('/')
}
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Zaloguj się</CardTitle>
      <CardDescription>Wpisz e-mail i hasło, aby kontynuować.</CardDescription>
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
      <NuxtLink to="/auth/register" class="ml-1 font-medium text-primary hover:underline">
        Zarejestruj się
      </NuxtLink>
    </CardFooter>
  </Card>
</template>
