-- Phase 7 — subscriptions + demo gating (workstream 2)
-- plan enum, subscriptions table (one row per org), an org-creation trigger
-- that provisions a 'demo' subscription and seeds a small living sample, and
-- a network backfill for pre-existing orgs.

create type public.plan as enum ('demo', 'starter', 'pro', 'network');

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null unique references public.organizations (id) on delete cascade,
  plan public.plan not null default 'demo',
  status text not null default 'active',
  current_period_end timestamptz,
  created_at timestamptz not null default now()
);

create index idx_subscriptions_org on public.subscriptions (org_id);

-- Client may read its org's subscription; writes are service_role only
-- (Stripe webhooks later — design.md §10).
grant select on public.subscriptions to authenticated;
grant select, insert, update, delete on public.subscriptions to service_role;

alter table public.subscriptions enable row level security;

create policy "subscriptions_select_member"
  on public.subscriptions for select to authenticated
  using (private.is_org_member(org_id));

-- =============================================================
-- Demo sample seeding — a small living app for freshly created demo orgs.
-- Rows are clearly marked with the "Przykład: " prefix. Wrapped so that a
-- sample failure never blocks org creation.
-- =============================================================
create function public.seed_demo_samples(_org_id uuid, _owner_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _branch_id uuid;
  _org_channel_id uuid;
begin
  -- Sample branch (its chat channel is auto-created by the branch trigger).
  insert into public.branches (org_id, name, address)
  values (_org_id, 'Przykład: Lokal Główny', 'ul. Przykładowa 1')
  returning id into _branch_id;

  if _owner_id is not null then
    insert into public.branch_members (branch_id, user_id, role, position)
    values (_branch_id, _owner_id, 'manager', 'Kierownik')
    on conflict do nothing;
  end if;

  -- Sample tasks.
  insert into public.tasks (org_id, branch_id, title, description, status, priority, created_by, position)
  values
    (_org_id, _branch_id, 'Przykład: Otwarcie lokalu', 'Przykładowe zadanie — wykup subskrypcję, aby tworzyć własne.', 'todo', 'high', _owner_id, 1),
    (_org_id, _branch_id, 'Przykład: Uzupełnienie magazynu', 'Przykładowe zadanie w toku.', 'in_progress', 'normal', _owner_id, 2),
    (_org_id, _branch_id, 'Przykład: Zamknięcie kasy', 'Przykładowe zadanie zakończone.', 'done', 'normal', _owner_id, 3);

  -- Sample chat messages in the org channel.
  select id into _org_channel_id
  from public.chat_channels
  where org_id = _org_id and type = 'org'
  limit 1;

  if _org_channel_id is not null and _owner_id is not null then
    insert into public.chat_messages (channel_id, org_id, branch_id, author_id, body)
    values
      (_org_channel_id, _org_id, null, _owner_id, 'Przykład: Witaj w OZMO! To jest tryb demo.'),
      (_org_channel_id, _org_id, null, _owner_id, 'Przykład: Wykup subskrypcję, aby pisać własne wiadomości.');
  end if;

  -- Sample products + stock (delivery movement materializes stock_levels).
  declare
    _p1 uuid;
    _p2 uuid;
  begin
    insert into public.products (org_id, name, unit, category)
    values (_org_id, 'Przykład: Kawa ziarnista', 'kg', 'Napoje') returning id into _p1;
    insert into public.products (org_id, name, unit, category)
    values (_org_id, 'Przykład: Mleko', 'l', 'Napoje') returning id into _p2;

    insert into public.branch_product_settings (branch_id, product_id, org_id, min_stock)
    values (_branch_id, _p1, _org_id, 5), (_branch_id, _p2, _org_id, 10);

    if _owner_id is not null then
      insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
      values
        (_org_id, _branch_id, _p1, 8, 'delivery', 'Przykład: dostawa', _owner_id),
        (_org_id, _branch_id, _p2, 4, 'delivery', 'Przykład: dostawa', _owner_id);
    end if;
  end;
exception
  when others then
    -- Never block org creation on sample-seeding problems.
    null;
end;
$$;

revoke all on function public.seed_demo_samples(uuid, uuid) from public;

-- =============================================================
-- Org-creation trigger: provision a demo subscription for every new org.
-- Demo *sample* data is added only by the onboarding RPC (create_organization),
-- so orgs created via service_role (tests, seed.sql) stay clean and are then
-- promoted to 'network'.
-- =============================================================
create function public.handle_new_org_subscription()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.subscriptions (org_id, plan)
  values (new.id, 'demo')
  on conflict (org_id) do nothing;
  return new;
end;
$$;

create trigger organizations_subscription
  after insert on public.organizations
  for each row execute function public.handle_new_org_subscription();

-- Backfill any pre-existing orgs as fully-functional 'network'
-- (seeded/test/existing orgs — design.md workstream 2).
insert into public.subscriptions (org_id, plan)
select id, 'network' from public.organizations
on conflict (org_id) do nothing;
