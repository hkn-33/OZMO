-- Seed data for OZMO local dev.
--
-- Phase 1: no org-specific seed (orgs created via app onboarding).
-- Phase 2: default checklist templates attached per-org by trigger.
--
-- Phase 7 (workstream 8): a rich, idempotent test account.
--   Login: demo / Demo1234!  (email demo@users.ozmo.local)
--   Org "Restauracje Bella" (plan network — full access), 3 branches,
--   6 more employees, tasks, chat, reports, schedule, stock, costs.
-- Idempotent: the whole block is skipped if the demo user already exists,
-- so `supabase db reset` (empty DB) seeds once and re-runs are no-ops.

do $$
declare
  d_org uuid := 'a0000000-0000-0000-0000-0000000000b1';
  u_demo   uuid := 'b0000000-0000-0000-0000-000000000001';
  u_anna   uuid := 'b0000000-0000-0000-0000-000000000002';
  u_piotr  uuid := 'b0000000-0000-0000-0000-000000000003';
  u_kasia  uuid := 'b0000000-0000-0000-0000-000000000004';
  u_marek  uuid := 'b0000000-0000-0000-0000-000000000005';
  u_ewa    uuid := 'b0000000-0000-0000-0000-000000000006';
  u_tomasz uuid := 'b0000000-0000-0000-0000-000000000007';
  b_centrum uuid := 'c0000000-0000-0000-0000-000000000001';
  b_galeria uuid := 'c0000000-0000-0000-0000-000000000002';
  b_stare   uuid := 'c0000000-0000-0000-0000-000000000003';
  ch_org uuid;
  ch_centrum uuid;
  ch_galeria uuid;
  ch_stare uuid;
  rep_closed uuid := 'd0000000-0000-0000-0000-0000000000c1';
  rep_draft  uuid := 'd0000000-0000-0000-0000-0000000000c2';
  t1 uuid := 'e0000000-0000-0000-0000-000000000001';
  t2 uuid := 'e0000000-0000-0000-0000-000000000002';
  _monday date := (date_trunc('week', now()))::date; -- ISO Monday
  _pw text;
