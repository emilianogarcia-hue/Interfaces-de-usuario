\set ON_ERROR_STOP 1
-- Permisos que Supabase da por defecto.
grant usage on schema public, auth to anon, authenticated;
grant all on all tables in schema public to anon, authenticated;
grant all on all sequences in schema public to anon, authenticated;
grant execute on all functions in schema auth to anon, authenticated;
insert into auth.users (id, email, raw_user_meta_data) values
  ('6f1c2b1e-0000-4000-8000-000000000001', 'ana@correo.mx', '{"full_name":"Ana Pérez","colony":"Santa Fe"}');
-- El usuario crea su reporte con su sesión.
set role authenticated;
select set_config('request.jwt.claim.sub', '6f1c2b1e-0000-4000-8000-000000000001', false);
insert into public.reports (category, colony, description)
  values ('Basura acumulada', 'Santa Fe', 'Bolsas de basura acumuladas en la esquina');
reset role;
\echo '--- Notificaciones antes del cambio'
select type, title from public.notifications order by id;
-- La Alcaldía cambia el estado desde el panel (sin sesión de usuario).
update public.reports set status = 'en_proceso';
\echo '--- Notificaciones después de pasar a en_proceso'
select type, title, body, data from public.notifications order by id;
update public.reports set status = 'resuelto';
\echo '--- Después de pasar a resuelto'
select type, title from public.notifications where type = 'reporte' order by id;
\echo '--- Contador que ve la campana (no leídas)'
select count(*) as no_leidas from public.notifications where read_at is null;
