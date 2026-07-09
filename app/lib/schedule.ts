// Shared schedule constants. weekday: 0=Monday .. 6=Sunday (Monday-start UI).

export const WEEKDAYS_FULL = [
  'Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela',
] as const

export const WEEKDAYS_SHORT = [
  'Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Nd',
] as const

/** weekday index (0=Mon..6=Sun) for a JS Date interpreted in local calendar. */
export function weekdayIndex(d: Date): number {
  return (d.getDay() + 6) % 7
}
