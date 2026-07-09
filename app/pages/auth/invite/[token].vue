<script setup lang="ts">
import { toast } from 'vue-sonner'

definePageMeta({ layout: 'auth' })

const route = useRoute()
const user = useSupabaseUser()
const { load } = useOrg()

const token = route.params.token as string
const next = `/auth/invite/${token}`
const state = ref<'idle' | 'accepting' | 'done' | 'error'>('idle')
const message = ref('')

async function accept() {
  state.value = 'accepting'
  try {
    await $fetch('/api/invitations/accept', { method: 'POST', body: { token } })
    await load(true)
    state.value = 'done'
    toast.success('Dołączono do organizacji')
    setTimeout(() => navigateTo('/'), 1200)
  } catch (e: any) {
    state.value = 'error'
    message.value = e?.data?.message ?? e?.message ?? 'Nie udało się zaakceptować zaproszenia'
  }
}

// Jeśli użytkownik jest zalogowany, akceptuj automatycznie.
watchEffect(() => {
  if (user.value && state.value === 'idle') accept()
})
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Zaproszenie do OZMO</CardTitle>
      <CardDescription v-if="!user">
        Zaloguj się lub załóż konto, aby dołączyć do organizacji.
      </CardDescription>
    </CardHeader>
    <CardContent class="space-y-4">
      <template v-if="!user">
        <NuxtLink :to="`/auth/login?next=${encodeURIComponent(next)}`">
          <Button class="w-full">Zaloguj się</Button>
        </NuxtLink>
        <NuxtLink :to="`/auth/register?next=${encodeURIComponent(next)}`">
          <Button variant="outline" class="w-full">Załóż konto</Button>
        </NuxtLink>
      </template>

      <template v-else>
        <p v-if="state === 'accepting'" class="text-sm text-muted-foreground">
          Przetwarzanie zaproszenia…
        </p>
        <p v-else-if="state === 'done'" class="text-sm text-muted-foreground">
          Gotowe! Przekierowujemy Cię do pulpitu.
        </p>
        <template v-else-if="state === 'error'">
          <p class="text-sm text-destructive">{{ message }}</p>
          <Button variant="outline" class="w-full" @click="navigateTo('/')">
            Przejdź do pulpitu
          </Button>
        </template>
      </template>
    </CardContent>
  </Card>
</template>
