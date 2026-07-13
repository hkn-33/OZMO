import { test, expect } from '@playwright/test'
import { gotoH } from './helpers'

test('landing page renders for anonymous visitors with pricing', async ({ page }) => {
  await gotoH(page, '/')

  await expect(
    page.getByRole('heading', {
      name: /Każdy lokal. Jeden rytm./,
    }),
  ).toBeVisible()

  await expect(page.getByRole('link', { name: 'OZMO — strona główna' })).toBeVisible()
  await expect(page.getByRole('button', { name: /Otwórz demo/ }).first()).toBeVisible()

  // Three pricing tiers with placeholder prices.
  await expect(page.getByRole('heading', { name: 'Starter' })).toBeVisible()
  await expect(page.getByText('149 zł')).toBeVisible()
  await expect(page.getByText('249 zł')).toBeVisible()
  await expect(page.getByText('399 zł')).toBeVisible()
  await expect(page.getByText(/Ceny wkrótce/)).toBeVisible()

  // CTA to register.
  await expect(
    page.getByRole('link', { name: /Załóż konto/ }).first(),
  ).toBeVisible()

  await expect(page.getByRole('contentinfo')).toContainText(/Mniej pilnowania narzędzi/)
})

test('landing stays within the viewport on mobile and tablet', async ({ page }) => {
  for (const width of [320, 375, 414, 768]) {
    await page.setViewportSize({ width, height: 812 })
    await gotoH(page, '/')

    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
    expect(overflow, `horizontal overflow at ${width}px`).toBeLessThanOrEqual(0)
    await expect(page.getByRole('heading', { name: /Każdy lokal. Jeden rytm./ })).toBeVisible()
  }
})
