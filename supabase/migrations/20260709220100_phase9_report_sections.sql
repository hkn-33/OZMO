-- Phase 9 (workstream 2) — configurable manager-report sections.
-- Kills the hardcoded public.report_section enum and replaces it with a per-org
-- report_section_defs table (name, sort, fields jsonb, required, is_revenue_source).
-- manager_report_sections.section (enum) → section_def_id (FK). Rewrites the
-- section-seeding, close-lock and revenue-sync triggers to work off the defs.

-- =============================================================
-- report_section_defs (per-org, configurable)
-- fields jsonb: array of { key, label, type: 'money'|'number'|'text'|'boolean' }
-- Exactly one def per org should carry is_revenue_source = true (revenue sync).
-- =============================================================
create table public.report_section_defs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  sort int not null default 0,
  fields jsonb not null default '[]'::jsonb,
  required boolean not null default true,
  is_revenue_source boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index report_section_defs_org_name_uniq
  on public.report_section_defs (org_id, lower(name));
create index idx_report_section_defs_org on public.report_section_defs (org_id, sort);

-- =============================================================
-- Migrate manager_report_sections.section (enum) → section_def_id (FK).
-- For every org with reports, create the 5 legacy (gastro) defs with equivalent
-- fields, then repoint each section row. On a fresh DB this is a no-op.
-- =============================================================
alter table public.manager_report_sections
  add column section_def_id uuid references public.report_section_defs (id) on delete cascade;

do $$
declare
  _org uuid;
begin
  for _org in select distinct org_id from public.manager_reports loop
    insert into public.report_section_defs (org_id, name, sort, fields, required, is_revenue_source) values
      (_org, 'Przychód dnia', 0,
        '[{"key":"gotowka","label":"Gotówka","type":"money"},{"key":"karta","label":"Karta","type":"money"},{"key":"inne","label":"Inne","type":"money"}]'::jsonb,
        true, true),
      (_org, 'Kasa', 1,
        '[{"key":"stan_poczatkowy","label":"Stan początkowy","type":"money"},{"key":"stan_koncowy","label":"Stan końcowy","type":"money"},{"key":"uwagi","label":"Uwagi","type":"text"}]'::jsonb,
        true, false),
      (_org, 'Kontrola jakości', 2,
        '[{"key":"zgodnosc","label":"Zgodność z wymogami","type":"boolean"},{"key":"uwagi","label":"Uwagi","type":"text"}]'::jsonb,
        true, false),
      (_org, 'Magazyn', 3,
        '[{"key":"braki","label":"Braki","type":"text"},{"key":"zamowienia","label":"Zamówienia","type":"text"}]'::jsonb,
        true, false),
      (_org, 'Przebieg zmiany', 4,
        '[{"key":"obsada","label":"Obsada (liczba osób)","type":"number"},{"key":"problemy","label":"Problemy","type":"text"},{"key":"notatki","label":"Notatki","type":"text"}]'::jsonb,
        true, false)
    on conflict do nothing;
  end loop;

  update public.manager_report_sections s
    set section_def_id = d.id
  from public.manager_reports r, public.report_section_defs d
  where s.report_id = r.id
    and d.org_id = r.org_id
    and d.name = case s.section
      when 'utarg' then 'Przychód dnia'
      when 'kasa' then 'Kasa'
      when 'sanepid' then 'Kontrola jakości'
      when 'magazyn' then 'Magazyn'
      when 'zmiana' then 'Przebieg zmiany'
    end;
end $$;

alter table public.manager_report_sections
  drop constraint manager_report_sections_report_id_section_key;
alter table public.manager_report_sections drop column section;
alter table public.manager_report_sections alter column section_def_id set not null;
alter table public.manager_report_sections
  add constraint manager_report_sections_report_def_uniq unique (report_id, section_def_id);
drop type public.report_section;

-- =============================================================
-- Rewrite trigger functions (built in phase 3 / phase 5) to work off defs.
-- =============================================================

-- Auto-create one section row per org report-section def.
create or replace function public.seed_report_sections()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.manager_report_sections (report_id, section_def_id)
  select new.id, d.id
  from public.report_section_defs d
  where d.org_id = new.org_id;
  return new;
end;
$$;

-- Close-lock: draft → closed allowed only when all REQUIRED sections completed.
create or replace function public.enforce_manager_report_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'closed' then
    raise exception 'Raport jest zamknięty i nie można go edytować';
  end if;

  if new.status = 'closed' and old.status <> 'closed' then
    if exists (
      select 1
      from public.manager_report_sections s
      join public.report_section_defs d on d.id = s.section_def_id
      where s.report_id = new.id and d.required and s.completed = false
    ) then
      raise exception 'Nie można zamknąć raportu: nie wszystkie wymagane sekcje są ukończone';
    end if;
    new.closed_by := (select auth.uid());
    new.closed_at := now();
  end if;

  return new;
end;
$$;

-- Revenue sync: on draft → closed, sum every 'money' field of the section whose
-- def carries is_revenue_source, then upsert revenue_entries.
create or replace function public.sync_revenue_from_report()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _data jsonb;
  _fields jsonb;
  _f jsonb;
  _sum numeric := 0;
begin
  if new.status = 'closed' and old.status is distinct from 'closed' then
    select s.data, d.fields
      into _data, _fields
      from public.manager_report_sections s
      join public.report_section_defs d on d.id = s.section_def_id
      where s.report_id = new.id and d.is_revenue_source
      limit 1;

    if _fields is not null then
      for _f in select * from jsonb_array_elements(_fields) loop
        if _f ->> 'type' = 'money' then
          _sum := _sum + coalesce((_data ->> (_f ->> 'key'))::numeric, 0);
        end if;
      end loop;
    end if;

    insert into public.revenue_entries (org_id, branch_id, date, amount, source, created_by)
    values (new.org_id, new.branch_id, new.date, coalesce(_sum, 0), 'manager_report', new.closed_by)
    on conflict (branch_id, date, source)
    do update set amount = excluded.amount, created_by = excluded.created_by;
  end if;
  return new;
end;
$$;

-- =============================================================
-- Grants + RLS for report_section_defs.
-- SELECT: org members. CUD: org admins (settings-level config).
-- =============================================================
grant select, insert, update, delete on public.report_section_defs to authenticated, service_role;

alter table public.report_section_defs enable row level security;

create policy "report_section_defs_select_member"
  on public.report_section_defs for select to authenticated
  using (private.is_org_member(org_id));

create policy "report_section_defs_insert_admin"
  on public.report_section_defs for insert to authenticated
  with check (private.is_org_admin(org_id));

create policy "report_section_defs_update_admin"
  on public.report_section_defs for update to authenticated
  using (private.is_org_admin(org_id))
  with check (private.is_org_admin(org_id));

create policy "report_section_defs_delete_admin"
  on public.report_section_defs for delete to authenticated
  using (private.is_org_admin(org_id));
