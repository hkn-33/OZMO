import { serverSupabaseClient, serverSupabaseUser } from '#supabase/server'
import type { Database } from '~~/shared/types/database.types'

/**
 * Tworzy zaproszenie. Autoryzacja przez RLS: insert do `invitations`
 * przechodzi tylko dla org admina (polityka invitations_insert_admin).
 * E-mail na razie nie jest wysyłany — zwracamy link do skopiowania.
 */
export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event)
  if (!user) {
    throw createError({ statusCode: 401, message: 'Musisz być zalogowany' })
  }

  const body = await readBody(event)
  const { orgId, email, orgRole, branchId, branchRole } = body ?? {}

  if (!orgId || !email || !orgRole) {
    throw createError({
      statusCode: 400,
      message: 'Wymagane: orgId, email, orgRole',
    })
  }

  const client = await serverSupabaseClient<Database>(event)
  const { data, error } = await client
    .from('invitations')
    .insert({
      org_id: orgId,
      email: String(email).trim().toLowerCase(),
      org_role: orgRole,
      branch_id: branchId ?? null,
      branch_role: branchRole ?? null,
      invited_by: user.sub,
    })
    .select('token')
    .single()

  if (error || !data) {
    throw createError({
      statusCode: 403,
      message: 'Nie udało się utworzyć zaproszenia (brak uprawnień?)',
      data: error?.message,
    })
  }

  const origin = getRequestURL(event).origin
  return {
    token: data.token,
    link: `${origin}/auth/invite/${data.token}`,
  }
})
