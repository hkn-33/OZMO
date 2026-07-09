<script setup lang="ts">
const user = useSupabaseUser()
</script>

<template>
  <div class="space-y-6">
    <div>
      <h1 class="text-2xl font-bold tracking-tight">OZMO</h1>
      <p class="text-muted-foreground">
        Witaj{{ user?.email ? `, ${user.email}` : '' }}. System operacyjny dla
        Twojej sieci lokali.
      </p>
    </div>

    <Card>
      <CardHeader>
        <CardTitle>Pulpit</CardTitle>
        <CardDescription>
          To jest miejsce na przegląd dnia — zadania, powiadomienia i skróty.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <p class="text-sm text-muted-foreground">
          Moduły pojawią się tutaj w kolejnych fazach.
        </p>
      </CardContent>
    </Card>
  </div>
</template>
