import 'package:ecocuajimalpa/features/profile/data/profile_repository.dart';
import 'package:ecocuajimalpa/features/profile/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const UserProfile ana = UserProfile(
  fullName: 'Ana Pérez',
  email: 'ana@correo.mx',
  colony: 'Santa Fe',
  reportsCount: 2,
  recycledKg: 0,
);

Future<FakeProfileRepository> openEditor(WidgetTester tester) async {
  final FakeProfileRepository repository = FakeProfileRepository(ana);

  // Se abre encima de otra pantalla para probar el botón atrás.
  tester.view.physicalSize = const Size(1300, 4200);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<bool>(
                  builder: (context) =>
                      EditProfileScreen(profile: ana, repository: repository),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();

  return repository;
}

FilledButton saveButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(FilledButton, 'Guardar cambios'));

void main() {
  testWidgets('guardar se activa solo con cambios y envía los datos', (
    tester,
  ) async {
    final FakeProfileRepository repository = await openEditor(tester);

    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Teléfono (opcional)'),
      '55 1234 5678',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Sobre mí (opcional)'),
      'Vecina de Santa Fe',
    );
    await tester.tap(find.text('Consejos ecológicos'));
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(repository.updates, hasLength(1));
    final ProfileUpdate update = repository.updates.single;
    expect(update.fullName, 'Ana Pérez');
    expect(update.phone, '55 1234 5678');
    expect(update.bio, 'Vecina de Santa Fe');
    expect(update.notifications.tips, isFalse);
    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('no guarda con un teléfono inválido', (tester) async {
    final FakeProfileRepository repository = await openEditor(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Teléfono (opcional)'),
      '12345',
    );
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un teléfono de 10 dígitos'), findsOneWidget);
    expect(repository.updates, isEmpty);
  });

  testWidgets('pregunta antes de salir con cambios sin guardar', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Ana María Pérez',
    );
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('cambia la contraseña validando la confirmación', (tester) async {
    final FakeProfileRepository repository = await openEditor(tester);

    await tester.tap(find.text('Contraseña'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña nueva'),
      'nuevaClave1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'otraClave1',
    );
    await tester.tap(find.text('Cambiar'));
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'nuevaClave1',
    );
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();

    expect(repository.passwords, <String>['nuevaClave1']);
  });

  testWidgets('pide el correo nuevo y lo envía', (tester) async {
    final FakeProfileRepository repository = await openEditor(tester);

    await tester.tap(find.text('Correo electrónico'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo nuevo'),
      'ana@correo.mx',
    );
    await tester.tap(find.text('Enviar enlace'));
    await tester.pump();
    expect(find.text('Es el mismo correo que ya usas'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo nuevo'),
      'ana.nueva@correo.mx',
    );
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(repository.emails, <String>['ana.nueva@correo.mx']);
  });

  testWidgets('eliminar la cuenta exige escribir ELIMINAR', (tester) async {
    final FakeProfileRepository repository = await openEditor(tester);

    await tester.tap(find.text('Eliminar mi cuenta'));
    await tester.pumpAndSettle();

    FilledButton confirm() =>
        tester.widget(find.widgetWithText(FilledButton, 'Eliminar'));

    expect(confirm().onPressed, isNull);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'ELIMINAR',
    );
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(repository.deleted, isTrue);
  });
}
