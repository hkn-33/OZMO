/**
 * Po zalogowaniu: jeśli użytkownik nie należy do żadnej organizacji,
 * kieruj na /onboarding. Jeśli należy, a jest na /onboarding — na pulpit.
 */
export default defineNuxtRouteMiddleware(async (to) => {
  // Strony auth (login/register/invite/confirm) obsługuje moduł supabase.
  if (to.path.startsWith('/auth')) return

  const user = useSupabaseUser()
  if (!user.value) return

  const { load, memberships } = useOrg()
  await load()

  const hasOrg = memberships.value.length > 0

  if (!hasOrg && to.path !== '/onboarding') {
    return navigateTo('/onboarding')
  }
  if (hasOrg && to.path === '/onboarding') {
    return navigateTo('/')
  }
})
