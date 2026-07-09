<template>
  <div class="flex min-h-svh w-full items-center justify-center bg-background p-4">
    <div class="w-full max-w-sm">
      <div class="mb-6 flex items-center justify-center gap-2.5">
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg bg-primary font-heading text-base font-semibold text-primary-foreground"
          aria-hidden="true"
        >O</span>
        <span class="font-heading text-2xl font-semibold tracking-tight">OZMO</span>
      </div>
      <slot />
    </div>
  </div>
</template>
