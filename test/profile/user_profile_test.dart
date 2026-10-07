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
}
