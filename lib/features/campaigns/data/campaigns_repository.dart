import 'package:supabase_flutter/supabase_flutter.dart';

import 'campaign.dart';

abstract class CampaignsRepository {
  /// Campañas que todavía no terminan, de la más próxima a la más lejana.
  Future<List<Campaign>> activeCampaigns();

  Future<void> join(int campaignId);

  Future<void> leave(int campaignId);
}

class SupabaseCampaignsRepository implements CampaignsRepository {
  SupabaseCampaignsRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Campaign>> activeCampaigns() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('campaigns')
        .select(
          'id, title, description, location, colony, category, starts_at, '
          'ends_at, participants_count',
        )
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at');

    final Set<int> joinedIds = <int>{};
    final User? user = _client.auth.currentUser;

    if (user != null) {
      final List<Map<String, dynamic>> joinedRows = await _client
          .from('campaign_participants')
          .select('campaign_id')
          .eq('user_id', user.id);

      joinedIds.addAll(
        joinedRows.map((row) => (row['campaign_id'] as num).toInt()),
      );
    }

    return rows
        .map(
          (row) => Campaign.fromJson(
            row,
            joined: joinedIds.contains((row['id'] as num).toInt()),
          ),
        )
        .toList();
  }

  @override
  Future<void> join(int campaignId) async {
    await _client.from('campaign_participants').insert(<String, dynamic>{
      'campaign_id': campaignId,
      'user_id': _client.auth.currentUser!.id,
    });
  }

  @override
  Future<void> leave(int campaignId) async {
    await _client
        .from('campaign_participants')
        .delete()
        .eq('campaign_id', campaignId)
        .eq('user_id', _client.auth.currentUser!.id);
  }
}
