-- Phase 9 (workstream 3) — industry presets + neutral onboarding.
-- OZMO is now a general multi-branch business platform. The old restaurant-only
-- default-templates trigger is replaced by public.apply_industry_preset(org, industry)
-- which seeds industry-appropriate checklist templates, cost categories and report
-- section defs. An org-insert trigger applies the preset based on organizations.industry.

alter table public.organizations add column industry text;

-- =============================================================
-- Retire the phase-2 restaurant-only default templates trigger.
-- =============================================================
drop trigger if exists organizations_seed_templates on public.organizations;
drop function if exists public.seed_default_checklist_templates();

-- =============================================================
-- apply_industry_preset — seeds templates + cost categories + report defs
-- for one org, tailored to the chosen industry. Security definer (bypass RLS).
-- Idempotent via unique indexes (on conflict do nothing).
-- =============================================================
create function public.apply_industry_preset(_org_id uuid, _industry text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _created_by uuid;
  _ind text := coalesce(lower(_industry), 'inna');
begin
  select created_by into _created_by from public.organizations where id = _org_id;

  -- ----- Checklist templates -----------------------------------
  if _ind = 'gastronomia' or _ind = 'kawiarnia' then
    insert into public.checklist_templates (org_id, name, description, items, created_by) values
      (_org_id, 'Otwarcie lokalu', 'Czynności przy otwarciu zmiany', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź czystość sali i toalet'),
        jsonb_build_object('label', 'Włącz oświetlenie i sprzęt'),
        jsonb_build_object('label', 'Sprawdź kasę i stan gotówki'),
        jsonb_build_object('label', 'Skontroluj temperatury lodówek'),
        jsonb_build_object('label', 'Przygotuj stanowiska pracy'),
        jsonb_build_object('label', 'Odbierz poranne dostawy')), _created_by),
      (_org_id, 'Zamknięcie lokalu', 'Czynności przy zamknięciu zmiany', jsonb_build_array(
        jsonb_build_object('label', 'Rozlicz kasę i przychód dnia'),
        jsonb_build_object('label', 'Wyczyść i wyłącz sprzęt'),
        jsonb_build_object('label', 'Umyj podłogi i blaty'),
        jsonb_build_object('label', 'Wynieś śmieci'),
        jsonb_build_object('label', 'Sprawdź zamknięcie i uzbrój alarm')), _created_by),
      (_org_id, 'Sprzątanie', 'Rutynowe sprzątanie', jsonb_build_array(
        jsonb_build_object('label', 'Umyj podłogi'),
        jsonb_build_object('label', 'Zdezynfekuj powierzchnie robocze'),
        jsonb_build_object('label', 'Wyczyść toalety'),
        jsonb_build_object('label', 'Opróżnij kosze'),
        jsonb_build_object('label', 'Uzupełnij środki czystości')), _created_by),
      (_org_id, 'Inwentaryzacja', 'Spis stanów magazynowych', jsonb_build_array(
        jsonb_build_object('label', 'Policz stany produktów suchych'),
        jsonb_build_object('label', 'Sprawdź stany w lodówkach'),
        jsonb_build_object('label', 'Sprawdź stan napojów'),
        jsonb_build_object('label', 'Odnotuj produkty przeterminowane'),
        jsonb_build_object('label', 'Zgłoś braki do zamówienia')), _created_by),
      (_org_id, 'Kontrola Sanepid/HACCP', 'Lista kontrolna zgodności sanitarnej', jsonb_build_array(
        jsonb_build_object('label', 'Zapisz temperatury lodówek i mroźni'),
        jsonb_build_object('label', 'Skontroluj daty przydatności'),
        jsonb_build_object('label', 'Sprawdź czystość stanowisk'),
        jsonb_build_object('label', 'Sprawdź higienę personelu'),
        jsonb_build_object('label', 'Uzupełnij karty kontroli HACCP')), _created_by)
    on conflict do nothing;
  elsif _ind = 'hotel' then
    insert into public.checklist_templates (org_id, name, description, items, created_by) values
      (_org_id, 'Przygotowanie pokoi', 'Housekeeping', jsonb_build_array(
        jsonb_build_object('label', 'Wymiana pościeli i ręczników'),
        jsonb_build_object('label', 'Sprzątanie łazienek'),
        jsonb_build_object('label', 'Uzupełnienie kosmetyków i zapasów'),
        jsonb_build_object('label', 'Kontrola sprawności wyposażenia'),
        jsonb_build_object('label', 'Odkurzanie i wietrzenie')), _created_by),
      (_org_id, 'Odprawa recepcji', 'Check-in / check-out', jsonb_build_array(
        jsonb_build_object('label', 'Przegląd rezerwacji na dziś'),
        jsonb_build_object('label', 'Przygotowanie kart / kluczy'),
        jsonb_build_object('label', 'Rozliczenie kasy recepcji'),
        jsonb_build_object('label', 'Obsługa wymeldowań')), _created_by),
      (_org_id, 'Sprzątanie części wspólnych', 'Lobby, korytarze, sala', jsonb_build_array(
        jsonb_build_object('label', 'Sprzątanie lobby i recepcji'),
        jsonb_build_object('label', 'Korytarze i windy'),
        jsonb_build_object('label', 'Toalety ogólnodostępne'),
        jsonb_build_object('label', 'Sala śniadaniowa')), _created_by),
      (_org_id, 'Przegląd BHP', 'Bezpieczeństwo obiektu', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź drogi ewakuacyjne'),
        jsonb_build_object('label', 'Kontrola gaśnic i oświetlenia awaryjnego'),
        jsonb_build_object('label', 'Sprawdź oznakowanie'),
        jsonb_build_object('label', 'Zgłoś usterki')), _created_by),
      (_org_id, 'Zamknięcie dnia recepcji', 'Podsumowanie doby', jsonb_build_array(
        jsonb_build_object('label', 'Raport dobowy'),
        jsonb_build_object('label', 'Rozliczenie płatności'),
        jsonb_build_object('label', 'Przekazanie zmiany')), _created_by)
    on conflict do nothing;
  elsif _ind = 'sklep' then
    insert into public.checklist_templates (org_id, name, description, items, created_by) values
      (_org_id, 'Otwarcie sklepu', 'Rozpoczęcie dnia', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź czystość i ekspozycję'),
        jsonb_build_object('label', 'Włącz kasy i systemy'),
        jsonb_build_object('label', 'Rozmień gotówkę'),
        jsonb_build_object('label', 'Sprawdź ceny i promocje')), _created_by),
      (_org_id, 'Zamknięcie sklepu', 'Koniec dnia', jsonb_build_array(
        jsonb_build_object('label', 'Rozlicz kasy'),
        jsonb_build_object('label', 'Zabezpiecz utarg'),
        jsonb_build_object('label', 'Sprzątanie sali sprzedaży'),
        jsonb_build_object('label', 'Uzbrój alarm')), _created_by),
      (_org_id, 'Wykładanie towaru', 'Uzupełnianie półek', jsonb_build_array(
        jsonb_build_object('label', 'Przyjmij dostawę'),
        jsonb_build_object('label', 'Uzupełnij półki'),
        jsonb_build_object('label', 'Rotacja towaru wg dat'),
        jsonb_build_object('label', 'Uzupełnij metki i ceny')), _created_by),
      (_org_id, 'Kontrola cen i metek', 'Zgodność cen', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź ceny na półkach'),
        jsonb_build_object('label', 'Zaktualizuj promocje'),
        jsonb_build_object('label', 'Wymień uszkodzone etykiety')), _created_by),
      (_org_id, 'Inwentaryzacja', 'Spis stanów', jsonb_build_array(
        jsonb_build_object('label', 'Policz towar wg kategorii'),
        jsonb_build_object('label', 'Odnotuj braki i nadwyżki'),
        jsonb_build_object('label', 'Zgłoś zamówienia')), _created_by)
    on conflict do nothing;
  elsif _ind = 'magazyn' then
    insert into public.checklist_templates (org_id, name, description, items, created_by) values
      (_org_id, 'Przyjęcie dostawy', 'Rozładunek i kontrola', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź dokument dostawy (WZ)'),
        jsonb_build_object('label', 'Zliczenie ilościowe'),
        jsonb_build_object('label', 'Kontrola jakości i uszkodzeń'),
        jsonb_build_object('label', 'Rozmieszczenie w strefach'),
        jsonb_build_object('label', 'Wprowadzenie do systemu')), _created_by),
      (_org_id, 'Wysyłka zamówień', 'Kompletacja i wydanie', jsonb_build_array(
        jsonb_build_object('label', 'Kompletacja zamówień'),
        jsonb_build_object('label', 'Kontrola przed wysyłką'),
        jsonb_build_object('label', 'Etykiety i dokumenty'),
        jsonb_build_object('label', 'Wydanie przewoźnikowi')), _created_by),
      (_org_id, 'Przegląd BHP', 'Bezpieczeństwo pracy', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź drogi transportowe'),
        jsonb_build_object('label', 'Kontrola wózków widłowych'),
        jsonb_build_object('label', 'Sprawdź gaśnice i wyjścia'),
        jsonb_build_object('label', 'Środki ochrony osobistej')), _created_by),
      (_org_id, 'Inwentaryzacja strefy', 'Spis z natury', jsonb_build_array(
        jsonb_build_object('label', 'Policz pozycje w strefie'),
        jsonb_build_object('label', 'Porównaj ze stanem systemowym'),
        jsonb_build_object('label', 'Wyjaśnij różnice'),
        jsonb_build_object('label', 'Zatwierdź korekty')), _created_by),
      (_org_id, 'Kontrola sprzętu', 'Przegląd wyposażenia', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź regały i zabezpieczenia'),
        jsonb_build_object('label', 'Stan wózków i palet'),
        jsonb_build_object('label', 'Zgłoś usterki')), _created_by)
    on conflict do nothing;
  else -- 'inna' — minimal generic set
    insert into public.checklist_templates (org_id, name, description, items, created_by) values
      (_org_id, 'Otwarcie', 'Rozpoczęcie dnia', jsonb_build_array(
        jsonb_build_object('label', 'Sprawdź stanowiska pracy'),
        jsonb_build_object('label', 'Uruchom sprzęt i systemy'),
        jsonb_build_object('label', 'Przegląd zadań na dziś')), _created_by),
      (_org_id, 'Zamknięcie', 'Koniec dnia', jsonb_build_array(
        jsonb_build_object('label', 'Podsumuj dzień'),
        jsonb_build_object('label', 'Zabezpiecz obiekt'),
        jsonb_build_object('label', 'Przekaż zmianę')), _created_by),
      (_org_id, 'Sprzątanie', 'Porządki', jsonb_build_array(
        jsonb_build_object('label', 'Uprzątnij stanowiska'),
        jsonb_build_object('label', 'Opróżnij kosze'),
        jsonb_build_object('label', 'Uzupełnij materiały')), _created_by)
    on conflict do nothing;
  end if;

  -- ----- Cost categories ---------------------------------------
  if _ind = 'gastronomia' or _ind = 'kawiarnia' then
    insert into public.cost_categories (org_id, name, sort) values
      (_org_id, 'Jedzenie', 0), (_org_id, 'Napoje', 1), (_org_id, 'Praca', 2),
      (_org_id, 'Media', 3), (_org_id, 'Inne', 4)
    on conflict do nothing;
  elsif _ind = 'hotel' then
    insert into public.cost_categories (org_id, name, sort) values
      (_org_id, 'Utrzymanie', 0), (_org_id, 'Wyżywienie', 1), (_org_id, 'Praca', 2),
      (_org_id, 'Media', 3), (_org_id, 'Inne', 4)
    on conflict do nothing;
  elsif _ind = 'sklep' then
    insert into public.cost_categories (org_id, name, sort) values
      (_org_id, 'Towar', 0), (_org_id, 'Praca', 1), (_org_id, 'Media', 2),
      (_org_id, 'Marketing', 3), (_org_id, 'Inne', 4)
    on conflict do nothing;
  elsif _ind = 'magazyn' then
    insert into public.cost_categories (org_id, name, sort) values
      (_org_id, 'Towar', 0), (_org_id, 'Transport', 1), (_org_id, 'Praca', 2),
      (_org_id, 'Media', 3), (_org_id, 'Inne', 4)
    on conflict do nothing;
  else
    insert into public.cost_categories (org_id, name, sort) values
      (_org_id, 'Praca', 0), (_org_id, 'Media', 1), (_org_id, 'Inne', 2)
    on conflict do nothing;
  end if;

  -- ----- Report section defs -----------------------------------
  if _ind = 'gastronomia' or _ind = 'kawiarnia' then
    insert into public.report_section_defs (org_id, name, sort, fields, required, is_revenue_source) values
      (_org_id, 'Przychód dnia', 0,
        '[{"key":"gotowka","label":"Gotówka","type":"money"},{"key":"karta","label":"Karta","type":"money"},{"key":"inne","label":"Inne","type":"money"}]'::jsonb, true, true),
      (_org_id, 'Kasa', 1,
        '[{"key":"stan_poczatkowy","label":"Stan początkowy","type":"money"},{"key":"stan_koncowy","label":"Stan końcowy","type":"money"},{"key":"uwagi","label":"Uwagi","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Kontrola jakości', 2,
        '[{"key":"zgodnosc","label":"Zgodność z wymogami","type":"boolean"},{"key":"uwagi","label":"Uwagi","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Magazyn', 3,
        '[{"key":"braki","label":"Braki","type":"text"},{"key":"zamowienia","label":"Zamówienia","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Przebieg zmiany', 4,
        '[{"key":"obsada","label":"Obsada (liczba osób)","type":"number"},{"key":"problemy","label":"Problemy","type":"text"},{"key":"notatki","label":"Notatki","type":"text"}]'::jsonb, true, false)
    on conflict do nothing;
  elsif _ind = 'hotel' then
    insert into public.report_section_defs (org_id, name, sort, fields, required, is_revenue_source) values
      (_org_id, 'Przychód dnia', 0,
        '[{"key":"gotowka","label":"Gotówka","type":"money"},{"key":"karta","label":"Karta","type":"money"},{"key":"inne","label":"Inne","type":"money"}]'::jsonb, true, true),
      (_org_id, 'Obłożenie', 1,
        '[{"key":"pokoje","label":"Liczba pokoi","type":"number"},{"key":"zajete","label":"Zajęte pokoje","type":"number"}]'::jsonb, true, false),
      (_org_id, 'Housekeeping', 2,
        '[{"key":"status","label":"Status sprzątania","type":"text"},{"key":"uwagi","label":"Uwagi","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Przebieg zmiany', 3,
        '[{"key":"obsada","label":"Obsada (liczba osób)","type":"number"},{"key":"notatki","label":"Notatki","type":"text"}]'::jsonb, true, false)
    on conflict do nothing;
  elsif _ind = 'sklep' then
    insert into public.report_section_defs (org_id, name, sort, fields, required, is_revenue_source) values
      (_org_id, 'Przychód dnia', 0,
        '[{"key":"gotowka","label":"Gotówka","type":"money"},{"key":"karta","label":"Karta","type":"money"},{"key":"inne","label":"Inne","type":"money"}]'::jsonb, true, true),
      (_org_id, 'Kasa', 1,
        '[{"key":"stan_poczatkowy","label":"Stan początkowy","type":"money"},{"key":"stan_koncowy","label":"Stan końcowy","type":"money"}]'::jsonb, true, false),
      (_org_id, 'Stan magazynu', 2,
        '[{"key":"braki","label":"Braki","type":"text"},{"key":"zamowienia","label":"Zamówienia","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Przebieg zmiany', 3,
        '[{"key":"obsada","label":"Obsada (liczba osób)","type":"number"},{"key":"notatki","label":"Notatki","type":"text"}]'::jsonb, true, false)
    on conflict do nothing;
  elsif _ind = 'magazyn' then
    insert into public.report_section_defs (org_id, name, sort, fields, required, is_revenue_source) values
      (_org_id, 'Przychód dnia', 0,
        '[{"key":"gotowka","label":"Gotówka","type":"money"},{"key":"przelewy","label":"Przelewy","type":"money"}]'::jsonb, true, true),
      (_org_id, 'Stan magazynu', 1,
        '[{"key":"pozycje","label":"Liczba pozycji","type":"number"},{"key":"uwagi","label":"Uwagi","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Wysyłki', 2,
        '[{"key":"liczba_wysylek","label":"Liczba wysyłek","type":"number"},{"key":"opoznienia","label":"Opóźnienia","type":"text"}]'::jsonb, true, false),
      (_org_id, 'Przebieg zmiany', 3,
        '[{"key":"obsada","label":"Obsada (liczba osób)","type":"number"},{"key":"notatki","label":"Notatki","type":"text"}]'::jsonb, true, false)
    on conflict do nothing;
  else
    insert into public.report_section_defs (org_id, name, sort, fields, required, is_revenue_source) values
      (_org_id, 'Przychód dnia', 0,
        '[{"key":"gotowka","label":"Gotówka","type":"money"},{"key":"karta","label":"Karta","type":"money"},{"key":"inne","label":"Inne","type":"money"}]'::jsonb, true, true),
      (_org_id, 'Przebieg zmiany', 1,
        '[{"key":"notatki","label":"Notatki","type":"text"}]'::jsonb, true, false)
    on conflict do nothing;
  end if;