begin
  if exists (select 1 from auth.users where email = 'demo@users.ozmo.local') then
    return;
  end if;

  _pw := extensions.crypt('Demo1234!', extensions.gen_salt('bf'));

  -- ---------------------------------------------------------------
  -- Auth users (username-based, @users.ozmo.local). Profile rows are
  -- created by the on_auth_user_created trigger (username from metadata).
  -- ---------------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change, email_change_token_new
  )
  values
    ('00000000-0000-0000-0000-000000000000', u_demo, 'authenticated', 'authenticated', 'demo@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"demo","full_name":"Demo Właściciel"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_anna, 'authenticated', 'authenticated', 'anna.nowak@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"anna.nowak","full_name":"Anna Nowak"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_piotr, 'authenticated', 'authenticated', 'piotr.kowalski@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"piotr.kowalski","full_name":"Piotr Kowalski"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_kasia, 'authenticated', 'authenticated', 'kasia.wisniewska@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"kasia.wisniewska","full_name":"Katarzyna Wiśniewska"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_marek, 'authenticated', 'authenticated', 'marek.wojcik@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"marek.wojcik","full_name":"Marek Wójcik"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_ewa, 'authenticated', 'authenticated', 'ewa.kaminska@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"ewa.kaminska","full_name":"Ewa Kamińska"}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', u_tomasz, 'authenticated', 'authenticated', 'tomasz.lewandowski@users.ozmo.local', _pw, now(),
     '{"provider":"email","providers":["email"]}', '{"username":"tomasz.lewandowski","full_name":"Tomasz Lewandowski"}', now(), now(), '', '', '', '');

  insert into auth.identities (id, provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select gen_random_uuid(), u.id::text, u.id,
         jsonb_build_object('sub', u.id::text, 'email', u.email), 'email', now(), now(), now()
  from auth.users u
  where u.id in (u_demo, u_anna, u_piotr, u_kasia, u_marek, u_ewa, u_tomasz);

  -- ---------------------------------------------------------------
  -- Organization (network plan) + branches. Triggers create the org chat
  -- channel, per-branch chat channels, checklist templates and a demo
  -- subscription (upgraded to network below).
  -- ---------------------------------------------------------------
  insert into public.organizations (id, name, slug, created_by)
  values (d_org, 'Restauracje Bella', 'restauracje-bella', u_demo);
  update public.subscriptions set plan = 'network' where org_id = d_org;

  insert into public.org_members (org_id, user_id, role) values
    (d_org, u_demo, 'owner'),
    (d_org, u_anna, 'admin'),
    (d_org, u_piotr, 'member'),
    (d_org, u_kasia, 'member'),
    (d_org, u_marek, 'member'),
    (d_org, u_ewa, 'member'),
    (d_org, u_tomasz, 'member');

  insert into public.branches (id, org_id, name, address) values
    (b_centrum, d_org, 'Bella Centrum', 'ul. Rynek 5, Kraków'),
    (b_galeria, d_org, 'Bella Galeria', 'al. Pokoju 44, Kraków'),
    (b_stare,   d_org, 'Bella Stare Miasto', 'ul. Floriańska 12, Kraków');

  insert into public.branch_members (branch_id, user_id, role, position) values
    (b_centrum, u_demo,   'manager',  'Kierownik'),
    (b_centrum, u_kasia,  'employee', 'Kelnerka'),
    (b_centrum, u_tomasz, 'employee', 'Kucharz'),
    (b_galeria, u_anna,   'manager',  'Kierowniczka'),
    (b_galeria, u_marek,  'employee', 'Barman'),
    (b_stare,   u_piotr,  'manager',  'Kierownik'),
    (b_stare,   u_ewa,    'employee', 'Kelnerka');

  select id into ch_org from public.chat_channels where org_id = d_org and type = 'org' limit 1;
  select id into ch_centrum from public.chat_channels where branch_id = b_centrum limit 1;
  select id into ch_galeria from public.chat_channels where branch_id = b_galeria limit 1;
  select id into ch_stare from public.chat_channels where branch_id = b_stare limit 1;

  -- ---------------------------------------------------------------
  -- Tasks (various states) across branches.
  -- ---------------------------------------------------------------
  insert into public.tasks (id, org_id, branch_id, title, description, status, priority, due_at, created_by, position) values
    (t1, d_org, b_centrum, 'Otwarcie lokalu', 'Poranna checklista otwarcia.', 'in_progress', 'high', now() + interval '2 hours', u_demo, 1),
    (t2, d_org, b_centrum, 'Inwentaryzacja baru', 'Policz stany alkoholi i napojów.', 'todo', 'normal', now() + interval '1 day', u_demo, 2),
    (gen_random_uuid(), d_org, b_centrum, 'Zamknięcie kasy', 'Rozliczenie utargu.', 'done', 'normal', now() - interval '12 hours', u_demo, 3),
    (gen_random_uuid(), d_org, b_centrum, 'Naprawa ekspresu', 'Zgłoszenie do serwisu.', 'todo', 'urgent', now() + interval '3 hours', u_kasia, 4),
    (gen_random_uuid(), d_org, b_galeria, 'Sprzątanie sali', 'Generalne po weekendzie.', 'in_progress', 'normal', now() + interval '5 hours', u_anna, 1),
    (gen_random_uuid(), d_org, b_galeria, 'Zamówienie dostawy', 'Uzupełnić braki magazynowe.', 'todo', 'high', now() + interval '1 day', u_anna, 2),
    (gen_random_uuid(), d_org, b_galeria, 'Szkolenie BHP', 'Dla nowego barmana.', 'todo', 'low', now() + interval '3 days', u_anna, 3),
    (gen_random_uuid(), d_org, b_stare, 'Kontrola Sanepid', 'Przygotowanie dokumentów HACCP.', 'in_progress', 'high', now() + interval '2 days', u_piotr, 1),
    (gen_random_uuid(), d_org, b_stare, 'Wymiana menu', 'Nowa karta sezonowa.', 'done', 'normal', now() - interval '1 day', u_piotr, 2),
    (gen_random_uuid(), d_org, b_stare, 'Grafik na przyszły tydzień', 'Ułożyć i opublikować.', 'todo', 'normal', now() + interval '2 days', u_piotr, 3);

  insert into public.task_checklist_items (task_id, label, done, done_by, done_at, sort) values
    (t1, 'Otworzyć lokal i wyłączyć alarm', true, u_kasia, now() - interval '1 hour', 0),
    (t1, 'Włączyć ekspres i lodówki', true, u_kasia, now() - interval '50 minutes', 1),
    (t1, 'Sprawdzić czystość sali', false, null, null, 2),
    (t1, 'Przygotować kasę (bilon)', false, null, null, 3),
    (t2, 'Policzyć piwa', false, null, null, 0),
    (t2, 'Policzyć alkohole wysokoprocentowe', false, null, null, 1),
    (t2, 'Policzyć napoje bezalkoholowe', false, null, null, 2);

  insert into public.task_comments (task_id, org_id, branch_id, author_id, body) values
    (t1, d_org, b_centrum, u_demo, 'Pamiętajcie o wymianie wody w kwiatach.'),
    (t1, d_org, b_centrum, u_kasia, 'Zrobione, ekspres rozgrzany.'),
    (t2, d_org, b_centrum, u_tomasz, 'Brakuje toniku, dopiszę do zamówienia.');

  -- ---------------------------------------------------------------
  -- Group chat messages.
  -- ---------------------------------------------------------------
  insert into public.chat_messages (channel_id, org_id, branch_id, author_id, body) values
    (ch_org, d_org, null, u_demo, 'Dzień dobry wszystkim! W tym tygodniu promocja na lunche.'),
    (ch_org, d_org, null, u_anna, 'Super, przygotujemy plakaty w Galerii.'),
    (ch_org, d_org, null, u_piotr, 'U nas w Starym Mieście też ruszamy.'),
    (ch_centrum, d_org, b_centrum, u_demo, 'Kasia, weź dziś wcześniejszą zmianę?'),
    (ch_centrum, d_org, b_centrum, u_kasia, 'Jasne, będę o 8.'),
    (ch_galeria, d_org, b_galeria, u_anna, 'Marek, dostawa piw przyjdzie po 10.'),
    (ch_stare, d_org, b_stare, u_piotr, 'Ewa, jutro kontrola — ogarnijmy zaplecze.');

  -- ---------------------------------------------------------------
  -- Day notes.
  -- ---------------------------------------------------------------
  insert into public.day_notes (org_id, branch_id, author_id, date, body, severity) values
    (d_org, b_centrum, u_kasia, current_date, 'Dużo gości na lunchu, zabrakło zupy dnia.', 'info'),
    (d_org, b_centrum, u_tomasz, current_date, 'Zmywarka głośno pracuje, warto zgłosić.', 'issue'),
    (d_org, b_galeria, u_marek, current_date, 'Spokojny dzień, wszystko OK.', 'info');

  -- ---------------------------------------------------------------
  -- Manager reports: one closed (yesterday) + one draft (today), Centrum.
  -- ---------------------------------------------------------------
  insert into public.manager_reports (id, org_id, branch_id, date, status, created_by)
  values (rep_closed, d_org, b_centrum, current_date - 1, 'draft', u_demo);
  -- Sections were auto-created; fill + complete them, then close.
  update public.manager_report_sections
    set data = '{"gotowka": 1800, "karta": 2600, "inne": 100}'::jsonb, completed = true
    where report_id = rep_closed and section = 'utarg';
  update public.manager_report_sections set completed = true, data = '{"stan": "zgodny"}'::jsonb
    where report_id = rep_closed and section <> 'utarg';
  update public.manager_reports set status = 'closed' where id = rep_closed;

  insert into public.manager_reports (id, org_id, branch_id, date, status, created_by)
  values (rep_draft, d_org, b_centrum, current_date, 'draft', u_demo);
  update public.manager_report_sections
    set data = '{"gotowka": 900, "karta": 1200, "inne": 0}'::jsonb, completed = true
    where report_id = rep_draft and section = 'utarg';

  -- ---------------------------------------------------------------
  -- Schedule: shifts this week (published) + availability.
  -- weekday 0 = Monday.
  -- ---------------------------------------------------------------
  insert into public.shifts (org_id, branch_id, user_id, starts_at, ends_at, position, published, created_by) values
    (d_org, b_centrum, u_kasia,  _monday + interval '8 hours',  _monday + interval '16 hours', 'Kelnerka', true, u_demo),
    (d_org, b_centrum, u_tomasz, _monday + interval '10 hours', _monday + interval '18 hours', 'Kuchnia', true, u_demo),
    (d_org, b_centrum, u_kasia,  _monday + interval '1 day 8 hours', _monday + interval '1 day 16 hours', 'Kelnerka', true, u_demo),
    (d_org, b_galeria, u_marek,  _monday + interval '12 hours', _monday + interval '20 hours', 'Bar', true, u_anna),
    (d_org, b_stare,   u_ewa,    _monday + interval '9 hours',  _monday + interval '17 hours', 'Kelnerka', true, u_piotr);

  insert into public.availability (org_id, branch_id, user_id, weekday, from_time, to_time) values
    (d_org, b_centrum, u_kasia, 0, '08:00', '16:00'),
    (d_org, b_centrum, u_kasia, 1, '08:00', '16:00'),
    (d_org, b_centrum, u_tomasz, 0, '10:00', '20:00'),
    (d_org, b_galeria, u_marek, 2, '12:00', '22:00'),
    (d_org, b_stare, u_ewa, 3, '09:00', '17:00');

  -- ---------------------------------------------------------------
  -- Suppliers.
  -- ---------------------------------------------------------------
  insert into public.suppliers (org_id, name, contact_name, phone) values
    (d_org, 'Hurtownia Smak', 'Jan Dostawca', '600100200'),
    (d_org, 'Browar Regionalny', 'Ala Piwna', '600300400'),
    (d_org, 'Warzywniak Świeży', 'Ola Zielona', '600500600');

  -- ---------------------------------------------------------------
  -- Products (15, org-level) + per-branch minimums + stock via movements.
  -- Some Centrum products intentionally below minimum.
  -- ---------------------------------------------------------------
  insert into public.products (id, org_id, name, unit, category)
  select ('f0000000-0000-0000-0000-0000000000' || lpad(g::text, 2, '0'))::uuid, d_org, p.name, p.unit, p.category
  from (values
    (1,'Kawa ziarnista','kg','Napoje'),
    (2,'Herbata czarna','opak','Napoje'),
    (3,'Mleko','l','Napoje'),
    (4,'Cukier','kg','Suche'),
    (5,'Mąka pszenna','kg','Suche'),
    (6,'Makaron','kg','Suche'),
    (7,'Pomidory','kg','Warzywa'),
    (8,'Sałata','szt','Warzywa'),
    (9,'Ser mozzarella','kg','Nabiał'),
    (10,'Masło','kg','Nabiał'),
    (11,'Piwo lager','opak','Alkohol'),
    (12,'Wino czerwone','szt','Alkohol'),
    (13,'Cola','opak','Napoje'),
    (14,'Woda mineralna','opak','Napoje'),
    (15,'Oliwa z oliwek','l','Suche')
  ) p(g, name, unit, category);

  -- Minimums for Centrum (all 15) + a subset for the other branches.
  insert into public.branch_product_settings (branch_id, product_id, org_id, min_stock)
  select b_centrum, pr.id, d_org,
         case when pr.name in ('Kawa ziarnista','Mleko','Piwo lager') then 20 else 5 end
  from public.products pr where pr.org_id = d_org;

  insert into public.branch_product_settings (branch_id, product_id, org_id, min_stock)
  select b_galeria, pr.id, d_org, 8
  from public.products pr where pr.org_id = d_org and pr.name in ('Kawa ziarnista','Mleko','Piwo lager','Cola','Woda mineralna');

  insert into public.branch_product_settings (branch_id, product_id, org_id, min_stock)
  select b_stare, pr.id, d_org, 6
  from public.products pr where pr.org_id = d_org and pr.name in ('Kawa ziarnista','Mleko','Wino czerwone','Sałata');

  -- Stock via delivery movements (materializes stock_levels). Centrum first:
  -- coffee/mleko/piwo below their high minimums to show red cells.
  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select d_org, b_centrum, pr.id,
         case
           when pr.name = 'Kawa ziarnista' then 8   -- below min 20
           when pr.name = 'Mleko' then 12           -- below min 20
           when pr.name = 'Piwo lager' then 15      -- below min 20
           else 30
         end,
         'delivery', 'Dostawa startowa', u_demo
  from public.products pr where pr.org_id = d_org;

  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select d_org, b_galeria, pr.id,
         case when pr.name = 'Cola' then 3 else 25 end, -- Cola below min 8
         'delivery', 'Dostawa startowa', u_anna
  from public.products pr where pr.org_id = d_org and pr.name in ('Kawa ziarnista','Mleko','Piwo lager','Cola','Woda mineralna');

  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select d_org, b_stare, pr.id, 18,
         'delivery', 'Dostawa startowa', u_piotr
  from public.products pr where pr.org_id = d_org and pr.name in ('Kawa ziarnista','Mleko','Wino czerwone','Sałata');

  -- A couple of usage movements at Centrum for history.
  insert into public.stock_movements (org_id, branch_id, product_id, qty_delta, type, note, created_by)
  select d_org, b_centrum, pr.id, -2, 'usage', 'Zużycie dzienne', u_kasia
  from public.products pr where pr.org_id = d_org and pr.name in ('Mleko','Cukier');

  -- ---------------------------------------------------------------
  -- Costs + revenue for the last 20 days (all branches) → /costs KPIs.
  -- (Closed manager report above already synced one revenue row.)
  -- ---------------------------------------------------------------
  insert into public.revenue_entries (org_id, branch_id, date, amount, source)
  select d_org, b.id, gs::date, (3500 + (random() * 2500))::numeric(10,2), 'manual'
  from (values (b_centrum), (b_galeria), (b_stare)) b(id),
       generate_series(current_date - 20, current_date - 2, interval '1 day') gs
  on conflict (branch_id, date, source) do nothing;

  insert into public.cost_entries (org_id, branch_id, date, category, amount, source, created_by)
  select d_org, b.id, gs::date, c.cat::public.cost_category, (c.factor * (3500 + random() * 2500))::numeric(10,2), 'manual', u_demo
  from (values (b_centrum), (b_galeria), (b_stare)) b(id),
       generate_series(current_date - 20, current_date - 2, interval '1 day') gs,
       (values ('food', 0.30), ('beverage', 0.10), ('labor', 0.25)) c(cat, factor);

end;
$$;
