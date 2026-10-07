import 'package:ecocuajimalpa/features/auth/presentation/forgot_password_screen.dart';
import 'package:ecocuajimalpa/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('valida el formulario antes de llamar al servidor', (
    tester,
  ) async {
    await pumpScreen(tester, const LoginScreen());

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.textContaining('al menos 8'), findsOneWidget);
  });

  testWidgets('el enlace de recuperación queda alineado a la derecha', (
    tester,
  ) async {
    await pumpScreen(tester, const LoginScreen());

    final double fieldRight = tester
        .getTopRight(find.byType(TextFormField).first)
        .dx;
    final double linkRight = tester
        .getTopRight(find.text('¿Olvidaste tu contraseña?'))
        .dx;

    expect(linkRight, closeTo(fieldRight, 12));
  });

  testWidgets('abre la recuperación con el correo escrito', (tester) async {
    await pumpScreen(tester, const LoginScreen());

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@correo.mx');
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('Enviar código'), findsOneWidget);
    expect(find.text('ana@correo.mx'), findsOneWidget);
  });
}
