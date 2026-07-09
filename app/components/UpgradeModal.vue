<script setup lang="ts">
import { Sparkles } from '@lucide/vue'

const { upgradeOpen } = useDemoGuard()
</script>

<template>
  <Dialog v-model:open="upgradeOpen">
    <DialogContent>
      <DialogHeader>
        <DialogTitle class="flex items-center gap-2">
          <Sparkles class="size-5 text-primary" /> Funkcja pełnej wersji
        </DialogTitle>
        <DialogDescription>
          Ta funkcja jest dostępna w pełnej wersji. Wykup subskrypcję, aby tworzyć
          własne dane.
        </DialogDescription>
      </DialogHeader>
      <p class="text-sm text-muted-foreground">
        W trybie demo widzisz przykładowe dane tylko do odczytu.
        Wkrótce płatności online (Stripe).
      </p>
      <DialogFooter class="gap-2 sm:justify-between">
        <Button variant="outline" @click="upgradeOpen = false">Może później</Button>
        <NuxtLink to="/#pricing" @click="upgradeOpen = false">
          <Button>Zobacz pakiety</Button>
        </NuxtLink>
      </DialogFooter>
    </DialogContent>
  </Dialog>
</template>
