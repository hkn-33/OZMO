<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const user = useSupabaseUser()

// Po potwierdzeniu / zwrocie z linku sesja jest ustawiana przez @nuxtjs/supabase.
watch(
  user,
  (value) => {
    if (value) navigateTo('/')
  },
  { immediate: true },
)
</script>

<template>
  <Card>
    <CardHeader>
      <CardTitle>Potwierdzanie…</CardTitle>
      <CardDescription>Trwa logowanie, za chwilę nastąpi przekierowanie.</CardDescription>
    </CardHeader>
    <CardContent>
      <NuxtLink to="/auth/login" class="text-sm font-medium text-primary hover:underline">
        Wróć do logowania
      </NuxtLink>
    </CardContent>
  </Card>
</template>
