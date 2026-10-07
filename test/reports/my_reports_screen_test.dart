import 'package:ecocuajimalpa/features/reports/data/report.dart';
import 'package:ecocuajimalpa/features/reports/presentation/my_reports_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('muestra un mensaje cuando no hay reportes', (tester) async {
    await pumpScreen(
      tester,
      MyReportsScreen(repository: FakeReportsRepository()),
    );

    expect(find.text('Aún no tienes reportes'), findsOneWidget);
  });

  testWidgets('lista los reportes con su folio y estado', (tester) async {
    await pumpScreen(
      tester,
      MyReportsScreen(
        repository: FakeReportsRepository(
          reports: <Report>[
            Report(
              id: 1,
              folio: 'ECO-2026-0001',
              category: 'Problema de agua',
              colony: 'El Yaqui',
              description: 'Fuga en la banqueta',
              status: ReportStatus.enProceso,
              createdAt: DateTime(2026, 9, 1),
            ),
          ],
        ),
      ),
    );

    expect(find.text('Problema de agua'), findsOneWidget);
    expect(find.text('Folio #ECO-2026-0001 · El Yaqui'), findsOneWidget);
    expect(find.text('En proceso'), findsOneWidget);
  });

  testWidgets('avisa si no se pudieron cargar', (tester) async {
    await pumpScreen(
      tester,
      MyReportsScreen(repository: FakeReportsRepository(fail: true)),
    );

    expect(find.text('No se pudieron cargar tus reportes'), findsOneWidget);
  });
}
