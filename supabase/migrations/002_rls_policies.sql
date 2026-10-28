-- =====================================================================
-- Tripzo — 002_rls_policies.sql
-- Enable RLS on every table and define access policies.
-- Run this SECOND, after 001_schema.sql.
--
-- Design rule used throughout: financial tables (payments, payment_webhook_events,
-- payouts, refunds, audit_logs) have SELECT-only policies for end users.
-- All writes to those tables happen from server code using the Supabase
-- service_role key, which bypasses RLS entirely — never from the browser.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Helper functions (security definer so they can read public.users
-- without recursing into the RLS policy that's checking them)
-- ---------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.users u where u.id = auth.uid() and u.role = 'admin'
  );
$$;

create or replace function public.current_driver_id()
returns uuid
language sql
security definer
stable
as $$
  select id from public.driver_profiles where user_id = auth.uid();
$$;

create or replace function public.is_verified_driver()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.driver_profiles d
    where d.user_id = auth.uid() and d.verification_status = 'verified'
  );
$$;

-- =====================================================================
-- users
-- =====================================================================
alter table public.users enable row level security;

create policy users_select_own on public.users
  for select using (id = auth.uid() or public.is_admin());

create policy users_update_own on public.users
  for update using (id = auth.uid() or public.is_admin())
  with check (
    -- a non-admin can never change their own role or suspension flag
    (id = auth.uid() and role = (select role from public.users where id = auth.uid())
       and is_suspended = (select is_suspended from public.users where id = auth.uid()))
    or public.is_admin()
  );

-- =====================================================================
-- guest_profiles
-- =====================================================================
alter table public.guest_profiles enable row level security;

create policy guest_profiles_owner on public.guest_profiles
  for all using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- =====================================================================
-- driver_profiles
-- Profile basics are visible to any authenticated user (needed so guests
-- can compare drivers on a quotation); only the owner or admin can write.
-- =====================================================================
alter table public.driver_profiles enable row level security;

create policy driver_profiles_select_all on public.driver_profiles
  for select using (auth.role() = 'authenticated');

create policy driver_profiles_insert_own on public.driver_profiles
  for insert with check (user_id = auth.uid());

create policy driver_profiles_update_own on public.driver_profiles
  for update using (user_id = auth.uid() or public.is_admin())
  with check (
    -- drivers cannot self-verify; only admin can change verification_status
    (user_id = auth.uid()
       and verification_status = (select verification_status from public.driver_profiles where id = driver_profiles.id))
    or public.is_admin()
  );

-- =====================================================================
-- driver_documents  (private — never visible to other drivers or guests)
-- =====================================================================
alter table public.driver_documents enable row level security;

create policy driver_documents_owner_select on public.driver_documents
  for select using (
    driver_id = public.current_driver_id() or public.is_admin()
  );

create policy driver_documents_owner_insert on public.driver_documents
  for insert with check (driver_id = public.current_driver_id());

create policy driver_documents_admin_update on public.driver_documents
  for update using (public.is_admin());

-- =====================================================================
-- vehicles
-- =====================================================================
alter table public.vehicles enable row level security;

create policy vehicles_select_all on public.vehicles
  for select using (auth.role() = 'authenticated');

create policy vehicles_owner_write on public.vehicles
  for all using (driver_id = public.current_driver_id() or public.is_admin())
  with check (driver_id = public.current_driver_id() or public.is_admin());

-- =====================================================================
-- driver_operating_regions
-- =====================================================================
alter table public.driver_operating_regions enable row level security;

create policy driver_regions_select_all on public.driver_operating_regions
  for select using (auth.role() = 'authenticated');

create policy driver_regions_owner_write on public.driver_operating_regions
  for all using (driver_id = public.current_driver_id() or public.is_admin())
  with check (driver_id = public.current_driver_id() or public.is_admin());

-- =====================================================================
-- driver_availability
-- =====================================================================
alter table public.driver_availability enable row level security;

create policy driver_availability_select_all on public.driver_availability
  for select using (auth.role() = 'authenticated');

create policy driver_availability_owner_write on public.driver_availability
  for all using (driver_id = public.current_driver_id() or public.is_admin())
  with check (driver_id = public.current_driver_id() or public.is_admin());

-- =====================================================================
-- itineraries
-- Guest: full access to their own. Verified drivers: read itineraries
-- that are open for quoting AND match one of their operating regions.
-- (Treat this as an MVP eligibility filter — refine matching server-side.)
-- =====================================================================
alter table public.itineraries enable row level security;

create policy itineraries_guest_owner on public.itineraries
  for all using (guest_id = auth.uid() or public.is_admin())
  with check (guest_id = auth.uid() or public.is_admin());

create policy itineraries_driver_eligible_select on public.itineraries
  for select using (
    public.is_verified_driver()
    and status in ('REQUESTED','QUOTING')
    and exists (
      select 1 from public.driver_operating_regions r
      where r.driver_id = public.current_driver_id()
        and (r.region_name = itineraries.pickup_location
             or r.region_name = itineraries.drop_location)
    )
  );

