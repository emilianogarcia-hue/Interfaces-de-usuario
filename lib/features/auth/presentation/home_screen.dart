import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../recycling/presentation/recycling_centers_screen.dart';
import '../../reports/presentation/report_screen.dart';
import '../../learning/presentation/learn_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoadingProfile = true;

  String _fullName = 'Usuario';
  int _reportsCount = 0;
  double _recycledKg = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
      return;
    }

    try {
      final Map<String, dynamic>? profile = await _supabase
          .from('profiles')
          .select('full_name, reports_count, recycled_kg')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      final String metadataName =
          user.userMetadata?['full_name']?.toString().trim() ?? '';

      setState(() {
        final String profileName =
            profile?['full_name']?.toString().trim() ?? '';

        _fullName = profileName.isNotEmpty
            ? profileName
            : metadataName.isNotEmpty
                ? metadataName
                : 'Usuario';

        _reportsCount = (profile?['reports_count'] as num?)?.toInt() ?? 0;
        _recycledKg = (profile?['recycled_kg'] as num?)?.toDouble() ?? 0;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      final String metadataName =
          user.userMetadata?['full_name']?.toString().trim() ?? '';

      setState(() {
        _fullName = metadataName.isNotEmpty ? metadataName : 'Usuario';
        _isLoadingProfile = false;
      });
    }
  }

  String get _firstName {
    final String name = _fullName.trim();

    if (name.isEmpty) {
      return 'Usuario';
    }

    return name.split(RegExp(r'\s+')).first;
  }

  String get _formattedRecycledKg {
    if (_recycledKg == _recycledKg.roundToDouble()) {
      return _recycledKg.toInt().toString();
    }

    return _recycledKg.toStringAsFixed(1);
  }
void _openReportScreen() {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => const ReportScreen(),
    ),
  );
}
void _openLearnScreen() {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => const LearnScreen(),
    ),
  );
}
  void _openRecyclingCenters() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const RecyclingCentersScreen(),
      ),
    );
  }

  void _showPendingMessage(String moduleName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('El módulo "$moduleName" será el siguiente paso.'),
        backgroundColor: AppColors.darkGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          color: AppColors.primaryGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 105),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const Text(
                        'Acciones rápidas',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActions(),
                      const SizedBox(height: 18),
                      _buildDailyTip(),
                      const SizedBox(height: 17),
                      _buildRecentActivityHeader(),
                      const SizedBox(height: 10),
                      _buildRecentActivityCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkGreen,
            AppColors.mediumGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _isLoadingProfile
                    ? const _HeaderLoading()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenido/a, $_firstName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'EcoCuajimalpa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Alcaldía Cuajimalpa de Morelos · CDMX',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: () => _showPendingMessage('Notificaciones'),
                      borderRadius: BorderRadius.circular(18),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC857),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            children: [
              Expanded(
                child: _buildStatisticCard(
                  icon: Icons.description_outlined,
                  value: _reportsCount.toString(),
                  label: 'Reportes enviados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatisticCard(
                  icon: Icons.recycling_rounded,
                  value: _formattedRecycledKg,
                  label: 'Kg reciclados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatisticCard(
                  icon: Icons.eco_outlined,
                  value: '3',
                  label: 'Campañas activas',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.23),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.18,
          children: [
            _buildActionCard(
              title: 'Hacer Reporte',
              description: 'Avisa sobre basura o zonas descuidadas',
              icon: Icons.delete_outline_rounded,
              borderColor: const Color(0xFFFFA445),
              backgroundColor: const Color(0xFFFFF8EF),
              iconColor: const Color(0xFFF58A1F),
              onTap: _openReportScreen,
            ),
            _buildActionCard(
              title: 'Centros de Reciclaje',
              description: 'Encuentra el más cercano a ti',
              icon: Icons.location_on_outlined,
              borderColor: const Color(0xFF5DE39B),
              backgroundColor: const Color(0xFFF2FFF8),
              iconColor: AppColors.primaryGreen,
              badgeText: '5 cercanos',
              onTap: _openRecyclingCenters,
            ),
            _buildActionCard(
              title: 'Aprende a Reciclar',
              description: 'Guías y tutoriales sencillos',
              icon: Icons.menu_book_outlined,
              borderColor: const Color(0xFF66E79A),
              backgroundColor: const Color(0xFFF1FFF6),
              iconColor: const Color(0xFF00C968),
              badgeText: 'Nuevo',
             onTap: _openLearnScreen,

            ),
            _buildActionCard(
              title: 'Campañas Activas',
              description: 'Jornadas y eventos ecológicos',
              icon: Icons.park_outlined,
              borderColor: const Color(0xFF3EDDC4),
              backgroundColor: const Color(0xFFF1FFFC),
              iconColor: const Color(0xFF00AE92),
              badgeText: '3 activas',
              onTap: () => _showPendingMessage('Campañas'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color borderColor,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: borderColor,
              width: 1.4,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              if (badgeText != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF009E68),
            Color(0xFF10BD7E),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consejo del día',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Separa tus residuos en orgánicos, inorgánicos y reciclables. ¡Pequeñas acciones hacen grandes cambios!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Actividad reciente',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _showPendingMessage('Actividad reciente'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: const Row(
            children: [
              Text(
                'Ver todo',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryGreen,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.lightGreen,
            child: Icon(
              Icons.eco_outlined,
              color: AppColors.primaryGreen,
            ),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido a EcoCuajimalpa',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Ya puedes realizar reportes y participar en campañas.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              _buildNavigationItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Inicio',
                isSelected: true,
                onTap: () {},
              ),
              _buildNavigationItem(
                icon: Icons.recycling_outlined,
                selectedIcon: Icons.recycling_rounded,
                label: 'Reciclaje',
                onTap: _openRecyclingCenters,
              ),
              _buildNavigationItem(
                icon: Icons.description_outlined,
                selectedIcon: Icons.description_rounded,
                label: 'Reportar',
                onTap: _openReportScreen,

              ),
              _buildNavigationItem(
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book_rounded,
                label: 'Aprender',
                onTap: _openLearnScreen,
              ),
              _buildNavigationItem(
                icon: Icons.campaign_outlined,
                selectedIcon: Icons.campaign_rounded,
                label: 'Campañas',
                onTap: () => _showPendingMessage('Campañas'),
              ),
              _buildNavigationItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Perfil',
                onTap: () => _showPendingMessage('Perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 2,
            vertical: 8,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderLoading extends StatelessWidget {
  const _HeaderLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 135,
          height: 13,
          child: LinearProgressIndicator(
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
        SizedBox(height: 9),
        SizedBox(
          width: 165,
          height: 20,
          child: LinearProgressIndicator(
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
        SizedBox(height: 9),
        SizedBox(
          width: 210,
          height: 12,
          child: LinearProgressIndicator(
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
      ],
    );
  }
}