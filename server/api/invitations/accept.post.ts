import { serverSupabaseUser, serverSupabaseServiceRole } from '#supabase/server'
import type { Database } from '~~/shared/types/database.types'

/**
 * Akceptacja zaproszenia. Wymaga zalogowanego użytkownika.
 * Używa service_role (zaproszony nie jest jeszcze członkiem → RLS by zablokował).
 * Idempotentne: ponowne wywołanie na zaakceptowanym zaproszeniu jest bezpieczne.
 */
export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event)
  if (!user) {
    throw createError({ statusCode: 401, message: 'Musisz być zalogowany' })
  }

  const body = await readBody(event)
  const token = body?.token
  if (!token) {
    throw createError({ statusCode: 400, message: 'Brak tokenu zaproszenia' })
  }

  const admin = serverSupabaseServiceRole<Database>(event)

  const { data: inv, error: invErr } = await admin
    .from('invitations')
    .select('*')
    .eq('token', token)
    .maybeSingle()

  if (invErr || !inv) {
    throw createError({ statusCode: 404, message: 'Zaproszenie nie istnieje' })
  }

  if (inv.accepted_at) {
    return { ok: true, orgId: inv.org_id, alreadyAccepted: true }
  }

  if (new Date(inv.expires_at).getTime() < Date.now()) {
    throw createError({ statusCode: 410, message: 'Zaproszenie wygasło' })
  }

  const userEmail = (user.email ?? '').toLowerCase()
  if (userEmail !== inv.email.toLowerCase()) {
    throw createError({
      statusCode: 403,
      message: 'Zaproszenie wystawiono na inny adres e-mail',
    })
  }

  const { error: omErr } = await admin.from('org_members').upsert(
    { org_id: inv.org_id, user_id: user.sub, role: inv.org_role },
    { onConflict: 'org_id,user_id', ignoreDuplicates: true },
  )
  if (omErr) {
    throw createError({ statusCode: 500, message: omErr.message })
  }

  if (inv.branch_id) {
    const { error: bmErr } = await admin.from('branch_members').upsert(
      {
        branch_id: inv.branch_id,
        user_id: user.sub,
        role: inv.branch_role ?? 'employee',
      },
      { onConflict: 'branch_id,user_id', ignoreDuplicates: true },
    )
    if (bmErr) {
      throw createError({ statusCode: 500, message: bmErr.message })
    }
  }

  await admin
    .from('invitations')
    .update({ accepted_at: new Date().toISOString() })
    .eq('id', inv.id)

  return { ok: true, orgId: inv.org_id }
})
