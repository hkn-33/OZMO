import type { RealtimeChannel } from '@supabase/supabase-js'
import type { Database } from '~~/shared/types/database.types'

export type NotificationType = Database['public']['Enums']['notification_type']

export interface NotificationRow {
  id: string
  user_id: string
  org_id: string
  type: NotificationType
  payload: {
    task_id?: string
    comment_id?: string
    title?: string
    author_id?: string
    branch_id?: string
    shift_id?: string
    starts_at?: string
    ends_at?: string
    position?: string
  }
  created_at: string
  read_at: string | null
}

/**
 * Powiadomienia zalogowanego użytkownika: wczytanie z tabeli `notifications`
 * + realtime na prywatnym kanale `user:{uuid}` (broadcast z bazy).
 * Nieprzeczytane przetrwają reconnect (źródło = tabela).
 */
export function useNotifications() {
  const supabase = useSupabaseClient<Database>()
  const user = useSupabaseUser()

  const items = useState<NotificationRow[]>('notif.items', () => [])
  const loaded = useState<boolean>('notif.loaded', () => false)
  const channel = useState<RealtimeChannel | null>('notif.channel', () => null)

  const unread = computed(() => items.value.filter((n) => !n.read_at).length)

  async function load(force = false) {
    if (!user.value) return
    if (loaded.value && !force) return
    const { data } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50)
    items.value = (data ?? []) as NotificationRow[]
    loaded.value = true
  }

  async function subscribe() {
    if (!user.value || channel.value) return
    const { data } = await supabase.auth.getSession()
    if (data.session) await supabase.realtime.setAuth(data.session.access_token)

    const ch = supabase
      .channel(`user:${user.value.id}`, { config: { private: true } })
      .on('broadcast', { event: 'new_notification' }, () => {
        // źródłem prawdy jest tabela — dociągamy świeże wiersze
        load(true)
      })
    ch.subscribe()
    channel.value = ch
  }

  function unsubscribe() {
    if (channel.value) {
      supabase.removeChannel(channel.value)
      channel.value = null
    }
  }

  async function markRead(id: string) {
    const now = new Date().toISOString()
    const { error } = await supabase
      .from('notifications')
      .update({ read_at: now })
      .eq('id', id)
    if (!error) {
      const n = items.value.find((x) => x.id === id)
      if (n) n.read_at = now
    }
  }

  async function markAllRead() {
    const ids = items.value.filter((n) => !n.read_at).map((n) => n.id)
    if (!ids.length) return
    const now = new Date().toISOString()
    const { error } = await supabase
      .from('notifications')
      .update({ read_at: now })
      .in('id', ids)
    if (!error) {
      items.value.forEach((n) => {
        if (!n.read_at) n.read_at = now
      })
    }
  }

  return { items, unread, loaded, load, subscribe, unsubscribe, markRead, markAllRead }
}
