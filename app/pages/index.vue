<script setup lang="ts">
import {
  CalendarClock,
  ListChecks,
  FileText,
  Network,
  ChevronRight,
  ArrowUpRight,
  Clock3,
  CircleAlert,
  CheckCircle2,
} from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { tzTime } from '~/lib/tz'
import { formatDateTime, localDateKey } from '~/lib/utils'

// `/` jest publiczne: niezalogowani widzą landing, zalogowani — pulpit.
definePageMeta({ layout: false })

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { activeOrgId, activeOrg, role, isAdmin, load } = useOrg()
await load()

// Po twardym wejściu na stronę `user.value` bywa *claims* JWT (`.sub`, bez `.id`).
const uid = computed(() => user.value?.id ?? (user.value as { sub?: string } | null)?.sub ?? null)

const roleLabels: Record<string, string> = {
  owner: 'Właściciel',
  admin: 'Administrator',
  member: 'Członek',
}

type MyTask = { id: string; title: string; status: string; due_at: string | null; priority: string }
type StockAlert = { name: string; branch: string; qty: number; min: number }
type DayNoteLite = { id: string; body: string; severity: string; branch: string }
type NetworkStats = { branches: number; openTasks: number; closedReports: number }

const priorityVariant: Record<string, string> = {
  low: 'outline',
  normal: 'secondary',
  high: 'warning',
  urgent: 'danger',
}

const { data: dash } = await useAsyncData(
  () => `dashboard:${activeOrgId.value}:${uid.value}`,
  async () => {
    const org = activeOrgId.value
    if (!org || !uid.value) return null
    const today = localDateKey()

    const [assignRes, settingsRes, levelsRes, branchesRes, notesRes] = await Promise.all([
      supabase
        .from('task_assignees')
        .select('tasks!inner(id, title, status, due_at, priority, org_id)')
        .eq('user_id', uid.value)
        .eq('tasks.org_id', org)
        .neq('tasks.status', 'done')
        .limit(25),
      supabase
        .from('branch_product_settings')
        .select('branch_id, product_id, min_stock, products(name)')
        .eq('org_id', org)
        .gt('min_stock', 0),
      supabase.from('stock_levels').select('branch_id, product_id, qty').eq('org_id', org),
      supabase.from('branches').select('id, name').eq('org_id', org),
      supabase
        .from('day_notes')
        .select('id, body, severity, branch_id')
        .eq('org_id', org)
        .eq('date', today)
        .order('created_at', { ascending: false })
        .limit(5),
    ])

    const branchName = new Map((branchesRes.data ?? []).map((b) => [b.id, b.name]))

    // My open tasks — sort due soonest first, nulls last.
    const myTasks: MyTask[] = ((assignRes.data ?? []) as unknown as { tasks: MyTask }[])
      .map((r) => r.tasks)
      .filter(Boolean)
      .sort((a, b) => {
        if (!a.due_at && !b.due_at) return 0
        if (!a.due_at) return 1
        if (!b.due_at) return -1
        return a.due_at.localeCompare(b.due_at)
      })
      .slice(0, 5)

    // Stock alerts — level below minimum.
    const levelMap = new Map(
      (levelsRes.data ?? []).map((l) => [`${l.branch_id}:${l.product_id}`, Number(l.qty)]),
    )
    const alerts: StockAlert[] = []
    for (const s of settingsRes.data ?? []) {
      const qty = levelMap.get(`${s.branch_id}:${s.product_id}`) ?? 0
      const min = Number(s.min_stock)
      if (qty < min) {
        alerts.push({
          name: (s.products as { name?: string } | null)?.name ?? 'Produkt',
          branch: branchName.get(s.branch_id) ?? '',
          qty,
          min,
        })
      }
    }
    alerts.sort((a, b) => b.min - b.qty - (a.min - a.qty))

    const notes: DayNoteLite[] = (notesRes.data ?? []).map((n) => ({
      id: n.id,
      body: n.body,
      severity: n.severity,
      branch: branchName.get(n.branch_id) ?? '',
    }))

    // Network stats for admins/owners.
    let network: NetworkStats | null = null
    if (isAdmin.value) {
      const [openTasksRes, closedRepRes] = await Promise.all([
        supabase
          .from('tasks')
          .select('id', { count: 'exact', head: true })
          .eq('org_id', org)
          .neq('status', 'done'),
        supabase
          .from('manager_reports')
          .select('branch_id', { count: 'exact', head: true })
          .eq('org_id', org)
          .eq('date', today)
          .eq('status', 'closed'),
      ])
      network = {
        branches: branchesRes.data?.length ?? 0,
        openTasks: openTasksRes.count ?? 0,
        closedReports: closedRepRes.count ?? 0,
      }
    }

    return {
      myTasks,
      alerts: alerts.slice(0, 5),
      alertCount: alerts.length,
      notes,
      network,
      branchCount: branchesRes.data?.length ?? 0,
    }
  },
  { watch: [activeOrgId, user] },
)

