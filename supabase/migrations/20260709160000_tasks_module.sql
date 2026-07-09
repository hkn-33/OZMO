-- Phase 2 — tasks, checklists, task chat, notifications (modules M1, M2, M4)
-- Implements design.md §5 (M1/M2/M4) + §6 (realtime) + §4 (strategia RLS).
-- Reuses phase-1 private.* helpers; adds task-scoped helpers on top.

-- =============================================================
-- Enums
-- =============================================================
create type public.task_status as enum ('todo', 'in_progress', 'done');
create type public.task_priority as enum ('low', 'normal', 'high', 'urgent');
create type public.notification_type as enum (
  'task_assigned',
  'mentioned',
  'comment_on_my_task',
  'task_due_soon'
);

-- =============================================================
-- Tables
-- =============================================================
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  title text not null,
  description text,
  status public.task_status not null default 'todo',
  priority public.task_priority not null default 'normal',
  due_at timestamptz,
  created_by uuid references auth.users (id),
  position numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.task_assignees (
  task_id uuid not null references public.tasks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (task_id, user_id)
);

create table public.checklist_templates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  description text,
  items jsonb not null default '[]'::jsonb, -- array of { "label": text }
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

create table public.task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  label text not null,
  done boolean not null default false,
  done_by uuid references auth.users (id),
  done_at timestamptz,
  sort int not null default 0
);

