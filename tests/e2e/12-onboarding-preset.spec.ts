import { test, expect } from '@playwright/test'
import { unique, PASSWORD, gotoH, adminClient } from './helpers'

// Onboarding with an industry preset seeds industry-appropriate templates,
// cost categories and report section defs (workstream 3).
test('onboarding: Magazyn preset seeds warehouse templates, categories, report defs', async ({
  page,
}) => {
  const s = unique()
  const email = `wh_${s}@ozmo.test`
  const orgName = `Magazyn ${s}`

  await gotoH(page, '/auth/register')
  await page.fill('#email', email)
  await page.fill('#password', PASSWORD)
  await page.getByRole('button', { name: 'Zarejestruj się' }).click()
  await page.waitForURL((url) => !url.pathname.startsWith('/auth'))

  await gotoH(page, '/onboarding')
  await page.fill('#name', orgName)
  await page.getByRole('button', { name: 'Dalej' }).click()
  await page.getByRole('button', { name: 'Magazyn / Hurtownia' }).click()
  await page.getByRole('button', { name: 'Utwórz firmę' }).click()
  await page.waitForURL((url) => url.pathname === '/')

  // Verify the preset landed (DB, service role).
  const admin = adminClient()
  const { data: org } = await admin.from('organizations').select('id, industry').eq('name', orgName).single()
  expect(org?.industry).toBe('magazyn')

  const { data: tmpl } = await admin.from('checklist_templates').select('name').eq('org_id', org!.id)
  const tmplNames = (tmpl ?? []).map((t) => t.name)
  expect(tmplNames).toContain('Przyjęcie dostawy')
  expect(tmplNames.length).toBe(5)

  const { data: cats } = await admin.from('cost_categories').select('name').eq('org_id', org!.id)
  const catNames = (cats ?? []).map((c) => c.name)
  expect(catNames).toEqual(expect.arrayContaining(['Towar', 'Transport', 'Praca', 'Media', 'Inne']))

  const { data: defs } = await admin.from('report_section_defs').select('name, is_revenue_source').eq('org_id', org!.id)
  const defNames = (defs ?? []).map((d) => d.name)
  expect(defNames).toContain('Wysyłki')
  expect((defs ?? []).filter((d) => d.is_revenue_source).length).toBe(1)
})
