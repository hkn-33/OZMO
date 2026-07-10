import { serverSupabaseUser, serverSupabaseServiceRole } from '#supabase/server'
import type { Database } from '~~/shared/types/database.types'

/**
 * RODO — samoobsługowe usunięcie konta (POST /api/account/delete).
 *
 * Strategia: BAN + ANONIMIZACJA (nie twardy DELETE z auth.users).
 * Powód (zweryfikowane FK, patrz docs/rodo.md):
 *  - profiles.id -> auth.users ON DELETE CASCADE: twardy delete skasowałby też
 *    anonimizowany profil (anonimizacja by "nie przeżyła").
 *  - autorstwo (task_comments.author_id, chat_messages.author_id,
 *    stock_movements.created_by, tasks.created_by, manager_reports.*, itd.)
 *    ma ON DELETE NO ACTION — twardy delete auth.users zostałby ODRZUCONY,
 *    dopóki istnieje jakakolwiek autorska treść. Treść zachowujemy
 *    (uzasadniony interes / integralność audytu).
 *
 * Dlatego: profil anonimizujemy, więzy PII (org_members, branch_members,
 * availability) usuwamy, a wpis auth.users banujemy i anonimizujemy e-mail —
 * użytkownik nie może się już zalogować, a jego dane osobowe znikają.
 *
 * Blokada: ostatni owner organizacji, która ma innych członków, musi najpierw
 * przekazać własność (inaczej organizacja zostałaby bez właściciela).
 */
export default defineEventHandler(async (event) => {
  const user = await serverSupabaseUser(event)
  if (!user) {
    throw createError({ statusCode: 401, message: 'Musisz być zalogowany' })
  }

  const uid = user.sub as string
  const admin = serverSupabaseServiceRole<Database>(event)

  // --- Blokada: konto publicznego demo (współdzielone, resetowane co godzinę) ---
  const { data: demoMembership } = await admin
    .from('org_members')
    .select('org_id, organizations!inner(is_public_demo)')
    .eq('user_id', uid)
    .eq('organizations.is_public_demo', true)
    .limit(1)
  if ((user.email as string) === 'demo-public@users.ozmo.local' || (demoMembership?.length ?? 0) > 0) {
    throw createError({
      statusCode: 403,
      message: 'Konto demo jest chronione i nie może zostać usunięte.',
    })
  }

  // --- Blokada: ostatni owner organizacji z innymi członkami ---
  const { data: ownedOrgs, error: ownErr } = await admin
    .from('org_members')
    .select('org_id')
    .eq('user_id', uid)
    .eq('role', 'owner')

  if (ownErr) {
    throw createError({ statusCode: 500, message: ownErr.message })
  }

  for (const row of ownedOrgs ?? []) {
    const orgId = row.org_id
    const { count: total } = await admin
      .from('org_members')
      .select('*', { count: 'exact', head: true })
      .eq('org_id', orgId)
    const { count: owners } = await admin
      .from('org_members')
      .select('*', { count: 'exact', head: true })
      .eq('org_id', orgId)
      .eq('role', 'owner')

    if ((total ?? 0) > 1 && (owners ?? 0) <= 1) {
      throw createError({
        statusCode: 409,
        message:
          'Jesteś jedynym właścicielem organizacji, która ma innych członków. ' +
          'Przekaż najpierw rolę właściciela innej osobie, a potem usuń konto.',
      })
    }
  }

  // --- Anonimizacja profilu ---
  const { error: profErr } = await admin
    .from('profiles')
    .update({ full_name: 'Usunięty użytkownik', phone: null, avatar_url: null })
    .eq('id', uid)
  if (profErr) {
    throw createError({ statusCode: 500, message: profErr.message })
  }

  // --- Usunięcie więzów PII (członkostwa, dostępność) ---
  await admin.from('org_members').delete().eq('user_id', uid)
  await admin.from('branch_members').delete().eq('user_id', uid)
  await admin.from('availability').delete().eq('user_id', uid)

  // --- Ban + anonimizacja wpisu auth.users (blokuje logowanie, usuwa e-mail PII) ---
  const { error: banErr } = await admin.auth.admin.updateUserById(uid, {
    ban_duration: '876000h', // ~100 lat
    email: `deleted+${uid}@ozmo.invalid`,
    user_metadata: {},
    app_metadata: {},
  })
  if (banErr) {
    throw createError({ statusCode: 500, message: banErr.message })
  }

  return { ok: true }
})
