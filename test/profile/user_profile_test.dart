import 'package:ecocuajimalpa/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile(String name) => UserProfile(
  fullName: name,
  email: 'ana@correo.mx',
  colony: 'Santa Fe',
  reportsCount: 0,
  recycledKg: 0,
);

void main() {
  test('firstName toma la primera palabra', () {
    expect(profile('  Ana   María Pérez ').firstName, 'Ana');
    expect(profile('').firstName, 'Usuario');
  });

  test('initials usa hasta dos iniciales', () {
    expect(profile('ana pérez').initials, 'AP');
    expect(profile('Ana').initials, 'A');
    expect(profile('   ').initials, 'U');
  });

  test('ProfileUpdate.toRow limpia campos opcionales vacíos', () {
    const ProfileUpdate update = ProfileUpdate(
      fullName: '  Ana Pérez ',
      colony: 'Santa Fe',
      phone: '   ',
      bio: ' Me gusta reforestar ',
      notifications: NotificationPreferences(campaigns: false),
    );

    expect(update.toRow('u1'), <String, dynamic>{
      'id': 'u1',
      'full_name': 'Ana Pérez',
      'colony': 'Santa Fe',
      'phone': null,
      'bio': 'Me gusta reforestar',
      'notify_reports': true,
      'notify_campaigns': false,
      'notify_tips': true,
    });
  });

  test('NotificationPreferences compara por valor', () {
    expect(
      const NotificationPreferences(),
      const NotificationPreferences().copyWith(tips: true),
    );
    expect(
      const NotificationPreferences() ==
          const NotificationPreferences().copyWith(tips: false),
      isFalse,
    );
  });
}
