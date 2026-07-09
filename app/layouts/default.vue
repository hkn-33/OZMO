<script setup lang="ts">
import type { Component } from 'vue'
import {
  LayoutDashboard,
  ListChecks,
  MessagesSquare,
  CalendarDays,
  Package,
  FileText,
  Users,
  Building2,
  Wallet,
  Menu,
  LogOut,
  Check,
  Settings,
  Search,
} from '@lucide/vue'

type NavItem = {
  label: string
  to: string
  icon: Component
  primary?: boolean
}

const navItems: NavItem[] = [
  { label: 'Pulpit', to: '/', icon: LayoutDashboard, primary: true },
  { label: 'Zadania', to: '/tasks', icon: ListChecks, primary: true },
  { label: 'Czaty', to: '/chat', icon: MessagesSquare, primary: true },
  { label: 'Grafik', to: '/schedule', icon: CalendarDays, primary: true },
  { label: 'Magazyn', to: '/stock', icon: Package },
  { label: 'Raporty', to: '/reports', icon: FileText },
  { label: 'Oddziały', to: '/branches', icon: Building2 },
  { label: 'Zespół', to: '/people', icon: Users },
  { label: 'Koszty', to: '/costs', icon: Wallet },
]

const primaryItems = navItems.filter((i) => i.primary)

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const sheetOpen = ref(false)
const searchOpen = ref(false)

function onGlobalKeydown(e: KeyboardEvent) {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
    e.preventDefault()
    searchOpen.value = true
  }
}
onMounted(() => window.addEventListener('keydown', onGlobalKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onGlobalKeydown))

const { memberships, activeOrg, activeOrgId, setActive, load } = useOrg()
await load()

const { load: loadSubscription } = useSubscription()
await loadSubscription()
watch(activeOrgId, () => loadSubscription(true))

const userLabel = computed(() => user.value?.email ?? 'Konto')
const userInitial = computed(() => (user.value?.email?.[0] ?? '?').toUpperCase())

async function logout() {
  await supabase.auth.signOut()
  await navigateTo('/auth/login')
}
</script>

