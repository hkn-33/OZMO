import { serverSupabaseUser, serverSupabaseServiceRole } from '#supabase/server'
import type { Database } from '~~/shared/types/database.types'

/**
 * Dodaje pracownika bezpośrednio (bez zaproszenia e-mail).
 * Tworzy konto auth z e-mailem `${username}@users.ozmo.local`, potwierdzone,
 * z metadanymi (username, full_name, must_change_password) i hasłem tymczasowym
 * (zwracanym raz do skopiowania). Wpisuje org_members (+ branch_members).
 * Autoryzacja: org admin, albo manager oddziału dodający do własnego oddziału.
 */
const USERNAME_RE = /^[a-z0-9_.-]{3,30}$/

function tempPassword(): string {
  const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const bytes = crypto.getRandomValues(new Uint8Array(10))
  return `Ozmo${Array.from(bytes, (byte) => chars[byte % chars.length]).join('')}`
}

export default defineEventHandler(async (event) => {
  const caller = await serverSupabaseUser(event)
  if (!caller) {
    throw createError({ statusCode: 401, message: 'Musisz być zalogowany' })
  }

  const body = await readBody(event)
  const { orgId, username, fullName, orgRole, branchId, branchRole } = body ?? {}

  if (!orgId || !username || !fullName) {
    throw createError({ statusCode: 400, message: 'Wymagane: orgId, username, fullName' })
  }
  const uname = String(username).trim().toLowerCase()
  if (!USERNAME_RE.test(uname)) {
    throw createError({
      statusCode: 400,
      message: 'Nazwa użytkownika: 3–30 znaków, dozwolone a-z 0-9 _ . -',
    })
  }

  const admin = serverSupabaseServiceRole<Database>(event)

  // Autoryzacja: org admin lub manager wskazanego oddziału.
  const { data: orgMem } = await admin
    .from('org_members')
    .select('role')
    .eq('org_id', orgId)
    .eq('user_id', caller.sub)
    .maybeSingle()
  const isOrgAdmin = orgMem?.role === 'owner' || orgMem?.role === 'admin'

  let isBranchMgr = false
  if (branchId) {
    const { data: bm } = await admin
      .from('branch_members')
      .select('role')
      .eq('branch_id', branchId)
      .eq('user_id', caller.sub)
      .maybeSingle()
    isBranchMgr = bm?.role === 'manager'
  }

  if (!isOrgAdmin && !isBranchMgr) {
    throw createError({ statusCode: 403, message: 'Brak uprawnień' })
  }

  const password = tempPassword()
  const email = `${uname}@users.ozmo.local`

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      username: uname,
      full_name: String(fullName).trim(),
      must_change_password: true,
    },
  })
  if (createErr || !created?.user) {
    throw createError({
      statusCode: 409,
      message: 'Nie udało się utworzyć konta (nazwa użytkownika zajęta?)',
      data: createErr?.message,
    })
  }
  const newUserId = created.user.id

  // Członkostwo w organizacji (branch manager może dodać tylko jako member).
  const effectiveOrgRole = isOrgAdmin && orgRole ? orgRole : 'member'
  const { error: omErr } = await admin
    .from('org_members')
    .insert({ org_id: orgId, user_id: newUserId, role: effectiveOrgRole })
  if (omErr) {
    await admin.auth.admin.deleteUser(newUserId)
    throw createError({ statusCode: 400, message: 'Nie udało się dodać do organizacji', data: omErr.message })
  }

  if (branchId) {
    const { error: bmErr } = await admin.from('branch_members').insert({
      branch_id: branchId,
      user_id: newUserId,
      role: branchRole ?? 'employee',
    })
    if (bmErr) {
      throw createError({ statusCode: 400, message: 'Konto utworzone, ale nie przypisano do oddziału', data: bmErr.message })
    }
  }

  return { userId: newUserId, username: uname, email, password }
})
