import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Preferencias de avisos dentro de la app.
class NotificationPreferences {
  const NotificationPreferences({
    this.reports = true,
    this.campaigns = true,
    this.tips = true,
  });

  final bool reports;
  final bool campaigns;
  final bool tips;

  NotificationPreferences copyWith({
    bool? reports,
    bool? campaigns,
    bool? tips,
  }) {
    return NotificationPreferences(
      reports: reports ?? this.reports,
      campaigns: campaigns ?? this.campaigns,
      tips: tips ?? this.tips,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationPreferences &&
        other.reports == reports &&
        other.campaigns == campaigns &&
        other.tips == tips;
  }

  @override
  int get hashCode => Object.hash(reports, campaigns, tips);
}

class UserProfile {
  const UserProfile({
    required this.fullName,
    required this.email,
    required this.colony,
    required this.reportsCount,
    required this.recycledKg,
    this.phone,
    this.bio,
    this.avatarUrl,
    this.notifications = const NotificationPreferences(),
    this.pendingEmail,
  });

  final String fullName;
  final String email;
  final String? colony;
  final int reportsCount;
  final double recycledKg;
  final String? phone;
  final String? bio;
  final String? avatarUrl;
  final NotificationPreferences notifications;

  /// Correo nuevo que espera confirmación, si el usuario pidió cambiarlo.
  final String? pendingEmail;

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

/// Cambios del formulario de perfil.
class ProfileUpdate {
  const ProfileUpdate({
    required this.fullName,
    required this.colony,
    this.phone,
    this.bio,
    required this.notifications,
  });

  final String fullName;
  final String colony;
  final String? phone;
  final String? bio;
  final NotificationPreferences notifications;

  Map<String, dynamic> toRow(String userId) {
    String? clean(String? value) {
      final String text = value?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    return <String, dynamic>{
      'id': userId,
      'full_name': fullName.trim(),
      'colony': colony,
      'phone': clean(phone),
      'bio': clean(bio),
      'notify_reports': notifications.reports,
      'notify_campaigns': notifications.campaigns,
      'notify_tips': notifications.tips,
    };
  }
}

abstract class ProfileRepository {
  Future<UserProfile> load();

  Future<void> update(ProfileUpdate update);

  /// Sube la foto y devuelve su URL pública.
  Future<String> uploadAvatar(Uint8List bytes, String extension);

  Future<void> removeAvatar();

  /// Supabase envía un enlace de confirmación al correo nuevo.
  Future<void> changeEmail(String newEmail);

  Future<void> changePassword(String newPassword);

  Future<void> deleteAccount();

  Future<void> signOut();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _avatarsBucket = 'avatars';
  static const String _reportPhotosBucket = 'report-photos';

  User get _user {
    final User? user = _client.auth.currentUser;

    if (user == null) {
      throw const AuthException('No hay una sesión activa.');
    }

    return user;
  }

  @override
  Future<UserProfile> load() async {
    final User user = _user;

    final String metadataName =
        user.userMetadata?['full_name']?.toString().trim() ?? '';
    final String? metadataColony = user.userMetadata?['colony']?.toString();

    Map<String, dynamic>? profile;

    try {
      profile = await _client
          .from('profiles')
          .select(
            'full_name, colony, reports_count, recycled_kg, phone, bio, '
            'avatar_url, notify_reports, notify_campaigns, notify_tips',
          )
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      // Si el esquema todavía no tiene alguna columna nueva, se usan los
      // datos de la cuenta para no dejar la pantalla vacía.
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
      pendingEmail: user.newEmail,
      colony: profile?['colony']?.toString() ?? metadataColony,
      reportsCount: (profile?['reports_count'] as num?)?.toInt() ?? 0,
      recycledKg: (profile?['recycled_kg'] as num?)?.toDouble() ?? 0,
      phone: profile?['phone']?.toString(),
      bio: profile?['bio']?.toString(),
      avatarUrl: profile?['avatar_url']?.toString(),
      notifications: NotificationPreferences(
        reports: profile?['notify_reports'] as bool? ?? true,
        campaigns: profile?['notify_campaigns'] as bool? ?? true,
        tips: profile?['notify_tips'] as bool? ?? true,
      ),
    );
  }

  @override
  Future<void> update(ProfileUpdate update) async {
    final User user = _user;

    await _client.from('profiles').upsert(update.toRow(user.id));

    await _client.auth.updateUser(
      UserAttributes(
        data: <String, dynamic>{
          'full_name': update.fullName.trim(),
          'colony': update.colony,
        },
      ),
    );
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, String extension) async {
    final User user = _user;
    final String ext = extension == 'png' ? 'png' : 'jpg';
    // Un nombre nuevo por foto evita que se muestre la anterior en caché.
    final String path =
        '${user.id}/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _removeFolder(_avatarsBucket, user.id);

    await _client.storage
        .from(_avatarsBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            upsert: true,
          ),
        );

    final String url = _client.storage.from(_avatarsBucket).getPublicUrl(path);

    await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': url})
        .eq('id', user.id);

    return url;
  }

  @override
  Future<void> removeAvatar() async {
    final User user = _user;

    await _removeFolder(_avatarsBucket, user.id);
    await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': null})
        .eq('id', user.id);
  }

  @override
  Future<void> changeEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail.trim()));
  }

  @override
  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> deleteAccount() async {
    final User user = _user;

    // Las fotos se borran con la API de Storage antes de borrar el usuario.
    for (final String bucket in <String>[_avatarsBucket, _reportPhotosBucket]) {
      try {
        await _removeFolder(bucket, user.id);
      } catch (_) {
        // Si una foto no se puede borrar, la cuenta se elimina de todos modos.
      }
    }

    await _client.rpc<void>('delete_my_account');
    await _client.auth.signOut();
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  Future<void> _removeFolder(String bucket, String folder) async {
    final List<FileObject> files = await _client.storage
        .from(bucket)
        .list(path: folder);

    if (files.isEmpty) {
      return;
    }

    await _client.storage
        .from(bucket)
        .remove(files.map((file) => '$folder/${file.name}').toList());
  }
}
