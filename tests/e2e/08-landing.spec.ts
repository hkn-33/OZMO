import { test, expect } from '@playwright/test'
import { gotoH } from './helpers'

test('landing page renders for anonymous visitors with pricing', async ({ page }) => {
  await gotoH(page, '/')

  await expect(
    page.getByRole('heading', {
      name: /System operacyjny dla sieci restauracji i hoteli/,
    }),
  ).toBeVisible()

  // Three pricing tiers with placeholder prices.
  await expect(page.getByRole('heading', { name: 'Starter' })).toBeVisible()
  await expect(page.getByText('149 zł')).toBeVisible()
  await expect(page.getByText('249 zł')).toBeVisible()
  await expect(page.getByText('399 zł')).toBeVisible()
  await expect(page.getByText(/Ceny wkrótce/)).toBeVisible()

  // CTA to register.
  await expect(
    page.getByRole('link', { name: /Zacznij za darmo|Załóż konto/ }).first(),
  ).toBeVisible()
})
