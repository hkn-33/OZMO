-- Phase 6 — harden ownership columns: default created_by / author_id to auth.uid().
--
-- Client code sets these to useSupabaseUser().value.id. Immediately after a
-- full-page (SSR) navigation that ref transiently holds the JWT *claims* object
-- (has `.sub`, no `.id`), so the key evaluates to undefined and is omitted from
-- the insert — which then fails the WITH CHECK `created_by = auth.uid()` (403).
-- Defaulting the column to auth.uid() makes ownership authoritative on the
-- server and immune to that client race (defense-in-depth: the client should
-- never be trusted to supply its own id anyway). Policies are unchanged: a
-- supplied value must still equal auth.uid(); an omitted one is filled correctly.
alter table public.tasks              alter column created_by set default auth.uid();
alter table public.task_comments      alter column author_id  set default auth.uid();
alter table public.day_notes          alter column author_id  set default auth.uid();
alter table public.manager_reports    alter column created_by set default auth.uid();
alter table public.cost_entries       alter column created_by set default auth.uid();
alter table public.revenue_entries    alter column created_by set default auth.uid();
alter table public.stock_movements    alter column created_by set default auth.uid();
alter table public.chat_messages      alter column author_id  set default auth.uid();
alter table public.shifts             alter column created_by set default auth.uid();
alter table public.checklist_templates alter column created_by set default auth.uid();
