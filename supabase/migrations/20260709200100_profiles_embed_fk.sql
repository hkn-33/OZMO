-- Phase 6 — fix: enable PostgREST to embed public.profiles from membership tables.
--
-- The app resolves member/author display names via `profiles(...)` embeds off
-- branch_members / org_members (app/pages/tasks, people, schedule/*). Those
-- user columns only had a foreign key to auth.users, which PostgREST does not
-- expose, so the embed failed with "Could not find a relationship between
-- '<table>' and 'profiles' in the schema cache" and the whole membership query
-- returned no rows — member lists, assignee pickers and author names came back
-- empty. profiles.id is 1:1 with auth.users(id) (created by handle_new_user),
-- so an explicit FK to profiles is always satisfiable. Deletion stays
-- consistent: profiles.id -> auth.users ON DELETE CASCADE, and these FKs also
-- cascade, so removing a user cleans up membership rows either way.

alter table public.branch_members
  add constraint branch_members_user_id_profiles_fkey
  foreign key (user_id) references public.profiles (id) on delete cascade;

alter table public.org_members
  add constraint org_members_user_id_profiles_fkey
  foreign key (user_id) references public.profiles (id) on delete cascade;
