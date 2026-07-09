// Phase 9 RLS/DB checks (standalone node script).
//   node tests/rls/phase9.mjs
// Verifies row-level security + triggers on the new tables:
//   cost_categories, report_section_defs, stocktakes, stocktake_items,
//   and the close_stocktake RPC (correction movements + stock level update).
// Uses service_role for seeding and per-user anon clients for RLS-scoped access.
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { createClient } from '@supabase/supabase-js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const env = {}
for (const line of readFileSync(resolve(__dirname, '../../.env'), 'utf8').split('\n')) {
  const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/)
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '')
}
const URL = env.SUPABASE_URL
const ANON = env.SUPABASE_KEY
const SERVICE = env.SUPABASE_SERVICE_KEY
const PW = 'password123'

const admin = createClient(URL, SERVICE, { auth: { autoRefreshToken: false, persistSession: false } })

let pass = 0, fail = 0
function ok(name, cond) { if (cond) { pass++; console.log('  PASS', name) } else { fail++; console.log('  FAIL', name) } }
const uniq = () => (Date.now().toString(36) + Math.random().toString(36).slice(2, 6)).toLowerCase()

async function mkUser(email) {
  const { data, error } = await admin.auth.admin.createUser({ email, password: PW, email_confirm: true })
  if (error) throw new Error('createUser ' + error.message)
  return data.user.id
}
async function clientFor(email) {
  const c = createClient(URL, ANON, { auth: { autoRefreshToken: false, persistSession: false } })
  const { error } = await c.auth.signInWithPassword({ email, password: PW })
  if (error) throw new Error('signIn ' + error.message)
  return c
}

async function seedOrg(industry) {
  const s = uniq()
  const ownerEmail = `own_${s}@ozmo.test`
  const empEmail = `emp_${s}@ozmo.test`
  const ownerId = await mkUser(ownerEmail)
  const empId = await mkUser(empEmail)
  const { data: org } = await admin.from('organizations')
    .insert({ name: `Org ${s}`, slug: `org-${s}`, created_by: ownerId, industry })
    .select().single()
  await admin.from('subscriptions').update({ plan: 'network' }).eq('org_id', org.id)
  await admin.from('org_members').insert([
    { org_id: org.id, user_id: ownerId, role: 'owner' },
    { org_id: org.id, user_id: empId, role: 'member' },
  ])
  const { data: branch } = await admin.from('branches')
    .insert({ org_id: org.id, name: `Oddział ${s}` }).select().single()
  await admin.from('branch_members').insert([
    { branch_id: branch.id, user_id: ownerId, role: 'manager', position: 'Kierownik' },
    { branch_id: branch.id, user_id: empId, role: 'employee', position: 'Pracownik' },
  ])
  return { s, ownerEmail, empEmail, ownerId, empId, orgId: org.id, branchId: branch.id }
}

