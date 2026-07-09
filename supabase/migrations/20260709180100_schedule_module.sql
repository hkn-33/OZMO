-- Phase 4 — work schedule (module M5), part 2/2.
-- Implements design.md §5 (M5) + §4 (strategia RLS). Reuses phase-1 private.*
-- helpers (is_branch_member / is_branch_manager / has_branch_access) — no new
-- helpers needed. Notification delivery reuses the phase-2 broadcast trigger on
-- public.notifications (fan-out to user:{uuid}); no new realtime policy required.
--
-- Convention: weekday is 0=Monday .. 6=Sunday (UI is Monday-start, Polish).

-- =============================================================
-- Tables
-- =============================================================
create table public.shifts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  position text,
  published boolean not null default false,
  note text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  constraint shifts_time_valid check (ends_at > starts_at)
);

-- Recurring weekly availability declared by an employee.
create table public.availability (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  weekday int not null,
  from_time time not null,
  to_time time not null,
  note text,
  constraint availability_weekday_valid check (weekday between 0 and 6)
);

-- Typical staffing per weekday (planning hints).
create table public.shift_templates (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  weekday int not null,
  position text,
  needed int not null default 1,
  from_time time not null,
  to_time time not null,
  constraint shift_templates_weekday_valid check (weekday between 0 and 6)
);

-- Indexes (membership/parent-side filtering, design.md §10 perf rule)
create index idx_shifts_branch on public.shifts (branch_id, starts_at);
create index idx_shifts_user on public.shifts (user_id);
create index idx_availability_branch on public.availability (branch_id);
create index idx_availability_user on public.availability (user_id);
create index idx_shift_templates_branch on public.shift_templates (branch_id);

-- =============================================================
-- Notification trigger: draft→published (or inserted published) → notify the
-- shift's user_id. Dedupe: skip if a shift_published notification for the same
-- shift already exists. Delivery is handled by the existing phase-2 broadcast
-- trigger on public.notifications (user:{uuid}).
-- =============================================================
create function public.notify_shift_published()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.published and (tg_op = 'INSERT' or old.published is distinct from new.published) then
    if not exists (
      select 1 from public.notifications
      where user_id = new.user_id
        and type = 'shift_published'
        and payload ->> 'shift_id' = new.id::text
    ) then
      insert into public.notifications (user_id, org_id, type, payload)
      values (
        new.user_id,
        new.org_id,
        'shift_published',
        jsonb_build_object(
          'shift_id', new.id,
          'branch_id', new.branch_id,
          'starts_at', new.starts_at,
          'ends_at', new.ends_at,
          'position', new.position
        )
      );
    end if;
  end if;
  return new;
end;
$$;

create trigger shifts_notify_published
  after insert or update on public.shifts
  for each row execute function public.notify_shift_published();

-- =============================================================
-- copy_week_shifts RPC — manager-only (checked inside). Copies all shifts of
-- the source week into the target week as drafts (published = false),
-- preserving weekday/time-of-day offsets and positions. Returns count.
-- =============================================================
create function public.copy_week_shifts(
  p_branch_id uuid,
  from_week_start date,
  to_week_start date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  _offset interval;
  _org_id uuid;
  _count integer;
begin
  if not private.is_branch_manager(p_branch_id) then
    raise exception 'Not authorized';
  end if;

  select org_id into _org_id from public.branches where id = p_branch_id;

  _offset := (to_week_start - from_week_start) * interval '1 day';

  insert into public.shifts (
    org_id, branch_id, user_id, starts_at, ends_at, position, note, published, created_by
  )
  select
    _org_id, p_branch_id, user_id,
    starts_at + _offset, ends_at + _offset,
    position, note, false, (select auth.uid())
  from public.shifts
  where branch_id = p_branch_id
    and starts_at >= from_week_start::timestamptz
    and starts_at < (from_week_start + 7)::timestamptz;

  get diagnostics _count = row_count;
  return _count;
end;
$$;

revoke all on function public.copy_week_shifts(uuid, date, date) from public;
grant execute on function public.copy_week_shifts(uuid, date, date) to authenticated;

-- =============================================================
-- Table grants (RLS still gates rows for `authenticated`).
-- =============================================================
grant select, insert, update, delete on
  public.shifts,
  public.availability,
  public.shift_templates
to authenticated, service_role;

-- =============================================================
-- RLS — deny-by-default. All policies wrap auth.uid() in (select ...).
-- =============================================================
alter table public.shifts enable row level security;
alter table public.availability enable row level security;
alter table public.shift_templates enable row level security;

-- shifts -------------------------------------------------------
-- Managers (incl. org admin/owner) see all shifts of their branches;
-- employees see only published shifts of their branch (whole-branch
-- visibility helps swaps). CUD: managers only.
create policy "shifts_select_access"
  on public.shifts for select to authenticated
  using (
    private.is_branch_manager(branch_id)
    or (published and private.is_branch_member(branch_id))
  );

create policy "shifts_insert_manager"
  on public.shifts for insert to authenticated
  with check (
    private.is_branch_manager(branch_id)
    and created_by = (select auth.uid())
  );

create policy "shifts_update_manager"
  on public.shifts for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "shifts_delete_manager"
  on public.shifts for delete to authenticated
  using (private.is_branch_manager(branch_id));

-- availability -------------------------------------------------
-- SELECT: any branch member (managers plan against the team grid).
-- Employees manage their own rows; managers may also edit anyone's.
create policy "availability_select_access"
  on public.availability for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "availability_insert_own_or_manager"
  on public.availability for insert to authenticated
  with check (
    private.has_branch_access(branch_id)
    and (user_id = (select auth.uid()) or private.is_branch_manager(branch_id))
  );

create policy "availability_update_own_or_manager"
  on public.availability for update to authenticated
  using (user_id = (select auth.uid()) or private.is_branch_manager(branch_id))
  with check (
    private.has_branch_access(branch_id)
    and (user_id = (select auth.uid()) or private.is_branch_manager(branch_id))
  );

create policy "availability_delete_own_or_manager"
  on public.availability for delete to authenticated
  using (user_id = (select auth.uid()) or private.is_branch_manager(branch_id));

-- shift_templates ----------------------------------------------
create policy "shift_templates_select_access"
  on public.shift_templates for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "shift_templates_insert_manager"
  on public.shift_templates for insert to authenticated
  with check (private.is_branch_manager(branch_id));

create policy "shift_templates_update_manager"
  on public.shift_templates for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "shift_templates_delete_manager"
  on public.shift_templates for delete to authenticated
  using (private.is_branch_manager(branch_id));
