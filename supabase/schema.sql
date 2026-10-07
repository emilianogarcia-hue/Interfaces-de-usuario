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

-- =====================================================================
-- Perfil extendido: foto, teléfono, presentación y preferencias
-- =====================================================================
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists notify_reports boolean not null default true;
alter table public.profiles add column if not exists notify_campaigns boolean not null default true;
alter table public.profiles add column if not exists notify_tips boolean not null default true;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_bio_length'
  ) then
    alter table public.profiles
      add constraint profiles_bio_length check (bio is null or char_length(bio) <= 160);
  end if;
end;
$$;

-- Los contadores solo los cambian los triggers, no la app.
create or replace function public.protect_profile_counters()
returns trigger
language plpgsql
as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.reports_count := old.reports_count;
    new.recycled_kg := old.recycled_kg;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_counters on public.profiles;
create trigger profiles_protect_counters
  before update on public.profiles
  for each row execute function public.protect_profile_counters();

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Fotos de perfil: lectura pública, cada usuario escribe solo en su carpeta.
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "Fotos de perfil: subir propias" on storage.objects;
create policy "Fotos de perfil: subir propias" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Archivos propios: actualizar" on storage.objects;
create policy "Archivos propios: actualizar" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('avatars', 'report-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Archivos propios: borrar" on storage.objects;
create policy "Archivos propios: borrar" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('avatars', 'report-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Listar archivos propios (la app lo usa al eliminar la cuenta).
drop policy if exists "Archivos propios: listar" on storage.objects;
create policy "Archivos propios: listar" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('avatars', 'report-photos')
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Eliminar la cuenta propia. La app borra antes las fotos con la API de
-- Storage; esto borra el usuario y, en cascada, su perfil, reportes,
-- inscripciones y notificaciones.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'No hay una sesión activa';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- =====================================================================
-- Notificaciones
-- =====================================================================
create table if not exists public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null default 'sistema'
    check (type in ('reporte', 'campana', 'recordatorio', 'consejo', 'sistema')),
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

-- La app solo lee, marca como leídas y borra sus notificaciones; las crea
-- la base de datos con los triggers de abajo.
drop policy if exists "Notificaciones propias: leer" on public.notifications;
create policy "Notificaciones propias: leer" on public.notifications
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "Notificaciones propias: marcar" on public.notifications;
create policy "Notificaciones propias: marcar" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Notificaciones propias: borrar" on public.notifications;
create policy "Notificaciones propias: borrar" on public.notifications
  for delete to authenticated using (user_id = auth.uid());

-- Avisos en tiempo real para el contador de la campana.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;

-- Bienvenida al crear el perfil.
create or replace function public.notify_welcome()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, title, body)
  values (
    new.id,
    'sistema',
    '¡Bienvenido a EcoCuajimalpa!',
    'Ya puedes reportar problemas, encontrar centros de reciclaje y unirte a campañas.'
  );
  return new;
end;
$$;

drop trigger if exists profiles_notify_welcome on public.profiles;
create trigger profiles_notify_welcome
  after insert on public.profiles
  for each row execute function public.notify_welcome();

-- Aviso cuando cambia el estado de un reporte.
create or replace function public.notify_report_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  status_label text;
  message text;
begin
  if new.status is not distinct from old.status then
    return new;
  end if;

  if not coalesce(
    (select notify_reports from public.profiles where id = new.user_id),
    true
  ) then
    return new;
  end if;

  status_label := case new.status
    when 'en_proceso' then 'está en proceso'
    when 'resuelto' then 'fue resuelto'
    when 'rechazado' then 'fue rechazado'
    else 'volvió a pendiente'
  end;

  message := case new.status
    when 'en_proceso' then 'La Alcaldía ya está atendiendo el problema en ' || new.colony || '.'
    when 'resuelto' then '¡Gracias por reportar! El problema en ' || new.colony || ' quedó atendido.'
    when 'rechazado' then 'Revisa los detalles en Mis reportes.'
    else 'Tu reporte en ' || new.colony || ' espera revisión.'
  end;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    new.user_id,
    'reporte',
    'Tu reporte ' || coalesce(new.folio, '') || ' ' || status_label,
    message,
    jsonb_build_object('report_id', new.id, 'status', new.status)
  );

  return new;
