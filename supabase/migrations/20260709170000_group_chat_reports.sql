-- Phase 3 — group chats, day notes, manager daily report (modules M10, M3, M6)
-- Implements design.md §5 (M10/M3/M6) + §6 (realtime) + §4 (strategia RLS).
-- Reuses phase-1 private.* helpers (is_org_member/is_branch_member/is_org_admin/
-- has_branch_access/is_branch_manager); adds channel- and report-scoped helpers.

-- =============================================================
-- Enums
-- =============================================================
create type public.chat_channel_type as enum ('org', 'branch', 'custom');
create type public.day_note_severity as enum ('info', 'issue');
create type public.manager_report_status as enum ('draft', 'closed');
create type public.report_section as enum ('utarg', 'kasa', 'sanepid', 'magazyn', 'zmiana');

-- =============================================================
-- M10 — Group chats
-- =============================================================
create table public.chat_channels (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid references public.branches (id) on delete cascade,
  type public.chat_channel_type not null,
  name text not null,
  created_at timestamptz not null default now()
);

-- Membership rows only for `custom` channels (org/branch derive access from
-- org_members / branch_members).
create table public.chat_members (
  channel_id uuid not null references public.chat_channels (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.chat_channels (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid references public.branches (id) on delete cascade,
  author_id uuid not null references auth.users (id),
  body text not null,
  created_at timestamptz not null default now()
);

create table public.chat_reads (
  channel_id uuid not null references public.chat_channels (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (channel_id, user_id)
);

create index idx_chat_channels_org on public.chat_channels (org_id);
create index idx_chat_channels_branch on public.chat_channels (branch_id);
create index idx_chat_members_user on public.chat_members (user_id);
create index idx_chat_messages_channel on public.chat_messages (channel_id, created_at);

-- =============================================================
-- M3 — Day notes (employee day report)
-- =============================================================
create table public.day_notes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  author_id uuid not null references auth.users (id),
  date date not null default current_date,
  body text not null,
  severity public.day_note_severity not null default 'info',
  created_at timestamptz not null default now()
);

create index idx_day_notes_branch_date on public.day_notes (branch_id, date);

-- =============================================================
-- M6 — Manager daily report
-- =============================================================
create table public.manager_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  date date not null default current_date,
  status public.manager_report_status not null default 'draft',
  closed_by uuid references auth.users (id),
  closed_at timestamptz,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  unique (branch_id, date)
);

create table public.manager_report_sections (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.manager_reports (id) on delete cascade,
  section public.report_section not null,
  data jsonb not null default '{}'::jsonb,
  completed boolean not null default false,
  unique (report_id, section)
);

create index idx_manager_reports_branch_date on public.manager_reports (branch_id, date);
create index idx_manager_report_sections_report on public.manager_report_sections (report_id);

-- =============================================================
-- Channel-scoped helpers (private schema, security definer).
-- Built on phase-1 helpers; bypass RLS, no recursion.
-- =============================================================

-- can_access_channel: org member (org channel), branch member/org admin
-- (branch channel), or explicit member (custom channel).
create function private.can_access_channel(_channel_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.chat_channels c
    where c.id = _channel_id
      and (
        (c.type = 'org' and private.is_org_member(c.org_id))
        or (c.type = 'branch'
            and (private.is_branch_member(c.branch_id) or private.is_org_admin(c.org_id)))
        or (c.type = 'custom' and exists (
          select 1 from public.chat_members m
          where m.channel_id = c.id and m.user_id = (select auth.uid())
        ))
      )
  );
$$;

-- can_access_channel_topic: realtime helper — parse "chat:{uuid}" and gate.
create function private.can_access_channel_topic(_topic text)
returns boolean
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  _id uuid;
begin
  begin
    _id := (split_part(_topic, ':', 2))::uuid;
  exception when others then
    return false;
  end;
  return private.can_access_channel(_id);
end;
$$;

-- Report-scoped helpers (read the report's branch_id, apply phase-1 helpers).
create function private.can_access_report(_report_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.manager_reports r
    where r.id = _report_id and private.has_branch_access(r.branch_id)
  );
$$;

create function private.can_manage_report(_report_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.manager_reports r
    where r.id = _report_id and private.is_branch_manager(r.branch_id)
  );
$$;

revoke all on function
  private.can_access_channel(uuid),
  private.can_access_channel_topic(text),
  private.can_access_report(uuid),
  private.can_manage_report(uuid)
from public;
grant execute on function
  private.can_access_channel(uuid),
  private.can_access_channel_topic(text),
  private.can_access_report(uuid),
  private.can_manage_report(uuid)
to authenticated;

-- =============================================================
-- Auto-create channels (trigger, security definer — bypass RLS).
-- Org insert → "Ogólny"; branch insert → channel named after the branch.
-- =============================================================
create function public.create_org_chat_channel()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.chat_channels (org_id, branch_id, type, name)
  values (new.id, null, 'org', 'Ogólny');
  return new;
end;
$$;

create trigger organizations_create_chat_channel
  after insert on public.organizations
  for each row execute function public.create_org_chat_channel();

create function public.create_branch_chat_channel()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.chat_channels (org_id, branch_id, type, name)
  values (new.org_id, new.id, 'branch', new.name);
  return new;
end;
$$;

create trigger branches_create_chat_channel
  after insert on public.branches
  for each row execute function public.create_branch_chat_channel();

-- Backfill existing orgs/branches (created before this migration).
insert into public.chat_channels (org_id, branch_id, type, name)
select id, null, 'org', 'Ogólny' from public.organizations;

insert into public.chat_channels (org_id, branch_id, type, name)
select org_id, id, 'branch', name from public.branches;

-- =============================================================
-- M6 — Auto-create the 5 report sections on report insert.
-- =============================================================
create function public.seed_report_sections()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.manager_report_sections (report_id, section)
  values
    (new.id, 'utarg'),
    (new.id, 'kasa'),
    (new.id, 'sanepid'),
    (new.id, 'magazyn'),
    (new.id, 'zmiana');
  return new;
end;
$$;

create trigger manager_reports_seed_sections
  after insert on public.manager_reports
  for each row execute function public.seed_report_sections();

-- =============================================================
-- M6 — Closing lock + immutability (design.md §5 M6).
-- Close (draft → closed) allowed only when every section completed;
-- sets closed_by/closed_at. A closed report is immutable.
-- =============================================================
create function public.enforce_manager_report_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Any edit to an already-closed report is rejected.
  if old.status = 'closed' then
    raise exception 'Raport jest zamknięty i nie można go edytować';
  end if;

  if new.status = 'closed' and old.status <> 'closed' then
    if exists (
      select 1 from public.manager_report_sections s
      where s.report_id = new.id and s.completed = false
    ) then
      raise exception 'Nie można zamknąć raportu: nie wszystkie sekcje są ukończone';
    end if;
    new.closed_by := (select auth.uid());
    new.closed_at := now();
  end if;

  return new;
end;
$$;

create trigger manager_reports_enforce_transition
  before update on public.manager_reports
  for each row execute function public.enforce_manager_report_transition();

-- Reject edits to sections of a closed report.
create function public.enforce_section_editable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _status public.manager_report_status;
begin
  select status into _status from public.manager_reports where id = new.report_id;
  if _status = 'closed' then
    raise exception 'Raport jest zamknięty — sekcji nie można edytować';
  end if;
  return new;
end;
$$;

create trigger manager_report_sections_enforce_editable
  before update on public.manager_report_sections
  for each row execute function public.enforce_section_editable();

-- =============================================================
-- Realtime — Broadcast from Database (design.md §6/§10).
-- Chat messages fan-out to topic chat:{channel_id}.
-- =============================================================
create function public.broadcast_chat_message()
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
      'created_at', new.created_at
    ),
    'new_message',
    'chat:' || new.channel_id::text,
    true
  );
  return new;
