import 'package:ecocuajimalpa/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('rechaza vacío', () {
      expect(Validators.email(null), 'Ingresa tu correo electrónico');
      expect(Validators.email('   '), 'Ingresa tu correo electrónico');
    });

    test('rechaza formatos inválidos', () {
      for (final String value in <String>[
        'ana',
        'ana@',
        'ana@correo',
        'a b@c.d',
      ]) {
        expect(
          Validators.email(value),
          'Ingresa un correo válido',
          reason: value,
        );
      }
    });

    test('acepta correos válidos aunque tengan espacios alrededor', () {
      expect(Validators.email('ana@correo.mx'), isNull);
      expect(Validators.email('  ana.perez@uam.edu.mx '), isNull);
    });
  });

  group('Validators.password', () {
    test('exige al menos 8 caracteres', () {
      expect(Validators.password(''), 'Ingresa tu contraseña');
      expect(Validators.password('1234567'), contains('al menos 8'));
      expect(Validators.password('12345678'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('detecta contraseñas distintas', () {
      expect(
        Validators.confirmPassword('', 'secreto123'),
        'Confirma tu contraseña',
      );
      expect(
        Validators.confirmPassword('secreto124', 'secreto123'),
        'Las contraseñas no coinciden',
      );
      expect(Validators.confirmPassword('secreto123', 'secreto123'), isNull);
    });
  });

  group('Validators.fullName', () {
    test('exige al menos 3 caracteres sin contar espacios', () {
      expect(Validators.fullName('  '), 'Ingresa tu nombre completo');
      expect(Validators.fullName(' Al '), 'El nombre es demasiado corto');
      expect(Validators.fullName('Ana'), isNull);
    });
  });

  group('Validators.colony', () {
    test('exige una colonia', () {
      expect(Validators.colony(null), 'Selecciona tu colonia');
      expect(Validators.colony('Santa Fe'), isNull);
    });
  });

  group('Validators.otpCode', () {
    test('acepta solo códigos numéricos de 6 a 10 dígitos', () {
      expect(Validators.otpCode('12345'), isNotNull);
      expect(Validators.otpCode('12a456'), isNotNull);
      expect(Validators.otpCode('123456'), isNull);
      expect(Validators.otpCode(' 12345678 '), isNull);
    });
  });

  group('Validators.optionalPhone', () {
    test('es opcional', () {
      expect(Validators.optionalPhone(null), isNull);
      expect(Validators.optionalPhone('  '), isNull);
    });

    test('acepta 10 dígitos con espacios, guiones o +52', () {
      expect(Validators.optionalPhone('55 1234 5678'), isNull);
      expect(Validators.optionalPhone('55-1234-5678'), isNull);
      expect(Validators.optionalPhone('+52 55 1234 5678'), isNull);
    });

    test('rechaza longitudes o letras inválidas', () {
      expect(Validators.optionalPhone('5512345'), isNotNull);
      expect(Validators.optionalPhone('55123456789'), isNotNull);
      expect(Validators.optionalPhone('55 1234 abcd'), isNotNull);
    });
  });

  test('Validators.bio limita a 160 caracteres', () {
    expect(Validators.bio('a' * 160), isNull);
    expect(Validators.bio('a' * 161), 'Máximo 160 caracteres');
    expect(Validators.bio(null), isNull);
  });

  test('Validators.newEmail rechaza el mismo correo', () {
    expect(
      Validators.newEmail('ANA@correo.mx ', 'ana@correo.mx'),
      'Es el mismo correo que ya usas',
    );
    expect(Validators.newEmail('otra@correo.mx', 'ana@correo.mx'), isNull);
    expect(Validators.newEmail('otra@', 'ana@correo.mx'), isNotNull);
  });
}
