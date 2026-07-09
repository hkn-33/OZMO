import { test, expect } from '@playwright/test'
import { unique, escapeRegex, PASSWORD, gotoH } from './helpers'

test('create branch → invite → second user registers via link → accepts → sees branch', async ({
  browser,
}) => {
  const s = unique()
  const orgName = `Sieć ${s}`
  const branchName = `Lokal ${s}`
  const inviteEmail = `emp_${s}@ozmo.test`

  // --- Owner: register, create org, create branch, invite ---
  const ownerCtx = await browser.newContext()
  const op = await ownerCtx.newPage()

  await gotoH(op, '/auth/register')
  await op.fill('#email', `owner_${s}@ozmo.test`)
  await op.fill('#password', PASSWORD)
  await op.getByRole('button', { name: 'Zarejestruj się' }).click()
  await op.waitForURL((url) => !url.pathname.startsWith('/auth'))
  await gotoH(op, '/onboarding')
  await op.fill('#name', orgName)
  await op.getByRole('button', { name: 'Utwórz organizację' }).click()
  await op.waitForURL((url) => url.pathname === '/')

  // Create branch
  await gotoH(op, '/branches')
  await op.getByRole('button', { name: 'Dodaj oddział' }).click()
  await op.fill('#b-name', branchName)
  await op.getByRole('button', { name: 'Zapisz' }).click()
  await expect(op.getByText(branchName)).toBeVisible()

  // Create invitation (member + branch employee)
  await gotoH(op, '/people')
  await op.getByRole('button', { name: 'Zaproś' }).click()
  await op.fill('#inv-email', inviteEmail)
  // Assign branch (combobox currently reads "Bez przypisania")
  await op.getByRole('combobox').filter({ hasText: 'Bez przypisania' }).click()
  await op.getByRole('option', { name: branchName }).click()
  await op.getByRole('button', { name: 'Utwórz zaproszenie' }).click()

  // Read the invite URL from the readonly input, extract token.
  const linkInput = op.locator('input[readonly]')
  await expect(linkInput).toBeVisible()
  const inviteUrl = await linkInput.inputValue()
  const token = inviteUrl.split('/').filter(Boolean).pop()!
  expect(token.length).toBeGreaterThan(10)

  // --- Second user: open invite link, register, auto-accept ---
  const empCtx = await browser.newContext()
  const ep = await empCtx.newPage()
  await gotoH(ep, `/auth/invite/${token}`)
  await ep.getByRole('link', { name: 'Załóż konto' }).click()
  await ep.waitForURL('**/auth/register**')
  await ep.fill('#email', inviteEmail)
  await ep.fill('#password', PASSWORD)
  await ep.getByRole('button', { name: 'Zarejestruj się' }).click()

  // register → next (invite page) → auto-accept → redirect to dashboard
  await ep.waitForURL((url) => url.pathname === '/', { timeout: 30_000 })

  // Dashboard "Moje oddziały" lists the branch the user was added to.
  await expect(
    ep.getByText(new RegExp(escapeRegex(branchName))).first(),
  ).toBeVisible({ timeout: 20_000 })

  await ownerCtx.close()
  await empCtx.close()
})