end;
$$;

drop trigger if exists reports_notify_status on public.reports;
create trigger reports_notify_status
  after update of status on public.reports
  for each row execute function public.notify_report_status();

-- Aviso de campaña nueva a quien tenga activadas esas notificaciones.
create or replace function public.notify_new_campaign()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, type, title, body, data)
  select
    p.id,
    'campana',
    'Nueva campaña: ' || new.title,
    new.location || ' · ' || to_char(new.starts_at at time zone 'America/Mexico_City', 'DD/MM HH24:MI'),
    jsonb_build_object('campaign_id', new.id)
  from public.profiles p
  where p.notify_campaigns;

  return new;
end;
$$;

drop trigger if exists campaigns_notify_new on public.campaigns;
create trigger campaigns_notify_new
  after insert on public.campaigns
  for each row execute function public.notify_new_campaign();

-- Recordatorio para inscritos en campañas que empiezan en las próximas
-- 24 horas. No se repite para la misma campaña. Para que corra solo,
-- activa pg_cron (Database → Extensions) y ejecuta una vez:
--   select cron.schedule('recordatorios-campanas', '0 * * * *',
--                        'select public.send_campaign_reminders()');
create or replace function public.send_campaign_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted integer;
begin
  insert into public.notifications (user_id, type, title, body, data)
  select
    cp.user_id,
    'recordatorio',
    'Mañana: ' || c.title,
    c.location || ' · ' || to_char(c.starts_at at time zone 'America/Mexico_City', 'DD/MM HH24:MI'),
    jsonb_build_object('campaign_id', c.id)
  from public.campaign_participants cp
  join public.campaigns c on c.id = cp.campaign_id
  join public.profiles p on p.id = cp.user_id
  where c.starts_at between now() and now() + interval '24 hours'
    and p.notify_campaigns
    and not exists (
      select 1 from public.notifications n
      where n.user_id = cp.user_id
        and n.type = 'recordatorio'
        and n.data ->> 'campaign_id' = c.id::text
    );

  get diagnostics inserted = row_count;
  return inserted;
end;
$$;

revoke all on function public.send_campaign_reminders() from public, anon, authenticated;

-- Consejo ecológico para quien tenga activados los consejos. Para enviarlo
-- cada lunes a las 9:00 (hora del servidor) con pg_cron:
--   select cron.schedule('consejo-semanal', '0 9 * * 1',
--                        'select public.send_eco_tip()');
create or replace function public.send_eco_tip()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  tips text[] := array[
    'Enjuaga y aplasta los envases de plástico antes de separarlos: ocupan menos y se reciclan mejor.',
    'El aceite de cocina usado contamina hasta mil litros de agua. Guárdalo en una botella y llévalo a un centro de acopio.',
    'Las pilas no van a la basura común. Busca en Reciclaje un centro que las reciba.',
    'Cerrar la llave mientras te cepillas ahorra hasta 12 litros de agua cada vez.',
    'Los restos de fruta y verdura sirven para hacer composta y nutrir plantas.',
    'Lleva tu propia bolsa al mercado y evita las de un solo uso.',
    'El vidrio se recicla infinitas veces: sepáralo limpio y sin tapas.'
  ];
  tip text := tips[1 + floor(random() * array_length(tips, 1))::int];
  inserted integer;
begin
  insert into public.notifications (user_id, type, title, body)
  select id, 'consejo', 'Consejo de la semana', tip
  from public.profiles
  where notify_tips;

  get diagnostics inserted = row_count;
  return inserted;
end;
$$;

revoke all on function public.send_eco_tip() from public, anon, authenticated;