create table public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  author_id uuid not null references auth.users (id),
  body text not null,
  mentions uuid[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  type public.notification_type not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

-- Indexes (membership/parent-side filtering, design.md §10 perf rule)
create index idx_tasks_branch on public.tasks (branch_id);
create index idx_tasks_org on public.tasks (org_id);
create index idx_task_assignees_user on public.task_assignees (user_id);
create index idx_checklist_templates_org on public.checklist_templates (org_id);
create index idx_task_checklist_items_task on public.task_checklist_items (task_id);
create index idx_task_comments_task on public.task_comments (task_id, created_at);
create index idx_notifications_user on public.notifications (user_id, created_at desc);

-- =============================================================
-- Task-scoped helper functions (private schema, security definer).
-- Built on top of phase-1 helpers (is_branch_member / is_org_admin).
-- =============================================================

-- can_access_task: branch member of the task's branch, or org admin.
create function private.can_access_task(_task_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.tasks t
    where t.id = _task_id
      and (private.is_branch_member(t.branch_id) or private.is_org_admin(t.org_id))
  );
$$;

-- manages_any_branch: is the caller a manager of ANY branch in the org?
-- Used for org-level checklist_templates CUD (org admin OR branch manager).
create function private.manages_any_branch(_org_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.branch_members bm
    join public.branches b on b.id = bm.branch_id
    where b.org_id = _org_id
      and bm.user_id = (select auth.uid())
      and bm.role = 'manager'
  );
$$;

-- can_access_task_topic: realtime helper — parse "task:{uuid}" and gate.
create function private.can_access_task_topic(_topic text)
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
  return private.can_access_task(_id);
end;
$$;

revoke all on function
  private.can_access_task(uuid),
  private.manages_any_branch(uuid),
  private.can_access_task_topic(text)
from public;
grant execute on function
  private.can_access_task(uuid),
  private.manages_any_branch(uuid),
  private.can_access_task_topic(text)
to authenticated;

-- =============================================================
-- updated_at maintenance on tasks
-- =============================================================
create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

-- =============================================================
-- Default checklist templates on organization creation
-- (design.md §5 M1 seed — attached per-org via AFTER INSERT trigger,
--  so every new org gets the 5 Polish starter templates. This keeps
--  seed.sql org-agnostic; templates are copied, not referenced.)
-- =============================================================
create function public.seed_default_checklist_templates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.checklist_templates (org_id, name, description, items, created_by)
  values
    (new.id, 'Otwarcie lokalu', 'Czynności przy otwarciu zmiany', jsonb_build_array(
      jsonb_build_object('label', 'Sprawdź czystość sali i toalet'),
      jsonb_build_object('label', 'Włącz oświetlenie i muzykę'),
      jsonb_build_object('label', 'Uruchom ekspres do kawy i sprzęt kuchenny'),
      jsonb_build_object('label', 'Sprawdź kasę fiskalną i stan gotówki w kasie'),
      jsonb_build_object('label', 'Skontroluj temperatury lodówek i mroźni'),
      jsonb_build_object('label', 'Przygotuj stoły i zastawę'),
      jsonb_build_object('label', 'Sprawdź dostępność menu i kart'),
      jsonb_build_object('label', 'Odbierz i sprawdź poranne dostawy')
    ), new.created_by),
    (new.id, 'Zamknięcie lokalu', 'Czynności przy zamknięciu zmiany', jsonb_build_array(
      jsonb_build_object('label', 'Rozlicz kasę i utarg dnia'),
      jsonb_build_object('label', 'Wyczyść i wyłącz sprzęt kuchenny'),
      jsonb_build_object('label', 'Umyj podłogi i blaty robocze'),
      jsonb_build_object('label', 'Wynieś śmieci i posegreguj odpady'),
      jsonb_build_object('label', 'Sprawdź zamknięcie okien i drzwi'),
      jsonb_build_object('label', 'Wyłącz oświetlenie i muzykę'),
      jsonb_build_object('label', 'Uzbrój alarm'),
      jsonb_build_object('label', 'Zapisz uwagi na koniec zmiany')
    ), new.created_by),
    (new.id, 'Sprzątanie', 'Rutynowe sprzątanie lokalu', jsonb_build_array(
      jsonb_build_object('label', 'Umyj podłogi na sali i w kuchni'),
      jsonb_build_object('label', 'Zdezynfekuj blaty i powierzchnie robocze'),
      jsonb_build_object('label', 'Wyczyść toalety i uzupełnij środki higieniczne'),
      jsonb_build_object('label', 'Umyj lodówki i sprzęt AGD'),
      jsonb_build_object('label', 'Opróżnij i umyj kosze na śmieci'),
      jsonb_build_object('label', 'Wyczyść okna i lustra'),
      jsonb_build_object('label', 'Uzupełnij środki czystości')
    ), new.created_by),
    (new.id, 'Inwentaryzacja', 'Spis stanów magazynowych', jsonb_build_array(
      jsonb_build_object('label', 'Policz stany produktów suchych'),
      jsonb_build_object('label', 'Sprawdź stany w lodówkach i mroźniach'),
      jsonb_build_object('label', 'Zważ i policz mięso oraz wędliny'),
      jsonb_build_object('label', 'Sprawdź stan alkoholi i napojów'),
      jsonb_build_object('label', 'Odnotuj produkty przeterminowane'),
      jsonb_build_object('label', 'Wpisz stany do systemu'),
      jsonb_build_object('label', 'Zgłoś braki do zamówienia')
    ), new.created_by),
    (new.id, 'Kontrola Sanepid/HACCP', 'Lista kontrolna zgodności sanitarnej', jsonb_build_array(
      jsonb_build_object('label', 'Sprawdź i zapisz temperatury lodówek i mroźni'),
      jsonb_build_object('label', 'Skontroluj daty przydatności produktów'),
      jsonb_build_object('label', 'Sprawdź czystość stanowisk pracy'),
      jsonb_build_object('label', 'Zweryfikuj oznakowanie i datowanie produktów'),
      jsonb_build_object('label', 'Sprawdź dostępność środków dezynfekcyjnych'),
      jsonb_build_object('label', 'Skontroluj higienę personelu (fartuchy, rękawiczki)'),
      jsonb_build_object('label', 'Uzupełnij karty kontroli HACCP'),
      jsonb_build_object('label', 'Sprawdź segregację odpadów')
    ), new.created_by);
  return new;
end;
$$;

create trigger organizations_seed_templates
  after insert on public.organizations
  for each row execute function public.seed_default_checklist_templates();

-- =============================================================
-- Notification triggers (security definer — bypass RLS to insert).
-- =============================================================

-- task_assigned: on assignment, notify the assignee (skip self-assignment).
create function public.notify_task_assigned()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _t public.tasks;
begin
  if new.user_id = (select auth.uid()) then
    return new; -- assigned yourself → no notification
  end if;

  select * into _t from public.tasks where id = new.task_id;
  if _t.id is null then
    return new;
  end if;

  insert into public.notifications (user_id, org_id, type, payload)
  values (
    new.user_id,
    _t.org_id,
    'task_assigned',
    jsonb_build_object('task_id', _t.id, 'title', _t.title, 'branch_id', _t.branch_id)
  );
  return new;
end;
$$;

create trigger task_assignees_notify
  after insert on public.task_assignees
  for each row execute function public.notify_task_assigned();

-- comment notifications: mentioned + comment_on_my_task.
create function public.notify_task_comment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid;
  _title text;
begin
  select title into _title from public.tasks where id = new.task_id;

  -- 1) mentioned users (skip the author)
  foreach _uid in array coalesce(new.mentions, '{}'::uuid[])
  loop
    if _uid <> new.author_id then
      insert into public.notifications (user_id, org_id, type, payload)
      values (
        _uid,
        new.org_id,
        'mentioned',
        jsonb_build_object('task_id', new.task_id, 'comment_id', new.id,
                           'title', _title, 'author_id', new.author_id, 'branch_id', new.branch_id)
      );
    end if;
  end loop;

  -- 2) assignees + task creator (comment_on_my_task), excluding the author
  --    and anyone already notified via a mention above.
  insert into public.notifications (user_id, org_id, type, payload)
  select distinct r.uid, new.org_id, 'comment_on_my_task'::public.notification_type,
         jsonb_build_object('task_id', new.task_id, 'comment_id', new.id,
                            'title', _title, 'author_id', new.author_id, 'branch_id', new.branch_id)
  from (
    select ta.user_id as uid from public.task_assignees ta where ta.task_id = new.task_id
    union
    select t.created_by as uid from public.tasks t where t.id = new.task_id and t.created_by is not null
  ) r
  where r.uid <> new.author_id
    and not (r.uid = any (coalesce(new.mentions, '{}'::uuid[])));

  return new;