end;
$$;

create trigger chat_messages_broadcast
  after insert on public.chat_messages
  for each row execute function public.broadcast_chat_message();

-- =============================================================
-- Table grants (RLS still gates rows for `authenticated`).
-- =============================================================
grant select, insert, update, delete on
  public.chat_channels,
  public.chat_members,
  public.chat_messages,
  public.chat_reads,
  public.day_notes,
  public.manager_reports,
  public.manager_report_sections
to authenticated, service_role;

-- =============================================================
-- RLS — deny-by-default. All policies wrap auth.uid() in (select ...).
-- =============================================================
alter table public.chat_channels enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_reads enable row level security;
alter table public.day_notes enable row level security;
alter table public.manager_reports enable row level security;
alter table public.manager_report_sections enable row level security;

-- chat_channels (created by triggers only; no client INSERT/UPDATE/DELETE) ---
create policy "chat_channels_select_access"
  on public.chat_channels for select to authenticated
  using (private.can_access_channel(id));

-- chat_members (visible to channel members) --------------------
create policy "chat_members_select_access"
  on public.chat_members for select to authenticated
  using (private.can_access_channel(channel_id));

-- chat_messages -----------------------------------------------
create policy "chat_messages_select_access"
  on public.chat_messages for select to authenticated
  using (private.can_access_channel(channel_id));

