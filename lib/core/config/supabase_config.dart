/// Credenciales públicas de Supabase.
///
/// Se pueden sobrescribir al compilar con:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...`
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ulfwxpwjhkerwmilnyyq.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_FzC2FUFNCSWsMtP3IFT1ag_dOUe2NW-',
  );

  /// Bucket de Storage donde se guardan las fotos de los reportes.
  static const String reportPhotosBucket = 'report-photos';
}
