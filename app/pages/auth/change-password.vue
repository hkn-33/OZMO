<script setup lang="ts">
import { toast } from 'vue-sonner'

definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const password = ref('')
const confirm = ref('')
const loading = ref(false)

const mustChange = computed(
  () =>
    !!(user.value as { user_metadata?: Record<string, unknown> })?.user_metadata
      ?.must_change_password,
)

async function onSubmit() {
  if (password.value.length < 8) {
    toast.error('Hasło musi mieć co najmniej 8 znaków')
    return
  }
  if (password.value !== confirm.value) {
    toast.error('Hasła nie są takie same')
    return
  }
  loading.value = true
  const { error } = await supabase.auth.updateUser({
    password: password.value,
    data: { must_change_password: false },
  })
  loading.value = false
  if (error) {
    toast.error('Nie udało się zmienić hasła', { description: error.message })
    return
  }
  // Access token (JWT) niesie metadane z chwili wydania — odśwież sesję, aby
  // nowy token miał już `must_change_password=false` (inaczej middleware
  // zapętla przekierowania na tę stronę).
  await supabase.auth.refreshSession()
  toast.success('Hasło zmienione')
  await navigateTo('/')
}
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Ustaw nowe hasło</CardTitle>
      <CardDescription>
        {{ mustChange
          ? 'To pierwsze logowanie — ustaw własne hasło, aby kontynuować.'
          : 'Ustaw nowe hasło do swojego konta.' }}
      </CardDescription>
    </CardHeader>
    <CardContent>
      <form class="space-y-4" @submit.prevent="onSubmit">
        <div class="space-y-2">
          <Label for="pw">Nowe hasło</Label>
          <Input id="pw" v-model="password" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <div class="space-y-2">
          <Label for="pw2">Powtórz hasło</Label>
          <Input id="pw2" v-model="confirm" type="password" autocomplete="new-password" minlength="8" required />
        </div>
        <Button type="submit" class="w-full" :disabled="loading">
          {{ loading ? 'Zapisywanie…' : 'Zapisz hasło' }}
        </Button>
      </form>
    </CardContent>
  </Card>
</template>
