# EcoCuajimalpa

App móvil en Flutter para que los vecinos de la alcaldía Cuajimalpa de
Morelos (CDMX) reporten problemas ambientales, encuentren centros de
reciclaje, participen en campañas y aprendan a separar sus residuos.
El backend es [Supabase](https://supabase.com) (autenticación, base de
datos y almacenamiento de fotos).

## Funciones

| Módulo | Qué hace |
| --- | --- |
| Cuenta | Registro, inicio de sesión, recuperación de contraseña con código por correo y cierre de sesión. |
| Inicio | Saludo, estadísticas del usuario, acciones rápidas y actividad reciente. |
| Reportar | Formulario en 3 pasos con tipo de problema, colonia, descripción, GPS opcional y foto opcional. Se guarda en Supabase con un folio (`ECO-2026-0001`). |
| Mis reportes | Historial de reportes con su estado: pendiente, en proceso, resuelto o rechazado. |
| Reciclaje | Centros desde Supabase sobre un mapa de OpenStreetMap, distancia desde tu ubicación, búsqueda, filtros, ruta en Google Maps y llamada. |
| Aprender | Guía de separación de residuos y cuidado del agua. |
| Campañas | Jornadas ecológicas con inscripción y conteo de participantes. |
| Perfil | Datos del usuario y accesos a reportes, campañas y notificaciones. |
| Editar perfil | Foto (cámara o galería), nombre, teléfono, colonia, "Sobre mí", preferencias de notificaciones, cambio de correo y contraseña, y eliminación de la cuenta. Avisa antes de salir sin guardar. |
| Notificaciones | Avisos de cambio de estado de reportes, campañas nuevas, recordatorios y consejos. Contador en la campana de Inicio en tiempo real, filtros de no leídas, marcar todo leído y deslizar para borrar. |

## Estructura

```
lib/
  main.dart                 Inicializa Supabase y decide entre login y app
  core/                     Configuración, colores, validaciones, formatos,
                            servicio de ubicación y barra de navegación
  features/
    auth/                   Login, registro, recuperación e inicio
    shell/                  Contenedor de pestañas
    reports/                Modelo, repositorio y pantallas de reportes
    recycling/              Modelo, filtros y pantalla de centros
    campaigns/              Modelo, repositorio y pantalla de campañas
    profile/                Repositorio, perfil y edición de perfil
    notifications/          Modelo, repositorio y centro de notificaciones
    learning/               Guía de reciclaje
supabase/schema.sql         Tablas, permisos (RLS), triggers y datos de ejemplo
test/                       Pruebas unitarias y de widgets
```

Cada módulo con datos tiene un repositorio (`*_repository.dart`) con una
interfaz y una implementación de Supabase, para que las pruebas usen
versiones falsas sin red.

## Configurar Supabase (una sola vez)

1. Abre tu proyecto en supabase.com → **SQL Editor**.
2. Pega el contenido de [`supabase/schema.sql`](supabase/schema.sql) y
   presiona **Run**. Se puede volver a ejecutar sin perder datos.
3. Para la recuperación de contraseña: en **Authentication → Email
   Templates → Reset Password**, agrega el código al mensaje, por ejemplo:
   `Tu código para cambiar la contraseña es: {{ .Token }}`.
4. Carga tus centros de reciclaje en `recycling_centers`,
   `recycling_materials` y `recycling_center_materials` si aún no lo has
   hecho.
5. Opcional: para recordatorios de campañas y consejos automáticos, activa
   la extensión **pg_cron** en **Database → Extensions** y ejecuta las
   líneas `cron.schedule` que están comentadas al final de `schema.sql`.

`schema.sql` crea el bucket `avatars` para las fotos de perfil, la tabla
`notifications` y los triggers que generan los avisos. Si ya lo habías
ejecutado antes, vuelve a correrlo completo para agregar estas partes.

La URL y la llave pública de Supabase están en
`lib/core/config/supabase_config.dart`. Puedes usar otro proyecto sin
cambiar el código:

```
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_KEY=sb_publishable_xxx
```

## Ejecutar

```
flutter pub get
flutter run
```

## Calidad

```
dart format lib test   # formato
flutter analyze        # análisis estático
flutter test           # pruebas unitarias y de widgets
```

GitHub Actions ejecuta los tres pasos en cada push a `main` y en cada pull
request (`.github/workflows/flutter.yml`).
