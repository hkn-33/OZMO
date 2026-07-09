<script setup lang="ts">
import { toast } from 'vue-sonner'
import { UserPlus, Copy, X } from '@lucide/vue'
import type { Database } from '~~/shared/types/database.types'

type OrgRole = Database['public']['Enums']['org_role']
type BranchRole = Database['public']['Enums']['branch_role']

const supabase = useSupabaseClient<Database>()
const user = useSupabaseUser()
const { activeOrgId, activeOrg, isAdmin, isOwner, load } = useOrg()
const { guard, isDemo, upgradeOpen } = useDemoGuard()
function blockDemo() {
  if (isDemo.value) {
    upgradeOpen.value = true
    return true
  }
  return false
}
await load()

const orgRoleLabels: Record<OrgRole, string> = {
  owner: 'Właściciel',
  admin: 'Administrator',
  member: 'Członek',
}
const branchRoleLabels: Record<BranchRole, string> = {
  manager: 'Menadżer',
  employee: 'Pracownik',
}

type Member = {
  user_id: string
  role: OrgRole
  profiles: { full_name: string | null; avatar_url: string | null; username: string | null } | null
}
type BranchAssignment = {
  branch_id: string
  user_id: string
  role: BranchRole
  position: string | null
  branches: { id: string; name: string; org_id: string } | null
}
type Branch = { id: string; name: string }
type Invitation = {
  id: string
  token: string
  email: string
  org_role: OrgRole
  branch_id: string | null
  expires_at: string
}

const { data, refresh, pending } = await useAsyncData(
  () => `people:${activeOrgId.value}`,
  async () => {
    if (!activeOrgId.value) {
      return { members: [], assignments: [], branches: [], invitations: [] }
    }
    const org = activeOrgId.value
    const [members, assignments, branches, invitations] = await Promise.all([
      supabase
        .from('org_members')
        .select('user_id, role, profiles(full_name, avatar_url, username)')
        .eq('org_id', org),
      supabase
        .from('branch_members')
        .select('branch_id, user_id, role, position, branches!inner(id, name, org_id)')
        .eq('branches.org_id', org),
      supabase.from('branches').select('id, name').eq('org_id', org).eq('active', true).order('name'),
      supabase
        .from('invitations')
        .select('id, token, email, org_role, branch_id, expires_at')
        .eq('org_id', org)
        .is('accepted_at', null)
        .order('created_at', { ascending: false }),
    ])
    return {
      members: (members.data ?? []) as Member[],
      assignments: (assignments.data ?? []) as unknown as BranchAssignment[],
      branches: (branches.data ?? []) as Branch[],
      invitations: (invitations.data ?? []) as Invitation[],
    }
  },
  { watch: [activeOrgId] },
)

function memberName(m: Member) {
  return m.profiles?.full_name?.trim() || 'Bez nazwy'
}
function assignmentsFor(userId: string) {
  return data.value?.assignments.filter((a) => a.user_id === userId) ?? []
}

// --- dodawanie pracownika (username, bez e-maila) ---
const addOpen = ref(false)
const addForm = reactive({
  username: '',
  fullName: '',
  orgRole: 'member' as OrgRole,
  branchId: '',
  branchRole: 'employee' as BranchRole,
})
const addResult = ref<{ username: string; password: string } | null>(null)
const adding = ref(false)

function openAdd() {
  addForm.username = ''
  addForm.fullName = ''
  addForm.orgRole = 'member'
  addForm.branchId = ''
  addForm.branchRole = 'employee'
  addResult.value = null
  addOpen.value = true
}

