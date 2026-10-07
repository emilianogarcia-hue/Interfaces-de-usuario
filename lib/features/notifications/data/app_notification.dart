import 'package:flutter/material.dart';

enum NotificationType {
  reporte('reporte', Icons.description_outlined, Color(0xFF126CFF)),
  campana('campana', Icons.campaign_outlined, Color(0xFF00AE92)),
  recordatorio(
    'recordatorio',
    Icons.event_available_outlined,
    Color(0xFFF58A1F),
  ),
  consejo('consejo', Icons.lightbulb_outline_rounded, Color(0xFF00A86B)),
  sistema('sistema', Icons.eco_outlined, Color(0xFF205C48));

  const NotificationType(this.dbValue, this.icon, this.color);

  final String dbValue;
  final IconData icon;
  final Color color;

  static NotificationType fromDb(String? value) {
    return NotificationType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => NotificationType.sistema,
    );
  }

  /// Las campañas y recordatorios llevan a la pestaña de Campañas.
  bool get opensCampaigns =>
      this == NotificationType.campana || this == NotificationType.recordatorio;

  bool get opensReports => this == NotificationType.reporte;
}

/// Aviso de la tabla `notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.data = const <String, dynamic>{},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final dynamic data = json['data'];

    return AppNotification(
      id: (json['id'] as num).toInt(),
      type: NotificationType.fromDb(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? '')?.toLocal(),
      data: data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime when) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      readAt: readAt ?? when,
      data: data,
    );
  }
}

enum NotificationGroup {
  hoy('Hoy'),
  semana('Esta semana'),
  anteriores('Anteriores');

  const NotificationGroup(this.label);

  final String label;

  static NotificationGroup of(DateTime date, DateTime now) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(date.year, date.month, date.day);
    final int days = today.difference(day).inDays;

    if (days <= 0) {
      return NotificationGroup.hoy;
    }

    if (days < 7) {
      return NotificationGroup.semana;
    }

    return NotificationGroup.anteriores;
  }
}

/// Agrupa por Hoy / Esta semana / Anteriores, de la más nueva a la más vieja.
Map<NotificationGroup, List<AppNotification>> groupNotifications(
  List<AppNotification> notifications, {
  DateTime? now,
}) {
  final DateTime reference = now ?? DateTime.now();
  final List<AppNotification> sorted = List<AppNotification>.of(notifications)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final Map<NotificationGroup, List<AppNotification>> groups =
      <NotificationGroup, List<AppNotification>>{};

  for (final AppNotification notification in sorted) {
    groups
        .putIfAbsent(
          NotificationGroup.of(notification.createdAt, reference),
          () => <AppNotification>[],
        )
        .add(notification);
  }

  return <NotificationGroup, List<AppNotification>>{
    for (final NotificationGroup group in NotificationGroup.values)
      if (groups[group] != null) group: groups[group]!,
  };
}
