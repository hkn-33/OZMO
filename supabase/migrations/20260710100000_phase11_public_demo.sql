-- Phase 11 — public demo account with hourly reset.
--
-- a. organizations.is_public_demo flag.
-- b. private.reset_demo_org(): wipes the demo org's *domain* data (keeping
--    structure: org, branches, members, templates, categories, section defs,
--    products, suppliers, per-branch settings) and re-seeds a compact, living
--    dataset with relative timestamps so it always looks fresh.
-- c. pg_cron hourly schedule (tolerant of a missing extension).

-- ---------------------------------------------------------------------------
-- a. Flag
-- ---------------------------------------------------------------------------
alter table public.organizations
  add column if not exists is_public_demo boolean not null default false;

-- ---------------------------------------------------------------------------
-- b. Reset routine
-- ---------------------------------------------------------------------------
create or replace function private.reset_demo_org()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _org uuid;
  _owner uuid;
  _b1 uuid;
  _b2 uuid;
  _e1 uuid;
  _e2 uuid;
  _ch_org uuid;
  _ch_b1 uuid;
  _t1 uuid := gen_random_uuid();
  _t2 uuid := gen_random_uuid();
  _rep uuid := gen_random_uuid();
  _low_prod uuid;
  _low_min numeric;
  _monday date := (date_trunc('week', now()))::date; -- ISO Monday