end;
$$;

revoke all on function public.apply_industry_preset(uuid, text) from public;
grant execute on function public.apply_industry_preset(uuid, text) to authenticated, service_role;

-- =============================================================
-- Org-insert trigger: seed preset from organizations.industry (default 'inna').
-- Every org (onboarding, seed, service_role) gets a baseline preset.
-- =============================================================
create function public.apply_org_industry_preset()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.apply_industry_preset(new.id, coalesce(new.industry, 'inna'));
  return new;
end;
$$;

create trigger organizations_apply_preset
  after insert on public.organizations
  for each row execute function public.apply_org_industry_preset();

-- =============================================================
-- create_organization — now accepts industry. Replaces the unused phase-1
-- 2-arg (name, slug) version; the 1-arg version stays for backwards compat.
-- =============================================================
drop function if exists public.create_organization(text, text);

create function public.create_organization(_name text, _industry text)
returns public.organizations
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := (select auth.uid());
  _org public.organizations;
  _base text;
  _slug text;
begin
  if _uid is null then
    raise exception 'Not authenticated';
  end if;

  _base := lower(_name);
  _base := translate(_base, 'ąćęłńóśźż', 'acelnoszz');
  _base := regexp_replace(_base, '[^a-z0-9]+', '-', 'g');
  _base := regexp_replace(_base, '(^-+|-+$)', '', 'g');
  if _base = '' then
    _base := 'org';
  end if;

  _slug := _base;
  while exists (select 1 from public.organizations where slug = _slug) loop
    _slug := _base || '-' || substr(md5(random()::text), 1, 6);
  end loop;

  insert into public.organizations (name, slug, created_by, industry)
  values (_name, _slug, _uid, coalesce(_industry, 'inna'))
  returning * into _org;

  insert into public.org_members (org_id, user_id, role)
  values (_org.id, _uid, 'owner');

  perform public.seed_demo_samples(_org.id, _uid);

  return _org;
end;
$$;

revoke all on function public.create_organization(text, text) from public;
grant execute on function public.create_organization(text, text) to authenticated;