type NextShift = {
  id: string
  starts_at: string
  ends_at: string
  position: string | null
  branches: { name: string; timezone: string } | null
}
const { data: nextShift } = await useAsyncData(
  () => `next-shift:${uid.value}`,
  async () => {
    if (!uid.value) return null
    const { data } = await supabase
      .from('shifts')
      .select('id, starts_at, ends_at, position, branches(name, timezone)')
      .eq('user_id', uid.value)
      .eq('published', true)
      .gte('starts_at', new Date().toISOString())
      .order('starts_at', { ascending: true })
      .limit(1)
      .maybeSingle()
    return (data ?? null) as unknown as NextShift | null
  },
  { watch: [user] },
)
const nextShiftLabel = computed(() => {
  const s = nextShift.value
  if (!s) return null
  const tz = s.branches?.timezone ?? 'Europe/Warsaw'
  const day = new Intl.DateTimeFormat('pl-PL', {
    weekday: 'long', day: 'numeric', month: 'long', timeZone: tz,
  }).format(new Date(s.starts_at))
  return `${day}, ${tzTime(s.starts_at, tz)}–${tzTime(s.ends_at, tz)}`
})

const chat = useChat()
const unreadChannels = computed(() =>
  chat.channels.value
    .map((c) => ({ ...c, unread: chat.unreadMap.value[c.id] ?? 0 }))
    .filter((c) => c.unread > 0)
    .sort((a, b) => b.unread - a.unread)
    .slice(0, 5),
)
onMounted(() => {
  if (uid.value) chat.loadChannels(true)
})
watch(user, () => {
  if (uid.value) chat.loadChannels(true)
})

const dueLabel = (iso: string | null) => (iso ? formatDateTime(iso) : 'bez terminu')
const todayLabel = new Intl.DateTimeFormat('pl-PL', {
  weekday: 'long', day: 'numeric', month: 'long',
}).format(new Date())
</script>

