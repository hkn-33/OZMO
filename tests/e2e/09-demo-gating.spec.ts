import { test, expect } from '@playwright/test'
import { unique, PASSWORD, gotoH } from './helpers'

test('demo org: clicking "Nowe zadanie" opens the upgrade modal', async ({ page }) => {
  const s = unique()
  const email = `demo_${s}@ozmo.test`

  // Register → onboarding creates a DEMO org (with sample data).
  await gotoH(page, '/auth/register')
  await page.fill('#email', email)
  await page.fill('#password', PASSWORD)
  await page.getByRole('button', { name: 'Zarejestruj się' }).click()
  await page.waitForURL((url) => !url.pathname.startsWith('/auth'))
  await gotoH(page, '/onboarding')
  await page.fill('#name', `Sieć ${s}`)
  await page.getByRole('button', { name: 'Utwórz organizację' }).click()
  await page.waitForURL((url) => url.pathname === '/')

  // The demo org has a sample branch, so the tasks page shows the create button.
  await gotoH(page, '/tasks')
  const newBtn = page.getByRole('button', { name: 'Nowe zadanie' })
  await expect(newBtn).toBeVisible({ timeout: 20_000 })
  await newBtn.click()

  // Instead of the create dialog, the shared upgrade modal appears.
  await expect(page.getByText(/dostępna w pełnej wersji/)).toBeVisible()
})
