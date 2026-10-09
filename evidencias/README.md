# Evidencias de la matriz de pruebas

Capturas de los casos aprobados de la matriz "Copia de MATRIZ" (Calidad y
Pruebas). Se generaron con las pruebas de widgets de la app (rama
`feature/completar-app`), con datos de ejemplo y sin conexión a Supabase.
No son capturas tomadas en un teléfono.

Las pruebas que generan las capturas están en `shots_test.dart.txt`,
`pendientes_test.dart.txt`, `dispositivo_test.dart.txt` (GPS, cámara y
galería simulados) y `supabase_test.dart.txt` (Supabase simulado, con
respuestas que imitan las del servidor real). Para correrlas, cópialas a `test/_shots/` en
la rama `feature/completar-app` (sin la extensión `.txt`, y `foto_reporte.jpg` en
`test/_shots/assets/`) y ejecuta
`flutter test --update-goldens test/_shots`.

CP-NOT-004 se probó cargando `schema.sql` en Postgres 16 local, con
`supabase_stubs.sql` para lo mínimo de Supabase (esquema `auth`, roles y
permisos por defecto), y luego `not004.sql`.

## Pestaña "Casos válidos y no válidos"

Las capturas de esa pestaña están en `casos-v2/<ID>.png` y las pruebas que
las generan en `casos-v2/pruebas/`. Se corren igual que las de arriba: copiar
los archivos a `test/_shots/` (sin `.txt`) y ejecutar
`flutter test --update-goldens test/_shots/v2_*_test.dart`. Las capturas
salen en `test/_shots/out2/`.
