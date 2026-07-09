-- Phase 5 — stock/inventory (M8) + cost control (M9).
-- Implements design.md §5 (M8/M9) + §4 (strategia RLS). Reuses phase-1/2 private.*
-- helpers (is_org_member / is_org_admin / has_branch_access / is_branch_manager /
-- is_branch_member / manages_any_branch). Notification delivery reuses the phase-2
-- broadcast trigger on public.notifications (fan-out to user:{uuid}); no new
-- realtime policy needed. The 'stock_low' notification value is added in the
-- companion enum migration committed just before this one.

-- =============================================================
-- Enums (brand-new types — safe to create and use in one file;
-- only ADD VALUE to an existing enum needs a separate migration).
-- =============================================================
create type public.stock_movement_type as enum (
  'delivery', 'usage', 'waste', 'correction', 'transfer'
);
create type public.cost_category as enum ('food', 'beverage', 'labor', 'other');
create type public.cost_source as enum ('manual', 'stock', 'payroll');

-- =============================================================
-- M8 — Stock tables
-- =============================================================

-- Suppliers (org-level).
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  contact_name text,
  phone text,
  email text,
  note text,
  created_at timestamptz not null default now()
);

-- Products (org-level catalog). Per-branch minimum in branch_product_settings.
create table public.products (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  unit text not null default 'szt', -- szt/kg/l/opak
  category text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Per-branch product settings (minimum stock level).
create table public.branch_product_settings (
  branch_id uuid not null references public.branches (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  min_stock numeric not null default 0,
  primary key (branch_id, product_id)
);

-- Materialized stock levels (maintained by trigger; never written by client).
create table public.stock_levels (
  branch_id uuid not null references public.branches (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  qty numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key (branch_id, product_id)
);

-- Stock movements (INSERT-only ledger; corrections via counter-movement).
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  qty_delta numeric not null,
  type public.stock_movement_type not null,
  supplier_id uuid references public.suppliers (id) on delete set null,
  doc_ref text, -- WZ / invoice number
  note text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  -- Sign conventions (design.md §5 M8): delivery > 0; usage/waste < 0;
  -- correction/transfer any non-zero sign.
  constraint stock_movements_qty_nonzero check (qty_delta <> 0),
  constraint stock_movements_sign check (
    (type = 'delivery' and qty_delta > 0)
    or (type in ('usage', 'waste') and qty_delta < 0)
    or (type in ('correction', 'transfer'))
  )
);

create index idx_suppliers_org on public.suppliers (org_id);
create index idx_products_org on public.products (org_id);
create index idx_branch_product_settings_branch on public.branch_product_settings (branch_id);
create index idx_stock_levels_branch on public.stock_levels (branch_id);
create index idx_stock_movements_branch_product on public.stock_movements (branch_id, product_id, created_at desc);

-- =============================================================
-- M9 — Cost control tables
-- =============================================================

-- Revenue (fed from closed manager reports; manual override allowed).
create table public.revenue_entries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  date date not null default current_date,
  amount numeric not null default 0 check (amount >= 0),
  source text not null default 'manager_report',
  note text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  unique (branch_id, date, source)
);

create table public.cost_entries (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  date date not null default current_date,
  category public.cost_category not null,
  amount numeric not null default 0 check (amount >= 0),
  source public.cost_source not null default 'manual',
  note text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

create index idx_revenue_entries_branch_date on public.revenue_entries (branch_id, date);
create index idx_cost_entries_branch_date on public.cost_entries (branch_id, date);

-- =============================================================
-- M8 — Stock movement application + low-stock alert (security definer:
-- writes stock_levels and notifications, bypassing RLS/grants).
-- Movements are INSERT-only; stock_levels.qty += qty_delta.
-- Low-stock alert fires only when the level CROSSES below the minimum
-- (new < min AND previous >= min) to avoid spamming on repeated
-- below-minimum movements. Notifies every branch manager of the branch.
-- =============================================================
create function public.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _prev numeric;
  _new numeric;
  _min numeric;
  _name text;
begin
  select qty into _prev from public.stock_levels
    where branch_id = new.branch_id and product_id = new.product_id;
  if _prev is null then
    _prev := 0;
  end if;
  _new := _prev + new.qty_delta;

  insert into public.stock_levels (org_id, branch_id, product_id, qty, updated_at)
  values (new.org_id, new.branch_id, new.product_id, _new, now())
  on conflict (branch_id, product_id)
  do update set qty = public.stock_levels.qty + new.qty_delta, updated_at = now();

  select min_stock into _min from public.branch_product_settings
    where branch_id = new.branch_id and product_id = new.product_id;
  if _min is null then
    _min := 0;
  end if;

  -- crossing below minimum → notify branch managers (no spam)
  if _new < _min and _prev >= _min then
    select name into _name from public.products where id = new.product_id;
    insert into public.notifications (user_id, org_id, type, payload)
    select bm.user_id, new.org_id, 'stock_low'::public.notification_type,
           jsonb_build_object(
             'product_id', new.product_id,
             'branch_id', new.branch_id,
             'name', _name,
             'qty', _new,
             'min_stock', _min
           )
    from public.branch_members bm
    where bm.branch_id = new.branch_id and bm.role = 'manager';
  end if;

  return new;
end;
$$;

create trigger stock_movements_apply
  after insert on public.stock_movements
  for each row execute function public.apply_stock_movement();

-- =============================================================
-- M9 — Utarg → revenue on manager report close (design.md §10 phase-3 note).
-- After a report transitions to 'closed', upsert its revenue from the utarg
-- section (gotowka + karta + inne). Idempotent via unique(branch_id,date,source).
-- =============================================================
create function public.sync_revenue_from_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _sum numeric;
begin
  if new.status = 'closed' and old.status is distinct from 'closed' then
    select coalesce((data ->> 'gotowka')::numeric, 0)
         + coalesce((data ->> 'karta')::numeric, 0)
         + coalesce((data ->> 'inne')::numeric, 0)
      into _sum
      from public.manager_report_sections
      where report_id = new.id and section = 'utarg';

    insert into public.revenue_entries (org_id, branch_id, date, amount, source, created_by)
    values (new.org_id, new.branch_id, new.date, coalesce(_sum, 0), 'manager_report', new.closed_by)
    on conflict (branch_id, date, source)
    do update set amount = excluded.amount, created_by = excluded.created_by;
  end if;
  return new;
end;
$$;

create trigger manager_reports_sync_revenue
  after update on public.manager_reports
  for each row execute function public.sync_revenue_from_report();

-- =============================================================
-- Table grants. RLS still gates rows for `authenticated`.
-- stock_levels: SELECT only (trigger, definer, writes rows).
-- stock_movements: SELECT + INSERT only (immutable ledger — no UPDATE/DELETE
-- privilege for authenticated → any such attempt is rejected before RLS).
-- =============================================================
grant select, insert, update, delete on
  public.suppliers,
  public.products,
  public.branch_product_settings,
  public.revenue_entries,
  public.cost_entries
to authenticated, service_role;

grant select on public.stock_levels to authenticated;
grant select, insert, update, delete on public.stock_levels to service_role;

grant select, insert on public.stock_movements to authenticated;
grant select, insert, update, delete on public.stock_movements to service_role;

-- =============================================================
-- RLS — deny-by-default. All policies wrap auth.uid() in (select ...).
-- =============================================================
alter table public.suppliers enable row level security;
alter table public.products enable row level security;
alter table public.branch_product_settings enable row level security;
alter table public.stock_levels enable row level security;
alter table public.stock_movements enable row level security;
alter table public.revenue_entries enable row level security;
alter table public.cost_entries enable row level security;

-- suppliers (org-level) ---------------------------------------
-- SELECT: org members. CUD: org admin OR any branch manager in the org.
create policy "suppliers_select_member"
  on public.suppliers for select to authenticated
  using (private.is_org_member(org_id));

create policy "suppliers_insert_admin_or_manager"
  on public.suppliers for insert to authenticated
  with check (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

create policy "suppliers_update_admin_or_manager"
  on public.suppliers for update to authenticated
  using (private.is_org_admin(org_id) or private.manages_any_branch(org_id))
  with check (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

create policy "suppliers_delete_admin_or_manager"
  on public.suppliers for delete to authenticated
  using (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

-- products (org-level) ----------------------------------------
create policy "products_select_member"
  on public.products for select to authenticated
  using (private.is_org_member(org_id));

create policy "products_insert_admin_or_manager"
  on public.products for insert to authenticated
  with check (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

create policy "products_update_admin_or_manager"
  on public.products for update to authenticated
  using (private.is_org_admin(org_id) or private.manages_any_branch(org_id))
  with check (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

create policy "products_delete_admin_or_manager"
  on public.products for delete to authenticated
  using (private.is_org_admin(org_id) or private.manages_any_branch(org_id));

-- branch_product_settings -------------------------------------
-- SELECT: branch access. CUD: branch manager.
create policy "branch_product_settings_select_access"
  on public.branch_product_settings for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "branch_product_settings_insert_manager"
  on public.branch_product_settings for insert to authenticated
  with check (private.is_branch_manager(branch_id));

create policy "branch_product_settings_update_manager"
  on public.branch_product_settings for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "branch_product_settings_delete_manager"
  on public.branch_product_settings for delete to authenticated
  using (private.is_branch_manager(branch_id));

-- stock_levels (read-only for clients; written by trigger/definer) ---
create policy "stock_levels_select_access"
  on public.stock_levels for select to authenticated
  using (private.has_branch_access(branch_id));

-- stock_movements (immutable ledger) --------------------------
-- SELECT: branch access. INSERT: branch members, self as created_by.
-- No UPDATE/DELETE policy (and no privilege) → movements are immutable.
create policy "stock_movements_select_access"
  on public.stock_movements for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "stock_movements_insert_member"
  on public.stock_movements for insert to authenticated
  with check (
    private.has_branch_access(branch_id)
    and created_by = (select auth.uid())
  );

-- revenue_entries ---------------------------------------------
-- SELECT: branch access. INSERT/UPDATE: branch manager (manual override).
-- The report-close trigger writes via security definer.
create policy "revenue_entries_select_access"
  on public.revenue_entries for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "revenue_entries_insert_manager"
  on public.revenue_entries for insert to authenticated
  with check (private.is_branch_manager(branch_id));

create policy "revenue_entries_update_manager"
  on public.revenue_entries for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

-- cost_entries ------------------------------------------------
-- SELECT: branch access. INSERT/UPDATE/DELETE: branch manager (self on insert).
create policy "cost_entries_select_access"
  on public.cost_entries for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "cost_entries_insert_manager"
  on public.cost_entries for insert to authenticated
  with check (
    private.is_branch_manager(branch_id)
    and created_by = (select auth.uid())
  );

create policy "cost_entries_update_manager"
  on public.cost_entries for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "cost_entries_delete_manager"
  on public.cost_entries for delete to authenticated
  using (private.is_branch_manager(branch_id));
