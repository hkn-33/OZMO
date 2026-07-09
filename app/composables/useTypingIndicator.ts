/**
 * Wskaźnik pisania (ephemeryczny broadcast, event 'typing' na kanale chat:{id}).
 * Bez zapisu w bazie. Wpisy wygasają po 3 s bez zdarzeń; wysyłka throttlowana
 * do 1/2 s. Reużywalny (chat grupowy; można podpiąć też do wątku komentarzy).
 */
export interface TypingPayload {
  id: string
  name: string
}

export function useTypingIndicator(selfId: () => string | undefined) {
  const typers = ref<Map<string, { name: string; timer: ReturnType<typeof setTimeout> }>>(
    new Map(),
  )

  const label = computed(() => {
    const names = [...typers.value.values()].map((t) => t.name)
    if (names.length === 0) return ''
    if (names.length === 1) return `${names[0]} pisze…`
    if (names.length === 2) return `${names[0]} i ${names[1]} piszą…`
    return 'Kilka osób pisze…'
  })

  function receive(payload: TypingPayload | undefined) {
    if (!payload?.id || payload.id === selfId()) return
    const existing = typers.value.get(payload.id)
    if (existing) clearTimeout(existing.timer)
    const timer = setTimeout(() => {
      typers.value.delete(payload.id)
      typers.value = new Map(typers.value)
    }, 3000)
    typers.value.set(payload.id, { name: payload.name || 'Ktoś', timer })
    typers.value = new Map(typers.value)
  }

  let lastSent = 0
  /** Owija akcję wysyłki, przepuszczając ją co najwyżej raz na 2 s. */
  function throttle(send: () => void) {
    return () => {
      const now = Date.now()
      if (now - lastSent < 2000) return
      lastSent = now
      send()
    }
  }

  function clear() {
    for (const t of typers.value.values()) clearTimeout(t.timer)
    typers.value = new Map()
    lastSent = 0
  }

  return { label, receive, throttle, clear }
}
