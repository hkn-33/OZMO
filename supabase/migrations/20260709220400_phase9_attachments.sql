-- Phase 9 (workstream 5) — attachments (Supabase Storage + jsonb metadata).
-- Private bucket 'attachments'; path convention:
--   {org_id}/{branch_id | 'org'}/{context}/{uuid}-filename
-- Storage RLS: read if org member with branch access; insert if same.
-- Size/mime enforced at bucket level (10MB, images + pdf + common docs).
-- Each of task_comments / chat_messages / day_notes gains an attachments jsonb
-- array: [{ path, name, size, type }].

-- =============================================================
-- Metadata columns.
-- =============================================================
alter table public.task_comments add column attachments jsonb not null default '[]'::jsonb;
alter table public.chat_messages add column attachments jsonb not null default '[]'::jsonb;
alter table public.day_notes add column attachments jsonb not null default '[]'::jsonb;

-- Include attachments in the realtime broadcast payloads so receivers can
-- render them without a refetch.
create or replace function public.broadcast_chat_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'id', new.id,
      'channel_id', new.channel_id,
      'author_id', new.author_id,
      'body', new.body,
      'attachments', new.attachments,
      'created_at', new.created_at
    ),
    'new_message',
    'chat:' || new.channel_id::text,
    true
  );
  return new;
end;
$$;

create or replace function public.broadcast_task_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'id', new.id,
      'task_id', new.task_id,
      'author_id', new.author_id,
      'body', new.body,
      'mentions', new.mentions,
      'attachments', new.attachments,
      'created_at', new.created_at
    ),
    'new_comment',
    'task:' || new.task_id::text,
    true
  );
  return new;
end;
$$;

-- =============================================================
-- Storage bucket (private) + size/mime limits.
-- =============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments', 'attachments', false, 10485760,
  array[
    'image/png', 'image/jpeg', 'image/gif', 'image/webp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain', 'text/csv'
  ]
)
on conflict (id) do nothing;

-- =============================================================
-- Path authorization helper. Parses {org_id}/{branch|'org'}/... and checks
-- org membership + branch access. Security definer; not exposed via PostgREST.
-- =============================================================
create function private.can_access_attachment(_name text)
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  _parts text[];
  _org uuid;
  _branch text;
begin
  _parts := string_to_array(_name, '/');
  if array_length(_parts, 1) < 2 then
    return false;
  end if;
  begin
    _org := _parts[1]::uuid;
  exception when others then
    return false;
  end;
  if not private.is_org_member(_org) then
    return false;
  end if;
  _branch := _parts[2];
  if _branch = 'org' then
    return true;
  end if;
  begin
    return private.has_branch_access(_branch::uuid);
  exception when others then
    return false;
  end;
end;
$$;

revoke all on function private.can_access_attachment(text) from public;
grant execute on function private.can_access_attachment(text) to authenticated;

-- =============================================================
-- Storage RLS policies on storage.objects for the 'attachments' bucket.
-- =============================================================
create policy "attachments_read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'attachments'
    and private.can_access_attachment(name)
  );

create policy "attachments_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and owner = (select auth.uid())
    and private.can_access_attachment(name)
  );

create policy "attachments_delete_owner"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'attachments'
    and owner = (select auth.uid())
  );
