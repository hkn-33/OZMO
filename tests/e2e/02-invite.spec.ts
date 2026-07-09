import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH, waitForHydration } from './helpers'

test('add employee by username → they can log in with the username + temp password', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const username = `jan${seed.suffix}` // valid: a-z0-9_.-

  const ownerCtx = await browser.newContext()
  const op = await ownerCtx.newPage()
  await login(op, seed.owner.email)

  await gotoH(op, '/people')
  await op.getByRole('button', { name: 'Dodaj pracownika' }).click()
  const dialog = op.getByRole('dialog')
  await op.fill('#m-username', username)
  await op.fill('#m-name', 'Jan Testowy')
  await dialog.getByRole('button', { name: 'Dodaj pracownika' }).click()

  // Result screen exposes username + one-time temp password (readonly inputs).
  const readonly = op.locator('input[readonly]')
  await expect(readonly.first()).toBeVisible({ timeout: 15_000 })
  const shownUsername = await readonly.nth(0).inputValue()
  const tempPassword = await readonly.nth(1).inputValue()
  expect(shownUsername).toBe(username)
  expect(tempPassword.length).toBeGreaterThan(6)

  // New context: log in with the username (no @) — first login forces a
  // password change (must_change_password).
  const empCtx = await browser.newContext()
  const ep = await empCtx.newPage()
  await gotoH(ep, '/auth/login')
  await ep.fill('#email', username)
  await ep.fill('#password', tempPassword)
  await ep.getByRole('button', { name: 'Zaloguj się' }).click()

  await ep.waitForURL('**/auth/change-password', { timeout: 30_000 })
  await expect(ep.getByRole('heading', { name: 'Ustaw nowe hasło' })).toBeVisible()

  // Change the password → lands in the app.
  await waitForHydration(ep)
  await ep.fill('#pw', 'NoweHaslo123')
  await ep.fill('#pw2', 'NoweHaslo123')
  await ep.getByRole('button', { name: 'Zapisz hasło' }).click()
  await ep.waitForURL((url) => !url.pathname.startsWith('/auth'), { timeout: 30_000 })

  await ownerCtx.close()
  await empCtx.close()
})
