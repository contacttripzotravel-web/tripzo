-- Tripzo — 001_schema.sql
-- Run FIRST in Supabase SQL Editor.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'guest'
    check (role in ('guest','driver','admin')),
  full_name text not null,
  email text not null unique,
  phone text,
  is_suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_users_updated_at
before update on public.users
for each row execute procedure public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    'guest'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table public.guest_profiles (
  user_id uuid primary key references public.users(id) on delete cascade,
  default_pickup_location text,
  marketing_opt_in boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_guest_profiles_updated_at
before update on public.guest_profiles
for each row execute procedure public.set_updated_at();

create table public.driver_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  verification_status text not null default 'pending'
    check (verification_status in ('pending','verified','rejected','suspended')),
  bio text,
  years_experience int check (years_experience >= 0),
  rating_avg numeric(3,2) not null default 0,
  rating_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_driver_profiles_updated_at
before update on public.driver_profiles
for each row execute procedure public.set_updated_at();

create index idx_driver_profiles_verification
on public.driver_profiles(verification_status);

create table public.driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.driver_profiles(id) on delete cascade,
  document_type text not null check (
    document_type in ('license','id_proof','vehicle_rc','insurance','permit','other')
  ),
  storage_path text not null,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  uploaded_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users(id)
);

create index idx_driver_documents_driver
on public.driver_documents(driver_id);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.driver_profiles(id) on delete cascade,
  category text not null check (
    category in ('hatchback','sedan','suv','tempo_traveller','bus','other')
  ),
  make text,
  model text,
  registration_number text not null unique,
  seating_capacity int not null check (seating_capacity > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_vehicles_updated_at
before update on public.vehicles
for each row execute procedure public.set_updated_at();

create index idx_vehicles_driver on public.vehicles(driver_id);

create table public.driver_operating_regions (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.driver_profiles(id) on delete cascade,
  region_name text not null,
  created_at timestamptz not null default now(),
  unique (driver_id, region_name)
);

create index idx_driver_regions_driver
on public.driver_operating_regions(driver_id);

create index idx_driver_regions_name
on public.driver_operating_regions(region_name);

create table public.driver_availability (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.driver_profiles(id) on delete cascade,
  available_from date not null,
  available_to date not null,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  check (available_to >= available_from)
);

create index idx_driver_availability_driver
on public.driver_availability(driver_id);

create table public.itineraries (
  id uuid primary key default gen_random_uuid(),
  reference_code text not null unique default (
    'TRZ-' || upper(substring(replace(gen_random_uuid()::text,'-','') from 1 for 8))
  ),
  guest_id uuid not null references public.users(id) on delete cascade,
  pickup_location text not null,
  drop_location text not null,
  start_date date not null,
  end_date date not null,
  passenger_count int not null check (passenger_count > 0),
  vehicle_preference text,
  luggage_requirements text,
  special_requirements text,
  additional_notes text,
  status text not null default 'REQUESTED' check (
    status in (
      'REQUESTED','QUOTING','QUOTE_SELECTED','AWAITING_ADVANCE',
      'CONFIRMED','IN_PROGRESS','COMPLETED','CANCELLED','DISPUTED'
    )
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create trigger trg_itineraries_updated_at
before update on public.itineraries
for each row execute procedure public.set_updated_at();

create index idx_itineraries_guest on public.itineraries(guest_id);
create index idx_itineraries_status on public.itineraries(status);

create table public.itinerary_days (
  id uuid primary key default gen_random_uuid(),
  itinerary_id uuid not null references public.itineraries(id) on delete cascade,
  day_number int not null check (day_number > 0),
  day_date date not null,
  notes text,
  unique (itinerary_id, day_number)
);

create index idx_itinerary_days_itinerary
on public.itinerary_days(itinerary_id);

create table public.itinerary_stops (
  id uuid primary key default gen_random_uuid(),
  itinerary_day_id uuid not null references public.itinerary_days(id) on delete cascade,
  stop_order int not null check (stop_order > 0),
  location_name text not null,
  notes text,
  unique (itinerary_day_id, stop_order)
);

create index idx_itinerary_stops_day
on public.itinerary_stops(itinerary_day_id);

create table public.quotations (
  id uuid primary key default gen_random_uuid(),
  itinerary_id uuid not null references public.itineraries(id) on delete cascade,
  driver_id uuid not null references public.driver_profiles(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id),
  total_fare_paise bigint not null check (total_fare_paise > 0),
  currency text not null default 'INR',
  included_services text,
  excluded_services text,
  toll_parking_conditions text,
  driver_accommodation_conditions text,
  additional_charges_paise bigint not null default 0
    check (additional_charges_paise >= 0),
  availability_confirmed boolean not null default true,
  expires_at timestamptz not null,
  cancellation_conditions text,
  status text not null default 'SUBMITTED'
    check (status in ('SUBMITTED','SELECTED','REJECTED','EXPIRED','WITHDRAWN')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_quotations_updated_at
before update on public.quotations
for each row execute procedure public.set_updated_at();

create or replace function public.prevent_quotation_fare_change()
returns trigger
language plpgsql
as $$
begin
  if old.status <> 'SUBMITTED' and (
       new.total_fare_paise <> old.total_fare_paise
    or new.additional_charges_paise <> old.additional_charges_paise
  ) then
    raise exception 'Cannot modify fare on a quotation once it has left SUBMITTED status';
  end if;
  return new;
end;
$$;

create trigger trg_lock_quotation_fare
before update on public.quotations
for each row execute procedure public.prevent_quotation_fare_change();

create index idx_quotations_itinerary on public.quotations(itinerary_id);
create index idx_quotations_driver on public.quotations(driver_id);
create index idx_quotations_status on public.quotations(status);

create table public.quotation_status_history (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.quotations(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by uuid references public.users(id),
  changed_at timestamptz not null default now(),
  note text
);

create index idx_quotation_history_quotation
on public.quotation_status_history(quotation_id);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  itinerary_id uuid not null references public.itineraries(id),
  quotation_id uuid not null unique references public.quotations(id),
  guest_id uuid not null references public.users(id),
  driver_id uuid not null references public.driver_profiles(id),
  agreed_fare_paise bigint not null check (agreed_fare_paise > 0),
  currency text not null default 'INR',
  commission_paise bigint not null default 0 check (commission_paise >= 0),
  advance_paise bigint not null check (advance_paise >= 0),
  balance_paise bigint not null check (balance_paise >= 0),
  status text not null default 'AWAITING_ADVANCE'
    check (status in (
      'AWAITING_ADVANCE','CONFIRMED','IN_PROGRESS',
      'COMPLETED','CANCELLED','DISPUTED'
    )),
  guest_completion_confirmed_at timestamptz,
  driver_completion_confirmed_at timestamptz,
  trip_started_at timestamptz,
  trip_completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (advance_paise + balance_paise = agreed_fare_paise)
);

create trigger trg_bookings_updated_at
before update on public.bookings
for each row execute procedure public.set_updated_at();

create or replace function public.prevent_booking_fare_change()
returns trigger
language plpgsql
as $$
begin
  if new.agreed_fare_paise <> old.agreed_fare_paise
     or new.advance_paise <> old.advance_paise
     or new.balance_paise <> old.balance_paise
     or new.currency <> old.currency then
    raise exception 'Booking fare snapshot is immutable';
  end if;
  return new;
end;
$$;

create trigger trg_lock_booking_fare
before update on public.bookings
for each row execute procedure public.prevent_booking_fare_change();

create index idx_bookings_guest on public.bookings(guest_id);
create index idx_bookings_driver on public.bookings(driver_id);
create index idx_bookings_status on public.bookings(status);

create table public.booking_status_history (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  old_status text,
  new_status text not null,
  changed_by uuid references public.users(id),
  changed_at timestamptz not null default now(),
  note text
);

create index idx_booking_history_booking
on public.booking_status_history(booking_id);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  payment_type text not null check (payment_type in ('ADVANCE','BALANCE')),
  amount_paise bigint not null check (amount_paise > 0),
  currency text not null default 'INR',
  provider text not null,
  provider_order_id text,
  provider_payment_id text,
  status text not null default 'PENDING'
    check (status in (
      'PENDING','PROCESSING','PAID','FAILED','REFUND_PENDING',
      'PARTIALLY_REFUNDED','REFUNDED'
    )),
  idempotency_key text not null unique,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_payment_id)
);

create trigger trg_payments_updated_at
before update on public.payments
for each row execute procedure public.set_updated_at();

create index idx_payments_booking on public.payments(booking_id);
create index idx_payments_status on public.payments(status);

create table public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null,
  event_id text not null,
  payment_id uuid references public.payments(id),
  payload jsonb not null,
  processed_at timestamptz,
  received_at timestamptz not null default now(),
  unique (provider, event_id)
);

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  driver_id uuid not null references public.driver_profiles(id),
  payout_type text not null check (payout_type in ('ADVANCE','FINAL')),
  amount_paise bigint not null check (amount_paise > 0),
  currency text not null default 'INR',
  status text not null default 'NOT_ELIGIBLE'
    check (status in ('NOT_ELIGIBLE','PENDING','PROCESSING','PAID','FAILED')),
  provider text,
  provider_payout_id text,
  idempotency_key text not null unique,
  initiated_at timestamptz,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (booking_id, payout_type)
);

create trigger trg_payouts_updated_at
before update on public.payouts
for each row execute procedure public.set_updated_at();

create index idx_payouts_booking on public.payouts(booking_id);
create index idx_payouts_driver on public.payouts(driver_id);

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id),
  amount_paise bigint not null check (amount_paise > 0),
  reason text,
  status text not null default 'PENDING'
    check (status in ('PENDING','PROCESSING','PAID','FAILED')),
  provider_refund_id text,
  initiated_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_refunds_updated_at