begin
  select id into _org
  from public.organizations
  where is_public_demo
  order by created_at
  limit 1;

  if _org is null then
    return;
  end if;

  select user_id into _owner from public.org_members
    where org_id = _org and role = 'owner' limit 1;

  select id into _b1 from public.branches where org_id = _org order by created_at limit 1;
  select id into _b2 from public.branches where org_id = _org order by created_at offset 1 limit 1;
  _b2 := coalesce(_b2, _b1);

  select user_id into _e1 from public.branch_members
    where branch_id = _b1 and role = 'employee' limit 1;
  select user_id into _e2 from public.branch_members
    where branch_id = _b1 and role = 'employee'
      and user_id is distinct from _e1 limit 1;
  _e1 := coalesce(_e1, _owner);
  _e2 := coalesce(_e2, _e1);

  select id into _ch_org from public.chat_channels
    where org_id = _org and type = 'org' limit 1;
  select id into _ch_b1 from public.chat_channels where branch_id = _b1 limit 1;

  -- -------------------------------------------------------------------------
  -- Wipe domain data (structure stays). Task/report/stocktake children cascade.
  -- -------------------------------------------------------------------------
  delete from public.notifications
    where user_id in (select user_id from public.org_members where org_id = _org);
  delete from public.tasks where org_id = _org;               -- + assignees/checklist/comments/links
  delete from public.chat_messages where org_id = _org;       -- channels kept
  delete from public.day_notes where org_id = _org;
  delete from public.manager_reports where org_id = _org;     -- + sections
  delete from public.stocktakes where org_id = _org;          -- + items
  delete from public.stock_movements where org_id = _org;
  delete from public.stock_levels where org_id = _org;
  delete from public.cost_entries where org_id = _org;
  delete from public.revenue_entries where org_id = _org;
  delete from public.shifts where org_id = _org;
  delete from public.availability where org_id = _org;

  -- -------------------------------------------------------------------------
  -- Tasks (mixed states) + checklist + comments + one assignment.
  -- -------------------------------------------------------------------------
  insert into public.tasks (id, org_id, branch_id, title, description, status, priority, due_at, created_by, position) values
    (_t1, _org, _b1, 'Otwarcie lokalu', 'Poranna checklista otwarcia.', 'in_progress', 'high', now() + interval '2 hours', _owner, 1),
    (_t2, _org, _b1, 'Inwentaryzacja baru', 'Policz stany napojów.', 'todo', 'normal', now() + interval '1 day', _owner, 2),
    (gen_random_uuid(), _org, _b1, 'Zamknięcie kasy', 'Rozliczenie utargu.', 'done', 'normal', now() - interval '12 hours', _owner, 3),
    (gen_random_uuid(), _org, _b2, 'Sprzątanie sali', 'Generalne po weekendzie.', 'todo', 'high', now() + interval '5 hours', _owner, 1);

  insert into public.task_checklist_items (task_id, label, done, done_by, done_at, sort) values
    (_t1, 'Otworzyć lokal i wyłączyć alarm', true, _e1, now() - interval '1 hour', 0),
    (_t1, 'Włączyć ekspres i lodówki', true, _e1, now() - interval '50 minutes', 1),
    (_t1, 'Sprawdzić czystość sali', false, null, null, 2),
    (_t2, 'Policzyć napoje', false, null, null, 0),
    (_t2, 'Policzyć alkohole', false, null, null, 1);

  insert into public.task_comments (task_id, org_id, branch_id, author_id, body) values
    (_t1, _org, _b1, _owner, 'Pamiętajcie o wymianie wody w kwiatach.'),
    (_t1, _org, _b1, _e1, 'Zrobione, ekspres rozgrzany.');

  insert into public.task_assignees (task_id, user_id) values (_t1, _e1)
    on conflict do nothing;

  -- -------------------------------------------------------------------------
  -- Chat messages (channels are kept, only messages are re-seeded).
  -- -------------------------------------------------------------------------
  if _ch_org is not null then
    insert into public.chat_messages (channel_id, org_id, branch_id, author_id, body) values
      (_ch_org, _org, null, _owner, 'Dzień dobry! W tym tygodniu promocja na lunche.'),
      (_ch_org, _org, null, _e2, 'Super, przygotujemy plakaty.');
  end if;
  if _ch_b1 is not null then
    insert into public.chat_messages (channel_id, org_id, branch_id, author_id, body) values
      (_ch_b1, _org, _b1, _owner, 'Kto bierze dziś wcześniejszą zmianę?'),
      (_ch_b1, _org, _b1, _e1, 'Ja mogę wejść o 8.');
  end if;

  -- -------------------------------------------------------------------------
  -- Day notes (today).
  -- -------------------------------------------------------------------------
  insert into public.day_notes (org_id, branch_id, author_id, date, body, severity) values
    (_org, _b1, _e1, current_date, 'Dużo gości na lunchu, zabrakło zupy dnia.', 'info'),
    (_org, _b1, _e2, current_date, 'Zmywarka głośno pracuje, warto zgłosić.', 'issue');

  -- -------------------------------------------------------------------------
  -- One closed manager report (yesterday): fill money fields of the revenue
  -- section, complete every section, then close (fires revenue sync).
  -- -------------------------------------------------------------------------
  insert into public.manager_reports (id, org_id, branch_id, date, status, created_by)
  values (_rep, _org, _b1, current_date - 1, 'draft', _owner);

  update public.manager_report_sections s set completed = true where s.report_id = _rep;
  update public.manager_report_sections s
    set data = coalesce(
      (select jsonb_object_agg(f ->> 'key', to_jsonb(1500))
         from jsonb_array_elements(d.fields) f
        where f ->> 'type' = 'money'), '{}'::jsonb)
    from public.report_section_defs d
    where s.section_def_id = d.id and s.report_id = _rep and d.is_revenue_source;
  update public.manager_reports set status = 'closed' where id = _rep;

  -- -------------------------------------------------------------------------
  -- Schedule: this week (published) + a little availability.
  -- -------------------------------------------------------------------------
  insert into public.shifts (org_id, branch_id, user_id, starts_at, ends_at, position, published, created_by) values
    (_org, _b1, _e1, _monday + interval '8 hours',        _monday + interval '16 hours',       'Zmiana', true, _owner),
    (_org, _b1, _e2, _monday + interval '1 day 10 hours', _monday + interval '1 day 18 hours', 'Zmiana', true, _owner),
    (_org, _b2, _owner, _monday + interval '2 days 9 hours', _monday + interval '2 days 17 hours', 'Zmiana', true, _owner);

  insert into public.availability (org_id, branch_id, user_id, weekday, from_time, to_time) values
    (_org, _b1, _e1, 0, '08:00', '16:00'),
    (_org, _b1, _e1, 1, '08:00', '16:00');

  -- -------------------------------------------------------------------------
  -- Stock: deliver 30 of every product to the primary branch, but keep the
  -- product with the highest per-branch minimum below its threshold.
  -- (Levels are materialized by the apply_stock_movement trigger.)
  -- -------------------------------------------------------------------------
  select pr.id, bps.min_stock into _low_prod, _low_min
  from public.products pr
  join public.branch_product_settings bps
    on bps.product_id = pr.id and bps.branch_id = _b1
  where pr.org_id = _org and pr.active
  order by bps.min_stock desc nulls last
  limit 1;

  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select _org, _b1, pr.id,
         case when pr.id = _low_prod then greatest(coalesce(_low_min, 5) - 2, 1) else 30 end,
         'delivery', 'Dostawa startowa', _owner
  from public.products pr
  where pr.org_id = _org and pr.active;

  -- A couple of usage movements for history.
  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select _org, _b1, pr.id, -2, 'usage', 'Zużycie dzienne', _e1
  from public.products pr
  where pr.org_id = _org and pr.active and pr.id <> coalesce(_low_prod, '00000000-0000-0000-0000-000000000000')
  limit 2;

  -- -------------------------------------------------------------------------
  -- Costs + revenue for the last 10 days (all branches) → /costs KPIs.
  -- -------------------------------------------------------------------------
  insert into public.revenue_entries (org_id, branch_id, date, amount, source)
  select _org, b.id, gs::date, (3500 + random() * 1500)::numeric(10,2), 'manual'
  from (select id from public.branches where org_id = _org) b,
       generate_series(current_date - 10, current_date - 1, interval '1 day') gs
  on conflict (branch_id, date, source) do nothing;

  insert into public.cost_entries (org_id, branch_id, date, category_id, amount, source, created_by)
  select _org, b.id, gs::date, cc.id, (0.28 * (3500 + random() * 1500))::numeric(10,2), 'manual', _owner
  from (select id from public.branches where org_id = _org) b
  cross join generate_series(current_date - 10, current_date - 1, interval '1 day') gs
  cross join (select id from public.cost_categories where org_id = _org order by sort limit 2) cc;
