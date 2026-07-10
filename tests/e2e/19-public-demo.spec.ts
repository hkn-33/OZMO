import { test, expect } from '@playwright/test'
import { login, gotoH } from './helpers'

test('landing "Wypróbuj demo" signs into the public demo dashboard with banner', async ({
  page,
}) => {
  await gotoH(page, '/')

  await page.getByRole('button', { name: /Wypróbuj demo/ }).first().click()

  // Lands on the dashboard of the public demo org.
  await page.waitForURL((url) => !url.pathname.startsWith('/auth'), {
    timeout: 30_000,
  })
  await expect(
    page.getByRole('heading', { level: 1, name: 'OZMO Demo' }),
  ).toBeVisible()

  // Global demo banner is present.
  const banner = page.getByTestId('demo-banner')
  await expect(banner).toBeVisible()
  await expect(banner).toContainText(/Tryb demo/)
  await expect(banner.getByRole('link', { name: /Załóż własne konto/ })).toBeVisible()
})

test('demo banner is absent for a normal (non-demo) org', async ({ page }) => {
  await login(page, 'demo', 'Demo1234!')
  await expect(
    page.getByRole('heading', { level: 1, name: 'Restauracje Bella' }),
  ).toBeVisible()
  await expect(page.getByTestId('demo-banner')).toHaveCount(0)
})

test('settings hides password + delete controls for the public demo account', async ({
  page,
}) => {
  await login(page, 'demo-public', 'OzmoDemo2026')
  await gotoH(page, '/settings')

  await expect(page.getByRole('heading', { name: 'Konto demo' })).toBeVisible()
  // Password + delete controls are hidden (their action buttons are gone).
  await expect(page.getByRole('button', { name: 'Zmień hasło' })).toHaveCount(0)
  await expect(page.locator('#newPassword')).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Usuń konto' })).toHaveCount(0)
})
