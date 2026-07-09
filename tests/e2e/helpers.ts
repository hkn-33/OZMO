import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Page } from '@playwright/test'

const __dirname = dirname(fileURLToPath(import.meta.url))

/** Parse the project's .env (Playwright doesn't auto-load it). */
export function loadEnv(): Record<string, string> {
  const path = resolve(__dirname, '../../.env')
  const out: Record<string, string> = {}
  for (const line of readFileSync(path, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/)
    if (m) out[m[1]] = m[2].replace(/^["']|["']$/g, '')
  }
  return out
}

const env = loadEnv()
export const SUPABASE_URL = env.SUPABASE_URL
export const SERVICE_KEY = env.SUPABASE_SERVICE_KEY

/** Service-role admin client (bypasses RLS) for fast test seeding. */
export function adminClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}

/** Unique, url-safe suffix per run (lowercase alnum). */
export function unique(): string {
  return (
    Date.now().toString(36) + Math.random().toString(36).slice(2, 6)
  ).toLowerCase()
}

export function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

export const PASSWORD = 'password123'

export interface TestUser {
  email: string
  password: string
  fullName: string
  id: string
}

async function createUser(
  admin: SupabaseClient,
  email: string,
  fullName: string,
): Promise<TestUser> {
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: PASSWORD,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  })
  if (error) throw new Error(`createUser: ${error.message}`)
  return { email, password: PASSWORD, fullName, id: data.user!.id }
}

export interface SeededOrg {
  admin: SupabaseClient
  suffix: string
  owner: TestUser
  emp: TestUser
  orgId: string
  orgName: string
  branchId: string
  branchName: string
}

/**
 * Seed (service_role): one org, one branch, an owner (also branch manager) and
 * an employee (branch employee). Triggers seed 5 checklist templates + org/branch
 * chat channels automatically. Used as precondition for feature tests; the feature
 * under test is still driven through the browser UI.
 */
export async function seedOrgWithUsers(): Promise<SeededOrg> {
  const admin = adminClient()
  const s = unique()
  const owner = await createUser(admin, `owner_${s}@ozmo.test`, `Olaf Owner ${s}`)
  const emp = await createUser(admin, `emp_${s}@ozmo.test`, `Ewa Emp ${s}`)

  const orgName = `Sieć ${s}`
  const { data: org, error: orgErr } = await admin
    .from('organizations')
    .insert({ name: orgName, slug: `siec-${s}`, created_by: owner.id })
    .select()
    .single()
  if (orgErr) throw new Error(`org: ${orgErr.message}`)

  // Test orgs are fully functional (network plan), like existing/seeded orgs.
  // The org-creation trigger provisions a 'demo' subscription; promote it.
  const { error: subErr } = await admin
    .from('subscriptions')
    .update({ plan: 'network' })
    .eq('org_id', org.id)
  if (subErr) throw new Error(`subscription: ${subErr.message}`)

  const { error: omErr } = await admin.from('org_members').insert([
    { org_id: org.id, user_id: owner.id, role: 'owner' },
    { org_id: org.id, user_id: emp.id, role: 'member' },
  ])
  if (omErr) throw new Error(`org_members: ${omErr.message}`)

  const branchName = `Lokal ${s}`
  const { data: branch, error: brErr } = await admin
    .from('branches')
    .insert({ org_id: org.id, name: branchName })
    .select()
    .single()
  if (brErr) throw new Error(`branch: ${brErr.message}`)

  const { error: bmErr } = await admin.from('branch_members').insert([
    { branch_id: branch.id, user_id: owner.id, role: 'manager', position: 'Kierownik' },
    { branch_id: branch.id, user_id: emp.id, role: 'employee', position: 'Kelner' },
  ])
  if (bmErr) throw new Error(`branch_members: ${bmErr.message}`)

  return {
    admin,
    suffix: s,
    owner,
    emp,
    orgId: org.id,
    orgName,
    branchId: branch.id,
    branchName,
  }
}

/**
 * Wait for Nuxt client hydration to finish. In dev the route is compiled
 * on-demand, so interacting before hydration triggers a native form submit
 * (v-model / @submit.prevent not yet attached). `#__nuxt.__vue_app__` is set
 * once the Vue app has mounted/hydrated.
 */
export async function waitForHydration(page: Page) {
  await page.waitForFunction(
    () => {
      const el = document.getElementById('__nuxt') as unknown as {
        __vue_app__?: unknown
      } | null
      return !!el && !!el.__vue_app__
    },
    { timeout: 30_000 },
  )
}

/** Full-page navigate and wait until hydrated before any interaction. */
export async function gotoH(page: Page, path: string) {
  await page.goto(path)
  await waitForHydration(page)
}

/** Log in through the real login UI and wait until off the auth pages. */
export async function login(page: Page, email: string, password = PASSWORD) {
  await gotoH(page, '/auth/login')
  await page.fill('#email', email)
  await page.fill('#password', password)
  await page.getByRole('button', { name: 'Zaloguj się' }).click()
  await page.waitForURL((url) => !url.pathname.startsWith('/auth'), {
    timeout: 30_000,
  })
}
