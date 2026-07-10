import { toast } from 'vue-sonner'

/**
 * Publiczne konto demo. Loguje wspólnymi danymi (jawne z założenia) i kieruje
 * na pulpit. Dane demo resetują się co godzinę (pg_cron → private.reset_demo_org).
 */
export const DEMO_USERNAME = 'demo-public'
const DEMO_EMAIL = 'demo-public@users.ozmo.local'
const DEMO_PASSWORD = 'OzmoDemo2026'

export function useDemo() {
  const supabase = useSupabaseClient()
  const signingIn = useState('demo.signingIn', () => false)

  async function enterDemo() {
    if (signingIn.value) return
    signingIn.value = true
    const { error } = await supabase.auth.signInWithPassword({
      email: DEMO_EMAIL,
      password: DEMO_PASSWORD,
    })
    if (error) {
      signingIn.value = false
      toast.error('Nie udało się otworzyć demo', { description: error.message })
      return
    }
    await navigateTo('/')
    signingIn.value = false
  }

  return { enterDemo, signingIn }
}
