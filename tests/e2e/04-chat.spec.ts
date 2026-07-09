import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, escapeRegex, gotoH } from './helpers'

test('group chat: message sent in branch channel is received live by second user', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const message = `Cześć zespół ${seed.suffix}`
  const nameRe = new RegExp(escapeRegex(seed.branchName))

  async function openBranchChannel(page: import('@playwright/test').Page) {
    await gotoH(page, '/chat')
    await expect(page.getByText('Kanały')).toBeVisible()
    // The channel list lives in <main>; the header branch picker (same name) is
    // outside it, so scope to main to pick the branch channel unambiguously.
    await page.locator('main').getByRole('button', { name: nameRe }).click()
  }

  // Employee opens the branch channel first and subscribes to realtime.
  const empCtx = await browser.newContext()
  const ep = await empCtx.newPage()
  await login(ep, seed.emp.email)
  await openBranchChannel(ep)
  // Wait for the window to settle (empty state or loaded) before the other side sends.
  await expect(
    ep.getByPlaceholder(/Napisz wiadomość/),
  ).toBeVisible()
  await ep.waitForTimeout(5000) // allow the private realtime channel to finish subscribing

  // Owner opens the same channel and sends a message.
  const ownerCtx = await browser.newContext()
  const op = await ownerCtx.newPage()
  await login(op, seed.owner.email)
  await openBranchChannel(op)
  const input = op.getByPlaceholder(/Napisz wiadomość/)
  await input.fill(message)
  await input.press('Enter')
  // Sender sees own message (optimistic)
  await expect(op.getByText(message)).toBeVisible()

  // Employee receives it live via the chat:{id} broadcast.
  await expect(ep.getByText(message)).toBeVisible({ timeout: 20_000 })

  await ownerCtx.close()
  await empCtx.close()
})
