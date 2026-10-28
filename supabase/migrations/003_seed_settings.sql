-- =====================================================================
-- Tripzo — 003_seed_settings.sql
-- Platform-wide configuration. Run this THIRD, after 002_rls_policies.sql.
--
-- No demo users/bookings are seeded here on purpose: Supabase auth.users
-- rows must be created through the Auth signup flow (passwords are
-- hashed by Supabase, not something you can INSERT directly). Once the
-- app is running, create demo accounts by actually signing up, and
-- clearly label them as demo in the UI/data if you keep them around.
-- =====================================================================

insert into public.platform_settings (key, value) values
  ('commission_percent', '0'),
  ('advance_percent', '25'),
  ('payment_provider', '"none"'),       -- set once a provider is approved & configured
  ('live_payments_enabled', 'false')    -- keep false until payment provider is tested
on conflict (key) do nothing;