-- =====================================================================
-- itinerary_days / itinerary_stops — inherit itinerary's visibility
-- =====================================================================
alter table public.itinerary_days enable row level security;

create policy itinerary_days_visible on public.itinerary_days
  for select using (
    exists (
      select 1 from public.itineraries i
      where i.id = itinerary_days.itinerary_id
        and (i.guest_id = auth.uid() or public.is_admin()
             or (public.is_verified_driver() and i.status in ('REQUESTED','QUOTING')))
    )
  );

create policy itinerary_days_guest_write on public.itinerary_days
  for insert with check (
    exists (select 1 from public.itineraries i
            where i.id = itinerary_days.itinerary_id and i.guest_id = auth.uid())
    or public.is_admin()
  );

create policy itinerary_days_guest_update on public.itinerary_days
  for update using (
    exists (select 1 from public.itineraries i
            where i.id = itinerary_days.itinerary_id and i.guest_id = auth.uid())
    or public.is_admin()
  );

create policy itinerary_days_guest_delete on public.itinerary_days
  for delete using (
    exists (select 1 from public.itineraries i
            where i.id = itinerary_days.itinerary_id and i.guest_id = auth.uid())
    or public.is_admin()
  );

alter table public.itinerary_stops enable row level security;

create policy itinerary_stops_visible on public.itinerary_stops
  for select using (
    exists (
      select 1 from public.itinerary_days d
      join public.itineraries i on i.id = d.itinerary_id
      where d.id = itinerary_stops.itinerary_day_id
        and (i.guest_id = auth.uid() or public.is_admin()
             or (public.is_verified_driver() and i.status in ('REQUESTED','QUOTING')))
    )
  );

create policy itinerary_stops_guest_write on public.itinerary_stops
  for insert with check (
    exists (
      select 1 from public.itinerary_days d
      join public.itineraries i on i.id = d.itinerary_id
      where d.id = itinerary_stops.itinerary_day_id and i.guest_id = auth.uid()
    ) or public.is_admin()
  );

create policy itinerary_stops_guest_update on public.itinerary_stops
  for update using (
    exists (
      select 1 from public.itinerary_days d
      join public.itineraries i on i.id = d.itinerary_id
      where d.id = itinerary_stops.itinerary_day_id and i.guest_id = auth.uid()
    ) or public.is_admin()
  );

create policy itinerary_stops_guest_delete on public.itinerary_stops
  for delete using (
    exists (
      select 1 from public.itinerary_days d
      join public.itineraries i on i.id = d.itinerary_id
      where d.id = itinerary_stops.itinerary_day_id and i.guest_id = auth.uid()
    ) or public.is_admin()
  );

-- =====================================================================
-- quotations
-- Driver: full control of their own quotations. Guest: can read quotations
-- on their own itinerary and update status (select/reject) but status
-- transitions that create a booking should go through a server function.
-- =====================================================================
alter table public.quotations enable row level security;

create policy quotations_driver_owner on public.quotations
  for all using (driver_id = public.current_driver_id() or public.is_admin())
  with check (driver_id = public.current_driver_id() or public.is_admin());

create policy quotations_guest_select on public.quotations
  for select using (
    exists (select 1 from public.itineraries i
            where i.id = quotations.itinerary_id and i.guest_id = auth.uid())
  );

create policy quotations_guest_update_status on public.quotations
  for update using (
    exists (select 1 from public.itineraries i
            where i.id = quotations.itinerary_id and i.guest_id = auth.uid())
  )
  with check (
    -- guest may only flip status between SUBMITTED/SELECTED/REJECTED, never touch fare
    status in ('SELECTED','REJECTED')
  );

-- =====================================================================
-- quotation_status_history
-- =====================================================================
alter table public.quotation_status_history enable row level security;

create policy quotation_history_visible on public.quotation_status_history
  for select using (
    public.is_admin()
    or exists (select 1 from public.quotations q
               where q.id = quotation_status_history.quotation_id
                 and q.driver_id = public.current_driver_id())
    or exists (select 1 from public.quotations q
               join public.itineraries i on i.id = q.itinerary_id
               where q.id = quotation_status_history.quotation_id
                 and i.guest_id = auth.uid())
  );

-- =====================================================================
-- bookings
-- =====================================================================
alter table public.bookings enable row level security;

create policy bookings_select_related on public.bookings
  for select using (
    guest_id = auth.uid()
    or driver_id = public.current_driver_id()
    or public.is_admin()
  );

-- Guests may only mark their own completion-confirmation timestamp.
create policy bookings_guest_confirm_completion on public.bookings
  for update using (guest_id = auth.uid())
  with check (
    guest_id = auth.uid()
    and agreed_fare_paise = (select agreed_fare_paise from public.bookings b where b.id = bookings.id)
  );

