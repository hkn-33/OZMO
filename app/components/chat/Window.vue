<script setup lang="ts">
import { Send } from '@lucide/vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import type { Database } from '~~/shared/types/database.types'
import type { ChatChannel } from '~/composables/useChat'

const props = defineProps<{ channel: ChatChannel }>()
const emit = defineEmits<{ read: [channelId: string] }>()

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()

interface Message {
  id: string
  author_id: string
  body: string
  created_at: string
}

const PAGE = 30
const messages = ref<Message[]>([])
const loading = ref(false)
const loadingOlder = ref(false)
const hasMore = ref(false)
const names = ref<Record<string, string>>({})
const scroller = ref<HTMLElement | null>(null)
const body = ref('')
const sending = ref(false)
let channel: RealtimeChannel | null = null

function nameOf(id: string) {
  return names.value[id] ?? 'Użytkownik'
}
function initialOf(id: string) {
  return (nameOf(id)[0] ?? '?').toUpperCase()
}

async function resolveNames(ids: string[]) {
  const missing = [...new Set(ids)].filter((id) => !(id in names.value))
  if (!missing.length) return
  const { data } = await supabase.from('profiles').select('id, full_name').in('id', missing)
  const next = { ...names.value }
  for (const id of missing) next[id] = 'Użytkownik'
  for (const p of data ?? []) next[p.id] = p.full_name?.trim() || 'Użytkownik'
  names.value = next
}

function scrollToBottom(smooth = false) {
  nextTick(() => {
    const el = scroller.value
    if (el) el.scrollTo({ top: el.scrollHeight, behavior: smooth ? 'smooth' : 'auto' })
  })
}

async function loadInitial() {
  loading.value = true
  const { data } = await supabase
    .from('chat_messages')
    .select('id, author_id, body, created_at')
    .eq('channel_id', props.channel.id)
    .order('created_at', { ascending: false })
    .limit(PAGE)
  const rows = ((data ?? []) as Message[]).reverse()
  messages.value = rows
  hasMore.value = (data?.length ?? 0) === PAGE
  await resolveNames(rows.map((m) => m.author_id))
  loading.value = false
  scrollToBottom()
  markRead()
}

async function loadOlder() {
  if (loadingOlder.value || !hasMore.value || !messages.value.length) return
  loadingOlder.value = true
  const el = scroller.value
  const prevHeight = el?.scrollHeight ?? 0
  const oldest = messages.value[0]!.created_at
  const { data } = await supabase
    .from('chat_messages')
    .select('id, author_id, body, created_at')
    .eq('channel_id', props.channel.id)
    .lt('created_at', oldest)
    .order('created_at', { ascending: false })
    .limit(PAGE)
  const rows = ((data ?? []) as Message[]).reverse()
  hasMore.value = (data?.length ?? 0) === PAGE
  await resolveNames(rows.map((m) => m.author_id))
  messages.value = [...rows, ...messages.value]
  loadingOlder.value = false
  // zachowaj pozycję po doładowaniu starszych
  nextTick(() => {
    if (el) el.scrollTop = el.scrollHeight - prevHeight
  })
}

function onScroll() {
  if (scroller.value && scroller.value.scrollTop < 60) loadOlder()
}

async function markRead() {
  emit('read', props.channel.id)
}

async function subscribe() {
  const { data } = await supabase.auth.getSession()
  if (data.session) await supabase.realtime.setAuth(data.session.access_token)
  channel = supabase
    .channel(`chat:${props.channel.id}`, { config: { private: true } })
    .on('broadcast', { event: 'new_message' }, async (msg) => {
      const p = msg.payload as Message
      if (messages.value.some((m) => m.id === p.id)) return
      await resolveNames([p.author_id])
      messages.value.push({ id: p.id, author_id: p.author_id, body: p.body, created_at: p.created_at })
      scrollToBottom(true)
      if (p.author_id !== user.value?.id) markRead()
    })
  channel.subscribe()
}

function teardown() {
  if (channel) {
    supabase.removeChannel(channel)
    channel = null
  }
}

