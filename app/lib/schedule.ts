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

// --- Role/position color coding (token contract: categorical Wong palette) ---
// Colour carries ONE meaning only: the position (stanowisko). Draft/published and
// "own shift" are expressed through opacity/border/ring, never through hue.

/** CSS var references for the categorical palette, in order of use. */
export const CAT_COLORS = [
  'var(--cat-1)', 'var(--cat-2)', 'var(--cat-3)', 'var(--cat-4)', 'var(--cat-5)',
] as const

/**
 * Stable color assignment per distinct position within a branch. Distinct
 * positions are sorted (Polish collation) and mapped ordinally to --cat-1..5,
 * cycling when there are more than five. Positions that are empty/null get no
 * color (neutral gray treatment on the card).
 */
export function buildPositionColors(positions: (string | null | undefined)[]): Map<string, string> {
  const distinct = [
    ...new Set(
      positions
        .map((p) => p?.trim())
        .filter((p): p is string => !!p),
    ),
  ].sort((a, b) => a.localeCompare(b, 'pl'))
  const map = new Map<string, string>()
  distinct.forEach((p, i) => map.set(p, CAT_COLORS[i % CAT_COLORS.length]!))
  return map
}

/** Color var for a position, or null when unset (→ neutral). */
export function positionColor(
  colors: Map<string, string>,
  position: string | null | undefined,
): string | null {
  const key = position?.trim()
  return key ? colors.get(key) ?? null : null
}

/**
 * Inline style for a shift card: strong colored left edge + soft tinted background
 * of the role color. Text stays foreground (the tint is only ~9% over --card, so
 * foreground text clears WCAG AA comfortably). Null color → neutral gray edge.
 */
export function shiftCardStyle(color: string | null): Record<string, string> {
  if (!color) {
    return { borderLeftColor: 'var(--border)' }
  }
  return {
    borderLeftColor: color,
    backgroundColor: `color-mix(in oklab, ${color} 9%, var(--card))`,
  }
}
