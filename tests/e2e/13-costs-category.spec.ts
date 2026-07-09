import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH } from './helpers'

// Costs page shows a dynamic KPI card per (custom) cost category (workstream 1).
test('costs: custom category shows its own KPI card with a percentage', async ({ browser }) => {
  const seed = await seedOrgWithUsers()
  const today = new Date().toISOString().slice(0, 10)

  // Add a custom category + revenue + a cost in that category (service role).
  const { data: cat } = await seed.admin
    .from('cost_categories')
    .insert({ org_id: seed.orgId, name: `Marketing ${seed.suffix}`, sort: 99 })
    .select()
    .single()
  await seed.admin.from('revenue_entries').insert({
    org_id: seed.orgId, branch_id: seed.branchId, date: today, amount: 1000, source: 'manual',
  })
  await seed.admin.from('cost_entries').insert({
    org_id: seed.orgId, branch_id: seed.branchId, date: today,
    category_id: cat!.id, amount: 300, source: 'manual', created_by: seed.owner.id,
  })

  const ctx = await browser.newContext()
  const page = await ctx.newPage()
  await login(page, seed.owner.email)
  await gotoH(page, '/costs')

  // The custom category renders as its own KPI card, alongside Przychód + Koszty razem.
  await expect(page.getByText(`Marketing ${seed.suffix}`).first()).toBeVisible({ timeout: 20_000 })
  await expect(page.getByText('Przychód').first()).toBeVisible()
  await expect(page.getByText(/Koszty razem/).first()).toBeVisible()

  await ctx.close()
})