<template>
  <Landing v-if="!user" />
  <NuxtLayout v-else name="default">
    <div class="mx-auto max-w-[92rem] space-y-6">
      <header class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div class="min-w-0">
          <p class="mb-1 text-sm text-muted-foreground">Dzień dobry · {{ todayLabel }}</p>
          <h1 class="min-w-0 [overflow-wrap:anywhere] text-2xl font-bold tracking-tight sm:text-3xl">
            {{ activeOrg?.name ?? 'OZMO' }}
          </h1>
          <p v-if="role" class="mt-1 text-sm text-muted-foreground">{{ roleLabels[role] }} · wszystko ważne na jednej stronie</p>
        </div>
        <NuxtLink
          to="/tasks"
          class="inline-flex min-h-11 shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-lg bg-[var(--color-panel-ink)] px-4 text-sm font-semibold text-[var(--color-on-ink)] transition-transform duration-150 active:translate-y-px"
        >
          Otwórz zadania <ArrowUpRight class="size-4" />
        </NuxtLink>
      </header>

      <section class="grid grid-cols-2 gap-3 md:grid-cols-6 xl:grid-cols-12" aria-label="Stan dnia">
        <div class="col-span-2 rounded-[var(--radius-card)] bg-[var(--color-panel-pink)] p-5 text-[var(--color-panel-ink)] md:col-span-3 xl:col-span-5">
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-sm font-semibold">Otwarte zadania (sieć)</p>
              <p class="mt-5 text-4xl font-bold tabular-nums">{{ dash?.network?.openTasks ?? dash?.myTasks.length ?? 0 }}</p>
            </div>
            <ListChecks class="size-5" />
          </div>
          <div class="mt-7 flex flex-wrap gap-x-6 gap-y-2 border-t border-[var(--color-panel-rule)] pt-3 text-sm">
            <span v-if="dash?.network"><strong class="tabular-nums">{{ dash.network.closedReports }}/{{ dash.network.branches }}</strong> raportów zamkniętych</span>
            <span><strong class="tabular-nums">{{ dash?.alertCount ?? 0 }}</strong> alertów magazynowych</span>
          </div>
        </div>

        <NuxtLink
          to="/schedule"
          class="rounded-[var(--radius-card)] bg-[var(--color-panel-yellow)] p-4 text-[var(--color-panel-ink)] transition-transform duration-150 active:translate-y-px md:col-span-3 md:p-5 xl:col-span-4"
        >
          <div class="flex items-start justify-between gap-4">
            <p class="text-sm font-semibold">Najbliższa zmiana</p>
            <CalendarClock class="size-5" />
          </div>
          <p class="mt-5 text-base font-semibold leading-snug sm:text-lg">{{ nextShiftLabel ?? 'Brak zaplanowanej zmiany' }}</p>
          <p v-if="nextShift?.position || nextShift?.branches?.name" class="mt-2 text-sm opacity-70">
            {{ [nextShift?.position, nextShift?.branches?.name].filter(Boolean).join(' · ') }}
          </p>
        </NuxtLink>

        <NuxtLink
          to="/branches"
          class="flex min-h-36 flex-col justify-between rounded-[var(--radius-card)] bg-[var(--color-panel-blue)] p-4 text-[var(--color-panel-ink)] transition-transform duration-150 active:translate-y-px md:col-span-2 md:p-5 xl:col-span-3"
        >
          <div class="flex items-start justify-between gap-4">
            <p class="text-sm font-semibold">Oddziały</p>
            <Network class="size-5" />
          </div>
          <p class="text-4xl font-bold tabular-nums">{{ dash?.network?.branches ?? dash?.branchCount ?? 0 }}</p>
        </NuxtLink>
      </section>

      <div class="grid min-w-0 gap-6 xl:grid-cols-[minmax(0,1.65fr)_minmax(19rem,0.75fr)]">
        <section class="min-w-0 overflow-hidden rounded-[var(--radius-card)] border bg-card" aria-labelledby="tasks-heading">
          <div class="flex items-center justify-between gap-4 border-b px-4 py-4 sm:px-6">
            <div>
              <h2 id="tasks-heading" class="text-lg font-semibold">Moje zadania</h2>
              <p class="text-sm text-muted-foreground">Najbliższe terminy i priorytety</p>
            </div>
            <NuxtLink to="/tasks" class="flex min-h-11 items-center gap-1 whitespace-nowrap text-sm font-medium text-muted-foreground hover:text-foreground">
              Wszystkie <ChevronRight class="size-4" />
            </NuxtLink>
          </div>

          <div v-if="!dash?.myTasks.length" class="grid min-h-72 place-items-center px-6 text-center">
            <div>
              <CheckCircle2 class="mx-auto mb-3 size-7 text-success" />
              <p class="font-medium">Nie masz przypisanych zadań</p>
              <p class="mt-1 text-sm text-muted-foreground">Nowe zadania pojawią się tutaj.</p>
            </div>
          </div>
          <ul v-else class="divide-y">
            <li v-for="t in dash.myTasks" :key="t.id">
              <NuxtLink
                :to="`/tasks?task=${t.id}`"
                class="group grid min-h-16 grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 px-4 py-3 transition-colors duration-150 hover:bg-muted/70 sm:px-6"
              >
                <span class="grid size-8 place-items-center rounded-full border bg-background text-muted-foreground group-hover:text-foreground">
                  <Clock3 class="size-4" />
                </span>
                <span class="min-w-0">
                  <span class="block truncate text-sm font-medium">{{ t.title }}</span>
                  <span class="mt-0.5 block text-xs text-muted-foreground">{{ t.status === 'in_progress' ? 'W trakcie' : 'Do zrobienia' }}</span>
                </span>
                <Badge :variant="(priorityVariant[t.priority] as any) ?? 'secondary'" class="shrink-0 whitespace-nowrap text-[10px]">
                  {{ dueLabel(t.due_at) }}
                </Badge>
              </NuxtLink>
            </li>
          </ul>
        </section>

        <aside class="min-w-0" aria-labelledby="today-heading">
          <div class="flex items-end justify-between gap-3 border-b pb-4">
            <div>
              <h2 id="today-heading" class="text-lg font-semibold">Dzisiaj</h2>
              <p class="text-sm capitalize text-muted-foreground">{{ todayLabel }}</p>
            </div>
            <span class="rounded-full bg-[var(--color-panel-ink)] px-3 py-1 text-xs font-medium text-[var(--color-on-ink)]">Na żywo</span>
          </div>

          <div class="relative ml-2 space-y-7 border-l py-6 pl-6">
            <section>
              <div class="absolute -left-[7px] mt-1 size-3 rounded-full border-2 border-background bg-[var(--color-accent)]" />
              <div class="flex items-center justify-between gap-3">
                <h3 class="text-sm font-semibold">Alerty magazynowe</h3>
                <Badge v-if="dash?.alertCount" variant="danger">{{ dash.alertCount }}</Badge>
              </div>
              <p v-if="!dash?.alerts.length" class="mt-2 text-sm text-muted-foreground">Stany są powyżej minimum.</p>
              <ul v-else class="mt-3 space-y-2">
                <li v-for="(a, i) in dash.alerts.slice(0, 3)" :key="i">
                  <NuxtLink to="/stock" class="flex min-h-11 items-center justify-between gap-3 rounded-lg bg-[var(--color-panel-green)] px-3 py-2 text-sm text-[var(--color-panel-ink)]">
                    <span class="min-w-0 truncate">{{ a.name }}<span v-if="a.branch" class="opacity-65"> · {{ a.branch }}</span></span>
                    <strong class="shrink-0 tabular-nums">{{ a.qty }} / {{ a.min }}</strong>
                  </NuxtLink>
                </li>
              </ul>
            </section>

            <section>
              <div class="absolute -left-[7px] mt-1 size-3 rounded-full border-2 border-background bg-info" />
              <div class="flex items-center justify-between gap-3">
                <h3 class="text-sm font-semibold">Nieprzeczytane czaty</h3>
                <Badge v-if="chat.totalUnread.value" variant="info">{{ chat.totalUnread.value }}</Badge>
              </div>
              <p v-if="!unreadChannels.length" class="mt-2 text-sm text-muted-foreground">Brak nowych wiadomości.</p>
              <ul v-else class="mt-2 space-y-1">
                <li v-for="c in unreadChannels.slice(0, 3)" :key="c.id">
                  <NuxtLink to="/chat" class="flex min-h-11 items-center justify-between gap-3 text-sm hover:underline">
                    <span class="truncate">{{ c.name }}</span><span class="tabular-nums text-muted-foreground">{{ c.unread }}</span>
                  </NuxtLink>
                </li>
              </ul>
            </section>

            <section>
              <div class="absolute -left-[7px] mt-1 size-3 rounded-full border-2 border-background bg-warning" />
              <div class="flex items-center justify-between gap-3">
                <h3 class="text-sm font-semibold">Notatki dnia</h3>
                <NuxtLink to="/reports" class="min-h-11 whitespace-nowrap text-sm text-muted-foreground hover:text-foreground">Raporty</NuxtLink>
              </div>
              <p v-if="!dash?.notes.length" class="mt-2 text-sm text-muted-foreground">Brak notatek na dziś.</p>
              <ul v-else class="mt-2 space-y-3">
                <li v-for="n in dash.notes.slice(0, 3)" :key="n.id" class="text-sm">
                  <div class="flex items-start gap-2">
                    <CircleAlert v-if="n.severity === 'issue'" class="mt-0.5 size-4 shrink-0 text-destructive" />
                    <FileText v-else class="mt-0.5 size-4 shrink-0 text-info" />
                    <span class="min-w-0">
                      <span class="line-clamp-2">{{ n.body }}</span>
                      <span v-if="n.branch" class="mt-0.5 block text-xs text-muted-foreground">{{ n.branch }}</span>
                    </span>
                  </div>
                </li>
              </ul>
            </section>
          </div>
        </aside>
      </div>
    </div>
  </NuxtLayout>
</template>
