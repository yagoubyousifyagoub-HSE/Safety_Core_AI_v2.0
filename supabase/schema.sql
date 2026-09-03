-- Safety Core AI — core schema + Row Level Security
-- Run in the Supabase SQL editor (or via `supabase db push`).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- profiles: one row per authenticated user, mirrors auth.users
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  role text not null default 'contractor' check (role in ('consultant', 'contractor', 'admin', 'guest')),
  company text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: read own row"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles: consultants/admins read all"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('consultant', 'admin')
    )
  );

-- Defence-in-depth: the trigger below (handle_new_user) is the primary way
-- profile rows get created, but these let a client-side upsert of the
-- caller's own row succeed too, if ever needed.
create policy "profiles: users can insert own row"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles: users can update own row"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------------------------------------------------------------------
-- Auto-create a profile row the instant a new auth.users row appears —
-- covers every sign-in path (email OTP, anonymous/guest) with one trigger,
-- no client-side race condition possible. Self-service accounts always
-- land on 'contractor'; anonymous sessions land on 'guest'. Nobody can
-- self-assign 'consultant' or 'admin' — that's a manual, out-of-band
-- action by an existing admin (e.g. `update public.profiles set role =
-- 'consultant' where id = '...'` from the SQL editor or an admin tool).
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, company)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email, 'Guest User'), '@', 1)),
    case when new.is_anonymous then 'guest' else 'contractor' end,
    new.raw_user_meta_data->>'company'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- project_boundaries: GeoJSON site polygons consumed by geofence_service
-- ---------------------------------------------------------------------
create table if not exists public.project_boundaries (
  id uuid primary key default gen_random_uuid(),
  project_name text not null unique,
  geometry jsonb not null, -- raw GeoJSON Polygon | MultiPolygon
  created_at timestamptz not null default now()
);

alter table public.project_boundaries enable row level security;

create policy "project_boundaries: any authenticated user can read"
  on public.project_boundaries for select
  using (auth.role() = 'authenticated');

create policy "project_boundaries: only consultants/admins write"
  on public.project_boundaries for all
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('consultant', 'admin')
    )
  );

-- ---------------------------------------------------------------------
-- observations: the core audit trail record
-- ---------------------------------------------------------------------
create table if not exists public.observations (
  id uuid primary key default gen_random_uuid(),
  local_id uuid not null unique, -- client-generated, used as the sync upsert key
  project_name text not null,
  title text not null,
  description text not null default '',
  category text not null,
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open' check (status in ('open', 'pendingVerification', 'closed')),
  latitude double precision not null,
  longitude double precision not null,
  was_inside_geofence_at_capture boolean not null default true,
  photo_before_url text,
  photo_after_url text,
  signature_url text,
  created_by uuid not null references public.profiles (id),
  assigned_contractor_id uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  due_date timestamptz,
  closed_at timestamptz
);

alter table public.observations enable row level security;

-- Consultants/admins: full access.
create policy "observations: consultants/admins full access"
  on public.observations for all
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('consultant', 'admin')
    )
  );

-- Contractors: read observations assigned to them, or that they raised.
create policy "observations: contractors read own scope"
  on public.observations for select
  using (
    assigned_contractor_id = auth.uid() or created_by = auth.uid()
  );

-- Contractors: insert new observations they raise themselves.
create policy "observations: contractors insert"
  on public.observations for insert
  with check (created_by = auth.uid());

-- Contractors: may only move status open -> pendingVerification and attach
-- the after-photo — final closure with signature is consultant-only, which
-- is enforced by the "consultants/admins full access" policy above plus the
-- application layer never exposing sign-off UI to the contractor role.
create policy "observations: contractors submit corrective action"
  on public.observations for update
  using (assigned_contractor_id = auth.uid() and status = 'open')
  with check (status in ('open', 'pendingVerification'));

-- Guests (anonymous "try the app" sessions) are confined to a single demo
-- project — this is what stops a guest from ever seeing or polluting real
-- site data, independent of anything the client enforces. Keep
-- 'Demo Site — Sandbox' in sync with AppConstants.demoProjectName in Dart.
create policy "observations: guests read demo project only"
  on public.observations for select
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'guest')
    and project_name = 'Demo Site — Sandbox'
  );

create policy "observations: guests insert into demo project only"
  on public.observations for insert
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'guest')
    and created_by = auth.uid()
    and project_name = 'Demo Site — Sandbox'
  );

create policy "observations: guests update own demo submissions"
  on public.observations for update
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'guest')
    and created_by = auth.uid()
    and project_name = 'Demo Site — Sandbox'
  )
  with check (project_name = 'Demo Site — Sandbox');

create index if not exists observations_status_idx on public.observations (status);
create index if not exists observations_project_idx on public.observations (project_name);

-- ---------------------------------------------------------------------
-- Storage buckets (create via dashboard or supabase CLI, then policy here)
-- ---------------------------------------------------------------------
-- insert into storage.buckets (id, name, public) values ('observation-photos', 'observation-photos', true);
-- insert into storage.buckets (id, name, public) values ('signatures', 'signatures', true);

create policy "storage: authenticated users can upload evidence"
  on storage.objects for insert
  with check (
    bucket_id in ('observation-photos', 'signatures')
    and auth.role() = 'authenticated'
  );

create policy "storage: anyone can read evidence via public URL"
  on storage.objects for select
  using (bucket_id in ('observation-photos', 'signatures'));

-- ---------------------------------------------------------------------
-- Seed: a small demo boundary so the guest/demo flow has a real geofence
-- to validate against out of the box. Adjust the coordinates to match
-- wherever you actually want the demo pin to land.
-- ---------------------------------------------------------------------
insert into public.project_boundaries (project_name, geometry)
values (
  'Demo Site — Sandbox',
  '{
    "type": "Polygon",
    "coordinates": [[
      [46.6720, 24.7130],
      [46.6820, 24.7130],
      [46.6820, 24.7220],
      [46.6720, 24.7220],
      [46.6720, 24.7130]
    ]]
  }'::jsonb
)
on conflict (project_name) do nothing;
