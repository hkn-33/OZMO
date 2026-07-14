import type { Database } from '~~/shared/types/database.types'

export interface BranchLite {
  id: string
  name: string
}

export function useBranch() {
  const supabase = useSupabaseClient<Database>()
  const { activeOrgId } = useOrg()

  const branches = useState<BranchLite[]>('branch.list', () => [])
  const loaded = useState<boolean>('branch.loaded', () => false)
  const activeBranchId = useCookie<string | null>('ozmo_active_branch', {
    default: () => null,
    sameSite: 'lax',
  })

  async function load(force = false) {
    if (loaded.value && !force) return
    if (!activeOrgId.value) {
      branches.value = []
      activeBranchId.value = null
      loaded.value = true
      return
    }
    const { data } = await supabase
      .from('branches')
      .select('id, name')
      .eq('org_id', activeOrgId.value)
      .eq('active', true)
      .order('name')

    branches.value = (data ?? []) as BranchLite[]
    const ids = branches.value.map((b) => b.id)
    if (!activeBranchId.value || !ids.includes(activeBranchId.value)) {
      activeBranchId.value = ids[0] ?? null
    }
    loaded.value = true
  }

  const activeBranch = computed(
    () => branches.value.find((b) => b.id === activeBranchId.value) ?? null,
  )
  const hasMultipleBranches = computed(() => branches.value.length > 1)

  function setActive(id: string) {
    if (branches.value.some((b) => b.id === id)) activeBranchId.value = id
  }

  return { branches, activeBranchId, activeBranch, hasMultipleBranches, loaded, load, setActive }
}