end;
$$;

create trigger task_comments_notify
  after insert on public.task_comments
  for each row execute function public.notify_task_comment();

-- =============================================================
-- Realtime — Broadcast from Database (design.md §6/§10).
-- Comments fan-out to topic task:{id}; notifications to user:{uuid}.
-- =============================================================
create function public.broadcast_task_comment()
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
      'created_at', new.created_at
    ),
    'new_comment',
    'task:' || new.task_id::text,
    true
  );
  return new;
end;
$$;

create trigger task_comments_broadcast
  after insert on public.task_comments
  for each row execute function public.broadcast_task_comment();

create function public.broadcast_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object(
      'id', new.id,
      'type', new.type,
      'payload', new.payload,
      'created_at', new.created_at
    ),
    'new_notification',
    'user:' || new.user_id::text,
    true
  );
  return new;
end;
$$;

create trigger notifications_broadcast
  after insert on public.notifications
  for each row execute function public.broadcast_notification();

-- =============================================================
-- Table grants (RLS still gates rows for `authenticated`).
-- notifications: no INSERT for authenticated (only triggers, definer).
-- =============================================================
grant select, insert, update, delete on
  public.tasks,
  public.task_assignees,
  public.checklist_templates,
  public.task_checklist_items,
  public.task_comments
to authenticated, service_role;

grant select, update on public.notifications to authenticated;
grant select, insert, update, delete on public.notifications to service_role;

