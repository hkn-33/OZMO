import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH } from './helpers'

test('manager report: close blocked until all 5 sections complete, then closes', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const ctx = await browser.newContext()
  const op = await ctx.newPage()
  await login(op, seed.owner.email)

  await gotoH(op, '/reports')
  await op.getByRole('tab', { name: /Raport menadżerski/ }).click()

  // Create today's report (auto-seeds 5 sections)
  await op.getByRole('button', { name: 'Utwórz raport' }).click()
  await expect(op.getByText('0/5').first()).toBeVisible({ timeout: 20_000 })

  // Close is blocked while incomplete + message shown
  const closeBtn = op.getByRole('button', { name: 'Zamknij raport' })
  await expect(closeBtn).toBeDisabled()
  await expect(op.getByText(/Aby zamknąć raport/)).toBeVisible()

  // Complete all 5 sections: expand → check "Sekcja gotowa" → save → collapse.
  // Assert the progress counter increments (robust vs. stacked toasts).
  const sections = ['Przychód dnia', 'Kasa', 'Kontrola jakości', 'Magazyn', 'Przebieg zmiany']
  for (let i = 0; i < sections.length; i++) {
    const trigger = op.getByRole('button', { name: sections[i] })
    await trigger.click()
    // "Sekcja gotowa" checkbox is the last checkbox in the open panel
    await op.getByRole('checkbox').last().check()
    await op.getByRole('button', { name: 'Zapisz sekcję' }).click()
    await expect(op.getByText(`${i + 1}/5`).first()).toBeVisible()
    await trigger.click() // collapse so next panel's controls are unambiguous
    await op.waitForTimeout(200)
  }

  await expect(op.getByText('5/5').first()).toBeVisible()
  await expect(closeBtn).toBeEnabled()
  await closeBtn.click()
  await expect(op.getByText('Raport zamknięty')).toBeVisible()
  await expect(op.getByText('Zamknięty').first()).toBeVisible()

  await ctx.close()
})
