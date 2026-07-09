import type { Database } from '~~/shared/types/database.types'

export type Plan = Database['public']['Enums']['plan']

/**
 * Subskrypcja aktywnej organizacji. Ekspozycja planu + flagi trybu demo.
 * Zapis subskrypcji tylko service_role (webhooki Stripe — później).
 */
export function useSubscription() {
  const supabase = useSupabaseClient<Database>()
  const { activeOrgId } = useOrg()

  const plan = useState<Plan | null>('sub.plan', () => null)
  const loaded = useState<boolean>('sub.loaded', () => false)

  async function load(force = false) {
    if (loaded.value && !force) return
    if (!activeOrgId.value) {
      plan.value = null
      loaded.value = true
      return
    }
    const { data } = await supabase
      .from('subscriptions')
      .select('plan')
      .eq('org_id', activeOrgId.value)
      .maybeSingle()
    plan.value = (data?.plan ?? null) as Plan | null
    loaded.value = true
  }

  const isDemo = computed(() => plan.value === 'demo')

  return { plan, isDemo, loaded, load }
}
