import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const EcoCuajimalpaApp());
}

class EcoCuajimalpaApp extends StatelessWidget {
  const EcoCuajimalpaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoCuajimalpa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
      ),
      home: const AuthGate(),
    );
  }
}

/// Muestra el inicio de sesión o la app según la sesión de Supabase, y
/// cambia sola cuando el usuario entra o sale.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final GoTrueClient auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final Session? session = snapshot.data?.session ?? auth.currentSession;

        if (session != null) {
          return const MainShell();
        }

        return const LoginScreen();
      },
    );
  }
}
