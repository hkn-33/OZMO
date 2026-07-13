import type { ClassValue } from "clsx"
import { clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

const plDateTime = new Intl.DateTimeFormat('pl-PL', {
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
})
const plDate = new Intl.DateTimeFormat('pl-PL', {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
})

export function localDateKey(date = new Date()) {
  return new Date(date.getTime() - date.getTimezoneOffset() * 60_000).toISOString().slice(0, 10)
}

/** Krótki polski znacznik czasu (np. „9 lip, 14:30"). */
export function formatDateTime(value: string | Date | null | undefined) {
  if (!value) return ''
  return plDateTime.format(new Date(value))
}

/** Polska data (np. „9 lip 2026"). */
export function formatDate(value: string | Date | null | undefined) {
  if (!value) return ''
  return plDate.format(new Date(value))
}

/** Względny czas po polsku („teraz", „5 min temu", „2 godz temu", inaczej data). */
export function formatRelative(value: string | Date | null | undefined) {
  if (!value) return ''
  const d = new Date(value)
  const diff = Date.now() - d.getTime()
  const min = Math.round(diff / 60000)
  if (min < 1) return 'teraz'
  if (min < 60) return `${min} min temu`
  const hrs = Math.round(min / 60)
  if (hrs < 24) return `${hrs} godz temu`
  return plDateTime.format(d)
}