before update on public.refunds
for each row execute procedure public.set_updated_at();

create index idx_refunds_payment on public.refunds(payment_id);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id),
  raised_by uuid not null references public.users(id),
  reason text not null,
  status text not null default 'OPEN'
    check (status in ('OPEN','UNDER_REVIEW','RESOLVED','REJECTED')),
  resolution_note text,
  resolved_by uuid references public.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_disputes_updated_at
before update on public.disputes
for each row execute procedure public.set_updated_at();

create index idx_disputes_booking on public.disputes(booking_id);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  guest_id uuid not null references public.users(id),
  driver_id uuid not null references public.driver_profiles(id),
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create index idx_reviews_driver on public.reviews(driver_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  is_read boolean not null default false,
  related_booking_id uuid references public.bookings(id),
  created_at timestamptz not null default now()
);

create index idx_notifications_user
on public.notifications(user_id, is_read);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_logs_entity
on public.audit_logs(entity_type, entity_id);

create table public.platform_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users(id)
);

create trigger trg_platform_settings_updated_at
before update on public.platform_settings
for each row execute procedure public.set_updated_at();

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  subject text not null,
  description text not null,
  status text not null default 'OPEN'
    check (status in ('OPEN','IN_PROGRESS','RESOLVED','CLOSED')),
  related_booking_id uuid references public.bookings(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_support_tickets_updated_at
before update on public.support_tickets
for each row execute procedure public.set_updated_at();
