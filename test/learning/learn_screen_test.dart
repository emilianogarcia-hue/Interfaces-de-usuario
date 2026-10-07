import 'package:ecocuajimalpa/features/learning/presentation/learn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('muestra la guía y expande una categoría a la vez', (
    tester,
  ) async {
    await pumpScreen(tester, const LearnScreen());

    expect(find.text('Aprende a Reciclar'), findsOneWidget);
    // Orgánicos viene abierta por defecto.
    expect(find.text('Bote verde'), findsOneWidget);

    await tester.tap(find.text('Vidrio'));
    await tester.pumpAndSettle();

    expect(find.text('Contenedor verde o café'), findsOneWidget);
    expect(find.text('Bote verde'), findsNothing);
  });

  testWidgets('sin pestañas no muestra botón atrás si es la raíz', (
    tester,
  ) async {
    await pumpScreen(tester, const LearnScreen());

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}
