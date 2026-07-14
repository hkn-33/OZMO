import { test, expect } from '@playwright/test'
import { unique, PASSWORD, gotoH } from './helpers'

test('register → onboarding → create org → dashboard shows org name', async ({ page }) => {
  const s = unique()
  const email = `new_${s}@ozmo.test`

  await gotoH(page, '/auth/register')
  await page.fill('#email', email)
  await page.fill('#password', PASSWORD)
  await page.getByRole('button', { name: 'Zarejestruj się' }).click()

  // New account has no org. The middleware only redirects to /onboarding once
  // the client session has propagated, so go there explicitly to avoid the race.
  await page.waitForURL((url) => !url.pathname.startsWith('/auth'))
  await gotoH(page, '/onboarding')

  const orgName = `Sieć ${s}`
  await page.fill('#name', orgName)
  // Step 1 → industry step; pick an industry, then create.
  await page.getByRole('button', { name: 'Dalej' }).click()
  await page.getByRole('button', { name: 'Gastronomia' }).click()
  await page.getByRole('button', { name: 'Utwórz firmę' }).click()

  await page.waitForURL((url) => url.pathname === '/')
  await expect(
    page.getByRole('heading', { level: 1, name: orgName }),
  ).toBeVisible()
  await expect(page.getByText('Główny lokal').first()).toBeVisible()
})
