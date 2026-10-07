-- =====================================================================
-- EcoCuajimalpa · Esquema de base de datos para Supabase
--
-- Cómo usarlo: abre tu proyecto en supabase.com → SQL Editor → pega este
-- archivo completo → Run. Se puede ejecutar más de una vez sin romper
-- nada: solo crea lo que falta y no borra datos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Perfiles de usuario
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  colony text,
  reports_count integer not null default 0,
  recycled_kg numeric(10, 2) not null default 0,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists colony text;
alter table public.profiles add column if not exists reports_count integer not null default 0;
alter table public.profiles add column if not exists recycled_kg numeric(10, 2) not null default 0;

alter table public.profiles enable row level security;

drop policy if exists "Perfil propio: leer" on public.profiles;
create policy "Perfil propio: leer" on public.profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "Perfil propio: crear" on public.profiles;
create policy "Perfil propio: crear" on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "Perfil propio: editar" on public.profiles;
create policy "Perfil propio: editar" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Crea el perfil automáticamente al registrarse, con el nombre y la colonia
-- que la app envía en los metadatos del registro.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, colony)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'colony'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Perfiles para usuarios que se registraron antes de este script.
insert into public.profiles (id, full_name, colony)
select id, raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'colony'
from auth.users
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- Centros de reciclaje
-- ---------------------------------------------------------------------
create table if not exists public.recycling_materials (
  id bigint generated always as identity primary key,
  name text not null unique
);

create table if not exists public.recycling_centers (
  id bigint generated always as identity primary key,
  slug text unique,
  name text not null,
  address text not null,
  colony text,
  latitude double precision not null,
  longitude double precision not null,
  phone text,
  opening_hours text,
  open_now boolean not null default true,
  rating numeric(2, 1) not null default 0,
  active boolean not null default true
);

create table if not exists public.recycling_center_materials (
  center_id bigint not null references public.recycling_centers (id) on delete cascade,
  material_id bigint not null references public.recycling_materials (id) on delete cascade,
  primary key (center_id, material_id)
);

alter table public.recycling_materials enable row level security;
alter table public.recycling_centers enable row level security;
alter table public.recycling_center_materials enable row level security;

drop policy if exists "Materiales: lectura pública" on public.recycling_materials;
create policy "Materiales: lectura pública" on public.recycling_materials
  for select using (true);

drop policy if exists "Centros: lectura pública" on public.recycling_centers;
create policy "Centros: lectura pública" on public.recycling_centers
  for select using (true);

drop policy if exists "Centros y materiales: lectura pública" on public.recycling_center_materials;
create policy "Centros y materiales: lectura pública" on public.recycling_center_materials
  for select using (true);

