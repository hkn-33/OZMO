-- Phase 7 — username-based users (workstream 3)
-- Adds profiles.username (unique, case-insensitive via lower() index),
-- fills it from auth metadata in the profile-creation trigger, and backfills
-- existing users from the email local-part.

alter table public.profiles add column username text;

-- Case-insensitive uniqueness (design.md §10: lower-unique index, no citext dep).
create unique index profiles_username_lower_key
  on public.profiles (lower(username));

-- Recreate the profile-creation trigger to also set a unique username.
-- Username source: metadata.username, else email local-part; sanitized to
-- [a-z0-9_.-]; numeric suffix on collision.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _base text;
  _username text;
  _n int := 0;
begin
  _base := lower(coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    split_part(new.email, '@', 1)
  ));
  _base := regexp_replace(_base, '[^a-z0-9_.-]', '', 'g');
  if _base = '' then
    _base := 'user';
  end if;
  _username := _base;
  while exists (
    select 1 from public.profiles where lower(username) = lower(_username)
  ) loop
    _n := _n + 1;
    _username := _base || _n::text;
  end loop;

  insert into public.profiles (id, full_name, username)
  values (new.id, new.raw_user_meta_data ->> 'full_name', _username);
  return new;
end;
$$;

-- Backfill existing users (no-op on a fresh local reset; matters for prod).
do $$
declare
  r record;
  _base text;
  _username text;
  _n int;
begin
  for r in
    select u.id, u.email
    from auth.users u
    join public.profiles p on p.id = u.id
    where p.username is null
  loop
    _base := regexp_replace(lower(split_part(r.email, '@', 1)), '[^a-z0-9_.-]', '', 'g');
    if _base = '' then
      _base := 'user';
    end if;
    _username := _base;
    _n := 0;
    while exists (
      select 1 from public.profiles where lower(username) = lower(_username)
    ) loop
      _n := _n + 1;
      _username := _base || _n::text;
    end loop;
    update public.profiles set username = _username where id = r.id;
  end loop;
end;
$$;
