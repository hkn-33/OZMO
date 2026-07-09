<script setup lang="ts">
import { Bell, CheckCheck, UserPlus, AtSign, MessageSquare, Clock, CalendarDays } from '@lucide/vue'
import type { Component } from 'vue'
import { formatRelative } from '~/lib/utils'
import type { NotificationRow, NotificationType } from '~/composables/useNotifications'

const { items, unread, load, subscribe, unsubscribe, markRead, markAllRead } = useNotifications()

onMounted(async () => {
  await load()
  await subscribe()
})
onBeforeUnmount(() => unsubscribe())

const open = ref(false)

const typeIcon: Record<NotificationType, Component> = {
  task_assigned: UserPlus,
  mentioned: AtSign,
  comment_on_my_task: MessageSquare,
  task_due_soon: Clock,
  shift_published: CalendarDays,
}
const typeLabel: Record<NotificationType, string> = {
  task_assigned: 'Przypisano Ci zadanie',
  mentioned: 'Wspomniano o Tobie',
  comment_on_my_task: 'Nowy komentarz do zadania',
  task_due_soon: 'Zbliża się termin zadania',
  shift_published: 'Opublikowano Twój grafik',
}

async function openNotification(n: NotificationRow) {
  if (!n.read_at) await markRead(n.id)
  open.value = false
  if (n.type === 'shift_published') {
    await navigateTo('/schedule')
  } else if (n.payload?.task_id) {
    await navigateTo({ path: '/tasks', query: { task: n.payload.task_id } })
  }
}
</script>

<template>
  <DropdownMenu v-model:open="open">
    <DropdownMenuTrigger as-child>
      <Button variant="ghost" size="icon" class="relative">
        <Bell class="size-5" />
        <span
          v-if="unread > 0"
          class="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-semibold text-primary-foreground"
        >
          {{ unread > 99 ? '99+' : unread }}
        </span>
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end" class="w-80">
      <div class="flex items-center justify-between px-2 py-1.5">
        <DropdownMenuLabel class="p-0">Powiadomienia</DropdownMenuLabel>
        <button
          v-if="unread > 0"
          class="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
          @click="markAllRead"
        >
          <CheckCheck class="size-3.5" /> oznacz wszystkie
        </button>
      </div>
      <DropdownMenuSeparator />
      <p
        v-if="!items.length"
        class="px-3 py-6 text-center text-sm text-muted-foreground"
      >
        Brak powiadomień.
      </p>
      <div v-else class="max-h-96 overflow-y-auto">
        <button
          v-for="n in items"
          :key="n.id"
          class="flex w-full items-start gap-3 px-3 py-2.5 text-left text-sm hover:bg-accent"
          :class="{ 'bg-accent/40': !n.read_at }"
          @click="openNotification(n)"
        >
          <component :is="typeIcon[n.type]" class="mt-0.5 size-4 shrink-0 text-muted-foreground" />
          <div class="min-w-0 flex-1">
            <p class="font-medium leading-tight">{{ typeLabel[n.type] }}</p>
            <p v-if="n.payload?.title" class="truncate text-muted-foreground">
              {{ n.payload.title }}
            </p>
            <p class="mt-0.5 text-xs text-muted-foreground">
              {{ formatRelative(n.created_at) }}
            </p>
          </div>
          <span v-if="!n.read_at" class="mt-1.5 size-2 shrink-0 rounded-full bg-primary" />
        </button>
      </div>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
