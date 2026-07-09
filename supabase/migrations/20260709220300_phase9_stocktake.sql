-- Phase 9 (workstream 4) — stocktake (inwentaryzacja / spis z natury).
-- A stocktake snapshots expected quantities per product, records counted
-- quantities, and on close writes correction stock_movements for every
-- discrepancy (delta = counted - expected). Immutable after close.
-- Reuses phase-1 helpers (has_branch_access / is_branch_manager).

create type public.stocktake_status as enum ('draft', 'closed');

create table public.stocktakes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  status public.stocktake_status not null default 'draft',
  note text,
  created_by uuid references auth.users (id) default auth.uid(),
  created_at timestamptz not null default now(),
  closed_by uuid references auth.users (id),
  closed_at timestamptz
);

create table public.stocktake_items (
  id uuid primary key default gen_random_uuid(),
  stocktake_id uuid not null references public.stocktakes (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete cascade,
  expected_qty numeric not null default 0, -- snapshot of stock level at add time
  counted_qty numeric,                     -- null until counted
  created_at timestamptz not null default now(),
  unique (stocktake_id, product_id)
);

create index idx_stocktakes_branch on public.stocktakes (branch_id, created_at desc);
create index idx_stocktake_items_stocktake on public.stocktake_items (stocktake_id);

-- =============================================================
-- Immutability triggers — no edits once closed.
-- (draft → closed itself is allowed; editing a closed row is not.)
-- =============================================================
create function public.enforce_stocktake_immutable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'closed' then
    raise exception 'Inwentaryzacja jest zamknięta i nie można jej edytować';
  end if;
  return new;
end;
$$;

create trigger stocktakes_enforce_immutable
  before update on public.stocktakes
  for each row execute function public.enforce_stocktake_immutable();

create function public.enforce_stocktake_item_editable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _status public.stocktake_status;
begin
  select status into _status from public.stocktakes
    where id = coalesce(new.stocktake_id, old.stocktake_id);
  if _status = 'closed' then
    raise exception 'Inwentaryzacja jest zamknięta — pozycji nie można zmieniać';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger stocktake_items_enforce_editable
  before insert or update or delete on public.stocktake_items
  for each row execute function public.enforce_stocktake_item_editable();

-- =============================================================
-- close_stocktake RPC — writes correction movements for every counted
-- discrepancy, then closes the stocktake. Manager-only (checked inside).
-- =============================================================
create function public.close_stocktake(_stocktake_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _st public.stocktakes;
  _uid uuid := (select auth.uid());
begin
  select * into _st from public.stocktakes where id = _stocktake_id;
  if _st.id is null then
    raise exception 'Nie znaleziono inwentaryzacji';
  end if;
  if not private.is_branch_manager(_st.branch_id) then
    raise exception 'Brak uprawnień';
  end if;
  if _st.status = 'closed' then
    raise exception 'Inwentaryzacja jest już zamknięta';
  end if;

  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select _st.org_id, _st.branch_id, i.product_id, (i.counted_qty - i.expected_qty),
         'correction', 'Inwentaryzacja #' || substr(_st.id::text, 1, 8), _uid
  from public.stocktake_items i
  where i.stocktake_id = _st.id
    and i.counted_qty is not null
    and i.counted_qty <> i.expected_qty;

  update public.stocktakes
    set status = 'closed', closed_by = _uid, closed_at = now()
    where id = _st.id;
end;
$$;

revoke all on function public.close_stocktake(uuid) from public;
grant execute on function public.close_stocktake(uuid) to authenticated;

-- =============================================================
-- Grants + RLS. SELECT: branch access. CUD: branch manager.
-- =============================================================
grant select, insert, update, delete on
  public.stocktakes, public.stocktake_items
to authenticated, service_role;

alter table public.stocktakes enable row level security;
alter table public.stocktake_items enable row level security;

create policy "stocktakes_select_access"
  on public.stocktakes for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "stocktakes_insert_manager"
  on public.stocktakes for insert to authenticated
  with check (private.is_branch_manager(branch_id) and created_by = (select auth.uid()));

create policy "stocktakes_update_manager"
  on public.stocktakes for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "stocktakes_delete_manager"
  on public.stocktakes for delete to authenticated
  using (private.is_branch_manager(branch_id));

create policy "stocktake_items_select_access"
  on public.stocktake_items for select to authenticated
  using (private.has_branch_access(branch_id));

create policy "stocktake_items_insert_manager"
  on public.stocktake_items for insert to authenticated
  with check (private.is_branch_manager(branch_id));

create policy "stocktake_items_update_manager"
  on public.stocktake_items for update to authenticated
  using (private.is_branch_manager(branch_id))
  with check (private.is_branch_manager(branch_id));

create policy "stocktake_items_delete_manager"
  on public.stocktake_items for delete to authenticated
  using (private.is_branch_manager(branch_id));
