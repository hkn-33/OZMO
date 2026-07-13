<script setup lang="ts">
import { Send } from '@lucide/vue'
import type { RealtimeChannel } from '@supabase/supabase-js'
import type { Database } from '~~/shared/types/database.types'
import type { ChatChannel } from '~/composables/useChat'
import type { Attachment } from '~/composables/useAttachments'

const props = defineProps<{ channel: ChatChannel }>()
const emit = defineEmits<{ read: [channelId: string] }>()

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { block } = useDemoGuard()

interface Message {
  id: string
  author_id: string
  body: string
  created_at: string
  attachments: Attachment[]
}

const PAGE = 30
const messages = ref<Message[]>([])
const loading = ref(false)
const loadingOlder = ref(false)
const hasMore = ref(false)
const names = ref<Record<string, string>>({})
const scroller = ref<HTMLElement | null>(null)
const body = ref('')
const pendingAttachments = ref<Attachment[]>([])
const sending = ref(false)
let channel: RealtimeChannel | null = null

// Po twardym wejściu na stronę `user.value` to *claims* JWT (`.sub`, bez `.id`).
const myId = () =>
  user.value?.id ?? (user.value as { sub?: string } | null)?.sub

const {
  label: typingLabel,
  receive: onTyping,
  throttle,
  clear: clearTyping,
} = useTypingIndicator(myId)

const myName = computed(() => {
  const meta = (user.value as { user_metadata?: { full_name?: string } } | null)?.user_metadata
  return meta?.full_name?.trim() || 'Ktoś'
})

const notifyTyping = throttle(() => {
  channel?.send({
    type: 'broadcast',
    event: 'typing',
    payload: { id: myId(), name: myName.value },
  })
})

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
    .select('id, author_id, body, created_at, attachments')
    .eq('channel_id', props.channel.id)
    .order('created_at', { ascending: false })
    .limit(PAGE)
  const rows = ((data ?? []) as unknown as Message[]).reverse()
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
    .select('id, author_id, body, created_at, attachments')
    .eq('channel_id', props.channel.id)
    .lt('created_at', oldest)
    .order('created_at', { ascending: false })
    .limit(PAGE)
  const rows = ((data ?? []) as unknown as Message[]).reverse()
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
      messages.value.push({
        id: p.id,
        author_id: p.author_id,
        body: p.body,
        created_at: p.created_at,
        attachments: p.attachments ?? [],
      })
      scrollToBottom(true)
      if (p.author_id !== user.value?.id) markRead()
    })
    .on('broadcast', { event: 'typing' }, (msg) => {
      onTyping(msg.payload as { id: string; name: string })
    })
  channel.subscribe(async (status) => {
    // Dociągnij wiadomości, które wpadły między loadInitial a dołączeniem do kanału —
    // bez tego wiadomość wysłana w tym oknie czasu pojawia się dopiero po odświeżeniu.
    if (status !== 'SUBSCRIBED') return
    const latest = messages.value[messages.value.length - 1]?.created_at
    let q = supabase
      .from('chat_messages')
      .select('id, author_id, body, created_at, attachments')
      .eq('channel_id', props.channel.id)
      .order('created_at', { ascending: true })
      .limit(PAGE)
    if (latest) q = q.gt('created_at', latest)
    const { data } = await q
    const fresh = ((data ?? []) as unknown as Message[]).filter(
      (r) => !messages.value.some((m) => m.id === r.id),
    )
    if (fresh.length) {
      await resolveNames(fresh.map((m) => m.author_id))
      messages.value.push(...fresh)
      scrollToBottom(true)
      markRead()
    }
  })
}

function teardown() {
  if (channel) {
    supabase.removeChannel(channel)
    channel = null
  }
  clearTyping()
}

async function send() {
  const text = body.value.trim()
  if ((!text && !pendingAttachments.value.length) || sending.value || !user.value) return
  if (block()) return
  sending.value = true
  const { data, error } = await supabase
    .from('chat_messages')
    .insert({
      channel_id: props.channel.id,
      org_id: props.channel.org_id,
      branch_id: props.channel.branch_id,
      author_id: user.value.id,
      body: text,
      attachments: pendingAttachments.value,
    })
    .select('id, author_id, body, created_at, attachments')
    .single()
  sending.value = false
  if (error) return
  body.value = ''
  pendingAttachments.value = []
  if (data && !messages.value.some((m) => m.id === data.id)) {
    messages.value.push(data as unknown as Message)
    scrollToBottom(true)
  }
}

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
const GROUP_GAP_MS = 5 * 60_000
function showAuthor(i: number) {
  if (i === 0) return true
  const cur = messages.value[i]!
  const prev = messages.value[i - 1]!
  if (cur.author_id !== prev.author_id || showDaySeparator(i)) return true
  // Nowy nagłówek po przerwie dłuższej niż 5 minut.
  return new Date(cur.created_at).getTime() - new Date(prev.created_at).getTime() > GROUP_GAP_MS
}
function isMine(id: string) {
  return id === myId()
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

        <div
          class="group -mx-2 flex gap-2 rounded-md px-2 py-0.5 transition-colors hover:bg-muted/40"
          :class="[showAuthor(i) ? 'mt-2' : 'mt-px', isMine(m.author_id) ? 'bg-primary/[0.035]' : '']"
        >
          <div class="w-8 shrink-0">
            <Avatar v-if="showAuthor(i)" class="size-8">
              <AvatarFallback class="text-xs">{{ initialOf(m.author_id) }}</AvatarFallback>
            </Avatar>
            <span
              v-else
              class="mt-0.5 hidden text-right text-[10px] leading-4 text-muted-foreground/70 group-hover:block"
            >
              {{ timeLabel(m.created_at) }}
            </span>
          </div>
          <div class="min-w-0 flex-1">
            <div v-if="showAuthor(i)" class="flex items-baseline gap-2">
              <span class="text-sm font-medium">{{ isMine(m.author_id) ? 'Ty' : nameOf(m.author_id) }}</span>
              <span class="text-[11px] text-muted-foreground">{{ timeLabel(m.created_at) }}</span>
            </div>
            <p v-if="m.body" class="whitespace-pre-wrap break-words text-sm">{{ m.body }}</p>
            <AttachmentList :attachments="m.attachments" />
          </div>
        </div>
      </template>
    </div>

    <div class="border-t p-3">
      <p class="mb-1 h-4 text-xs text-muted-foreground" data-testid="typing-indicator">
        {{ typingLabel }}
      </p>
      <!-- NB: `channel` (top-level realtime var) shadows the prop in template
           scope, so bind the prop explicitly via `props.channel`. -->
      <AttachmentInput
        v-if="props.channel"
        v-model="pendingAttachments"
        :org-id="props.channel.org_id"
        :branch-id="props.channel.branch_id"
        context="chat"
        class="mb-1.5"
      />
      <div class="flex items-end gap-2">
        <Textarea
          v-model="body"
          rows="1"
          placeholder="Napisz wiadomość… (Enter wysyła, Shift+Enter nowa linia)"
          class="max-h-32 min-h-9 resize-none"
          @input="notifyTyping"
          @keydown.enter.exact.prevent="send"
        />
        <Button size="icon" :disabled="sending || (!body.trim() && !pendingAttachments.length)" @click="send">
          <Send class="size-4" />
        </Button>
      </div>
    </div>
  </div>
</template>