async function saveMember() {
  if (!/^[a-z0-9_.-]{3,30}$/.test(addForm.username.trim().toLowerCase())) {
    toast.error('Nazwa użytkownika: 3–30 znaków, a-z 0-9 _ . -')
    return
  }
  if (!addForm.fullName.trim()) {
    toast.error('Podaj imię i nazwisko')
    return
  }
  adding.value = true
  try {
    const res = await $fetch<{ username: string; password: string }>('/api/members', {
      method: 'POST',
      body: {
        orgId: activeOrgId.value,
        username: addForm.username.trim().toLowerCase(),
        fullName: addForm.fullName.trim(),
        orgRole: addForm.orgRole,
        branchId: addForm.branchId || null,
        branchRole: addForm.branchId ? addForm.branchRole : null,
      },
    })
    addResult.value = res
    toast.success('Pracownik dodany')
    await refresh()
  } catch (e: any) {
    toast.error('Nie udało się dodać pracownika', { description: e?.data?.message ?? e?.message })
  } finally {
    adding.value = false
  }
}

async function copyText(text: string) {
  await navigator.clipboard.writeText(text)
  toast.success('Skopiowano')
}

// --- zmiana roli w organizacji ---
async function changeOrgRole(m: Member, role: OrgRole) {
  if (role === m.role) return
  if (blockDemo()) { await refresh(); return }
  const { error } = await supabase
    .from('org_members')
    .update({ role })
    .eq('org_id', activeOrgId.value!)
    .eq('user_id', m.user_id)
  if (error) {
    toast.error('Nie udało się zmienić roli', { description: error.message })
    await refresh()
    return
  }
  toast.success('Rola zaktualizowana')
  await refresh()
}

async function removeFromOrg(m: Member) {
  if (blockDemo()) return
  const { error } = await supabase
    .from('org_members')
    .delete()
    .eq('org_id', activeOrgId.value!)
    .eq('user_id', m.user_id)
  if (error) {
    toast.error('Nie udało się usunąć z organizacji', { description: error.message })
    return
  }
  toast.success('Usunięto z organizacji')
  await refresh()
}

async function removeFromBranch(a: BranchAssignment) {
  if (blockDemo()) return
  const { error } = await supabase
    .from('branch_members')
    .delete()
    .eq('branch_id', a.branch_id)
    .eq('user_id', a.user_id)
  if (error) {
    toast.error('Nie udało się odpiąć od oddziału', { description: error.message })
    return
  }
  await refresh()
}

// --- przypisanie do oddziału ---
const assignOpen = ref(false)
const assignTarget = ref<Member | null>(null)
const assignForm = reactive({ branchId: '', role: 'employee' as BranchRole, position: '' })

function openAssign(m: Member) {
  assignTarget.value = m
  assignForm.branchId = ''
  assignForm.role = 'employee'
  assignForm.position = ''
  assignOpen.value = true
}

async function saveAssign() {
  if (!assignForm.branchId || !assignTarget.value) return
  if (blockDemo()) { assignOpen.value = false; return }
  const { error } = await supabase.from('branch_members').upsert(
    {
      branch_id: assignForm.branchId,
      user_id: assignTarget.value.user_id,
      role: assignForm.role,
      position: assignForm.position.trim() || null,
    },
    { onConflict: 'branch_id,user_id' },
  )
  if (error) {
    toast.error('Nie udało się przypisać', { description: error.message })
    return
  }
  assignOpen.value = false
  toast.success('Przypisano do oddziału')
  await refresh()
}

// --- zaproszenia ---
const inviteOpen = ref(false)
const inviteForm = reactive({
  email: '',
  orgRole: 'member' as OrgRole,
  branchId: '',
  branchRole: 'employee' as BranchRole,
})
const inviteLink = ref('')
const inviting = ref(false)

function openInvite() {
  inviteForm.email = ''
  inviteForm.orgRole = 'member'
  inviteForm.branchId = ''
  inviteForm.branchRole = 'employee'
  inviteLink.value = ''
  inviteOpen.value = true
}

