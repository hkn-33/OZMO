import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH } from './helpers'

// Full stocktake cycle (workstream 4): start → count with a diff → close →
// correction movement written + stock level updated.
test('stocktake: start → count → close writes a correction and updates the level', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()

  // A product with a known stock level of 10 (delivery movement).
  const { data: product } = await seed.admin
    .from('products')
    .insert({ org_id: seed.orgId, name: `Produkt ${seed.suffix}`, unit: 'szt' })
    .select()
    .single()
  await seed.admin.from('stock_movements').insert({
    org_id: seed.orgId, branch_id: seed.branchId, product_id: product!.id,
    qty_delta: 10, type: 'delivery', created_by: seed.owner.id,
  })

  const ctx = await browser.newContext()
  const page = await ctx.newPage()
  await login(page, seed.owner.email) // owner = branch manager

  await gotoH(page, '/stock')
  await page.getByRole('tab', { name: 'Inwentaryzacja' }).click()

  // Start a new stocktake (all active products selected by default).
  await page.getByRole('button', { name: 'Nowa inwentaryzacja' }).click()
  await expect(page.getByText('Wybierz produkty do policzenia')).toBeVisible({ timeout: 15_000 })
  await page.getByRole('button', { name: 'Rozpocznij' }).click()

  // Count: expected 10 → count 7 (delta -3).
  const countInput = page.locator('main input[type="number"]').first()
  await expect(countInput).toBeVisible({ timeout: 15_000 })
  await countInput.fill('7')
  await countInput.blur()
  await expect(page.getByText('Policzono 1 / 1')).toBeVisible()

  // Close with diff confirm.
  await page.getByRole('button', { name: 'Zamknij', exact: true }).click()
  await expect(page.getByText(/Zamknąć inwentaryzację/)).toBeVisible()
  await page.getByRole('button', { name: 'Zamknij i skoryguj' }).click()
  await expect(page.getByText(/Inwentaryzacja zamknięta/)).toBeVisible({ timeout: 15_000 })

  // DB: a correction movement of -3 and the level is now 7.
  const { data: corr } = await seed.admin
    .from('stock_movements')
    .select('qty_delta, type, note')
    .eq('branch_id', seed.branchId)
    .eq('product_id', product!.id)
    .eq('type', 'correction')
  expect(corr?.length).toBe(1)
  expect(Number(corr![0]!.qty_delta)).toBe(-3)

  const { data: level } = await seed.admin
    .from('stock_levels')
    .select('qty')
    .eq('branch_id', seed.branchId)
    .eq('product_id', product!.id)
    .single()
  expect(Number(level?.qty)).toBe(7)

  await ctx.close()
})
