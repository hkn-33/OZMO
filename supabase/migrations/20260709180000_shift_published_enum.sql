-- Phase 4 — work schedule (module M5), part 1/2: enum value.
-- ALTER TYPE ... ADD VALUE must be committed before the value can be used.
-- Kept in a separate migration file so `supabase db reset` commits it before
-- the schedule module migration (which inserts notifications of this type).
alter type public.notification_type add value if not exists 'shift_published';