async function sendInvite() {
  if (!inviteForm.email.trim()) return
  inviting.value = true
  try {
    const res = await $fetch<{ link: string }>('/api/invitations', {
      method: 'POST',
      body: {
        orgId: activeOrgId.value,
        email: inviteForm.email.trim(),
        orgRole: inviteForm.orgRole,
        branchId: inviteForm.branchId || null,
        branchRole: inviteForm.branchId ? inviteForm.branchRole : null,
      },
    })
    inviteLink.value = res.link
    toast.success('Zaproszenie utworzone')
    await refresh()
  } catch (e: any) {
    toast.error('Nie udało się utworzyć zaproszenia', {
      description: e?.data?.message ?? e?.message,
    })
  } finally {
    inviting.value = false
  }
}

async function copyLink(link: string) {
  await navigator.clipboard.writeText(link)
  toast.success('Skopiowano link')
}

async function revokeInvite(inv: Invitation) {
  const { error } = await supabase.from('invitations').delete().eq('id', inv.id)
  if (error) {
    toast.error('Nie udało się anulować', { description: error.message })
    return
  }
  await refresh()
}

function inviteLinkFor(inv: Invitation) {
  return `${window.location.origin}/auth/invite/${inv.token}`
}

const branchName = (id: string) =>
  data.value?.branches.find((b) => b.id === id)?.name ?? '—'
</script>

