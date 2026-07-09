-- Phase 6 — performance quick wins: indexes for hot paths.
-- Only genuinely missing indexes are added here. Pre-existing coverage
-- (checked against pg_indexes before writing this migration):
--   notifications(user_id, created_at DESC)          -> idx_notifications_user   (bell list)
--   chat_messages(channel_id, created_at)            -> idx_chat_messages_channel (DESC served by backward scan)
--   stock_movements(branch_id, product_id, created_at DESC) -> idx_stock_movements_branch_product
--   shifts(branch_id, starts_at)                     -> idx_shifts_branch
-- These already existed, so they are intentionally NOT recreated.

-- tasks: list/Kanban filter by branch + status. Existing idx_tasks_branch is
-- (branch_id) only; add status as trailing column for status-filtered scans.
create index if not exists idx_tasks_branch_status
  on public.tasks (branch_id, status);

-- notifications: unread-count / unread-fetch path (bell badge). The existing
-- idx_notifications_user (user_id, created_at DESC) serves the ordered list;
-- this partial index serves the "unread for this user" predicate efficiently.
create index if not exists idx_notifications_user_unread
  on public.notifications (user_id)
  where read_at is null;
