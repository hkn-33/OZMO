-- Phase 11 — production hardening (advisor: anon/authenticated can EXECUTE
-- SECURITY DEFINER function).
--
-- Trigger and internal helper functions run as owner and are never meant to be
-- called through PostgREST (/rest/v1/rpc/*). Supabase grants EXECUTE on public
-- functions to anon+authenticated by default, so we revoke it explicitly.
--
-- Kept as-is (intended, self-authorizing RPCs called from the client):
--   create_organization(text), create_organization(text, text),
--   copy_week_shifts(uuid, date, date), close_stocktake(uuid),
--   apply_industry_preset(uuid, text).
--
-- `to_regprocedure` guards each entry so a signature absent on a given
-- environment (e.g. Supabase-managed public.rls_auto_enable on cloud) is
-- silently skipped.

do $$
declare
  _sig text;
  _oid oid;
  _sigs text[] := array[
    'public.apply_org_industry_preset()',
    'public.apply_stock_movement()',
    'public.broadcast_chat_message()',
    'public.broadcast_notification()',
    'public.broadcast_task_comment()',
    'public.create_branch_chat_channel()',
    'public.create_org_chat_channel()',
    'public.enforce_manager_report_transition()',
    'public.enforce_section_editable()',
    'public.enforce_stocktake_immutable()',
    'public.enforce_stocktake_item_editable()',
    'public.enforce_task_link()',
    'public.handle_new_org_subscription()',
    'public.handle_new_user()',
    'public.notify_shift_published()',
    'public.notify_task_assigned()',
    'public.notify_task_comment()',
    'public.rls_auto_enable()',
    'public.seed_demo_samples(uuid, uuid)',
    'public.seed_report_sections()',
    'public.sync_revenue_from_report()'
  ];
begin
  foreach _sig in array _sigs loop
    _oid := to_regprocedure(_sig);
    if _oid is not null then
      execute format('revoke execute on function %s from anon, authenticated, public', _sig);
    end if;
  end loop;
end;
$$;
