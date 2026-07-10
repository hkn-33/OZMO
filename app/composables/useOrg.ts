import type { Database } from '~~/shared/types/database.types'

export type OrgRole = Database['public']['Enums']['org_role']

export interface OrgMembership {
  org_id: string
  role: OrgRole
  organizations: {
    id: string
    name: string
    slug: string
    is_public_demo: boolean
  }
}

/**
 * Kontekst aktywnej organizacji.
 * Ładuje członkostwa zalogowanego użytkownika, trzyma aktywną organizację
 * (persystencja w cookie) i udostępnia akcje pomocnicze.
 */
export function useOrg() {
  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()

  const memberships = useState<OrgMembership[]>('org.memberships', () => [])
  const loaded = useState<boolean>('org.loaded', () => false)
  const activeOrgId = useCookie<string | null>('ozmo_active_org', {
    default: () => null,
    sameSite: 'lax',
  })

  async function load(force = false) {
    if ((loaded.value && !force) || !user.value) return
    const { data, error } = await supabase
      .from('org_members')
      .select('org_id, role, organizations(id, name, slug, is_public_demo)')
      .order('created_at', { ascending: true })

    if (!error && data) {
      memberships.value = data as unknown as OrgMembership[]
      const ids = memberships.value.map((m) => m.org_id)
      if (!activeOrgId.value || !ids.includes(activeOrgId.value)) {
        activeOrgId.value = ids[0] ?? null
      }
    }
    loaded.value = true
  }

  const activeMembership = computed<OrgMembership | null>(
    () => memberships.value.find((m) => m.org_id === activeOrgId.value) ?? null,
  )
  const activeOrg = computed(() => activeMembership.value?.organizations ?? null)
  const role = computed<OrgRole | null>(() => activeMembership.value?.role ?? null)
  const isAdmin = computed(() => role.value === 'owner' || role.value === 'admin')
  const isOwner = computed(() => role.value === 'owner')
  const isPublicDemo = computed(() => activeOrg.value?.is_public_demo ?? false)

  function setActive(orgId: string) {
    if (memberships.value.some((m) => m.org_id === orgId)) {
      activeOrgId.value = orgId
    }
  }

  return {
    memberships,
    activeOrgId,
    activeOrg,
    activeMembership,
    role,
    isAdmin,
    isOwner,
    isPublicDemo,
    loaded,
    load,
    setActive,
  }
}