end;
$$;

revoke all on function private.reset_demo_org() from public;

-- ---------------------------------------------------------------------------
-- Server-side protection: the public demo user's password may never change
-- (a changed password would lock everyone out of the shared account). GoTrue
-- writes encrypted_password directly, so a BEFORE UPDATE trigger is the real
-- enforcement point. Normal sign-ins don't touch encrypted_password → allowed.
-- ---------------------------------------------------------------------------
create or replace function private.protect_demo_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.email = 'demo-public@users.ozmo.local'
     and new.encrypted_password is distinct from old.encrypted_password then
    raise exception 'Konto demo jest chronione — nie można zmienić hasła.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_demo_user on auth.users;
create trigger protect_demo_user
  before update on auth.users
  for each row execute function private.protect_demo_user();

-- ---------------------------------------------------------------------------
-- c. Hourly pg_cron schedule (tolerant of a missing extension).
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron;
exception when others then
  raise notice 'pg_cron unavailable — skipping demo reset schedule';
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from cron.job where jobname = 'reset-demo-org') then
      perform cron.unschedule('reset-demo-org');
    end if;
    perform cron.schedule('reset-demo-org', '0 * * * *', 'select private.reset_demo_org()');
  end if;
exception when others then
  raise notice 'could not schedule reset-demo-org: %', sqlerrm;
end;
$$;
