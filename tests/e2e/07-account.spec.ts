import { test, expect } from '@playwright/test'
import { seedOrgWithUsers, login, gotoH, adminClient, PASSWORD } from './helpers'

test('RODO: last-owner guard blocks deletion when org has other members', async ({ page }) => {
  const seed = await seedOrgWithUsers() // owner is sole owner, org also has emp
  await login(page, seed.owner.email)
  await gotoH(page, '/settings')

  await page.getByRole('button', { name: 'Usuń konto', exact: true }).click()
  await page.fill('#confirm', 'USUŃ')
  await page.getByRole('button', { name: 'Usuń konto na stałe' }).click()

  // Blocked with the Polish last-owner message
  await expect(page.getByText(/jedynym właścicielem/i)).toBeVisible()

  // Account intact: owner still a member
  const { count } = await seed.admin
    .from('org_members')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', seed.owner.id)
  expect(count).toBe(1)
})

test('RODO: account deletion anonymizes profile, blocks login, keeps authored content', async ({
  page,
}) => {
  const seed = await seedOrgWithUsers()

  // Employee authors a day note (legitimate-interest content that must survive)
  const noteBody = `Notatka ${seed.suffix}`
  const { data: note } = await seed.admin
    .from('day_notes')
    .insert({
      org_id: seed.orgId,
      branch_id: seed.branchId,
      author_id: seed.emp.id,
      date: '2026-07-09',
      body: noteBody,
      severity: 'info',
    })
    .select('id')
    .single()

  await login(page, seed.emp.email)

  // Update profile first (exercises the settings page), then delete.
  // Wait for the profile to load (proves the client user session resolved).
  await gotoH(page, '/settings')
  await expect(page.locator('#fullName')).toHaveValue(/Ewa Emp/)
  await page.fill('#fullName', 'Ewa Testowa')
  await page.getByRole('button', { name: 'Zapisz' }).first().click()
  await expect(page.getByText('Zapisano dane profilu')).toBeVisible()

  await page.getByRole('button', { name: 'Usuń konto', exact: true }).click()
  await page.fill('#confirm', 'USUŃ')
  await page.getByRole('button', { name: 'Usuń konto na stałe' }).click()

  // Redirected to login after deletion
  await page.waitForURL('**/auth/login', { timeout: 20_000 })

  // Cannot log in anymore (auth user is banned) — attempt via the real login form
  await page.fill('#email', seed.emp.email)
  await page.fill('#password', PASSWORD)
  await page.getByRole('button', { name: 'Zaloguj się' }).click()
  await expect(page.getByText(/Nie udało się zalogować/i)).toBeVisible()

  // Profile anonymized
  const admin = adminClient()
  const { data: prof } = await admin
    .from('profiles')
    .select('full_name, phone, avatar_url')
    .eq('id', seed.emp.id)
    .single()
  expect(prof?.full_name).toBe('Usunięty użytkownik')
  expect(prof?.phone).toBeNull()

  // Memberships removed
  const { count: omCount } = await admin
    .from('org_members')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', seed.emp.id)
  expect(omCount).toBe(0)
  const { count: bmCount } = await admin
    .from('branch_members')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', seed.emp.id)
  expect(bmCount).toBe(0)

  // Authored content kept; org data intact
  const { data: keptNote } = await admin
    .from('day_notes')
    .select('id, author_id, body')
    .eq('id', note!.id)
    .maybeSingle()
  expect(keptNote?.body).toBe(noteBody)
  expect(keptNote?.author_id).toBe(seed.emp.id)

  const { count: orgCount } = await admin
    .from('organizations')
    .select('*', { count: 'exact', head: true })
    .eq('id', seed.orgId)
  expect(orgCount).toBe(1)
})
