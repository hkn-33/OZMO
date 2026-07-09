// Timezone helpers for the schedule (M5). Times are stored as timestamptz and
// displayed / bucketed in the branch's timezone (branches.timezone).

/** Offset (minutes) of tz at the given instant. */
function tzOffset(date: Date, tz: string): number {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  })
  const map: Record<string, string> = {}
  for (const p of dtf.formatToParts(date)) map[p.type] = p.value
  const asUTC = Date.UTC(
    Number(map.year), Number(map.month) - 1, Number(map.day),
    map.hour === '24' ? 0 : Number(map.hour), Number(map.minute), Number(map.second),
  )
  return (asUTC - date.getTime()) / 60000
}

/** Wall-clock date (YYYY-MM-DD) + time (HH:MM) in tz → UTC ISO instant. */
export function zonedTimeToIso(dateStr: string, timeStr: string, tz: string): string {
  const [y, m, d] = dateStr.split('-').map(Number)
  const [hh, mm] = timeStr.split(':').map(Number)
  const asUTC = Date.UTC(y!, m! - 1, d!, hh!, mm!)
  const off = tzOffset(new Date(asUTC), tz)
  return new Date(asUTC - off * 60000).toISOString()
}

/** Calendar date key (YYYY-MM-DD) of an instant, in tz. */
export function tzDateKey(iso: string, tz: string): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date(iso))
}

/** Time-of-day (HH:MM) of an instant, in tz. */
export function tzTime(iso: string, tz: string): string {
  return new Intl.DateTimeFormat('pl-PL', {
    timeZone: tz, hour: '2-digit', minute: '2-digit',
  }).format(new Date(iso))
}