<template>
  <div class="min-h-svh bg-background">
    <!-- Desktop sidebar -->
    <aside
      class="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r border-sidebar-border bg-sidebar text-sidebar-foreground lg:flex"
    >
      <div class="flex h-16 items-center gap-2.5 px-5">
        <span
          class="grid size-8 shrink-0 place-items-center rounded-lg bg-primary font-heading text-base font-bold text-primary-foreground"
          aria-hidden="true"
        >O</span>
        <span class="flex min-w-0 flex-col leading-tight">
          <span class="font-heading text-lg font-bold tracking-tight text-foreground">OZMO</span>
          <span v-if="activeOrg" class="truncate text-xs text-muted-foreground">
            {{ activeOrg.name }}
          </span>
        </span>
      </div>
      <nav class="flex-1 space-y-0.5 px-3 py-2">
        <NuxtLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors hover:bg-sidebar-accent hover:text-sidebar-accent-foreground"
          active-class="bg-primary/10 text-primary font-semibold hover:bg-primary/10 hover:text-primary"
        >
          <component :is="item.icon" class="size-[18px]" />
          {{ item.label }}
        </NuxtLink>
      </nav>
      <Separator />
      <div class="p-3">
        <DropdownMenu>
          <DropdownMenuTrigger as-child>
            <button
              class="flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm hover:bg-accent"
            >
              <Avatar class="size-8">
                <AvatarFallback>{{ userInitial }}</AvatarFallback>
              </Avatar>
              <span class="truncate">{{ userLabel }}</span>
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" class="w-56">
            <DropdownMenuLabel class="truncate">{{ userLabel }}</DropdownMenuLabel>
            <template v-if="memberships.length > 1">
              <DropdownMenuSeparator />
              <DropdownMenuLabel class="text-xs text-muted-foreground">
                Organizacja
              </DropdownMenuLabel>
              <DropdownMenuItem
                v-for="m in memberships"
                :key="m.org_id"
                @select="setActive(m.org_id)"
              >
                <Check
                  class="mr-2 size-4"
                  :class="m.org_id === activeOrgId ? 'opacity-100' : 'opacity-0'"
                />
                <span class="truncate">{{ m.organizations.name }}</span>
              </DropdownMenuItem>
            </template>
            <DropdownMenuSeparator />
            <DropdownMenuItem @select="() => navigateTo('/settings')">
              <Settings class="mr-2 size-4" />
              Ustawienia
            </DropdownMenuItem>
            <DropdownMenuItem @select="logout">
              <LogOut class="mr-2 size-4" />
              Wyloguj się
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </aside>

    <!-- Main content -->
    <div class="lg:pl-60">
      <!-- Top bar (branch picker + notifications; mobile also shows logo + menu) -->
      <header
        class="sticky top-0 z-20 flex h-14 items-center justify-between gap-3 border-b bg-background/85 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/70"
      >
        <div class="flex items-center gap-2">
          <span class="font-heading text-lg font-bold tracking-tight lg:hidden">OZMO</span>
          <LayoutBranchPicker />
        </div>
        <div class="flex items-center gap-1">
          <button
            class="hidden items-center gap-2 rounded-md border bg-muted/40 px-2.5 py-1.5 text-sm text-muted-foreground transition-colors hover:bg-muted sm:flex"
            @click="searchOpen = true"
          >
            <Search class="size-4" />
            <span>Szukaj…</span>
            <kbd class="rounded border bg-background px-1.5 font-mono text-[10px]">⌘K</kbd>
          </button>
          <Button variant="ghost" size="icon" class="sm:hidden" @click="searchOpen = true">
            <Search class="size-5" />
          </Button>
          <LayoutNotificationBell />
          <Sheet v-model:open="sheetOpen">
            <SheetTrigger as-child>
              <Button variant="ghost" size="icon" class="lg:hidden">
                <Menu class="size-5" />
              </Button>
            </SheetTrigger>
          <SheetContent side="right" class="w-72">
            <SheetHeader>
              <SheetTitle>Menu</SheetTitle>
            </SheetHeader>
            <nav class="mt-2 space-y-1 px-2">
              <NuxtLink
                v-for="item in navItems"
                :key="item.to"
                :to="item.to"
                class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-foreground hover:bg-accent hover:text-accent-foreground"
                active-class="bg-primary/10 text-primary font-semibold"
                @click="sheetOpen = false"
              >
                <component :is="item.icon" class="size-4" />
                {{ item.label }}
              </NuxtLink>
            </nav>
            <Separator class="my-2" />
            <div class="space-y-1 px-2">
              <NuxtLink
                to="/settings"
                class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-foreground hover:bg-accent hover:text-accent-foreground"
                active-class="bg-primary/10 text-primary font-semibold"
                @click="sheetOpen = false"
              >
                <Settings class="size-4" />
                Ustawienia
              </NuxtLink>
              <button
                class="flex w-full items-center gap-3 rounded-md px-3 py-2 text-sm text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                @click="logout"
              >
                <LogOut class="size-4" />
                Wyloguj się
              </button>
            </div>
          </SheetContent>
          </Sheet>
        </div>
      </header>

      <main class="p-4 pb-24 lg:p-8 lg:pb-8">
        <slot />
      </main>
    </div>

    <!-- Mobile bottom navigation -->
    <nav
      class="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t border-sidebar-border bg-sidebar/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden"
    >
      <NuxtLink
        v-for="item in primaryItems"
        :key="item.to"
        :to="item.to"
        class="flex min-h-[3.25rem] flex-col items-center justify-center gap-1 py-2 text-[11px] font-medium text-muted-foreground transition-colors"
        active-class="text-primary"
      >
        <component :is="item.icon" class="size-[22px]" />
        {{ item.label }}
      </NuxtLink>
      <button
        class="flex min-h-[3.25rem] flex-col items-center justify-center gap-1 py-2 text-[11px] font-medium text-muted-foreground transition-colors"
        @click="sheetOpen = true"
      >
        <Menu class="size-[22px]" />
        Więcej
      </button>
    </nav>

    <GlobalSearch v-model:open="searchOpen" />
    <UpgradeModal />
  </div>
</template>
