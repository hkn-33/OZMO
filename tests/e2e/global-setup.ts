import { SUPABASE_URL, SERVICE_KEY } from './helpers'

/**
 * Global setup: fail fast with a clear message if the local Supabase stack isn't
 * reachable (tests seed data through the service_role key). Test users/org/branch
 * are created fresh per test with unique slugs/emails (see helpers.seedOrgWithUsers),
 * so runs are repeatable without a cleanup step.
 */
export default async function globalSetup() {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    throw new Error(
      'Brak SUPABASE_URL / SUPABASE_SERVICE_KEY w .env — uruchom `supabase start` i uzupełnij .env.',
    )
  }
  const res = await fetch(`${SUPABASE_URL}/rest/v1/`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  }).catch(() => null)
  if (!res) {
    throw new Error(
      `Lokalny Supabase nie odpowiada pod ${SUPABASE_URL}. Uruchom \`supabase start\`.`,
    )
  }
}
