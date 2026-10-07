import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';

/// Recuperación de contraseña en dos pasos: se envía un código al correo y
/// con ese código se define la nueva contraseña.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.resetPasswordForEmail(_emailController.text.trim());

      if (!mounted) {
        return;
      }

      setState(() => _codeSent = true);
      _showMessage(
        'Si el correo está registrado, te enviamos un código de recuperación.',
      );
    } on AuthException catch (error) {
      _showMessage(_translate(error), isError: true);
    } catch (_) {
      _showMessage('No se pudo enviar el código.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyOTP(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
        type: OtpType.recovery,
      );

      await _auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (!mounted) {
        return;
      }

      _showMessage('Contraseña actualizada. ¡Bienvenido de nuevo!');
      // La verificación inicia sesión; AuthGate ya muestra la app debajo.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      _showMessage(_translate(error), isError: true);
    } catch (_) {
      _showMessage('No se pudo cambiar la contraseña.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _translate(AuthException error) {
    final String message = error.message.toLowerCase();

    if (message.contains('expired') || message.contains('invalid')) {
      return 'El código no es válido o ya expiró. Solicita uno nuevo.';
    }

    if (message.contains('rate') || message.contains('too many')) {
      return 'Realizaste demasiados intentos. Espera un momento.';
    }

    if (message.contains('same') && message.contains('password')) {
      return 'La nueva contraseña debe ser distinta a la anterior.';
    }

    return error.message;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : AppColors.darkGreen,
        ),
      );
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.darkGreen),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.fieldBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Recuperar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _codeSent
                      ? 'Escribe el código que llegó a tu correo y tu nueva '
                            'contraseña.'
                      : 'Te enviaremos un código a tu correo para que puedas '
                            'crear una nueva contraseña.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _emailController,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _decoration(
                    'tu@correo.com',
                    Icons.email_outlined,
                  ),
                  validator: Validators.email,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: _decoration(
                      'Código de verificación',
                      Icons.pin_outlined,
                    ),
                    validator: Validators.otpCode,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: _decoration(
                      'Nueva contraseña',
                      Icons.lock_outline,
                      suffix: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.darkGreen,
                        ),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscurePassword,
                    decoration: _decoration(
                      'Confirmar contraseña',
                      Icons.lock_outline,
                    ),
                    validator: (value) => Validators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : _codeSent
                      ? _resetPassword
                      : _sendCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _codeSent ? 'Cambiar contraseña' : 'Enviar código',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                if (_codeSent)
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                            _codeSent = false;
                            _codeController.clear();
                          }),
                    child: const Text('Usar otro correo o reenviar código'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
