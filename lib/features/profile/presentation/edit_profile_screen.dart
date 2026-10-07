import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/colonies.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/profile_repository.dart';

/// Edición completa del perfil: foto, datos personales, avisos, correo,
/// contraseña y eliminación de la cuenta.
///
/// Devuelve `true` al cerrar si se guardó algún cambio.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    required this.repository,
    this.imagePicker,
  });

  final UserProfile profile;
  final ProfileRepository repository;
  final ImagePicker? imagePicker;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController = TextEditingController(
    text: widget.profile.fullName,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.profile.phone ?? '',
  );
  late final TextEditingController _bioController = TextEditingController(
    text: widget.profile.bio ?? '',
  );

  late String? _colony = cuajimalpaColonies.contains(widget.profile.colony)
      ? widget.profile.colony
      : null;
  late NotificationPreferences _notifications = widget.profile.notifications;

  late String? _avatarUrl = widget.profile.avatarUrl;
  Uint8List? _avatarPreview;
  bool _isUploadingAvatar = false;

  bool _isSaving = false;
  bool _savedSomething = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refresh);
    _phoneController.addListener(_refresh);
    _bioController.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _hasChanges {
    final UserProfile original = widget.profile;
    final String originalColony = cuajimalpaColonies.contains(original.colony)
        ? original.colony!
        : '';

    return _nameController.text.trim() != original.fullName.trim() ||
        _phoneController.text.trim() != (original.phone ?? '').trim() ||
        _bioController.text.trim() != (original.bio ?? '').trim() ||
        (_colony ?? '') != originalColony ||
        _notifications != original.notifications;
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showMessage('Revisa los campos marcados en rojo.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await widget.repository.update(
        ProfileUpdate(
          fullName: _nameController.text,
          colony: _colony!,
          phone: _phoneController.text,
          bio: _bioController.text,
          notifications: _notifications,
        ),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      _showMessage('No se pudieron guardar los cambios.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Los cambios que hiciste se perderán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  // ---------------------------------------------------------------------
  // Foto de perfil
  // ---------------------------------------------------------------------

  Future<void> _changeAvatar() async {
    final bool hasPhoto = _avatarPreview != null || _avatarUrl != null;

    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Quitar foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == 'remove') {
      await _removeAvatar();
      return;
    }

    try {
      final XFile? file = await (widget.imagePicker ?? ImagePicker()).pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();
      final String extension = file.name.toLowerCase().endsWith('.png')
          ? 'png'
          : 'jpg';

      await _uploadAvatar(bytes, extension);
    } catch (_) {
      _showMessage(
        'No se pudo abrir la cámara o la galería. Revisa los permisos.',
        isError: true,
      );
    }
  }

  Future<void> _uploadAvatar(Uint8List bytes, String extension) async {
    final Uint8List? previousPreview = _avatarPreview;

    setState(() {
      _avatarPreview = bytes;
      _isUploadingAvatar = true;
    });

    try {
      final String url = await widget.repository.uploadAvatar(bytes, extension);

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarUrl = url;
        _savedSomething = true;
      });
      _showMessage('Foto de perfil actualizada.');
    } catch (_) {
      if (mounted) {
        setState(() => _avatarPreview = previousPreview);
      }
      _showMessage('No se pudo subir la foto.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _isUploadingAvatar = true);

    try {
      await widget.repository.removeAvatar();

      if (!mounted) {
        return;
      }

      setState(() {
        _avatarUrl = null;
        _avatarPreview = null;
        _savedSomething = true;
      });
      _showMessage('Foto eliminada.');
    } catch (_) {
      _showMessage('No se pudo quitar la foto.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Cuenta
  // ---------------------------------------------------------------------

  Future<void> _changeEmail() async {
    final String? newEmail = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _ChangeEmailDialog(currentEmail: widget.profile.email),
    );

    if (newEmail == null) {
      return;
    }

    try {
      await widget.repository.changeEmail(newEmail);
      _showMessage(
        'Te enviamos un enlace a $newEmail. El cambio se aplica al '
        'confirmarlo.',
      );
    } catch (_) {
      _showMessage(
        'No se pudo cambiar el correo. Puede que ya esté en uso.',
        isError: true,
      );
    }
  }

  Future<void> _changePassword() async {
    final String? newPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _ChangePasswordDialog(),
    );

    if (newPassword == null) {
      return;
    }

    try {
      await widget.repository.changePassword(newPassword);
      _showMessage('Contraseña actualizada.');
    } catch (_) {
      _showMessage(
        'No se pudo cambiar la contraseña. Prueba con una distinta a la '
        'actual.',
        isError: true,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _DeleteAccountDialog(),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    setState(() => _isSaving = true);

    try {
      await widget.repository.deleteAccount();
      // La sesión se cerró; AuthGate muestra el inicio de sesión.
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
      _showMessage('No se pudo eliminar la cuenta.', isError: true);
    }
  }

  // ---------------------------------------------------------------------
  // Vista
  // ---------------------------------------------------------------------

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
    String? helper,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon, color: AppColors.darkGreen),
      filled: true,
      fillColor: AppColors.fieldBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges && !_isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSaving) {
          return;
        }

        final NavigatorState navigator = Navigator.of(context);

        if (await _confirmDiscard()) {
          navigator.pop(_savedSomething);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          leading: BackButton(
            onPressed: () => Navigator.maybePop(context, _savedSomething),
          ),
          title: const Text(
            'Editar perfil',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 24),
              _sectionTitle('Datos personales'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  'Nombre completo',
                  Icons.person_outline,
                ),
                validator: Validators.fullName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _decoration(
                  'Teléfono (opcional)',
                  Icons.phone_outlined,
                  hint: '55 1234 5678',
                  helper: 'Solo se usa si la Alcaldía necesita contactarte',
                ),
                validator: Validators.optionalPhone,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _colony,
                isExpanded: true,
                decoration: _decoration('Colonia', Icons.location_on_outlined),
                items: cuajimalpaColonies
                    .map(
                      (colony) => DropdownMenuItem<String>(
                        value: colony,
                        child: Text(colony),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _colony = value),
                validator: Validators.colony,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                maxLength: Validators.maxBioLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration(
                  'Sobre mí (opcional)',
                  Icons.edit_note_rounded,
                  hint: 'Ej. Vecina de Contadero, me gusta reforestar',
                ),
                validator: Validators.bio,
              ),
              const SizedBox(height: 14),
              _sectionTitle('Notificaciones'),
              const SizedBox(height: 4),
              _buildNotificationSwitches(),
              const SizedBox(height: 20),
              _sectionTitle('Cuenta'),
              const SizedBox(height: 8),
              _buildAccountCard(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving || !_hasChanges ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  disabledBackgroundColor: const Color(0xFFD2DBD7),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 28),
              _buildDangerZone(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingAvatar ? null : _changeAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  initials: widget.profile.initials,
                  imageUrl: _avatarUrl,
                  imageBytes: _avatarPreview,
                  radius: 48,
                  backgroundColor: AppColors.mediumGreen,
                ),
                if (_isUploadingAvatar)
                  const Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: Colors.black38,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isUploadingAvatar ? null : _changeAvatar,
            child: const Text('Cambiar foto'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitches() {
    Widget item({
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primaryGreen,
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        item(
          title: 'Estado de mis reportes',
          subtitle: 'Cuando un reporte pasa a en proceso, resuelto o rechazado',
          value: _notifications.reports,
          onChanged: (value) => setState(
            () => _notifications = _notifications.copyWith(reports: value),
          ),
        ),
        item(
          title: 'Campañas',
          subtitle: 'Campañas nuevas y recordatorios de las que te inscribiste',
          value: _notifications.campaigns,
          onChanged: (value) => setState(
            () => _notifications = _notifications.copyWith(campaigns: value),
          ),
        ),
        item(
          title: 'Consejos ecológicos',
          subtitle: 'Tips de reciclaje y cuidado del agua',
          value: _notifications.tips,
          onChanged: (value) => setState(
            () => _notifications = _notifications.copyWith(tips: value),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountCard() {
    final String? pending = widget.profile.pendingEmail;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.email_outlined,
              color: AppColors.darkGreen,
            ),
            title: const Text('Correo electrónico'),
            subtitle: Text(
              pending == null
                  ? widget.profile.email
                  : '${widget.profile.email}\nPendiente de confirmar: $pending',
            ),
            isThreeLine: pending != null,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _changeEmail,
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.darkGreen),
            title: const Text('Contraseña'),
            subtitle: const Text('Cámbiala cuando quieras'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _changePassword,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC9C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eliminar cuenta',
            style: TextStyle(
              color: Colors.red,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Se borran tu perfil, tus reportes, tus fotos y tus inscripciones. '
            'No se puede deshacer.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _deleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({required this.currentEmail});

  final String currentEmail;

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar correo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Te enviaremos un enlace al correo nuevo para confirmarlo.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo nuevo',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  Validators.newEmail(value, widget.currentEmail),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          child: const Text('Enviar enlace'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Contraseña nueva',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  Validators.confirmPassword(value, _password.text),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, _password.text);
            }
          },
          child: const Text('Cambiar'),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const String _confirmationWord = 'ELIMINAR';
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool matches = _controller.text.trim() == _confirmationWord;

    return AlertDialog(
      title: const Text('¿Eliminar tu cuenta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrarán tu perfil, reportes, fotos e inscripciones. Esta '
            'acción no se puede deshacer.',
          ),
          const SizedBox(height: 12),
          const Text('Escribe ELIMINAR para confirmar:'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}
