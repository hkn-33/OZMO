import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, escapeRegex, gotoH } from './helpers'

test('task with checklist template → assignee notified → toggle item → @mention comment', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const title = `Otwarcie zmiany ${seed.suffix}`

  const ownerCtx = await browser.newContext()
  const op = await ownerCtx.newPage()
  await login(op, seed.owner.email)
  await gotoH(op, '/tasks')
  await op.getByRole('button', { name: 'Nowe zadanie' }).click()

  await op.fill('#t-title', title)
  // Choose a checklist template (placeholder "Bez szablonu")
  await op.getByRole('combobox').filter({ hasText: 'Bez szablonu' }).click()
  await op.getByRole('option', { name: /Otwarcie lokalu/ }).click()
  // Assign the employee (click the row label toggles its checkbox)
  await op.locator('label').filter({ hasText: seed.emp.fullName }).click()
  await op.getByRole('button', { name: 'Utwórz zadanie' }).click()
  await expect(op.getByText('Zadanie utworzone')).toBeVisible()

  const empCtx = await browser.newContext()
  const ep = await empCtx.newPage()
  await login(ep, seed.emp.email)
  await gotoH(ep, '/tasks')

  const badge = ep.locator('header .rounded-full.bg-primary')
  await expect(badge).toBeVisible({ timeout: 20_000 })
  // Confirm it is the assignment notification (clicking the badge opens the bell)
  await badge.click()
  await expect(ep.getByText('Przypisano Ci zadanie')).toBeVisible()
  await ep.keyboard.press('Escape')

  await ep.getByRole('button', { name: new RegExp(escapeRegex(title)) }).click()
  const sheet = ep.getByRole('dialog')
  await expect(sheet).toBeVisible()
  const firstItem = sheet.getByRole('checkbox').first()
  await expect(firstItem).toBeVisible()
  await firstItem.click()
  await expect(firstItem).toBeChecked()

  const commentBox = sheet.getByPlaceholder(/Napisz komentarz/)
  await commentBox.click()
  await commentBox.type('Zaczynam @Olaf')
  // mention dropdown → pick the owner
  await ep.getByRole('button', { name: new RegExp(escapeRegex(seed.owner.fullName)) }).click()
  await commentBox.press('Enter')
  await expect(sheet.getByText(/Zaczynam/)).toBeVisible()

  await ownerCtx.close()
  await empCtx.close()
})
