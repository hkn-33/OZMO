<script setup lang="ts">
import type { NuxtError } from '#app'

const props = defineProps<{ error: NuxtError }>()

const isNotFound = computed(() => props.error?.statusCode === 404)
const title = computed(() => (isNotFound.value ? 'Nie znaleziono strony' : 'Coś poszło nie tak'))
const message = computed(() =>
  isNotFound.value
    ? 'Ta strona nie istnieje lub została przeniesiona.'
    : 'Wystąpił nieoczekiwany błąd. Spróbuj ponownie za chwilę.',
)

function handleClear() {
  clearError({ redirect: '/' })
}
</script>

<template>
  <div class="flex min-h-svh w-full flex-col items-center justify-center bg-background px-6 text-center">
    <div class="flex items-center gap-2.5">
      <span
        class="grid size-8 shrink-0 place-items-center rounded-lg bg-primary font-heading text-base font-semibold text-primary-foreground"
        aria-hidden="true"
      >O</span>
      <span class="font-heading text-xl font-semibold tracking-tight">OZMO</span>
    </div>

    <p class="mt-10 font-mono text-sm font-medium tabular-nums text-muted-foreground">
      {{ error?.statusCode ?? 500 }}
    </p>
    <h1 class="mt-2 text-2xl font-semibold tracking-tight text-foreground">{{ title }}</h1>
    <p class="mt-2 max-w-sm text-sm text-muted-foreground">{{ message }}</p>

    <Button class="mt-8" @click="handleClear">Wróć do pulpitu</Button>
  </div>
</template>
