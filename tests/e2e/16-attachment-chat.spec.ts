import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH, escapeRegex } from './helpers'

// 1x1 PNG fixture (attachments bucket allows image/png).
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
)

// Attachment upload in a chat message renders an inline image preview (ws 5).
test('chat: upload an image attachment → preview renders in the message', async ({ browser }) => {
  const seed = await seedOrgWithUsers()
  const nameRe = new RegExp(escapeRegex(seed.branchName))

  const ctx = await browser.newContext()
  const page = await ctx.newPage()
  await login(page, seed.owner.email)

  await gotoH(page, '/chat')
  await expect(page.getByText('Kanały')).toBeVisible()
  await page.locator('main').getByRole('button', { name: nameRe }).click()
  await expect(page.getByPlaceholder(/Napisz wiadomość/)).toBeVisible()

  // Attach the image via the hidden file input.
  await page.locator('input[type="file"]').setInputFiles({
    name: 'sample.png',
    mimeType: 'image/png',
    buffer: PNG,
  })
  await expect(page.getByText('sample.png').first()).toBeVisible({ timeout: 15_000 })

  // Send (Enter in the composer). Caption keeps the message easy to locate.
  const box = page.getByPlaceholder(/Napisz wiadomość/)
  await box.fill(`Zdjęcie ${seed.suffix}`)
  await box.press('Enter')

  await expect(page.getByText(`Zdjęcie ${seed.suffix}`)).toBeVisible({ timeout: 10_000 })
  await expect(page.locator('main img[alt="sample.png"]')).toBeVisible({ timeout: 15_000 })

  await ctx.close()
})
