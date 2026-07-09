-- Phase 1 — multi-tenant core (module M7)
-- organizations, branches, members, roles, invitations
-- Implements design.md §4 (model domeny) + §4 (strategia RLS).

-- =============================================================
-- Enums
-- =============================================================
create type public.org_role as enum ('owner', 'admin', 'member');
create type public.branch_role as enum ('manager', 'employee');

-- =============================================================
-- Tables
-- =============================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  phone text,
  created_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

create table public.org_members (
  org_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.org_role not null default 'member',
  created_at timestamptz not null default now(),
  primary key (org_id, user_id)
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  address text,
  timezone text not null default 'Europe/Warsaw',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.branch_members (
  branch_id uuid not null references public.branches (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.branch_role not null default 'employee',
  position text,
  created_at timestamptz not null default now(),
  primary key (branch_id, user_id)
);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid references public.branches (id) on delete cascade,
  email text not null,
  org_role public.org_role not null default 'member',
  branch_role public.branch_role,
  token uuid not null unique default gen_random_uuid(),
  invited_by uuid references auth.users (id),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Indexes for membership-side filtering (perf rule, design.md §10)
create index idx_org_members_user on public.org_members (user_id);
create index idx_branches_org on public.branches (org_id);
create index idx_branch_members_user on public.branch_members (user_id);
create index idx_invitations_org on public.invitations (org_id);
create index idx_invitations_email on public.invitations (lower(email));

-- =============================================================
-- Profile auto-creation trigger (on auth.users insert)
-- =============================================================
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =============================================================
-- Private helper schema (NOT exposed via PostgREST)
-- =============================================================
create schema private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- is_org_member ------------------------------------------------
create function private.is_org_member(_org_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members
    where org_id = _org_id and user_id = (select auth.uid())
  );
$$;

-- org_role (null if none) -------------------------------------
create function private.org_role(_org_id uuid)
returns text
language sql
security definer
stable
set search_path = ''
as $$
  select role::text from public.org_members
  where org_id = _org_id and user_id = (select auth.uid());
$$;

-- is_org_admin (owner or admin) -------------------------------
create function private.is_org_admin(_org_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.org_members
    where org_id = _org_id and user_id = (select auth.uid())
      and role in ('owner', 'admin')
  );
$$;

-- is_branch_member (only branch_members table — no branches self-ref).
-- Used by the branches SELECT policy so INSERT ... RETURNING works
-- (a STABLE function re-reading `branches` can't see the just-inserted row).
create function private.is_branch_member(_branch_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.branch_members
    where branch_id = _branch_id and user_id = (select auth.uid())
  );
$$;

-- has_branch_access (branch member OR org admin/owner) --------
create function private.has_branch_access(_branch_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.branch_members
    where branch_id = _branch_id and user_id = (select auth.uid())
  ) or exists (
    select 1
    from public.branches b
    join public.org_members m on m.org_id = b.org_id
    where b.id = _branch_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner', 'admin')
  );
$$;

-- is_branch_manager (branch manager OR org admin/owner) -------
create function private.is_branch_manager(_branch_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.branch_members
    where branch_id = _branch_id and user_id = (select auth.uid())
      and role = 'manager'
  ) or exists (
    select 1
    from public.branches b
    join public.org_members m on m.org_id = b.org_id
    where b.id = _branch_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner', 'admin')
  );
$$;

-- shares_org (do we share any organization with target user) --
create function private.shares_org(_user_id uuid)
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select exists (
    select 1
    from public.org_members me
    join public.org_members other on other.org_id = me.org_id
    where me.user_id = (select auth.uid())
      and other.user_id = _user_id
  );
$$;

-- Function grants: authenticated only, never anon/public
revoke all on function
  private.is_org_member(uuid),
  private.org_role(uuid),
  private.is_org_admin(uuid),
  private.is_branch_member(uuid),
  private.has_branch_access(uuid),
  private.is_branch_manager(uuid),
  private.shares_org(uuid)
from public;
grant execute on function
  private.is_org_member(uuid),
  private.org_role(uuid),
  private.is_org_admin(uuid),
  private.is_branch_member(uuid),
  private.has_branch_access(uuid),
  private.is_branch_manager(uuid),
  private.shares_org(uuid)
to authenticated;

-- =============================================================
-- create_organization RPC (atomic: org + owner membership)
-- =============================================================
create function public.create_organization(_name text, _slug text)
returns public.organizations
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := (select auth.uid());
  _org public.organizations;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.organizations (name, slug, created_by)
  values (_name, _slug, _uid)
  returning * into _org;

  insert into public.org_members (org_id, user_id, role)
  values (_org.id, _uid, 'owner');

  return _org;
end;
$$;

revoke all on function public.create_organization(text, text) from public;
grant execute on function public.create_organization(text, text) to authenticated;

-- =============================================================
-- Table grants. RLS still gates every row for `authenticated`;
-- `service_role` (server routes only) bypasses RLS but needs privileges.
-- anon gets nothing.
-- =============================================================
grant select, insert, update, delete on
  public.profiles,
  public.organizations,
  public.org_members,
  public.branches,
  public.branch_members,
  public.invitations
to authenticated, service_role;

-- =============================================================
-- RLS — enabled on all tables, deny-by-default
-- All policies wrap auth.uid() in (select ...) per perf rule.
-- =============================================================
alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.org_members enable row level security;
alter table public.branches enable row level security;
alter table public.branch_members enable row level security;
alter table public.invitations enable row level security;

-- profiles -----------------------------------------------------
create policy "profiles_select_self_or_shared_org"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.shares_org(id));

create policy "profiles_update_self"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- organizations ------------------------------------------------
-- INSERT goes through public.create_organization RPC (security definer);
-- no direct INSERT policy on purpose.
create policy "organizations_select_member"
  on public.organizations for select to authenticated
  using (private.is_org_member(id));

create policy "organizations_update_admin"
  on public.organizations for update to authenticated
  using (private.is_org_admin(id))
  with check (private.is_org_admin(id));

create policy "organizations_delete_owner"
  on public.organizations for delete to authenticated
  using (private.org_role(id) = 'owner');

-- org_members --------------------------------------------------
create policy "org_members_select_same_org"
  on public.org_members for select to authenticated
  using (private.is_org_member(org_id));

-- Admins manage members, but only an owner may create/keep owner rows.
create policy "org_members_insert_admin"
  on public.org_members for insert to authenticated
  with check (
    private.is_org_admin(org_id)
    and (role <> 'owner' or private.org_role(org_id) = 'owner')
  );

create policy "org_members_update_admin"
  on public.org_members for update to authenticated
  using (
    private.is_org_admin(org_id)
    and (role <> 'owner' or private.org_role(org_id) = 'owner')
  )
  with check (
    private.is_org_admin(org_id)
    and (role <> 'owner' or private.org_role(org_id) = 'owner')
  );

create policy "org_members_delete_admin"
  on public.org_members for delete to authenticated
  using (
    private.is_org_admin(org_id)
    and (role <> 'owner' or private.org_role(org_id) = 'owner')
  );

-- branches -----------------------------------------------------
-- Org admins/owners see every branch (via org_id column — safe for
-- INSERT ... RETURNING); plain members see only their own branches.
create policy "branches_select_access"
  on public.branches for select to authenticated
  using (private.is_org_admin(org_id) or private.is_branch_member(id));

create policy "branches_insert_admin"
  on public.branches for insert to authenticated
  with check (private.is_org_admin(org_id));

create policy "branches_update_admin"
  on public.branches for update to authenticated
  using (private.is_org_admin(org_id))
  with check (private.is_org_admin(org_id));

create policy "branches_delete_admin"
  on public.branches for delete to authenticated
  using (private.is_org_admin(org_id));

-- branch_members -----------------------------------------------
create policy "branch_members_select_access"
  on public.branch_members for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "branch_members_insert_manager"
  on public.branch_members for insert to authenticated
  with check (private.is_branch_manager(branch_id));

create policy "branch_members_update_manager"
  on public.branch_members for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "branch_members_delete_manager"
  on public.branch_members for delete to authenticated
  using (private.is_branch_manager(branch_id));

-- invitations --------------------------------------------------
-- Acceptance flow does NOT read this table from the client
-- (server route uses service_role). Admins manage invitations.
create policy "invitations_select_admin"
  on public.invitations for select to authenticated
  using (private.is_org_admin(org_id));

create policy "invitations_insert_admin"
  on public.invitations for insert to authenticated
  with check (private.is_org_admin(org_id));

create policy "invitations_update_admin"
  on public.invitations for update to authenticated
  using (private.is_org_admin(org_id))
  with check (private.is_org_admin(org_id));

create policy "invitations_delete_admin"
  on public.invitations for delete to authenticated
  using (private.is_org_admin(org_id));
