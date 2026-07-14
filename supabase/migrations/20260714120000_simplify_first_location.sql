-- Keep onboarding atomic, but make its automatically created branch usable for
-- every industry instead of presenting it as restaurant demo data.
create or replace function public.create_organization(_name text, _industry text)
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

  update public.branches
  set name = 'Główny lokal', address = null
  where org_id = _org.id and name = 'Przykład: Lokal Główny';

  update public.tasks
  set title = case title
      when 'Przykład: Otwarcie lokalu' then 'Przykład: Otwarcie zmiany'
      when 'Przykład: Uzupełnienie magazynu' then 'Przykład: Uzupełnienie zapasów'
      when 'Przykład: Zamknięcie kasy' then 'Przykład: Zamknięcie dnia'
      else title
    end
  where org_id = _org.id;

  update public.products
  set name = case name
      when 'Przykład: Kawa ziarnista' then 'Przykład: Materiały eksploatacyjne'
      when 'Przykład: Mleko' then 'Przykład: Środek czystości'
      else name
    end,
    category = 'Materiały'
  where org_id = _org.id;

  return _org;
end;
$$;

revoke all on function public.create_organization(text, text) from public;
grant execute on function public.create_organization(text, text) to authenticated;
