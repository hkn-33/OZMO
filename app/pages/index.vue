<script setup lang="ts">
import {
  CalendarClock,
  ListChecks,
  PackageX,
  MessagesSquare,
  FileText,
  Network,
  ChevronRight,
} from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'
import { tzTime } from '~/lib/tz'
import { formatDateTime } from '~/lib/utils'

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

function todayStr() {
  const d = new Date()
  const off = d.getTimezoneOffset()
  return new Date(d.getTime() - off * 60000).toISOString().slice(0, 10)
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
    const today = todayStr()

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

// Najbliższa zmiana użytkownika.
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

// Nieprzeczytane czaty (klient, po hydratacji).
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
</script>

<template>
  <Landing v-if="!user" />
  <NuxtLayout v-else name="default">
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">{{ activeOrg?.name ?? 'OZMO' }}</h1>
        <p class="text-muted-foreground">
          Witaj{{ user?.email ? `, ${user.email}` : '' }}.
          <span v-if="role">Twoja rola: {{ roleLabels[role] }}.</span>
        </p>
      </div>

      <!-- Najbliższa zmiana -->
      <NuxtLink v-if="nextShiftLabel" to="/schedule" class="block">
        <Card class="transition-colors hover:bg-accent">
          <CardHeader class="pb-3">
            <CardTitle class="flex items-center gap-2 text-base">
              <CalendarClock class="size-4" /> Twoja najbliższa zmiana
            </CardTitle>
            <CardDescription class="text-foreground">
              {{ nextShiftLabel }}
              <template v-if="nextShift?.position"> · {{ nextShift.position }}</template>
              <template v-if="nextShift?.branches?.name"> · {{ nextShift.branches.name }}</template>
            </CardDescription>
          </CardHeader>
        </Card>
      </NuxtLink>

      <!-- Statystyki sieci (admin/właściciel) -->
      <div v-if="dash?.network" class="grid gap-4 sm:grid-cols-3">
        <Card>
          <CardHeader class="pb-2">
            <CardDescription class="flex items-center gap-1.5">
              <Network class="size-3.5" /> Oddziały
            </CardDescription>
            <CardTitle class="text-2xl tabular-nums">{{ dash.network.branches }}</CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader class="pb-2">
            <CardDescription class="flex items-center gap-1.5">
              <ListChecks class="size-3.5" /> Otwarte zadania (sieć)
            </CardDescription>
            <CardTitle class="text-2xl tabular-nums">{{ dash.network.openTasks }}</CardTitle>
          </CardHeader>
        </Card>
        <Card>
          <CardHeader class="pb-2">
            <CardDescription class="flex items-center gap-1.5">
              <FileText class="size-3.5" /> Zamknięte raporty dziś
            </CardDescription>
            <CardTitle class="text-2xl tabular-nums">
              {{ dash.network.closedReports }}<span class="text-base text-muted-foreground">/{{ dash.network.branches }}</span>
            </CardTitle>
          </CardHeader>
        </Card>
      </div>

      <div class="grid gap-4 lg:grid-cols-2">
        <!-- Moje zadania -->
        <Card>
          <CardHeader class="pb-3">
            <CardTitle class="flex items-center justify-between text-base">
              <span class="flex items-center gap-2"><ListChecks class="size-4" /> Moje zadania</span>
              <NuxtLink to="/tasks" class="text-xs font-normal text-muted-foreground hover:text-foreground">
                Wszystkie <ChevronRight class="inline size-3" />
              </NuxtLink>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p v-if="!dash?.myTasks.length" class="py-4 text-center text-sm text-muted-foreground">
              Brak przypisanych zadań. 🎉
            </p>
            <ul v-else class="space-y-1.5">
              <NuxtLink
                v-for="t in dash.myTasks"
                :key="t.id"
                :to="`/tasks?task=${t.id}`"
                class="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent"
              >
                <span class="min-w-0 flex-1 truncate text-sm">{{ t.title }}</span>
                <Badge :variant="(priorityVariant[t.priority] as any) ?? 'secondary'" class="shrink-0 text-[10px]">
                  {{ dueLabel(t.due_at) }}
                </Badge>
              </NuxtLink>
            </ul>
          </CardContent>
        </Card>

        <!-- Alerty magazynowe -->
        <Card>
          <CardHeader class="pb-3">
            <CardTitle class="flex items-center justify-between text-base">
              <span class="flex items-center gap-2"><PackageX class="size-4" /> Alerty magazynowe</span>
              <Badge v-if="dash?.alertCount" variant="danger" class="text-[10px]">{{ dash.alertCount }}</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p v-if="!dash?.alerts.length" class="py-4 text-center text-sm text-muted-foreground">
              Wszystkie stany powyżej minimum.
            </p>
            <ul v-else class="space-y-1.5">
              <NuxtLink
                v-for="(a, i) in dash.alerts"
                :key="i"
                to="/stock"
                class="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent"
              >
                <span class="min-w-0 flex-1 truncate text-sm">
                  {{ a.name }}
                  <span v-if="a.branch" class="text-muted-foreground">· {{ a.branch }}</span>
                </span>
                <Badge variant="warning" class="shrink-0 tabular-nums text-[10px]">
                  {{ a.qty }} / {{ a.min }}
                </Badge>
              </NuxtLink>
            </ul>
          </CardContent>
        </Card>

        <!-- Nieprzeczytane czaty -->
        <Card>
          <CardHeader class="pb-3">
            <CardTitle class="flex items-center justify-between text-base">
              <span class="flex items-center gap-2"><MessagesSquare class="size-4" /> Nieprzeczytane czaty</span>
              <Badge v-if="chat.totalUnread.value" variant="info" class="text-[10px]">{{ chat.totalUnread.value }}</Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p v-if="!unreadChannels.length" class="py-4 text-center text-sm text-muted-foreground">
              Brak nowych wiadomości.
            </p>
            <ul v-else class="space-y-1.5">
              <NuxtLink
                v-for="c in unreadChannels"
                :key="c.id"
                to="/chat"
                class="flex items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent"
              >
                <span class="min-w-0 flex-1 truncate text-sm">{{ c.name }}</span>
                <Badge variant="info" class="shrink-0 text-[10px]">{{ c.unread }}</Badge>
              </NuxtLink>
            </ul>
          </CardContent>
        </Card>

        <!-- Ostatnie notatki dnia -->
        <Card>
          <CardHeader class="pb-3">
            <CardTitle class="flex items-center justify-between text-base">
              <span class="flex items-center gap-2"><FileText class="size-4" /> Notatki dnia</span>
              <NuxtLink to="/reports" class="text-xs font-normal text-muted-foreground hover:text-foreground">
                Raporty <ChevronRight class="inline size-3" />
              </NuxtLink>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p v-if="!dash?.notes.length" class="py-4 text-center text-sm text-muted-foreground">
              Brak notatek na dziś.
            </p>
            <ul v-else class="space-y-2">
              <li v-for="n in dash.notes" :key="n.id" class="flex items-start gap-2">
                <Badge :variant="n.severity === 'issue' ? 'danger' : 'info'" class="shrink-0 text-[10px]">
                  {{ n.severity === 'issue' ? 'Problem' : 'Info' }}
                </Badge>
                <span class="min-w-0 flex-1 text-sm">
                  <span class="line-clamp-2">{{ n.body }}</span>
                  <span v-if="n.branch" class="text-xs text-muted-foreground">{{ n.branch }}</span>
                </span>
              </li>
            </ul>
          </CardContent>
        </Card>
      </div>
    </div>
  </NuxtLayout>
</template>
