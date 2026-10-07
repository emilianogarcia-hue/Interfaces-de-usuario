import 'package:flutter/material.dart';

enum ReportStatus {
  pendiente('pendiente', 'Pendiente', Color(0xFFF58A1F)),
  enProceso('en_proceso', 'En proceso', Color(0xFF126CFF)),
  resuelto('resuelto', 'Resuelto', Color(0xFF00A86B)),
  rechazado('rechazado', 'Rechazado', Color(0xFFD93A3A));

  const ReportStatus(this.dbValue, this.label, this.color);

  final String dbValue;
  final String label;
  final Color color;

  static ReportStatus fromDb(String? value) {
    return ReportStatus.values.firstWhere(
      (status) => status.dbValue == value,
      orElse: () => ReportStatus.pendiente,
    );
  }
}

/// Reporte ciudadano guardado en la tabla `reports`.
class Report {
  const Report({
    required this.id,
    required this.folio,
    required this.category,
    required this.colony,
    required this.description,
    required this.status,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.photoUrl,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: (json['id'] as num).toInt(),
      folio: json['folio']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      colony: json['colony']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: ReportStatus.fromDb(json['status']?.toString()),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      photoUrl: json['photo_url']?.toString(),
    );
  }

  final int id;
  final String folio;
  final String category;
  final String colony;
  final String description;
  final ReportStatus status;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
}

/// Datos capturados en el formulario antes de enviarse.
class NewReport {
  const NewReport({
    required this.category,
    required this.colony,
    required this.description,
    this.latitude,
    this.longitude,
    this.photoBytes,
    this.photoExtension = 'jpg',
  });

  final String category;
  final String colony;
  final String description;
  final double? latitude;
  final double? longitude;
  final List<int>? photoBytes;
  final String photoExtension;

  Map<String, dynamic> toInsertJson({String? photoUrl}) {
    return <String, dynamic>{
      'category': category,
      'colony': colony,
      'description': description.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'photo_url': photoUrl,
    };
  }
}
