import 'package:ecocuajimalpa/features/reports/presentation/report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<void> fillUntilLastStep(WidgetTester tester) async {
  await tester.tap(find.text('Basura acumulada'));
  await tester.pump();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Santa Fe').first);
  await tester.enterText(
    find.byType(TextField),
    'Bolsas de basura acumuladas en la esquina',
  );
  await tester.pump();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no deja continuar sin elegir el tipo de problema', (
    tester,
  ) async {
    await pumpScreen(tester, ReportScreen(repository: FakeReportsRepository()));

    expect(find.text('Paso 1 de 3'), findsOneWidget);

    final FilledButton button = tester.widget(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('pide una descripción de al menos 10 caracteres', (tester) async {
    await pumpScreen(tester, ReportScreen(repository: FakeReportsRepository()));

    await tester.tap(find.text('Zona descuidada'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Paso 2 de 3'), findsOneWidget);

    await tester.tap(find.text('Contadero'));
    await tester.enterText(find.byType(TextField), 'corta');
    await tester.pump();

    FilledButton button = tester.widget(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Pasto muy crecido');
    await tester.pump();

    button = tester.widget(find.widgetWithText(FilledButton, 'Continuar'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('envía el reporte y muestra el folio del servidor', (
    tester,
  ) async {
    final FakeReportsRepository repository = FakeReportsRepository();
    await pumpScreen(tester, ReportScreen(repository: repository));

    await fillUntilLastStep(tester);

    expect(find.text('Resumen del reporte'), findsOneWidget);
    expect(find.text('Sin foto'), findsOneWidget);

    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    expect(find.text('¡Reporte enviado!'), findsOneWidget);
    expect(find.textContaining('ECO-2026-0042'), findsOneWidget);

    expect(repository.submitted, hasLength(1));
    expect(repository.submitted.single.category, 'Basura acumulada');
    expect(repository.submitted.single.colony, 'Santa Fe');
    expect(repository.submitted.single.latitude, isNull);
    expect(repository.submitted.single.photoBytes, isNull);
  });

  testWidgets('si falla el envío se queda en el formulario con un aviso', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ReportScreen(repository: FakeReportsRepository(fail: true)),
    );

    await fillUntilLastStep(tester);
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    expect(find.text('¡Reporte enviado!'), findsNothing);
    expect(find.textContaining('No se pudo enviar el reporte'), findsOneWidget);
    expect(find.text('Paso 3 de 3'), findsOneWidget);
  });

  testWidgets('el botón atrás regresa al paso anterior', (tester) async {
    await pumpScreen(tester, ReportScreen(repository: FakeReportsRepository()));

    await tester.tap(find.text('Basura acumulada'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });
}
