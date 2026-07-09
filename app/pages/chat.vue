<script setup lang="ts">
import { Hash, Building2, ArrowLeft } from '@lucide/vue'
import type { ChatChannel } from '~/composables/useChat'

const { activeOrgId, load: loadOrg } = useOrg()
const { channels, unreadMap, loaded, loadChannels, refreshUnread, markRead } = useChat()

await loadOrg()
await loadChannels()
// Wymuś klienckie przeładowanie, gdy SSR pierwszego żądania zwrócił pustą listę
// (brak sesji w SSR → `loaded=true` z pustą listą blokowałby kolejne `loadChannels()`).
onMounted(() => loadChannels(!channels.value.length))
watch(activeOrgId, () => loadChannels(true))

const activeChannelId = ref<string | null>(null)
const activeChannel = computed<ChatChannel | null>(
  () => channels.value.find((c) => c.id === activeChannelId.value) ?? null,
)

// Domyślnie wybierz kanał ogólny (lub pierwszy).
watchEffect(() => {
  if (!activeChannelId.value && channels.value.length) {
    activeChannelId.value = (channels.value.find((c) => c.type === 'org') ?? channels.value[0]!).id
  }
})

function selectChannel(id: string) {
  activeChannelId.value = id
}
async function onRead(channelId: string) {
  await markRead(channelId)
}

function channelLabel(c: ChatChannel) {
  return c.type === 'org' ? c.name : c.name
}
</script>

<template>
  <div class="flex h-[calc(100svh-9rem)] flex-col lg:h-[calc(100svh-8rem)]">
    <h1 class="mb-3 text-2xl font-bold tracking-tight">Czaty</h1>

    <div class="flex min-h-0 flex-1 overflow-hidden rounded-lg border bg-card">
      <!-- Lista kanałów -->
      <aside
        class="w-full shrink-0 flex-col border-r lg:flex lg:w-64"
        :class="activeChannel ? 'hidden lg:flex' : 'flex'"
      >
        <div class="border-b px-4 py-3 text-sm font-semibold">Kanały</div>
        <nav class="flex-1 space-y-0.5 overflow-y-auto p-2">
          <p v-if="!channels.length && loaded" class="p-4 text-sm text-muted-foreground">
            Brak kanałów. Wybierz organizację.
          </p>
          <button
            v-for="c in channels"
            :key="c.id"
            class="flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm hover:bg-accent"
            :class="c.id === activeChannelId ? 'bg-accent font-medium' : 'text-muted-foreground'"
            @click="selectChannel(c.id)"
          >
            <component :is="c.type === 'org' ? Hash : Building2" class="size-4 shrink-0 opacity-70" />
            <span class="min-w-0 flex-1 truncate">{{ channelLabel(c) }}</span>
            <span
              v-if="unreadMap[c.id]"
              class="flex h-5 min-w-5 items-center justify-center rounded-full bg-primary px-1.5 text-[11px] font-semibold text-primary-foreground"
            >
              {{ unreadMap[c.id]! > 99 ? '99+' : unreadMap[c.id] }}
            </span>
          </button>
        </nav>
      </aside>

      <!-- Widok wiadomości -->
      <section class="min-w-0 flex-1 flex-col" :class="activeChannel ? 'flex' : 'hidden lg:flex'">
        <div v-if="activeChannel" class="flex items-center gap-2 border-b px-4 py-3">
          <Button variant="ghost" size="icon" class="lg:hidden" @click="activeChannelId = null">
            <ArrowLeft class="size-5" />
          </Button>
          <component :is="activeChannel.type === 'org' ? Hash : Building2" class="size-4 opacity-70" />
          <span class="font-semibold">{{ activeChannel.name }}</span>
        </div>
        <ChatWindow
          v-if="activeChannel"
          :key="activeChannel.id"
          :channel="activeChannel"
          class="min-h-0 flex-1"
          @read="onRead"
        />
        <div v-else class="flex flex-1 items-center justify-center text-sm text-muted-foreground">
          Wybierz kanał, aby rozpocząć rozmowę.
        </div>
      </section>
    </div>
  </div>
</template>
