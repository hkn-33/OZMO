import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH } from './helpers'

// Configuring report sections (workstream 2): a new section with a field
// appears in the manager report for new reports.
test('report config: add a section with a field → it appears in the manager report', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const fieldLabel = `Pole testowe ${seed.suffix}`

  const ctx = await browser.newContext()
  const page = await ctx.newPage()
  await login(page, seed.owner.email) // owner = org admin

  await gotoH(page, '/reports')
  await page.getByRole('tab', { name: 'Sekcje raportu' }).click()

  // Add a section (defaults to "Nowa sekcja"), give it one text field, save.
  await page.getByRole('button', { name: 'Dodaj sekcję' }).click()
  await expect(page.getByPlaceholder('Nazwa sekcji').last()).toBeVisible({ timeout: 15_000 })
  await page.getByRole('button', { name: 'Pole', exact: true }).last().click()
  await page.getByPlaceholder('Etykieta pola').last().fill(fieldLabel)
  await page.getByRole('button', { name: 'Zapisz sekcję' }).last().click()
  await expect(page.getByText('Zapisano sekcję')).toBeVisible()

  // Create today's report; the new section is auto-created from the def.
  await page.getByRole('tab', { name: /Raport menadżerski/ }).click()
  await page.getByRole('button', { name: 'Utwórz raport' }).click()
  const sectionTrigger = page.getByRole('button', { name: 'Nowa sekcja' })
  await expect(sectionTrigger).toBeVisible({ timeout: 20_000 })

  // Expanding it reveals the configured field.
  await sectionTrigger.click()
  await expect(page.getByText(fieldLabel).first()).toBeVisible()

  await ctx.close()
})