-- =============================================================
-- RLS — deny-by-default. All policies wrap auth.uid() in (select ...).
-- =============================================================
alter table public.tasks enable row level security;
alter table public.task_assignees enable row level security;
alter table public.checklist_templates enable row level security;
alter table public.task_checklist_items enable row level security;
alter table public.task_comments enable row level security;
alter table public.notifications enable row level security;

-- tasks --------------------------------------------------------
create policy "tasks_select_access"
  on public.tasks for select to authenticated
  using (private.is_branch_member(branch_id) or private.is_org_admin(org_id));

create policy "tasks_insert_member"
  on public.tasks for insert to authenticated
  with check (
    (private.is_branch_member(branch_id) or private.is_org_admin(org_id))
    and created_by = (select auth.uid())
  );

create policy "tasks_update_member"
  on public.tasks for update to authenticated
  using (private.is_branch_member(branch_id) or private.is_org_admin(org_id))
  with check (private.is_branch_member(branch_id) or private.is_org_admin(org_id));

create policy "tasks_delete_manager"
  on public.tasks for delete to authenticated
  using (private.is_branch_manager(branch_id));

-- task_assignees ----------------------------------------------
create policy "task_assignees_select_access"
  on public.task_assignees for select to authenticated
  using (private.can_access_task(task_id));

create policy "task_assignees_insert_access"
  on public.task_assignees for insert to authenticated
  with check (private.can_access_task(task_id));

create policy "task_assignees_delete_access"
  on public.task_assignees for delete to authenticated
  using (private.can_access_task(task_id));

-- checklist_templates (org-level) -----------------------------
create policy "checklist_templates_select_member"
  on public.checklist_templates for select to authenticated
  using (private.is_org_member(org_id));

create policy "checklist_templates_insert_admin_or_manager"
  on public.checklist_templates for insert to authenticated
  with check (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

create policy "checklist_templates_update_admin_or_manager"
  on public.checklist_templates for update to authenticated
  using (private.is_org_admin(org_id) or private.manages_any_branch(org_id))
  with check (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

create policy "checklist_templates_delete_admin_or_manager"
  on public.checklist_templates for delete to authenticated
  using (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

-- task_checklist_items ----------------------------------------
create policy "task_checklist_items_select_access"
  on public.task_checklist_items for select to authenticated
  using (private.can_access_task(task_id));

create policy "task_checklist_items_insert_access"
  on public.task_checklist_items for insert to authenticated
  with check (private.can_access_task(task_id));

create policy "task_checklist_items_update_access"
  on public.task_checklist_items for update to authenticated
  using (private.can_access_task(task_id))
  with check (private.can_access_task(task_id));

create policy "task_checklist_items_delete_access"
  on public.task_checklist_items for delete to authenticated
  using (private.can_access_task(task_id));

-- task_comments -----------------------------------------------
create policy "task_comments_select_access"
  on public.task_comments for select to authenticated
  using (private.can_access_task(task_id));

create policy "task_comments_insert_author"
  on public.task_comments for insert to authenticated
  with check (
    private.can_access_task(task_id)
    and author_id = (select auth.uid())
  );

-- notifications (own only; INSERT via triggers/definer) -------
create policy "notifications_select_own"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));

create policy "notifications_update_own"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- =============================================================
-- Realtime private-channel authorization (RLS on realtime.messages).
-- Clients read broadcast messages; SELECT is what gates a private
-- channel join. task:{id} → branch access; user:{uuid} → self.
-- =============================================================
alter table realtime.messages enable row level security;

create policy "realtime_read_task_or_user_topics"
  on realtime.messages for select to authenticated
  using (
    extension = 'broadcast'
    and (
      (realtime.topic() like 'task:%' and private.can_access_task_topic(realtime.topic()))
      or (realtime.topic() = 'user:' || (select auth.uid())::text)
    )
  );
