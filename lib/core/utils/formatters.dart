/// Formatos de texto en español usados en varias pantallas.
class Formatters {
  Formatters._();

  static const List<String> _months = <String>[
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static const List<String> _weekdays = <String>[
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];

  /// "Hace 5 min", "Hace 3 h", "Ayer" o "12 oct 2026".
  static String relativeDate(DateTime date, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final Duration difference = reference.difference(date);

    if (difference.inMinutes < 1) {
      return 'Hace un momento';
    }

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    }

    if (difference.inHours < 24 && reference.day == date.day) {
      return 'Hace ${difference.inHours} h';
    }

    final DateTime today = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final DateTime day = DateTime(date.year, date.month, date.day);

    if (today.difference(day).inDays == 1) {
      return 'Ayer';
    }

    return shortDate(date);
  }

  /// "12 oct 2026".
  static String shortDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// "sáb 12 oct · 09:00".
  static String eventDate(DateTime date) {
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');

    return '${_weekdays[date.weekday - 1]} ${date.day} '
        '${_months[date.month - 1]} · $hour:$minute';
  }

  /// 12 → "12", 12.5 → "12.5".
  static String kilograms(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}
