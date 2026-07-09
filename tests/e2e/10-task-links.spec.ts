import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH } from './helpers'

test('task linking: add a related task and navigate to it', async ({ page }) => {
  const seed = await seedOrgWithUsers()
  const titleA = `Zadanie A ${seed.suffix}`
  const titleB = `Zadanie B ${seed.suffix}`
  const { error } = await seed.admin.from('tasks').insert([
    { org_id: seed.orgId, branch_id: seed.branchId, title: titleA, created_by: seed.owner.id, position: 1 },
    { org_id: seed.orgId, branch_id: seed.branchId, title: titleB, created_by: seed.owner.id, position: 2 },
  ])
  expect(error).toBeNull()

  await login(page, seed.owner.email)
  await gotoH(page, '/tasks')

  await page.getByText(titleA).first().click()
  const sheet = page.getByRole('dialog')
  await expect(sheet.getByText('Powiązane zadania')).toBeVisible()

  await sheet.getByRole('button', { name: 'Powiąż zadanie' }).click()
  await sheet.getByPlaceholder('Szukaj zadania…').fill(titleB)
  await sheet.getByTestId('link-candidate').filter({ hasText: titleB }).click()

  const linked = sheet.getByTestId('linked-task').filter({ hasText: titleB })
  await expect(linked).toBeVisible()

  // Navigating to the linked task swaps the sheet to it.
  await linked.click()
  await expect(sheet.getByRole('heading', { name: titleB })).toBeVisible()
})
