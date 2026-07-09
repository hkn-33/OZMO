import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, escapeRegex, gotoH } from './helpers'

test('group chat: live delivery (no reload) + typing indicator across two contexts', async ({
  browser,
}) => {
  const seed = await seedOrgWithUsers()
  const message = `Cześć zespół ${seed.suffix}`
  const nameRe = new RegExp(escapeRegex(seed.branchName))

  async function openBranchChannel(page: import('@playwright/test').Page) {
    await gotoH(page, '/chat')
    await expect(page.getByText('Kanały')).toBeVisible()
    await page.locator('main').getByRole('button', { name: nameRe }).click()
  }

  // Employee opens the branch channel first and subscribes to realtime.
  const empCtx = await browser.newContext()
  const ep = await empCtx.newPage()
  await login(ep, seed.emp.email)
  await openBranchChannel(ep)
  await expect(ep.getByPlaceholder(/Napisz wiadomość/)).toBeVisible()
  await ep.waitForTimeout(4000) // allow the private realtime channel to subscribe

  // Owner opens the same channel.
  const ownerCtx = await browser.newContext()
  const op = await ownerCtx.newPage()
  await login(op, seed.owner.email)
  await openBranchChannel(op)
  const input = op.getByPlaceholder(/Napisz wiadomość/)
  await expect(input).toBeVisible()
  await op.waitForTimeout(3000) // owner's private channel begins subscribing

  // Owner types → employee sees the typing indicator (client broadcast on chat:{id}).
  // Retry typing until it lands, to absorb the owner channel's subscribe latency.
  await expect(async () => {
    await input.click()
    await input.pressSequentially('pisze', { delay: 60 })
    await input.press('Backspace')
    await expect(ep.getByTestId('typing-indicator')).toContainText('pisze', {
      timeout: 2500,
    })
  }).toPass({ timeout: 30_000 })

  // Owner sends → employee receives it LIVE, without any reload.
  await input.fill(message)
  await input.press('Enter')
  await expect(op.getByText(message)).toBeVisible() // optimistic (sender)
  await expect(ep.getByText(message)).toBeVisible({ timeout: 10_000 })

  await ownerCtx.close()
  await empCtx.close()
})
