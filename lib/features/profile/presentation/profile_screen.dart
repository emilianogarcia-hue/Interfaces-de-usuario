import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../reports/presentation/my_reports_screen.dart';
import '../../shell/main_shell.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.repository});

  final ProfileRepository? repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository =
      widget.repository ?? SupabaseProfileRepository();

  UserProfile? _profile;
  bool _isLoading = true;
  bool _hasError = false;
  MainShellScope? _shell;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final MainShellScope? shell = MainShellScope.maybeOf(context);

    if (shell != _shell) {
      _shell?.dataVersion.removeListener(_load);
      _shell = shell;
      _shell?.dataVersion.addListener(_load);
    }
  }

  @override
  void dispose() {
    _shell?.dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _profile == null;
      _hasError = false;
    });

    try {
      final UserProfile profile = await _repository.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasError = _profile == null;
        _isLoading = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final UserProfile? profile = _profile;

    if (profile == null) {
      return;
    }

    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (context) =>
            EditProfileScreen(profile: profile, repository: _repository),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado.'),
          backgroundColor: AppColors.darkGreen,
        ),
      );
      await _load();
      if (mounted) {
        MainShellScope.maybeOf(context)?.notifyDataChanged();
      }
    }
  }

  Future<void> _confirmSignOut() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a ingresar tu correo y '
          'contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
    await _repository.signOut();
  }

  void _openNotifications() {
    final MainShellScope? shell = MainShellScope.maybeOf(context);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (routeContext) => NotificationsScreen(
          onOpenCampaigns: shell == null
              ? null
              : () {
                  Navigator.of(routeContext).popUntil((route) => route.isFirst);
                  shell.selectTab(AppTab.campanas);
                },
        ),
      ),
    );
  }

  void _openMyReports() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const MyReportsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UserProfile? profile = _profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primaryGreen,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 160),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                )
              else if (_hasError || profile == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 140, 30, 30),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 58,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No se pudo cargar tu perfil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                      TextButton(
                        onPressed: _confirmSignOut,
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                )
              else ...[
                _buildHeader(profile),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
                  child: Column(
                    children: [
                      _buildOption(
                        icon: Icons.description_outlined,
                        title: 'Mis reportes',
                        subtitle: 'Consulta el estado de tus reportes',
                        onTap: _openMyReports,
                      ),
                      _buildOption(
                        icon: Icons.campaign_outlined,
                        title: 'Mis campañas',
                        subtitle: 'Jornadas en las que estás inscrito',
                        onTap: () => MainShellScope.maybeOf(
                          context,
                        )?.selectTab(AppTab.campanas),
                      ),
                      _buildOption(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notificaciones',
                        subtitle: 'Avisos de tus reportes y campañas',
                        onTap: _openNotifications,
                      ),
                      _buildOption(
                        icon: Icons.edit_outlined,
                        title: 'Editar perfil',
                        subtitle: 'Foto, datos, avisos, correo y contraseña',
                        onTap: _editProfile,
                      ),
                      _buildOption(
                        icon: Icons.logout_rounded,
                        title: 'Cerrar sesión',
                        subtitle: profile.email,
                        color: Colors.red,
                        onTap: _confirmSignOut,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 22, 15, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.mediumGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _editProfile,
            child: UserAvatar(
              initials: profile.initials,
              imageUrl: profile.avatarUrl,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            profile.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            profile.colony ?? 'Colonia sin definir',
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              profile.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _stat(
                  value: profile.reportsCount.toString(),
                  label: 'Reportes enviados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _stat(
                  value: Formatters.kilograms(profile.recycledKg),
                  label: 'Kg reciclados',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.23)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = AppColors.textPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.lightGreen,
                  child: Icon(
                    icon,
                    color: color == Colors.red ? color : AppColors.primaryGreen,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
