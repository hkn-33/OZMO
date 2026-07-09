import { test, expect } from '@playwright/test'
import { login, gotoH } from './helpers'

// Global search (Cmd/Ctrl+K) finds a task and a product in the active org (ws 5).
test('global search: finds a seeded task and product', async ({ page }) => {
  await login(page, 'demo@users.ozmo.local', 'Demo1234!')
  await gotoH(page, '/')

  // Open the palette from the header button.
  await page.getByRole('button', { name: /Szukaj/ }).click()
  const input = page.getByPlaceholder('Szukaj zadań, produktów, osób…')
  await expect(input).toBeVisible({ timeout: 15_000 })

  // Product: "Kawa ziarnista" (seeded).
  await input.fill('Kawa')
  await expect(page.getByRole('button', { name: /Kawa ziarnista/ })).toBeVisible({ timeout: 15_000 })

  // Task: "Otwarcie lokalu" (seeded task title).
  await input.fill('')
  await input.fill('Otwarcie')
  await expect(page.getByRole('button', { name: /Otwarcie lokalu/ })).toBeVisible({ timeout: 15_000 })
})
