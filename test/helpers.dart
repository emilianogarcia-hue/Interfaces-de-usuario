import 'package:ecocuajimalpa/features/campaigns/data/campaign.dart';
import 'package:ecocuajimalpa/features/campaigns/data/campaigns_repository.dart';
import 'package:ecocuajimalpa/features/reports/data/report.dart';
import 'package:ecocuajimalpa/features/reports/data/reports_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envuelve una pantalla en MaterialApp con un tamaño de teléfono alto para
/// que los formularios largos quepan sin desplazarse. Es algo más ancho que
/// un teléfono porque la fuente de pruebas dibuja cada letra como un cuadro.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1300, 2800);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pumpAndSettle();
}

class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({this.fail = false, List<Report>? reports})
    : reports = reports ?? <Report>[];

  final bool fail;
  final List<Report> reports;
  final List<NewReport> submitted = <NewReport>[];

  @override
  Future<Report> submit(NewReport report) async {
    if (fail) {
      throw Exception('sin conexión');
    }

    submitted.add(report);

    return Report(
      id: 42,
      folio: 'ECO-2026-0042',
      category: report.category,
      colony: report.colony,
      description: report.description,
      status: ReportStatus.pendiente,
      createdAt: DateTime(2026, 10, 7),
    );
  }

  @override
  Future<List<Report>> myReports({int? limit}) async {
    if (fail) {
      throw Exception('sin conexión');
    }

    return limit == null ? reports : reports.take(limit).toList();
  }
}

class FakeCampaignsRepository implements CampaignsRepository {
  FakeCampaignsRepository(this.campaigns);

  List<Campaign> campaigns;
  final List<int> joined = <int>[];
  final List<int> left = <int>[];

  @override
  Future<List<Campaign>> activeCampaigns() async => campaigns;

  @override
  Future<void> join(int campaignId) async => joined.add(campaignId);

  @override
  Future<void> leave(int campaignId) async => left.add(campaignId);
}
