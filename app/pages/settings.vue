<script setup lang="ts">
import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { isPublicDemo } = useOrg()

// Po twardym przeładowaniu strony `useSupabaseUser().value` bywa obiektem
// *claims* JWT (ma `.sub`, `.email`, ale nie `.id`) zanim klient odświeży sesję.
// Bierzemy stabilny identyfikator z `.id` lub `.sub`.
const uid = computed(
  () => user.value?.id ?? (user.value as unknown as { sub?: string } | null)?.sub ?? null,
)

const fullName = ref('')
const phone = ref('')
const profileLoading = ref(false)
const profileSaving = ref(false)

const newPassword = ref('')
const passwordSaving = ref(false)

const deleteOpen = ref(false)
const confirmText = ref('')
const deleting = ref(false)
const CONFIRM_WORD = 'USUŃ'

async function loadProfile() {
  if (!uid.value) return
  profileLoading.value = true
  const { data } = await supabase
    .from('profiles')
    .select('full_name, phone')
    .eq('id', uid.value)
    .maybeSingle()
  if (data) {
    fullName.value = data.full_name ?? ''
    phone.value = data.phone ?? ''
  }
  profileLoading.value = false
}

onMounted(loadProfile)
watch(uid, (v) => {
  if (v) loadProfile()
})

async function saveProfile() {
  if (!uid.value) return
  profileSaving.value = true
  const { error } = await supabase
    .from('profiles')
    .update({
      full_name: fullName.value.trim() || null,
      phone: phone.value.trim() || null,
    })
    .eq('id', uid.value)
  profileSaving.value = false
  if (error) {
    toast.error('Nie udało się zapisać profilu', { description: error.message })
    return
  }
  toast.success('Zapisano dane profilu')
}

async function savePassword() {
  if (newPassword.value.length < 6) return
  passwordSaving.value = true
  const { error } = await supabase.auth.updateUser({ password: newPassword.value })
  passwordSaving.value = false
  if (error) {
    toast.error('Nie udało się zmienić hasła', { description: error.message })
    return
  }
  newPassword.value = ''
  toast.success('Hasło zmienione')
}

async function deleteAccount() {
  if (confirmText.value.trim() !== CONFIRM_WORD) return
  deleting.value = true
  try {
    await $fetch('/api/account/delete', { method: 'POST' })
    await supabase.auth.signOut()
    toast.success('Konto zostało usunięte')
    await navigateTo('/auth/login')
  } catch (e: unknown) {
    const msg =
      (e as { data?: { message?: string }; message?: string })?.data?.message ??
      (e as { message?: string })?.message ??
      'Spróbuj ponownie później.'
    toast.error('Nie udało się usunąć konta', { description: msg })
    deleting.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-2xl space-y-6">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">Ustawienia konta</h1>
      <p class="text-sm text-muted-foreground">Zarządzaj swoimi danymi i kontem.</p>
    </div>

    <Card>
      <CardHeader>
        <CardTitle>Dane profilu</CardTitle>
        <CardDescription>Twoje imię i nazwisko oraz telefon.</CardDescription>
      </CardHeader>
      <CardContent>
        <form class="space-y-4" @submit.prevent="saveProfile">
          <div class="space-y-2">
            <Label for="email">E-mail</Label>
            <Input id="email" :model-value="user?.email ?? ''" type="email" disabled />
          </div>
          <div class="space-y-2">
            <Label for="fullName">Imię i nazwisko</Label>
            <Input id="fullName" v-model="fullName" placeholder="Jan Kowalski" :disabled="profileLoading" />
          </div>
          <div class="space-y-2">
            <Label for="phone">Telefon (opcjonalnie)</Label>
            <Input id="phone" v-model="phone" type="tel" placeholder="+48 600 000 000" :disabled="profileLoading" />
          </div>
          <Button type="submit" :disabled="profileSaving || profileLoading">
            {{ profileSaving ? 'Zapisywanie…' : 'Zapisz' }}
          </Button>
        </form>
      </CardContent>
    </Card>

    <Card v-if="isPublicDemo" class="border-warning/40 bg-warning-soft/40">
      <CardHeader>
        <CardTitle>Konto demo</CardTitle>
        <CardDescription>
          To wspólne konto demonstracyjne. Zmiana hasła i usunięcie konta są
          wyłączone, a dane resetują się co godzinę.
          <NuxtLink to="/auth/register" class="font-medium text-primary hover:underline">
            Załóż własne konto
          </NuxtLink>, aby korzystać z pełnych ustawień.
        </CardDescription>
      </CardHeader>
    </Card>

    <Card v-if="!isPublicDemo">
      <CardHeader>
        <CardTitle>Zmiana hasła</CardTitle>
        <CardDescription>Ustaw nowe hasło (min. 6 znaków).</CardDescription>
      </CardHeader>
      <CardContent>
        <form class="space-y-4" @submit.prevent="savePassword">
          <div class="space-y-2">
            <Label for="newPassword">Nowe hasło</Label>
            <Input
              id="newPassword"
              v-model="newPassword"
              type="password"
              autocomplete="new-password"
              minlength="6"
              placeholder="••••••••"
            />
          </div>
          <Button type="submit" :disabled="passwordSaving || newPassword.length < 6">
            {{ passwordSaving ? 'Zapisywanie…' : 'Zmień hasło' }}
          </Button>
        </form>
      </CardContent>
    </Card>

    <Card v-if="!isPublicDemo" class="border-destructive/50">
      <CardHeader>
        <CardTitle class="text-destructive">Usuń konto</CardTitle>
        <CardDescription>
          Twój profil zostanie zanonimizowany, a dostęp do organizacji odebrany.
          Utworzone przez Ciebie treści (komentarze, wiadomości, ruchy magazynowe)
          pozostaną, ale bez danych osobowych. Tej operacji nie można cofnąć.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Dialog v-model:open="deleteOpen">
          <DialogTrigger as-child>
            <Button variant="destructive">Usuń konto</Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Na pewno usunąć konto?</DialogTitle>
              <DialogDescription>
                Aby potwierdzić, wpisz <strong>{{ CONFIRM_WORD }}</strong> poniżej.
              </DialogDescription>
            </DialogHeader>
            <div class="space-y-2">
              <Label for="confirm">Potwierdzenie</Label>
              <Input id="confirm" v-model="confirmText" :placeholder="CONFIRM_WORD" autocomplete="off" />
            </div>
            <DialogFooter>
              <Button variant="outline" @click="deleteOpen = false">Anuluj</Button>
              <Button
                variant="destructive"
                :disabled="confirmText.trim() !== CONFIRM_WORD || deleting"
                @click="deleteAccount"
              >
                {{ deleting ? 'Usuwanie…' : 'Usuń konto na stałe' }}
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </CardContent>
    </Card>
  </div>
</template>