create policy "chat_messages_insert_author"
  on public.chat_messages for insert to authenticated
  with check (
    private.can_access_channel(channel_id)
    and author_id = (select auth.uid())
  );

-- chat_reads (own rows only) ----------------------------------
create policy "chat_reads_select_own"
  on public.chat_reads for select to authenticated
  using (user_id = (select auth.uid()));

create policy "chat_reads_insert_own"
  on public.chat_reads for insert to authenticated
  with check (user_id = (select auth.uid()) and private.can_access_channel(channel_id));

create policy "chat_reads_update_own"
  on public.chat_reads for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- day_notes ----------------------------------------------------
create policy "day_notes_select_access"
  on public.day_notes for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "day_notes_insert_member"
  on public.day_notes for insert to authenticated
  with check (
    private.has_branch_access(branch_id)
    and author_id = (select auth.uid())
  );

-- Own note editable only within the same day; managers anytime.
create policy "day_notes_update_own_or_manager"
  on public.day_notes for update to authenticated
  using (
    (author_id = (select auth.uid()) and date = current_date)
    or private.is_branch_manager(branch_id)
  )
  with check (
    (author_id = (select auth.uid()) and date = current_date)
    or private.is_branch_manager(branch_id)
  );

create policy "day_notes_delete_own_or_manager"
  on public.day_notes for delete to authenticated
  using (
    (author_id = (select auth.uid()) and date = current_date)
    or private.is_branch_manager(branch_id)
  );

-- manager_reports ---------------------------------------------
create policy "manager_reports_select_access"
  on public.manager_reports for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "manager_reports_insert_manager"
  on public.manager_reports for insert to authenticated
  with check (
    private.is_branch_manager(branch_id)
    and created_by = (select auth.uid())
  );

create policy "manager_reports_update_manager"
  on public.manager_reports for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

-- manager_report_sections -------------------------------------
create policy "manager_report_sections_select_access"
  on public.manager_report_sections for select to authenticated
  using (private.can_access_report(report_id));

create policy "manager_report_sections_update_manager"
  on public.manager_report_sections for update to authenticated
  using (private.can_manage_report(report_id))
  with check (private.can_manage_report(report_id));

-- =============================================================
-- Realtime private-channel authorization (RLS on realtime.messages).
-- Adds chat:{id} on top of phase-2 task:{id} / user:{uuid} policy.
-- realtime.messages RLS was already enabled in the tasks migration.
-- =============================================================
create policy "realtime_read_chat_topics"
  on realtime.messages for select to authenticated
  using (
    extension = 'broadcast'
    and realtime.topic() like 'chat:%'
    and private.can_access_channel_topic(realtime.topic())
  );
