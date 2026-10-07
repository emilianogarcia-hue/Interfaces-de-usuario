# Evidencias de la matriz de pruebas

Capturas de los casos aprobados de la matriz "Copia de MATRIZ" (Calidad y
Pruebas). Se generaron con las pruebas de widgets de la app (rama
`feature/completar-app`), con datos de ejemplo y sin conexión a Supabase.
No son capturas tomadas en un teléfono.

Las pruebas que generan las capturas están en `shots_test.dart.txt` y
`pendientes_test.dart.txt`. Para correrlas, cópialas a `test/_shots/` en
la rama `feature/completar-app` (sin la extensión `.txt`) y ejecuta
`flutter test --update-goldens test/_shots`.
