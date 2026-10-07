import 'package:ecocuajimalpa/features/notifications/data/app_notification.dart';
import 'package:ecocuajimalpa/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

List<AppNotification> sample() {
  final DateTime now = DateTime.now();

  return <AppNotification>[
    AppNotification(
      id: 1,
      type: NotificationType.campana,
      title: 'Nueva campaña: Reforestación',
      body: 'Parque Lineal',
      createdAt: now.subtract(const Duration(minutes: 5)),
    ),
    AppNotification(
      id: 2,
      type: NotificationType.sistema,
      title: '¡Bienvenido a EcoCuajimalpa!',
      body: '',
      createdAt: now.subtract(const Duration(days: 20)),
      readAt: now.subtract(const Duration(days: 19)),
    ),
  ];
}

void main() {
  testWidgets('agrupa los avisos y cuenta los no leídos', (tester) async {
    await pumpScreen(
      tester,
      NotificationsScreen(repository: FakeNotificationsRepository(sample())),
    );

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Anteriores'), findsOneWidget);
    expect(find.text('No leídas (1)'), findsOneWidget);
    expect(find.text('Marcar todo leído'), findsOneWidget);
  });

  testWidgets('al tocar una campaña la marca leída y abre Campañas', (
    tester,
  ) async {
    final FakeNotificationsRepository repository = FakeNotificationsRepository(
      sample(),
    );
    int openedCampaigns = 0;

    await pumpScreen(
      tester,
      NotificationsScreen(
        repository: repository,
        onOpenCampaigns: () => openedCampaigns++,
      ),
    );

    await tester.tap(find.text('Nueva campaña: Reforestación'));
    await tester.pumpAndSettle();

    expect(repository.read, <int>[1]);
    expect(openedCampaigns, 1);
    expect(find.text('No leídas (0)'), findsOneWidget);
    expect(find.text('Marcar todo leído'), findsNothing);
  });

  testWidgets('marca todas como leídas y filtra no leídas', (tester) async {
    final FakeNotificationsRepository repository = FakeNotificationsRepository(
      sample(),
    );

    await pumpScreen(tester, NotificationsScreen(repository: repository));

    await tester.tap(find.text('No leídas (1)'));
    await tester.pumpAndSettle();
    expect(find.text('¡Bienvenido a EcoCuajimalpa!'), findsNothing);

    await tester.tap(find.text('Marcar todo leído'));
    await tester.pumpAndSettle();

    expect(repository.markAllCalls, 1);
    expect(find.text('Estás al día'), findsOneWidget);
  });

  testWidgets('deslizar borra la notificación', (tester) async {
    final FakeNotificationsRepository repository = FakeNotificationsRepository(
      sample(),
    );

    await pumpScreen(tester, NotificationsScreen(repository: repository));

    await tester.drag(
      find.text('¡Bienvenido a EcoCuajimalpa!'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(repository.deleted, <int>[2]);
    expect(find.text('¡Bienvenido a EcoCuajimalpa!'), findsNothing);
  });

  testWidgets('muestra un estado vacío', (tester) async {
    await pumpScreen(
      tester,
      NotificationsScreen(
        repository: FakeNotificationsRepository(<AppNotification>[]),
      ),
    );

    expect(find.text('No tienes notificaciones'), findsOneWidget);
    expect(find.byType(NotificationTile), findsNothing);
  });
}
