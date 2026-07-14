import { test, expect } from '@playwright/test'
import { login, gotoH } from './helpers'

test('dashboard: widgets render for the demo account', async ({ page }) => {
  await login(page, 'demo@users.ozmo.local', 'Demo1234!')
  await gotoH(page, '/')

  await expect(page.getByRole('heading', { level: 1, name: 'Restauracje Bella' })).toBeVisible({
    timeout: 20_000,
  })
  await expect(page.getByText('Moje zadania').first()).toBeVisible()
  await expect(page.getByText('Braki magazynowe').first()).toBeVisible()
  await expect(page.getByText('Nowe wiadomości').first()).toBeVisible()
  await expect(page.getByText('Raport i zdarzenia').first()).toBeVisible()

  await expect(page.getByText('Wymaga uwagi').first()).toBeVisible()
  await expect(page.getByRole('heading', { level: 2, name: 'Do decyzji' })).toBeVisible()
  await expect(page.getByRole('link', { name: /Otwórz zadania/ })).toBeVisible()

  await expect(page.getByText(/\d+ \/ \d+/).first()).toBeVisible()

  for (const width of [320, 375, 414, 768]) {
    await page.setViewportSize({ width, height: 812 })
    expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(width)
  }
})
