import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import 'report.dart';

abstract class ReportsRepository {
  Future<Report> submit(NewReport report);

  Future<List<Report>> myReports({int? limit});
}

class SupabaseReportsRepository implements ReportsRepository {
  SupabaseReportsRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _columns =
      'id, folio, category, colony, description, status, created_at, '
      'latitude, longitude, photo_url';

  @override
  Future<Report> submit(NewReport report) async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw const AuthException('Tu sesión expiró. Inicia sesión de nuevo.');
    }

    String? photoUrl;

    if (report.photoBytes != null) {
      final String path =
          '${user.id}/'
          '${DateTime.now().millisecondsSinceEpoch}.${report.photoExtension}';

      await _client.storage
          .from(SupabaseConfig.reportPhotosBucket)
          .uploadBinary(
            path,
            Uint8List.fromList(report.photoBytes!),
            fileOptions: FileOptions(
              contentType:
                  'image/${report.photoExtension == 'png' ? 'png' : 'jpeg'}',
            ),
          );

      photoUrl = _client.storage
          .from(SupabaseConfig.reportPhotosBucket)
          .getPublicUrl(path);
    }

    final Map<String, dynamic> row = await _client
        .from('reports')
        .insert(<String, dynamic>{
          ...report.toInsertJson(photoUrl: photoUrl),
          'user_id': user.id,
        })
        .select(_columns)
        .single();

    return Report.fromJson(row);
  }

  @override
  Future<List<Report>> myReports({int? limit}) async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      return <Report>[];
    }

    PostgrestTransformBuilder<List<Map<String, dynamic>>> query = _client
        .from('reports')
        .select(_columns)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final List<Map<String, dynamic>> rows = await query;

    return rows.map(Report.fromJson).toList();
  }
}
