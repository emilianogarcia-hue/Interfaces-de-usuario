import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> list();

  /// Número de avisos sin leer, actualizado en tiempo real.
  Stream<int> unreadCount();

  Future<void> markRead(int id);

  Future<void> markAllRead();

  Future<void> delete(int id);
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<List<AppNotification>> list() async {
    final String? userId = _userId;

    if (userId == null) {
      return <AppNotification>[];
    }

    final List<Map<String, dynamic>> rows = await _client
        .from('notifications')
        .select('id, type, title, body, data, read_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(100);

    return rows.map(AppNotification.fromJson).toList();
  }

  @override
  Stream<int> unreadCount() {
    final String? userId = _userId;

    if (userId == null) {
      return Stream<int>.value(0);
    }

    return _client
        .from('notifications')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((row) => row['read_at'] == null).length);
  }

  @override
  Future<void> markRead(int id) async {
    await _client
        .from('notifications')
        .update(<String, dynamic>{
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .isFilter('read_at', null);
  }

  @override
  Future<void> markAllRead() async {
    final String? userId = _userId;

    if (userId == null) {
      return;
    }

    await _client
        .from('notifications')
        .update(<String, dynamic>{
          'read_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }

  @override
  Future<void> delete(int id) async {
    await _client.from('notifications').delete().eq('id', id);
  }
}
