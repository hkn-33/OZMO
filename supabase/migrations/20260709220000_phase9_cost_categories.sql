-- Phase 9 (workstream 1) — configurable cost categories.
-- Kills the hardcoded public.cost_category enum on cost_entries and replaces it
-- with a per-org public.cost_categories table + FK. Existing rows are migrated
-- by mapping the four old enum values to Polish default categories per org.
-- Reuses phase-1 private.* helpers (is_org_member / is_org_admin).

-- =============================================================
-- cost_categories (per-org, configurable)
-- =============================================================
create table public.cost_categories (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  sort int not null default 0,
  created_at timestamptz not null default now()
);
create unique index cost_categories_org_name_uniq
  on public.cost_categories (org_id, lower(name));
create index idx_cost_categories_org on public.cost_categories (org_id, sort);

-- =============================================================
-- Migrate cost_entries.category (enum) → category_id (FK).
-- For every org that already has cost_entries, create the four default
-- Polish categories, then repoint each row by mapping the old enum value.
-- On a fresh DB (db reset) there are no rows, so this is a no-op.
-- =============================================================
alter table public.cost_entries
  add column category_id uuid references public.cost_categories (id) on delete restrict;

do $$
declare
  _org uuid;
begin
  for _org in select distinct org_id from public.cost_entries loop
    insert into public.cost_categories (org_id, name, sort) values
      (_org, 'Jedzenie', 0),
      (_org, 'Napoje', 1),
      (_org, 'Praca', 2),
      (_org, 'Inne', 3)
    on conflict do nothing;
  end loop;

  update public.cost_entries ce
    set category_id = cc.id
  from public.cost_categories cc
  where cc.org_id = ce.org_id
    and cc.name = case ce.category
      when 'food' then 'Jedzenie'
      when 'beverage' then 'Napoje'
      when 'labor' then 'Praca'
      else 'Inne'
    end;
end $$;

alter table public.cost_entries drop column category;
alter table public.cost_entries alter column category_id set not null;
drop type public.cost_category;

create index idx_cost_entries_category on public.cost_entries (category_id);

-- =============================================================
-- Grants + RLS. SELECT: org members. CUD: org admins.
-- =============================================================
grant select, insert, update, delete on public.cost_categories to authenticated, service_role;

alter table public.cost_categories enable row level security;

create policy "cost_categories_select_member"
  on public.cost_categories for select to authenticated
  using (private.is_org_member(org_id));

create policy "cost_categories_insert_admin"
  on public.cost_categories for insert to authenticated
  with check (private.is_org_admin(org_id));

create policy "cost_categories_update_admin"
  on public.cost_categories for update to authenticated
  using (private.is_org_admin(org_id))
  with check (private.is_org_admin(org_id));

create policy "cost_categories_delete_admin"
  on public.cost_categories for delete to authenticated
  using (private.is_org_admin(org_id));
