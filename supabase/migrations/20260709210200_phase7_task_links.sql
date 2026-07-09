-- Phase 7 — task linking (workstream 7)
-- Symmetric links between tasks of the same org. One row per pair; queried in
-- both directions. Reverse duplicates rejected by trigger.

create table public.task_links (
  task_id uuid not null references public.tasks (id) on delete cascade,
  linked_task_id uuid not null references public.tasks (id) on delete cascade,
  created_by uuid references auth.users (id) default auth.uid(),
  created_at timestamptz not null default now(),
  primary key (task_id, linked_task_id),
  constraint task_links_no_self check (task_id <> linked_task_id)
);

create index idx_task_links_linked on public.task_links (linked_task_id);

-- Enforce same-org + reject the reverse pair (symmetric semantics).
create function public.enforce_task_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _org_a uuid;
  _org_b uuid;
begin
  select org_id into _org_a from public.tasks where id = new.task_id;
  select org_id into _org_b from public.tasks where id = new.linked_task_id;
  if _org_a is null or _org_b is null or _org_a <> _org_b then
    raise exception 'Zadania muszą należeć do tej samej organizacji';
  end if;
  if exists (
    select 1 from public.task_links
    where task_id = new.linked_task_id and linked_task_id = new.task_id
  ) then
    raise exception 'Powiązanie już istnieje';
  end if;
  return new;
end;
$$;

create trigger task_links_enforce
  before insert on public.task_links
  for each row execute function public.enforce_task_link();

grant select, insert, delete on public.task_links to authenticated, service_role;

alter table public.task_links enable row level security;

-- Access if the user can access either side's branch (both are same-org).
create policy "task_links_select_access"
  on public.task_links for select to authenticated
  using (
    private.can_access_task(task_id) or private.can_access_task(linked_task_id)
  );

create policy "task_links_insert_access"
  on public.task_links for insert to authenticated
  with check (
    private.can_access_task(task_id)
    and private.can_access_task(linked_task_id)
    and created_by = (select auth.uid())
  );

create policy "task_links_delete_access"
  on public.task_links for delete to authenticated
  using (
    private.can_access_task(task_id) or private.can_access_task(linked_task_id)
  );