<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold tracking-tight">Zespół</h1>
        <p class="text-muted-foreground">{{ activeOrg?.name ?? '' }}</p>
      </div>
      <Button v-if="isAdmin" @click="guard(openAdd)">
        <UserPlus class="mr-2 size-4" />
        Dodaj pracownika
      </Button>
    </div>

    <p v-if="pending" class="text-sm text-muted-foreground">Ładowanie…</p>

    <Tabs v-else default-value="members">
      <TabsList>
        <TabsTrigger value="members">Członkowie</TabsTrigger>
        <TabsTrigger v-if="isAdmin" value="invitations">
          Zaproszenia ({{ data?.invitations.length ?? 0 }})
        </TabsTrigger>
      </TabsList>

      <!-- Członkowie -->
      <TabsContent value="members" class="space-y-3">
        <Card v-for="m in data?.members" :key="m.user_id">
          <CardContent class="flex flex-col gap-3 p-4 sm:flex-row sm:items-start sm:justify-between">
            <div class="flex items-start gap-3">
              <Avatar class="size-10">
                <AvatarFallback>
                  {{ (memberName(m)[0] ?? '?').toUpperCase() }}
                </AvatarFallback>
              </Avatar>
              <div class="space-y-1">
                <div class="flex items-center gap-2">
                  <span class="font-medium">{{ memberName(m) }}</span>
                  <Badge v-if="m.user_id === user?.id" variant="outline">Ty</Badge>
                </div>
                <p v-if="m.profiles?.username" class="text-xs text-muted-foreground">
                  @{{ m.profiles.username }}
                </p>
                <div class="flex flex-wrap gap-1">
                  <Badge
                    v-for="a in assignmentsFor(m.user_id)"
                    :key="a.branch_id"
                    variant="secondary"
                    class="gap-1"
                  >
                    {{ a.branches?.name }} · {{ branchRoleLabels[a.role] }}
                    <button
                      v-if="isAdmin"
                      class="ml-1 opacity-60 hover:opacity-100"
                      @click="removeFromBranch(a)"
                    >
                      <X class="size-3" />
                    </button>
                  </Badge>
                </div>
              </div>
            </div>

            <div class="flex flex-wrap items-center gap-2">
              <template v-if="isAdmin">
                <Select
                  :model-value="m.role"
                  @update:model-value="(v) => changeOrgRole(m, v as OrgRole)"
                >
                  <SelectTrigger class="w-40">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem v-if="isOwner || m.role === 'owner'" value="owner">
                      {{ orgRoleLabels.owner }}
                    </SelectItem>
                    <SelectItem value="admin">{{ orgRoleLabels.admin }}</SelectItem>
                    <SelectItem value="member">{{ orgRoleLabels.member }}</SelectItem>
                  </SelectContent>
                </Select>
                <Button
                  v-if="data?.branches.length"
                  variant="outline"
                  size="sm"
                  @click="openAssign(m)"
                >
                  Do oddziału
                </Button>
                <Button
                  v-if="m.role !== 'owner'"
                  variant="ghost"
                  size="sm"
                  @click="removeFromOrg(m)"
                >
                  Usuń
                </Button>
              </template>
              <Badge v-else>{{ orgRoleLabels[m.role] }}</Badge>
            </div>
          </CardContent>
        </Card>
      </TabsContent>

      <!-- Zaproszenia -->
      <TabsContent v-if="isAdmin" value="invitations" class="space-y-3">
        <div class="flex justify-end">
          <Button variant="outline" size="sm" @click="guard(openInvite)">
            <UserPlus class="mr-2 size-4" /> Zaproś e-mailem
          </Button>
        </div>
        <p
          v-if="!data?.invitations.length"
          class="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground"
        >
          Brak oczekujących zaproszeń.
        </p>
        <Card v-for="inv in data?.invitations" :key="inv.id">
          <CardContent class="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
            <div class="space-y-1">
              <p class="font-medium">{{ inv.email }}</p>
              <div class="flex flex-wrap gap-1 text-xs text-muted-foreground">
                <Badge variant="secondary">{{ orgRoleLabels[inv.org_role] }}</Badge>
                <Badge v-if="inv.branch_id" variant="secondary">
                  {{ branchName(inv.branch_id) }}
                </Badge>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <Button variant="outline" size="sm" @click="copyLink(inviteLinkFor(inv))">
                <Copy class="mr-2 size-4" /> Kopiuj link
              </Button>
              <Button variant="ghost" size="sm" @click="revokeInvite(inv)">Anuluj</Button>
            </div>
          </CardContent>
        </Card>
      </TabsContent>
    </Tabs>

    <!-- Dialog: dodanie pracownika (username, hasło tymczasowe) -->
    <Dialog v-model:open="addOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Dodaj pracownika</DialogTitle>
          <DialogDescription>
            Utwórz konto z nazwą użytkownika i hasłem tymczasowym (bez e-maila).
          </DialogDescription>
        </DialogHeader>

        <div v-if="addResult" class="space-y-3">
          <p class="text-sm text-muted-foreground">
            Przekaż dane pracownikowi. Hasło pokazywane jest tylko teraz.
          </p>
          <div class="space-y-1">
            <Label>Nazwa użytkownika</Label>
            <div class="flex gap-2">
              <Input :model-value="addResult.username" readonly />
              <Button variant="outline" size="icon" @click="copyText(addResult.username)">
                <Copy class="size-4" />
              </Button>
            </div>
          </div>
          <div class="space-y-1">
            <Label>Hasło tymczasowe</Label>
            <div class="flex gap-2">
              <Input :model-value="addResult.password" readonly />
              <Button variant="outline" size="icon" @click="copyText(addResult.password)">
                <Copy class="size-4" />
              </Button>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" @click="addOpen = false">Zamknij</Button>
          </DialogFooter>
        </div>

        <form v-else class="space-y-4" @submit.prevent="saveMember">
          <div class="space-y-2">
            <Label for="m-username">Nazwa użytkownika</Label>
            <Input id="m-username" v-model="addForm.username" placeholder="jan.kowalski" required />
            <p class="text-xs text-muted-foreground">3–30 znaków: a-z, 0-9, _ . -</p>
          </div>
          <div class="space-y-2">
            <Label for="m-name">Imię i nazwisko</Label>
            <Input id="m-name" v-model="addForm.fullName" placeholder="Jan Kowalski" required />
          </div>
          <div class="space-y-2">
            <Label>Rola w organizacji</Label>
            <Select v-model="addForm.orgRole">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-if="isOwner" value="owner">{{ orgRoleLabels.owner }}</SelectItem>
                <SelectItem value="admin">{{ orgRoleLabels.admin }}</SelectItem>
                <SelectItem value="member">{{ orgRoleLabels.member }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-2">
            <Label>Oddział (opcjonalnie)</Label>
            <Select v-model="addForm.branchId">
              <SelectTrigger><SelectValue placeholder="Bez przypisania" /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="b in data?.branches" :key="b.id" :value="b.id">
                  {{ b.name }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div v-if="addForm.branchId" class="space-y-2">
            <Label>Rola w oddziale</Label>
            <Select v-model="addForm.branchRole">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="manager">{{ branchRoleLabels.manager }}</SelectItem>
                <SelectItem value="employee">{{ branchRoleLabels.employee }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <DialogFooter>
            <Button type="submit" :disabled="adding">
              {{ adding ? 'Dodawanie…' : 'Dodaj pracownika' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>

    <!-- Dialog: przypisanie do oddziału -->
    <Dialog v-model:open="assignOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Przypisz do oddziału</DialogTitle>
          <DialogDescription>{{ assignTarget && memberName(assignTarget) }}</DialogDescription>
        </DialogHeader>
        <form class="space-y-4" @submit.prevent="saveAssign">
          <div class="space-y-2">
            <Label>Oddział</Label>
            <Select v-model="assignForm.branchId">
              <SelectTrigger><SelectValue placeholder="Wybierz oddział" /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="b in data?.branches" :key="b.id" :value="b.id">
                  {{ b.name }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-2">
            <Label>Rola w oddziale</Label>
            <Select v-model="assignForm.role">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="manager">{{ branchRoleLabels.manager }}</SelectItem>
                <SelectItem value="employee">{{ branchRoleLabels.employee }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-2">
            <Label for="pos">Stanowisko (opcjonalnie)</Label>
            <Input id="pos" v-model="assignForm.position" placeholder="np. Kelner" />
          </div>
          <DialogFooter>
            <Button type="submit" :disabled="!assignForm.branchId">Przypisz</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>

    <!-- Dialog: zaproszenie -->
    <Dialog v-model:open="inviteOpen">
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Zaproś do organizacji</DialogTitle>
          <DialogDescription>
            E-mail nie jest jeszcze wysyłany — skopiuj link i przekaż osobie.
          </DialogDescription>
        </DialogHeader>

        <div v-if="inviteLink" class="space-y-3">
          <Label>Link zaproszenia</Label>
          <div class="flex gap-2">
            <Input :model-value="inviteLink" readonly />
            <Button variant="outline" size="icon" @click="copyLink(inviteLink)">
              <Copy class="size-4" />
            </Button>
          </div>
          <DialogFooter>
            <Button variant="outline" @click="inviteOpen = false">Zamknij</Button>
          </DialogFooter>
        </div>

        <form v-else class="space-y-4" @submit.prevent="sendInvite">
          <div class="space-y-2">
            <Label for="inv-email">E-mail</Label>
            <Input id="inv-email" v-model="inviteForm.email" type="email" required />
          </div>
          <div class="space-y-2">
            <Label>Rola w organizacji</Label>
            <Select v-model="inviteForm.orgRole">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem v-if="isOwner" value="owner">{{ orgRoleLabels.owner }}</SelectItem>
                <SelectItem value="admin">{{ orgRoleLabels.admin }}</SelectItem>
                <SelectItem value="member">{{ orgRoleLabels.member }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div class="space-y-2">
            <Label>Oddział (opcjonalnie)</Label>
            <Select v-model="inviteForm.branchId">
              <SelectTrigger><SelectValue placeholder="Bez przypisania" /></SelectTrigger>
              <SelectContent>
                <SelectItem v-for="b in data?.branches" :key="b.id" :value="b.id">
                  {{ b.name }}
                </SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div v-if="inviteForm.branchId" class="space-y-2">
            <Label>Rola w oddziale</Label>
            <Select v-model="inviteForm.branchRole">
              <SelectTrigger><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="manager">{{ branchRoleLabels.manager }}</SelectItem>
                <SelectItem value="employee">{{ branchRoleLabels.employee }}</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <DialogFooter>
            <Button type="submit" :disabled="inviting">
              {{ inviting ? 'Tworzenie…' : 'Utwórz zaproszenie' }}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  </div>
</template>
