<script setup lang="ts">
import { Search, ListChecks, Package, Users, MessagesSquare, Building2 } from '@lucide/vue'
import type { Component } from 'vue'
import type { Database } from '~~/shared/types/database.types'

const open = defineModel<boolean>('open', { default: false })

const supabase = useSupabaseClient<Database>()
const { activeOrgId } = useOrg()

type ResultType = 'task' | 'product' | 'person' | 'channel' | 'branch'
interface Result {
  type: ResultType
  id: string
  label: string
  sub?: string
}

const groups: { type: ResultType; label: string; icon: Component }[] = [
  { type: 'task', label: 'Zadania', icon: ListChecks },
  { type: 'product', label: 'Produkty', icon: Package },
  { type: 'person', label: 'Osoby', icon: Users },
  { type: 'channel', label: 'Kanały', icon: MessagesSquare },
  { type: 'branch', label: 'Oddziały', icon: Building2 },
]

const query = ref('')
const results = ref<Result[]>([])
const loading = ref(false)
const activeIndex = ref(0)
const inputEl = ref<{ $el?: HTMLElement } | HTMLElement | null>(null)
let timer: ReturnType<typeof setTimeout> | null = null

const grouped = computed(() =>
  groups
    .map((g) => ({ ...g, items: results.value.filter((r) => r.type === g.type) }))
    .filter((g) => g.items.length),
)
const flat = computed(() => grouped.value.flatMap((g) => g.items))

watch(query, () => {
  if (timer) clearTimeout(timer)
  const q = query.value.trim()
  if (q.length < 2) {
    results.value = []
    loading.value = false
    return
  }
  loading.value = true
  timer = setTimeout(() => runSearch(q), 250)
})

async function runSearch(q: string) {
  const org = activeOrgId.value
  if (!org) {
    loading.value = false
    return
  }
  const like = `%${q}%`
  const [tasks, products, people, channels, branches] = await Promise.all([
    supabase.from('tasks').select('id, title').eq('org_id', org).ilike('title', like).limit(5),
    supabase.from('products').select('id, name').eq('org_id', org).ilike('name', like).limit(5),
    supabase
      .from('profiles')
      .select('id, full_name, username')
      .or(`full_name.ilike.${like},username.ilike.${like}`)
      .limit(5),
    supabase.from('chat_channels').select('id, name').eq('org_id', org).ilike('name', like).limit(5),
    supabase.from('branches').select('id, name').eq('org_id', org).ilike('name', like).limit(5),
  ])
  const out: Result[] = []
  for (const t of tasks.data ?? []) out.push({ type: 'task', id: t.id, label: t.title })
  for (const p of products.data ?? []) out.push({ type: 'product', id: p.id, label: p.name })
  for (const p of people.data ?? [])
    out.push({
      type: 'person',
      id: p.id,
      label: p.full_name?.trim() || p.username || 'Użytkownik',
      sub: p.username ? `@${p.username}` : undefined,
    })
  for (const c of channels.data ?? []) out.push({ type: 'channel', id: c.id, label: c.name })
  for (const b of branches.data ?? []) out.push({ type: 'branch', id: b.id, label: b.name })
  results.value = out
  activeIndex.value = 0
  loading.value = false
}

function go(r: Result) {
  const routes: Record<ResultType, string> = {
    task: `/tasks?task=${r.id}`,
    product: '/stock',
    person: '/people',
    channel: '/chat',
    branch: '/branches',
  }
  open.value = false
  navigateTo(routes[r.type])
}

function onKeydown(e: KeyboardEvent) {
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    activeIndex.value = Math.min(activeIndex.value + 1, flat.value.length - 1)
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    activeIndex.value = Math.max(activeIndex.value - 1, 0)
  } else if (e.key === 'Enter') {
    e.preventDefault()
    const r = flat.value[activeIndex.value]
    if (r) go(r)
  }
}

watch(open, (v) => {
  if (v) {
    nextTick(() => {
      const el = inputEl.value
      const node = el instanceof HTMLElement ? el : el?.$el
      node?.querySelector?.('input')?.focus?.()
      ;(node as HTMLInputElement | undefined)?.focus?.()
    })
  } else {
    query.value = ''
    results.value = []
    activeIndex.value = 0
  }
})
</script>

<template>
  <Dialog v-model:open="open">
    <DialogContent class="gap-0 overflow-hidden p-0 sm:max-w-xl" @keydown="onKeydown">
      <DialogTitle class="sr-only">Wyszukiwarka</DialogTitle>
      <DialogDescription class="sr-only">
        Szukaj zadań, produktów, osób, kanałów i oddziałów.
      </DialogDescription>
      <div class="flex items-center gap-2 border-b px-4">
        <Search class="size-4 shrink-0 text-muted-foreground" />
        <input
          ref="inputEl"
          v-model="query"
          placeholder="Szukaj zadań, produktów, osób…"
          class="h-12 w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
        />
      </div>

      <div class="max-h-[60vh] overflow-y-auto p-2">
        <p v-if="query.trim().length < 2" class="px-3 py-6 text-center text-sm text-muted-foreground">
          Wpisz co najmniej 2 znaki.
        </p>
        <p v-else-if="loading" class="px-3 py-6 text-center text-sm text-muted-foreground">
          Szukanie…
        </p>
        <p v-else-if="!flat.length" class="px-3 py-6 text-center text-sm text-muted-foreground">
          Brak wyników.
        </p>

        <div v-for="g in grouped" v-else :key="g.type" class="mb-1">
          <p class="px-3 py-1.5 text-xs font-medium text-muted-foreground">{{ g.label }}</p>
          <button
            v-for="item in g.items"
            :key="item.id"
            class="flex w-full items-center gap-2.5 rounded-md px-3 py-2 text-left text-sm"
            :class="flat.indexOf(item) === activeIndex ? 'bg-accent' : 'hover:bg-accent'"
            @mouseenter="activeIndex = flat.indexOf(item)"
            @click="go(item)"
          >
            <component :is="g.icon" class="size-4 shrink-0 text-muted-foreground" />
            <span class="min-w-0 flex-1 truncate">{{ item.label }}</span>
            <span v-if="item.sub" class="shrink-0 text-xs text-muted-foreground">{{ item.sub }}</span>
          </button>
        </div>
      </div>
    </DialogContent>
  </Dialog>
</template>
