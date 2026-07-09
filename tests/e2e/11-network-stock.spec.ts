import { test, expect } from '@playwright/test'
import { login, gotoH } from './helpers'

test('stock "Cała sieć" matrix renders for an org admin', async ({ page }) => {
  await login(page, 'demo', 'Demo1234!')
  await gotoH(page, '/stock')

  await page.getByRole('tab', { name: /Cała sieć/ }).click()

  // Matrix: branch columns + product rows + totals.
  await expect(page.getByRole('columnheader', { name: 'Bella Centrum' })).toBeVisible()
  await expect(page.getByRole('columnheader', { name: 'Razem' })).toBeVisible()
  await expect(page.getByText('Kawa ziarnista').first()).toBeVisible()
})

test('demo/Demo1234! login shows the dashboard with the seeded org', async ({ page }) => {
  await login(page, 'demo', 'Demo1234!')
  await expect(
    page.getByRole('heading', { level: 1, name: 'Restauracje Bella' }),
  ).toBeVisible()
  await expect(page.getByText('Bella Centrum').first()).toBeVisible()
})
