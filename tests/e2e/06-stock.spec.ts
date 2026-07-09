import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, escapeRegex, gotoH } from './helpers'

test('stock: delivery then usage below minimum triggers stock_low notification', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const productName = `Pomidory ${seed.suffix}`
  const prodRe = new RegExp(escapeRegex(productName))

  const ctx = await browser.newContext()
  const op = await ctx.newPage()
  await login(op, seed.owner.email)
  await gotoH(op, '/stock')

  // --- Create a product (Produkty tab) ---
  await op.getByRole('tab', { name: 'Produkty' }).click()
  await op.getByRole('button', { name: 'Dodaj produkt' }).click()
  await op.fill('#p-name', productName)
  await op.getByRole('button', { name: 'Zapisz' }).click()
  await expect(op.getByText('Dodano produkt')).toBeVisible()

  // Set min_stock = 5 for this branch (via service_role — avoids the
  // conditional inline-save button; the alert path itself is UI-driven).
  const { data: prod } = await seed.admin
    .from('products')
    .select('id')
    .eq('org_id', seed.orgId)
    .eq('name', productName)
    .single()
  const { error: bpsErr } = await seed.admin
    .from('branch_product_settings')
    .upsert({
      branch_id: seed.branchId,
      product_id: prod!.id,
      org_id: seed.orgId,
      min_stock: 5,
    })
  expect(bpsErr).toBeNull()

  // --- Record delivery (+10) then usage (-7) → ends at 3, below min 5 ---
  await op.getByRole('tab', { name: 'Przyjęcie/Wydanie' }).click()

  // Delivery line (type defaults to "Dostawa")
  await op.getByRole('combobox').filter({ hasText: 'Wybierz produkt' }).click()
  await op.getByRole('option', { name: prodRe }).click()
  await op.fill('#mv-qty', '10')
  await op.getByRole('button', { name: 'Dodaj do listy' }).click()

  // Usage line: switch type to "Zużycie"
  await op.getByRole('combobox').filter({ hasText: 'Dostawa' }).click()
  await op.getByRole('option', { name: 'Zużycie' }).click()
  await op.getByRole('combobox').filter({ hasText: 'Wybierz produkt' }).click()
  await op.getByRole('option', { name: prodRe }).click()
  await op.fill('#mv-qty', '7')
  await op.getByRole('button', { name: 'Dodaj do listy' }).click()

  // Save both movements
  await op.getByRole('button', { name: /Zapisz wszystkie/ }).click()
  await expect(op.getByText(/Zapisano/)).toBeVisible()

  // --- Verify stock level shows "Niski stan" and the stock_low alert fired ---
  await op.getByRole('tab', { name: 'Stany' }).click()
  await expect(
    op.getByRole('row').filter({ hasText: prodRe }).getByText('Niski stan'),
  ).toBeVisible({ timeout: 15_000 })

  // Reload to force the bell to fetch notifications, then assert the alert.
  await gotoH(op, '/stock')
  const badge = op.locator('header .rounded-full.bg-primary')
  await expect(badge).toBeVisible({ timeout: 20_000 })
  await badge.click()
  await expect(op.getByText('Niski stan magazynowy')).toBeVisible()

  await ctx.close()
})
