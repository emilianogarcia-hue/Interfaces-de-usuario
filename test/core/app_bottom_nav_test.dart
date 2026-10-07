import 'package:ecocuajimalpa/core/widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cambia de pestaña y abre el reporte aparte', (tester) async {
    AppTab? selected;
    int reportTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            current: AppTab.inicio,
            onSelected: (tab) => selected = tab,
            onReport: () => reportTaps++,
          ),
        ),
      ),
    );

    for (final String label in <String>[
      'Inicio',
      'Reciclaje',
      'Reportar',
      'Aprender',
      'Campañas',
      'Perfil',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Campañas'));
    expect(selected, AppTab.campanas);

    await tester.tap(find.text('Reportar'));
    expect(reportTaps, 1);
    expect(selected, AppTab.campanas);
  });
}
