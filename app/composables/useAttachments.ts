import { toast } from 'vue-sonner'
import type { Database } from '~~/shared/types/database.types'

export interface Attachment {
  path: string
  name: string
  size: number
  type: string
}

const BUCKET = 'attachments'
const MAX_SIZE = 10 * 1024 * 1024 // 10 MB (also enforced by the bucket)

/**
 * Załączniki w prywatnym buckecie Storage `attachments`.
 * Ścieżka: {org_id}/{branch_id | 'org'}/{context}/{uuid}-nazwa — zgodnie z
 * politykami RLS Storage. Metadane trzymamy w kolumnach jsonb (task_comments,
 * chat_messages, day_notes). Podgląd/pobranie przez podpisane URL-e (cache).
 */
export function useAttachments() {
  const supabase = useSupabaseClient<Database>()
  const signedCache = useState<Record<string, { url: string; expires: number }>>(
    'attachments.signed',
    () => ({}),
  )

  function safeName(name: string) {
    const cleaned = name
      .normalize('NFKD')
      .replace(/[^\w.\-]+/g, '_')
      .replace(/_+/g, '_')
    return cleaned.slice(-80) || 'plik'
  }

  async function upload(
    file: File,
    opts: { orgId: string; branchId?: string | null; context: string },
  ): Promise<Attachment | null> {
    if (file.size > MAX_SIZE) {
      toast.error('Plik jest za duży', { description: 'Maksymalny rozmiar to 10 MB.' })
      return null
    }
    const seg = opts.branchId ?? 'org'
    const path = `${opts.orgId}/${seg}/${opts.context}/${crypto.randomUUID()}-${safeName(file.name)}`
    const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
      contentType: file.type || 'application/octet-stream',
      upsert: false,
    })
    if (error) {
      toast.error('Nie udało się wgrać pliku', { description: error.message })
      return null
    }
    return {
      path,
      name: file.name,
      size: file.size,
      type: file.type || 'application/octet-stream',
    }
  }

  async function signedUrl(path: string): Promise<string | null> {
    const now = Date.now()
    const cached = signedCache.value[path]
    if (cached && cached.expires > now + 30_000) return cached.url
    const { data, error } = await supabase.storage.from(BUCKET).createSignedUrl(path, 3600)
    if (error || !data) return null
    signedCache.value = {
      ...signedCache.value,
      [path]: { url: data.signedUrl, expires: now + 3600 * 1000 },
    }
    return data.signedUrl
  }

  async function remove(path: string) {
    await supabase.storage.from(BUCKET).remove([path])
  }

  function isImage(a: Attachment) {
    return a.type.startsWith('image/')
  }

  function formatSize(bytes: number) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`
  }

  return { upload, signedUrl, remove, isImage, formatSize }
}
