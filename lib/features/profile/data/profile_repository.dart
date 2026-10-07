import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.colony,
    required this.reportsCount,
    required this.recycledKg,
  });

  final String fullName;
  final String email;
  final String? colony;
  final int reportsCount;
  final double recycledKg;

  String get firstName {
    final String name = fullName.trim();

    if (name.isEmpty) {
      return 'Usuario';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

abstract class ProfileRepository {
  Future<UserProfile> load();

  Future<void> update({required String fullName, required String colony});

  Future<void> signOut();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<UserProfile> load() async {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw const AuthException('No hay una sesión activa.');
    }

    final String metadataName =
        user.userMetadata?['full_name']?.toString().trim() ?? '';
    final String? metadataColony = user.userMetadata?['colony']?.toString();

    Map<String, dynamic>? profile;

    try {
      profile = await _client
          .from('profiles')
          .select('full_name, colony, reports_count, recycled_kg')
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      // Si la tabla aún no tiene alguna columna, se usan los datos de la
      // cuenta para no dejar la pantalla vacía.
      profile = null;
    }

    final String profileName = profile?['full_name']?.toString().trim() ?? '';

    return UserProfile(
      fullName: profileName.isNotEmpty
          ? profileName
          : metadataName.isNotEmpty
          ? metadataName
          : 'Usuario',
      email: user.email ?? '',
      colony: profile?['colony']?.toString() ?? metadataColony,
      reportsCount: (profile?['reports_count'] as num?)?.toInt() ?? 0,
      recycledKg: (profile?['recycled_kg'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  Future<void> update({
    required String fullName,
    required String colony,
  }) async {
    final User user = _client.auth.currentUser!;

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': user.id,
      'full_name': fullName.trim(),
      'colony': colony,
    });

    await _client.auth.updateUser(
      UserAttributes(
        data: <String, dynamic>{'full_name': fullName.trim(), 'colony': colony},
      ),
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
