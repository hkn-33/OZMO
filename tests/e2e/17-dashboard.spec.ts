import { test, expect } from '@playwright/test'
import { login, gotoH } from './helpers'

// Dashboard widgets render for the seeded demo account (workstream 5).
// The demo account (seed.sql) is owner of "Restauracje Bella" with rich data.
test('dashboard: widgets render for the demo account', async ({ page }) => {
  await login(page, 'demo@users.ozmo.local', 'Demo1234!')
  await gotoH(page, '/')

  // Org heading + core widgets.
  await expect(page.getByRole('heading', { level: 1, name: 'Restauracje Bella' })).toBeVisible({
    timeout: 20_000,
  })
  await expect(page.getByText('Moje zadania').first()).toBeVisible()
  await expect(page.getByText('Alerty magazynowe').first()).toBeVisible()
  await expect(page.getByText('Nieprzeczytane czaty').first()).toBeVisible()
  await expect(page.getByText('Notatki dnia').first()).toBeVisible()

  // Owner also sees network stats.
  await expect(page.getByText('Otwarte zadania (sieć)').first()).toBeVisible()

  // Seeded demo has products below minimum → at least one stock alert row.
  await expect(page.getByText(/\d+ \/ \d+/).first()).toBeVisible()
})