async function main() {
  console.log('Seeding orgs...')
  const A = await seedOrg('gastronomia')
  const F = await seedOrg('magazyn') // foreign org
  const owner = await clientFor(A.ownerEmail) // org owner + branch manager
  const emp = await clientFor(A.empEmail)     // org member + branch employee
  const foreign = await clientFor(F.ownerEmail)

  // ---- Preset seeding ----
  console.log('\n[preset]')
  const { count: catCount } = await owner.from('cost_categories').select('*', { count: 'exact', head: true }).eq('org_id', A.orgId)
  ok('gastro preset created 5 cost categories', catCount === 5)
  const { count: defCount } = await owner.from('report_section_defs').select('*', { count: 'exact', head: true }).eq('org_id', A.orgId)
  ok('gastro preset created 5 report section defs', defCount === 5)
  const { data: revDef } = await owner.from('report_section_defs').select('id,name').eq('org_id', A.orgId).eq('is_revenue_source', true)
  ok('exactly one revenue-source def', (revDef?.length ?? 0) === 1)

  // ---- cost_categories RLS ----
  console.log('\n[cost_categories RLS]')
  const empInsCat = await emp.from('cost_categories').insert({ org_id: A.orgId, name: 'X' + A.s, sort: 9 })
  ok('employee (non-admin) cannot insert category', !!empInsCat.error)
  const ownInsCat = await owner.from('cost_categories').insert({ org_id: A.orgId, name: 'Marketing' + A.s, sort: 8 }).select().single()
  ok('org admin/owner can insert category', !ownInsCat.error && !!ownInsCat.data)
  const foreignSeeCat = await foreign.from('cost_categories').select('*').eq('org_id', A.orgId)
  ok('foreign org sees 0 of A categories', (foreignSeeCat.data?.length ?? 0) === 0)
  const empSeeCat = await emp.from('cost_categories').select('*').eq('org_id', A.orgId)
  ok('org member (employee) can SELECT categories', (empSeeCat.data?.length ?? 0) >= 5)

  // ---- report_section_defs RLS ----
  console.log('\n[report_section_defs RLS]')
  const empInsDef = await emp.from('report_section_defs').insert({ org_id: A.orgId, name: 'Nowa' + A.s, sort: 9, fields: [] })
  ok('employee cannot insert section def', !!empInsDef.error)
  const ownInsDef = await owner.from('report_section_defs').insert({ org_id: A.orgId, name: 'Dodatkowa' + A.s, sort: 9, fields: [{ key: 'a', label: 'A', type: 'text' }] }).select().single()
  ok('admin can insert section def', !ownInsDef.error)
  const foreignSeeDef = await foreign.from('report_section_defs').select('*').eq('org_id', A.orgId)
  ok('foreign org sees 0 of A defs', (foreignSeeDef.data?.length ?? 0) === 0)

  // ---- stocktakes: seed products + stock ----
  console.log('\n[stocktake]')
  const { data: p1 } = await admin.from('products').insert({ org_id: A.orgId, name: 'Prod1 ' + A.s, unit: 'szt' }).select().single()
  const { data: p2 } = await admin.from('products').insert({ org_id: A.orgId, name: 'Prod2 ' + A.s, unit: 'kg' }).select().single()
  // give p1 a stock level of 10 via a delivery movement
  await admin.from('stock_movements').insert({ org_id: A.orgId, branch_id: A.branchId, product_id: p1.id, qty_delta: 10, type: 'delivery', created_by: A.ownerId })

  // employee cannot create a stocktake (manager only)
  const empSt = await emp.from('stocktakes').insert({ org_id: A.orgId, branch_id: A.branchId }).select().single()
  ok('employee cannot create stocktake', !!empSt.error)

  // manager creates a stocktake + items (expected snapshot)
  const mgrSt = await owner.from('stocktakes').insert({ org_id: A.orgId, branch_id: A.branchId, note: 'Test' }).select().single()
  ok('manager creates stocktake', !mgrSt.error && !!mgrSt.data)
  const stId = mgrSt.data.id
  const insItems = await owner.from('stocktake_items').insert([
    { stocktake_id: stId, org_id: A.orgId, branch_id: A.branchId, product_id: p1.id, expected_qty: 10 },
    { stocktake_id: stId, org_id: A.orgId, branch_id: A.branchId, product_id: p2.id, expected_qty: 0 },
  ])
  ok('manager adds stocktake items', !insItems.error)

  // employee can SELECT (branch access) but not modify
  const empSeeSt = await emp.from('stocktakes').select('*').eq('id', stId)
  ok('employee can SELECT stocktake (branch access)', (empSeeSt.data?.length ?? 0) === 1)
  // RLS UPDATE with a failing USING clause silently affects 0 rows (no error);
  // verify the value was NOT actually changed.
  await emp.from('stocktake_items').update({ counted_qty: 5 }).eq('stocktake_id', stId).eq('product_id', p1.id)
  const { data: itemAfterEmp } = await admin.from('stocktake_items').select('counted_qty').eq('stocktake_id', stId).eq('product_id', p1.id).single()
  ok('employee cannot update stocktake item (value unchanged)', itemAfterEmp?.counted_qty === null)

  // foreign org sees nothing
  const foreignSeeSt = await foreign.from('stocktakes').select('*').eq('id', stId)
  ok('foreign org sees 0 stocktakes', (foreignSeeSt.data?.length ?? 0) === 0)

  // manager counts: p1 counted 7 (delta -3), p2 counted 4 (delta +4)
  await owner.from('stocktake_items').update({ counted_qty: 7 }).eq('stocktake_id', stId).eq('product_id', p1.id)
  await owner.from('stocktake_items').update({ counted_qty: 4 }).eq('stocktake_id', stId).eq('product_id', p2.id)

  // employee cannot close (RPC checks manager)
  const empClose = await emp.rpc('close_stocktake', { _stocktake_id: stId })
  ok('employee cannot close stocktake (RPC)', !!empClose.error)

  // manager closes → correction movements + level updates
  const mgrClose = await owner.rpc('close_stocktake', { _stocktake_id: stId })
  ok('manager closes stocktake', !mgrClose.error)

  const { data: stAfter } = await owner.from('stocktakes').select('status').eq('id', stId).single()
  ok('stocktake now closed', stAfter?.status === 'closed')

  const { data: lvl1 } = await admin.from('stock_levels').select('qty').eq('branch_id', A.branchId).eq('product_id', p1.id).single()
  ok('p1 stock corrected to 7', Number(lvl1?.qty) === 7)
  const { data: lvl2 } = await admin.from('stock_levels').select('qty').eq('branch_id', A.branchId).eq('product_id', p2.id).single()
  ok('p2 stock corrected to 4', Number(lvl2?.qty) === 4)
  const { data: corr } = await admin.from('stock_movements').select('qty_delta,note,type').eq('branch_id', A.branchId).eq('type', 'correction')
  ok('two correction movements written', (corr?.length ?? 0) === 2)

  // immutability: manager cannot edit a closed stocktake
  const editClosed = await owner.from('stocktakes').update({ note: 'x' }).eq('id', stId)
  ok('closed stocktake is immutable', !!editClosed.error)

  console.log(`\nRESULT: ${pass} passed, ${fail} failed`)
  process.exit(fail === 0 ? 0 : 1)
}

main().catch((e) => { console.error(e); process.exit(1) })
