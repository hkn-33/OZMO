/**
 * Pierwsze logowanie: konta zakładane przez menadżera mają w metadanych
 * `must_change_password`. Dopóki flaga jest ustawiona, użytkownik jest kierowany
 * na stronę zmiany hasła (poza samą tą stroną).
 */
export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser()
  if (!user.value) return
  const meta = (user.value as { user_metadata?: Record<string, unknown> }).user_metadata ?? {}
  if (meta.must_change_password && to.path !== '/auth/change-password') {
    return navigateTo('/auth/change-password')
  }
})
