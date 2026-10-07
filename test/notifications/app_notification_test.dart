import 'package:ecocuajimalpa/features/notifications/data/app_notification.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification notification(int id, DateTime createdAt, {bool read = false}) {
  return AppNotification(
    id: id,
    type: NotificationType.sistema,
    title: 'Aviso $id',
    body: '',
    createdAt: createdAt,
    readAt: read ? createdAt : null,
  );
}

void main() {
  test('fromJson lee tipo, datos y estado de lectura', () {
    final AppNotification parsed = AppNotification.fromJson(<String, dynamic>{
      'id': 5,
      'type': 'reporte',
      'title': 'Tu reporte ECO-2026-0001 está en proceso',
      'body': 'La Alcaldía ya está atendiendo el problema.',
      'data': <String, dynamic>{'report_id': 1, 'status': 'en_proceso'},
      'read_at': null,
      'created_at': '2026-10-07T15:00:00Z',
    });

    expect(parsed.type, NotificationType.reporte);
    expect(parsed.type.opensReports, isTrue);
    expect(parsed.isRead, isFalse);
    expect(parsed.data['report_id'], 1);
  });

  test('un tipo desconocido se trata como aviso del sistema', () {
    expect(NotificationType.fromDb('otro'), NotificationType.sistema);
    expect(NotificationType.recordatorio.opensCampaigns, isTrue);
    expect(NotificationType.consejo.opensCampaigns, isFalse);
  });

  test('markedRead conserva la fecha original de lectura', () {
    final DateTime first = DateTime(2026, 10, 1);
    final AppNotification read = notification(
      1,
      first,
      read: true,
    ).markedRead(DateTime(2026, 10, 5));

    expect(read.readAt, first);
  });

  test('groupNotifications agrupa por Hoy, Esta semana y Anteriores', () {
    final DateTime now = DateTime(2026, 10, 7, 12);

    final Map<NotificationGroup, List<AppNotification>> groups =
        groupNotifications(<AppNotification>[
          notification(1, DateTime(2026, 9, 1)),
          notification(2, DateTime(2026, 10, 7, 8)),
          notification(3, DateTime(2026, 10, 3)),
          notification(4, DateTime(2026, 10, 7, 11)),
        ], now: now);

    expect(groups.keys, <NotificationGroup>[
      NotificationGroup.hoy,
      NotificationGroup.semana,
      NotificationGroup.anteriores,
    ]);
    expect(groups[NotificationGroup.hoy]!.map((n) => n.id), <int>[4, 2]);
    expect(groups[NotificationGroup.semana]!.single.id, 3);
    expect(groups[NotificationGroup.anteriores]!.single.id, 1);
  });
}