async function send() {
  const text = body.value.trim()
  if (!text || sending.value || !user.value) return
  sending.value = true
  const { data, error } = await supabase
    .from('chat_messages')
    .insert({
      channel_id: props.channel.id,
      org_id: props.channel.org_id,
      branch_id: props.channel.branch_id,
      author_id: user.value.id,
      body: text,
    })
    .select('id, author_id, body, created_at')
    .single()
  sending.value = false
  if (error) return
  body.value = ''
  if (data && !messages.value.some((m) => m.id === data.id)) {
    messages.value.push(data as Message)
    scrollToBottom(true)
  }
}

// Separatory dni
const plDay = new Intl.DateTimeFormat('pl-PL', { day: 'numeric', month: 'long', year: 'numeric' })
const plTime = new Intl.DateTimeFormat('pl-PL', { hour: '2-digit', minute: '2-digit' })
function dayKey(iso: string) {
  return new Date(iso).toDateString()
}
function dayLabel(iso: string) {
  const d = new Date(iso)
  const today = new Date()
  const yest = new Date()
  yest.setDate(today.getDate() - 1)
  if (d.toDateString() === today.toDateString()) return 'Dzisiaj'
  if (d.toDateString() === yest.toDateString()) return 'Wczoraj'
  return plDay.format(d)
}
function timeLabel(iso: string) {
  return plTime.format(new Date(iso))
}
function showDaySeparator(i: number) {
  if (i === 0) return true
  return dayKey(messages.value[i]!.created_at) !== dayKey(messages.value[i - 1]!.created_at)
}
function showAuthor(i: number) {
  if (i === 0) return true
  const cur = messages.value[i]!
  const prev = messages.value[i - 1]!
  return cur.author_id !== prev.author_id || showDaySeparator(i)
}

watch(
  () => props.channel.id,
  async () => {
    teardown()
    await loadInitial()
    await subscribe()
  },
  { immediate: true },
)
onBeforeUnmount(teardown)
</script>

<template>
  <div class="flex h-full min-h-0 flex-col">
    <div ref="scroller" class="flex-1 space-y-1 overflow-y-auto px-4 py-3" @scroll="onScroll">
      <p v-if="loadingOlder" class="py-1 text-center text-xs text-muted-foreground">Ładowanie…</p>
      <p v-if="loading" class="py-8 text-center text-sm text-muted-foreground">Ładowanie wiadomości…</p>
      <p
        v-else-if="!messages.length"
        class="py-8 text-center text-sm text-muted-foreground"
      >
        Brak wiadomości. Napisz pierwszą.
      </p>

      <template v-for="(m, i) in messages" :key="m.id">
        <div v-if="showDaySeparator(i)" class="flex items-center gap-3 py-2">
          <div class="h-px flex-1 bg-border" />
          <span class="text-[11px] font-medium text-muted-foreground">{{ dayLabel(m.created_at) }}</span>
          <div class="h-px flex-1 bg-border" />
        </div>

        <div class="flex gap-2" :class="showAuthor(i) ? 'mt-2' : 'mt-0.5'">
          <div class="w-8 shrink-0">
            <Avatar v-if="showAuthor(i)" class="size-8">
              <AvatarFallback class="text-xs">{{ initialOf(m.author_id) }}</AvatarFallback>
            </Avatar>
          </div>
          <div class="min-w-0 flex-1">
            <div v-if="showAuthor(i)" class="flex items-baseline gap-2">
              <span class="text-sm font-medium">{{ nameOf(m.author_id) }}</span>
              <span class="text-[11px] text-muted-foreground">{{ timeLabel(m.created_at) }}</span>
            </div>
            <p class="whitespace-pre-wrap break-words text-sm">{{ m.body }}</p>
          </div>
        </div>
      </template>
    </div>

    <div class="border-t p-3">
      <div class="flex items-end gap-2">
        <Textarea
          v-model="body"
          rows="1"
          placeholder="Napisz wiadomość… (Enter wysyła, Shift+Enter nowa linia)"
          class="max-h-32 min-h-9 resize-none"
          @keydown.enter.exact.prevent="send"
        />
        <Button size="icon" :disabled="sending || !body.trim()" @click="send">
          <Send class="size-4" />
        </Button>
      </div>
    </div>
  </div>
</template>
