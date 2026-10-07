/// Validaciones de formularios compartidas por las pantallas de cuenta.
class Validators {
  Validators._();

  static const int minPasswordLength = 8;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico';
    }

    if (!_emailPattern.hasMatch(value.trim())) {
      return 'Ingresa un correo válido';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }

    if (value.length < minPasswordLength) {
      return 'La contraseña debe tener al menos $minPasswordLength caracteres';
    }

    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu nombre completo';
    }

    if (value.trim().length < 3) {
      return 'El nombre es demasiado corto';
    }

    return null;
  }

  static String? colony(String? value) {
    if (value == null || value.isEmpty) {
      return 'Selecciona tu colonia';
    }

    return null;
  }

  static String? otpCode(String? value) {
    if (value == null || !RegExp(r'^\d{6,10}$').hasMatch(value.trim())) {
      return 'Ingresa el código numérico que llegó a tu correo';
    }

    return null;
  }
}
