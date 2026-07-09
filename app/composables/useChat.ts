import type { Database } from '~~/shared/types/database.types'

export type ChatChannelType = Database['public']['Enums']['chat_channel_type']

export interface ChatChannel {
  id: string
  org_id: string
  branch_id: string | null
  type: ChatChannelType
  name: string
}

/**
 * Lista kanałów czatu dostępnych dla użytkownika w aktywnej organizacji
 * (kanał ogólny sieci + kanały oddziałów) wraz z licznikiem nieprzeczytanych.
 * RLS decyduje o widoczności; nieprzeczytane = wiadomości po `last_read_at`
 * (z pominięciem własnych).
 */
export function useChat() {
  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const { activeOrgId } = useOrg()

  // Po twardym wejściu na stronę `user.value` to *claims* JWT (`.sub`, bez `.id`)
  // zanim klient odświeży sesję. Bierzemy stabilny identyfikator z `.id` lub `.sub`.
  const uid = computed(
    () => user.value?.id ?? (user.value as { sub?: string } | null)?.sub ?? null,
  )

  const channels = useState<ChatChannel[]>('chat.channels', () => [])
  const unreadMap = useState<Record<string, number>>('chat.unread', () => ({})) // channel_id -> count
  const loaded = useState<boolean>('chat.loaded', () => false)

  async function loadChannels(force = false) {
    if (loaded.value && !force) return
    if (!activeOrgId.value || !uid.value) {
      channels.value = []
      unreadMap.value = {}
      loaded.value = true
      return
    }
    const { data } = await supabase
      .from('chat_channels')
      .select('id, org_id, branch_id, type, name')
      .eq('org_id', activeOrgId.value)
      .order('type') // 'org' < 'branch' < 'custom'
      .order('name')
    channels.value = (data ?? []) as ChatChannel[]
    await refreshUnread()
    loaded.value = true
  }

  async function refreshUnread() {
    if (!uid.value) return
    const { data: reads } = await supabase
      .from('chat_reads')
      .select('channel_id, last_read_at')
    const readMap = new Map((reads ?? []).map((r) => [r.channel_id, r.last_read_at]))

    const counts = await Promise.all(
      channels.value.map(async (ch) => {
        let q = supabase
          .from('chat_messages')
          .select('id', { count: 'exact', head: true })
          .eq('channel_id', ch.id)
          .neq('author_id', uid.value)
        const last = readMap.get(ch.id)
        if (last) q = q.gt('created_at', last)
        const { count } = await q
        return [ch.id, count ?? 0] as const
      }),
    )
    unreadMap.value = Object.fromEntries(counts)
  }

  async function markRead(channelId: string) {
    if (!uid.value) return
    await supabase
      .from('chat_reads')
      .upsert({ channel_id: channelId, user_id: uid.value, last_read_at: new Date().toISOString() })
    unreadMap.value = { ...unreadMap.value, [channelId]: 0 }
  }

  const totalUnread = computed(() =>
    Object.values(unreadMap.value).reduce((a, b) => a + b, 0),
  )

  return { channels, unreadMap, totalUnread, loaded, loadChannels, refreshUnread, markRead }
}
