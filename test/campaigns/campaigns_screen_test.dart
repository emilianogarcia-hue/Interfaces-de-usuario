import 'package:ecocuajimalpa/features/campaigns/data/campaign.dart';
import 'package:ecocuajimalpa/features/campaigns/presentation/campaigns_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Campaign campaign(int id, String title, {bool joined = false}) => Campaign(
  id: id,
  title: title,
  description: 'Descripción de $title',
  location: 'Parque',
  colony: 'Contadero',
  category: 'Limpieza',
  startsAt: DateTime.now().add(const Duration(days: 3)),
  endsAt: DateTime.now().add(const Duration(days: 3, hours: 4)),
  participantsCount: 5,
  joined: joined,
);

void main() {
  testWidgets('permite inscribirse y cancelar', (tester) async {
    final FakeCampaignsRepository repository = FakeCampaignsRepository(
      <Campaign>[campaign(1, 'Reforestación')],
    );

    await pumpScreen(tester, CampaignsScreen(repository: repository));

    expect(find.text('Reforestación'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('Inscribirme'));
    await tester.pumpAndSettle();

    expect(repository.joined, <int>[1]);
    expect(find.text('Inscrito · Cancelar'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.text('Inscrito · Cancelar'));
    await tester.pumpAndSettle();

    expect(repository.left, <int>[1]);
    expect(find.text('Inscribirme'), findsOneWidget);
  });

  testWidgets('filtra solo mis campañas', (tester) async {
    await pumpScreen(
      tester,
      CampaignsScreen(
        repository: FakeCampaignsRepository(<Campaign>[
          campaign(1, 'Reforestación', joined: true),
          campaign(2, 'Reciclatón'),
        ]),
      ),
    );

    expect(find.text('Reciclatón'), findsOneWidget);

    await tester.tap(find.text('Mis campañas (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Reforestación'), findsOneWidget);
    expect(find.text('Reciclatón'), findsNothing);
  });

  testWidgets('muestra un mensaje si no hay campañas', (tester) async {
    await pumpScreen(
      tester,
      CampaignsScreen(repository: FakeCampaignsRepository(<Campaign>[])),
    );

    expect(find.text('No hay campañas activas'), findsOneWidget);
  });
}