-- Drivers may only mark trip_started_at / driver_completion_confirmed_at.
create policy bookings_driver_update on public.bookings
  for update using (driver_id = public.current_driver_id())
  with check (
    driver_id = public.current_driver_id()
    and agreed_fare_paise = (select agreed_fare_paise from public.bookings b where b.id = bookings.id)
  );

create policy bookings_admin_all on public.bookings
  for all using (public.is_admin())
  with check (public.is_admin());

-- =====================================================================
-- booking_status_history
-- =====================================================================
alter table public.booking_status_history enable row level security;

create policy booking_history_visible on public.booking_status_history
  for select using (
    public.is_admin()
    or exists (select 1 from public.bookings b
               where b.id = booking_status_history.booking_id
                 and (b.guest_id = auth.uid() or b.driver_id = public.current_driver_id()))
  );

-- =====================================================================
-- payments  — SELECT only for end users; all writes are server-side
-- =====================================================================
alter table public.payments enable row level security;

create policy payments_select_related on public.payments
  for select using (
    public.is_admin()
    or exists (select 1 from public.bookings b
               where b.id = payments.booking_id
                 and (b.guest_id = auth.uid() or b.driver_id = public.current_driver_id()))
  );
-- No insert/update/delete policies for non-service roles: writes happen
-- only via the service_role key from trusted server code (payment
-- creation + webhook verification), which bypasses RLS.

-- =====================================================================
-- payment_webhook_events — fully server-only, no client policies at all
-- =====================================================================
alter table public.payment_webhook_events enable row level security;
-- Intentionally no policies: only the service_role key (which bypasses
-- RLS) may read or write this table.

-- =====================================================================
-- payouts — SELECT only for the related driver/admin; writes server-side
-- =====================================================================
alter table public.payouts enable row level security;

create policy payouts_select_related on public.payouts
  for select using (
    public.is_admin() or driver_id = public.current_driver_id()
  );

-- =====================================================================
-- refunds — SELECT only; writes server-side
-- =====================================================================
alter table public.refunds enable row level security;

create policy refunds_select_related on public.refunds
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.payments p
      join public.bookings b on b.id = p.booking_id
      where p.id = refunds.payment_id
        and (b.guest_id = auth.uid() or b.driver_id = public.current_driver_id())
    )
  );

-- =====================================================================
-- disputes
-- =====================================================================
alter table public.disputes enable row level security;

create policy disputes_select_related on public.disputes
  for select using (
    public.is_admin()
    or exists (select 1 from public.bookings b
               where b.id = disputes.booking_id
                 and (b.guest_id = auth.uid() or b.driver_id = public.current_driver_id()))
  );

create policy disputes_insert_related on public.disputes
  for insert with check (
    raised_by = auth.uid()
    and exists (select 1 from public.bookings b
                where b.id = disputes.booking_id
                  and (b.guest_id = auth.uid() or b.driver_id = public.current_driver_id()))
  );

create policy disputes_admin_update on public.disputes
  for update using (public.is_admin());

-- =====================================================================
-- reviews — public read (trust signal), guest writes once after completion
-- =====================================================================
alter table public.reviews enable row level security;

create policy reviews_select_all on public.reviews
  for select using (true);

create policy reviews_guest_insert on public.reviews
  for insert with check (
    guest_id = auth.uid()
    and exists (select 1 from public.bookings b
                where b.id = reviews.booking_id
                  and b.guest_id = auth.uid()
                  and b.status = 'COMPLETED')
  );

-- =====================================================================
-- notifications
-- =====================================================================
alter table public.notifications enable row level security;

create policy notifications_owner_select on public.notifications
  for select using (user_id = auth.uid() or public.is_admin());

create policy notifications_owner_update on public.notifications
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());
-- Inserts happen server-side (service role) when events occur.

-- =====================================================================
-- audit_logs — admin read-only; writes server-side
-- =====================================================================
alter table public.audit_logs enable row level security;

create policy audit_logs_admin_select on public.audit_logs
  for select using (public.is_admin());

-- =====================================================================
-- platform_settings — readable by any signed-in user, admin-only writes
-- =====================================================================
alter table public.platform_settings enable row level security;

create policy platform_settings_select_all on public.platform_settings
  for select using (auth.role() = 'authenticated');

create policy platform_settings_admin_write on public.platform_settings
  for all using (public.is_admin())
  with check (public.is_admin());

-- =====================================================================
-- support_tickets
-- =====================================================================
alter table public.support_tickets enable row level security;

create policy support_tickets_owner on public.support_tickets
  for select using (user_id = auth.uid() or public.is_admin());

create policy support_tickets_owner_insert on public.support_tickets
  for insert with check (user_id = auth.uid());

create policy support_tickets_admin_update on public.support_tickets
  for update using (public.is_admin());

-- =====================================================================
-- End of 002_rls_policies.sql
-- =====================================================================
