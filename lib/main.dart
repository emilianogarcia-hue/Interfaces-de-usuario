import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/presentation/home_screen.dart';
import 'features/auth/presentation/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ulfwxpwjhkerwmilnyyq.supabase.co',
    publishableKey:
        'sb_publishable_FzC2FUFNCSWsMtP3IFT1ag_dOUe2NW-',
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final bool hasSession = Supabase.instance.client.auth.currentSession != null;

    if (hasSession) {
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}