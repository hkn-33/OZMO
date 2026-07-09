/**
 * Utrzymuje token realtime w zgodzie z sesją użytkownika.
 *
 * Prywatne kanały (chat:{id}, task:{id}, user:{uuid}) autoryzują się przez RLS
 * na realtime.messages z użyciem access tokenu JWT. Bez ustawionego (i
 * odświeżanego) tokenu socket łączy się jako anon i broadcasty nie docierają —
 * dlatego wołamy setAuth przy starcie klienta oraz przy każdej zmianie sesji
 * (SIGNED_IN / TOKEN_REFRESHED). To eliminuje „wiadomości dopiero po odświeżeniu".
 */
export default defineNuxtPlugin(() => {
  const supabase = useSupabaseClient()

  const apply = async () => {
    const { data } = await supabase.auth.getSession()
    if (data.session?.access_token) {
      await supabase.realtime.setAuth(data.session.access_token)
    }
  }

  apply()

  supabase.auth.onAuthStateChange((_event, session) => {
    if (session?.access_token) {
      supabase.realtime.setAuth(session.access_token)
    }
  })
})
