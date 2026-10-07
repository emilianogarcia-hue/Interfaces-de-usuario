import 'package:ecocuajimalpa/features/reports/data/report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReportStatus.fromDb reconoce estados y usa pendiente por defecto', () {
    expect(ReportStatus.fromDb('en_proceso'), ReportStatus.enProceso);
    expect(ReportStatus.fromDb('resuelto').label, 'Resuelto');
    expect(ReportStatus.fromDb('desconocido'), ReportStatus.pendiente);
    expect(ReportStatus.fromDb(null), ReportStatus.pendiente);
  });

  test('Report.fromJson lee una fila de Supabase', () {
    final Report report = Report.fromJson(<String, dynamic>{
      'id': 12,
      'folio': 'ECO-2026-0012',
      'category': 'Basura acumulada',
      'colony': 'Santa Fe',
      'description': 'Bolsas en la esquina',
      'status': 'resuelto',
      'created_at': '2026-10-01T15:30:00Z',
      'latitude': 19.36,
      'longitude': -99.29,
      'photo_url': null,
    });

    expect(report.folio, 'ECO-2026-0012');
    expect(report.status, ReportStatus.resuelto);
    expect(report.createdAt.toUtc(), DateTime.utc(2026, 10, 1, 15, 30));
    expect(report.latitude, 19.36);
    expect(report.photoUrl, isNull);
  });

  test('NewReport.toInsertJson recorta la descripción e incluye la foto', () {
    const NewReport draft = NewReport(
      category: 'Zona descuidada',
      colony: 'Contadero',
      description: '  Pasto muy crecido en el parque  ',
    );

    expect(draft.toInsertJson(photoUrl: 'https://x/y.jpg'), <String, dynamic>{
      'category': 'Zona descuidada',
      'colony': 'Contadero',
      'description': 'Pasto muy crecido en el parque',
      'latitude': null,
      'longitude': null,
      'photo_url': 'https://x/y.jpg',
    });
  });
}
