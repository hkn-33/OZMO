-- Phase 5 — stock (M8), part 1/2: notification_type enum value.
-- ALTER TYPE ... ADD VALUE must be committed before the value can be used.
-- Kept in a separate migration file so `supabase db reset` commits it before
-- the stock/costs module migration (which inserts notifications of this type).
-- Same ordering rule as phase 4 (shift_published).
alter type public.notification_type add value if not exists 'stock_low';
