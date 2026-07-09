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

const { memberships, activeOrg, activeOrgId, setActive, load } = useOrg()
await load()

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
      class="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r bg-card lg:flex"
    >
      <div class="flex h-16 flex-col justify-center px-6">
        <span class="text-xl font-bold tracking-tight">OZMO</span>
        <span v-if="activeOrg" class="truncate text-xs text-muted-foreground">
          {{ activeOrg.name }}
        </span>
      </div>
      <nav class="flex-1 space-y-1 px-3 py-2">
        <NuxtLink
          v-for="item in navItems"
          :key="item.to"
          :to="item.to"
          class="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
          active-class="bg-accent text-accent-foreground"
        >
          <component :is="item.icon" class="size-4" />
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
        class="flex h-14 items-center justify-between gap-3 border-b px-4"
      >
        <div class="flex items-center gap-2">
          <span class="text-lg font-bold tracking-tight lg:hidden">OZMO</span>
          <LayoutBranchPicker />
        </div>
        <div class="flex items-center gap-1">
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
                class="flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                active-class="bg-accent text-accent-foreground"
                @click="sheetOpen = false"
              >
                <component :is="item.icon" class="size-4" />
                {{ item.label }}
              </NuxtLink>
            </nav>
            <Separator class="my-2" />
            <div class="px-2">
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
      class="fixed inset-x-0 bottom-0 z-30 grid grid-cols-5 border-t bg-card lg:hidden"
    >
      <NuxtLink
        v-for="item in primaryItems"
        :key="item.to"
        :to="item.to"
        class="flex flex-col items-center gap-1 py-2 text-[11px] text-muted-foreground"
        active-class="text-primary"
      >
        <component :is="item.icon" class="size-5" />
        {{ item.label }}
      </NuxtLink>
      <button
        class="flex flex-col items-center gap-1 py-2 text-[11px] text-muted-foreground"
        @click="sheetOpen = true"
      >
        <Menu class="size-5" />
        Więcej
      </button>
    </nav>
  </div>
</template>