-- ---------------------------------------------------------------------
-- Reportes ciudadanos
-- ---------------------------------------------------------------------
create table if not exists public.reports (
  id bigint generated always as identity primary key,
  folio text unique,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category text not null,
  colony text not null,
  description text not null check (char_length(trim(description)) >= 10),
  latitude double precision,
  longitude double precision,
  photo_url text,
  status text not null default 'pendiente'
    check (status in ('pendiente', 'en_proceso', 'resuelto', 'rechazado')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists reports_user_created_idx
  on public.reports (user_id, created_at desc);

alter table public.reports enable row level security;

drop policy if exists "Reportes propios: leer" on public.reports;
create policy "Reportes propios: leer" on public.reports
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Reportes propios: crear" on public.reports;
create policy "Reportes propios: crear" on public.reports
  for insert to authenticated
  with check (user_id = auth.uid() and status = 'pendiente');

-- Folio legible: ECO-2026-0001.
create or replace function public.set_report_folio()
returns trigger
language plpgsql
as $$
begin
  new.folio := 'ECO-' || to_char(now(), 'YYYY') || '-' || lpad(new.id::text, 4, '0');
  return new;
end;
$$;

drop trigger if exists reports_set_folio on public.reports;
create trigger reports_set_folio
  before insert on public.reports
  for each row execute function public.set_report_folio();

-- Mantiene el contador de reportes del perfil.
create or replace function public.increment_reports_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set reports_count = reports_count + 1
  where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists reports_increment_count on public.reports;
create trigger reports_increment_count
  after insert on public.reports
  for each row execute function public.increment_reports_count();

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists reports_touch_updated_at on public.reports;
create trigger reports_touch_updated_at
  before update on public.reports
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Fotos de los reportes (Storage)
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('report-photos', 'report-photos', true)
on conflict (id) do nothing;

-- Cada usuario sube fotos solo dentro de su carpeta: <user_id>/archivo.jpg
drop policy if exists "Fotos de reportes: subir propias" on storage.objects;
create policy "Fotos de reportes: subir propias" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'report-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------
-- Campañas
-- ---------------------------------------------------------------------
create table if not exists public.campaigns (
  id bigint generated always as identity primary key,
  title text not null,
  description text not null default '',
  location text not null default '',
  colony text,
  category text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  participants_count integer not null default 0,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

alter table public.campaigns add column if not exists participants_count integer not null default 0;

create table if not exists public.campaign_participants (
  campaign_id bigint not null references public.campaigns (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (campaign_id, user_id)
);

alter table public.campaigns enable row level security;
alter table public.campaign_participants enable row level security;

drop policy if exists "Campañas: lectura para usuarios" on public.campaigns;
create policy "Campañas: lectura para usuarios" on public.campaigns
  for select to authenticated using (true);

-- Cada usuario solo ve y cambia sus propias inscripciones.
drop policy if exists "Inscripciones propias: leer" on public.campaign_participants;
create policy "Inscripciones propias: leer" on public.campaign_participants
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Inscripciones propias: crear" on public.campaign_participants;
create policy "Inscripciones propias: crear" on public.campaign_participants
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "Inscripciones propias: borrar" on public.campaign_participants;
create policy "Inscripciones propias: borrar" on public.campaign_participants
  for delete to authenticated using (user_id = auth.uid());

-- Mantiene participants_count sin exponer quién se inscribió.
create or replace function public.update_participants_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.campaigns
    set participants_count = participants_count + 1
    where id = new.campaign_id;
    return new;
  end if;

  update public.campaigns
  set participants_count = greatest(participants_count - 1, 0)
  where id = old.campaign_id;
  return old;
end;
$$;

drop trigger if exists campaign_participants_count on public.campaign_participants;
create trigger campaign_participants_count
  after insert or delete on public.campaign_participants
  for each row execute function public.update_participants_count();

-- ---------------------------------------------------------------------
-- Datos de ejemplo (solo si las tablas están vacías)
-- ---------------------------------------------------------------------
insert into public.campaigns (title, description, location, colony, category, starts_at, ends_at)
select * from (values
  (
    'Jornada de limpieza en el Desierto de los Leones',
    'Recolectamos residuos en los senderos del parque. Lleva guantes y agua; nosotros ponemos las bolsas.',
    'Entrada principal del Parque Nacional',
    'San Mateo Tlaltenango',
    'Limpieza',
    date_trunc('day', now()) + interval '5 days 9 hours',
    date_trunc('day', now()) + interval '5 days 13 hours'
  ),
  (
    'Reciclatón de electrónicos',
    'Trae celulares, cables, cargadores y aparatos que ya no uses para su reciclaje responsable.',
    'Explanada de la Alcaldía',
    'Cuajimalpa Centro',
    'Reciclaje',
    date_trunc('day', now()) + interval '9 days 10 hours',
    date_trunc('day', now()) + interval '9 days 16 hours'
  ),
  (
    'Reforestación comunitaria',
    'Plantaremos árboles nativos en áreas verdes de la colonia. Actividad apta para familias.',
    'Parque Lineal Contadero',
    'Contadero',
    'Áreas verdes',
    date_trunc('day', now()) + interval '14 days 8 hours',
    date_trunc('day', now()) + interval '14 days 12 hours'
  )
) as seed
where not exists (select 1 from public.campaigns);
