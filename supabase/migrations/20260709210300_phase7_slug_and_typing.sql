-- Phase 7 — slug-free onboarding (workstream 4) + typing broadcast policy (ws 6)

-- 1-arg create_organization: slug generated internally (slugified name +
-- random suffix on collision). UI no longer collects a slug.
create function public.create_organization(_name text)
returns public.organizations
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := (select auth.uid());
  _org public.organizations;
  _base text;
  _slug text;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  _base := lower(_name);
  _base := translate(_base, 'ąćęłńóśźż', 'acelnoszz');
  _base := regexp_replace(_base, '[^a-z0-9]+', '-', 'g');
  _base := regexp_replace(_base, '(^-+|-+$)', '', 'g');
  if _base = '' then
    _base := 'org';
  end if;

  _slug := _base;
  while exists (select 1 from public.organizations where slug = _slug) loop
    _slug := _base || '-' || substr(md5(random()::text), 1, 6);
  end loop;

  insert into public.organizations (name, slug, created_by)
  values (_name, _slug, _uid)
  returning * into _org;

  insert into public.org_members (org_id, user_id, role)
  values (_org.id, _uid, 'owner');

  -- Demo signups start on the 'demo' plan (set by the org trigger); give them
  -- a small living sample so the app isn't empty. Only the onboarding path
  -- seeds samples (service_role/seed orgs are promoted to 'network' instead).
  perform public.seed_demo_samples(_org.id, _uid);

  return _org;
end;
$$;

revoke all on function public.create_organization(text) from public;
grant execute on function public.create_organization(text) to authenticated;

-- =============================================================
-- Typing indicator (workstream 6): allow authenticated users to SEND
-- ephemeral broadcasts (event 'typing') on chat:{id} they can access.
-- Broadcast SEND from a private channel is gated by an INSERT policy on
-- realtime.messages (SELECT policy for receiving was added in phase 3).
-- =============================================================
create policy "realtime_write_chat_topics"
  on realtime.messages for insert to authenticated
  with check (
    extension = 'broadcast'
    and realtime.topic() like 'chat:%'
    and private.can_access_channel_topic(realtime.topic())
  );
