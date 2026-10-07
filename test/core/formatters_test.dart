import 'package:ecocuajimalpa/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 7, 12, 0);

  group('Formatters.relativeDate', () {
    test('usa minutos y horas para el mismo día', () {
      expect(Formatters.relativeDate(now, now: now), 'Hace un momento');
      expect(
        Formatters.relativeDate(
          now.subtract(const Duration(minutes: 5)),
          now: now,
        ),
        'Hace 5 min',
      );
      expect(
        Formatters.relativeDate(
          now.subtract(const Duration(hours: 3)),
          now: now,
        ),
        'Hace 3 h',
      );
    });

    test('dice "Ayer" para el día anterior aunque sea hace menos de 24 h', () {
      expect(
        Formatters.relativeDate(DateTime(2026, 10, 6, 20, 0), now: now),
        'Ayer',
      );
    });

    test('usa la fecha corta para días anteriores', () {
      expect(
        Formatters.relativeDate(DateTime(2026, 9, 30, 9, 0), now: now),
        '30 sep 2026',
      );
    });
  });

  test('Formatters.eventDate', () {
    expect(
      Formatters.eventDate(DateTime(2026, 10, 10, 9, 5)),
      'sáb 10 oct · 09:05',
    );
  });

  test('Formatters.kilograms', () {
    expect(Formatters.kilograms(12), '12');
    expect(Formatters.kilograms(12.5), '12.5');
    expect(Formatters.kilograms(0), '0');
  });
}
