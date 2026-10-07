import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../campaigns/data/campaign.dart';
import '../../campaigns/data/campaigns_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../reports/data/report.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/presentation/my_reports_screen.dart';
import '../../shell/main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.profileRepository,
    this.reportsRepository,
    this.campaignsRepository,
    this.notificationsRepository,
  });

  final ProfileRepository? profileRepository;
  final ReportsRepository? reportsRepository;
  final CampaignsRepository? campaignsRepository;
  final NotificationsRepository? notificationsRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ProfileRepository _profileRepository =
      widget.profileRepository ?? SupabaseProfileRepository();
  late final ReportsRepository _reportsRepository =
      widget.reportsRepository ?? SupabaseReportsRepository();
  late final CampaignsRepository _campaignsRepository =
      widget.campaignsRepository ?? SupabaseCampaignsRepository();
  late final NotificationsRepository _notificationsRepository =
      widget.notificationsRepository ?? SupabaseNotificationsRepository();
  late final Stream<int> _unreadCount = _notificationsRepository
      .unreadCount()
      .handleError((Object _) {});

  bool _isLoadingProfile = true;

  String _firstName = 'Usuario';
  int _reportsCount = 0;
  double _recycledKg = 0;
  int? _activeCampaigns;
  List<Report> _recentReports = <Report>[];

  MainShellScope? _shell;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final MainShellScope? shell = MainShellScope.maybeOf(context);

    if (shell != _shell) {
      _shell?.dataVersion.removeListener(_loadDashboard);
      _shell = shell;
      _shell?.dataVersion.addListener(_loadDashboard);
    }
  }

  @override
  void dispose() {
    _shell?.dataVersion.removeListener(_loadDashboard);
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    await Future.wait<void>(<Future<void>>[
      _loadProfile(),
      _loadRecentReports(),
      _loadCampaigns(),
    ]);
  }

  Future<void> _loadProfile() async {
    try {
      final UserProfile profile = await _profileRepository.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _firstName = profile.firstName;
        _reportsCount = profile.reportsCount;
        _recycledKg = profile.recycledKg;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadRecentReports() async {
    try {
      final List<Report> reports = await _reportsRepository.myReports(limit: 3);

      if (mounted) {
        setState(() {
          _recentReports = reports;
        });
      }
    } catch (_) {
      // La sección muestra el mensaje de bienvenida si no hay datos.
    }
  }

  Future<void> _loadCampaigns() async {
    try {
      final List<Campaign> campaigns = await _campaignsRepository
          .activeCampaigns();

      if (mounted) {
        setState(() {
          _activeCampaigns = campaigns.length;
        });
      }
    } catch (_) {
      // Sin conexión se muestra un guion en lugar del número.
    }
  }

  void _openReportScreen() {
    MainShellScope.maybeOf(context)?.openReport();
  }

  void _openTab(AppTab tab) {
    MainShellScope.maybeOf(context)?.selectTab(tab);
  }

  void _openNotifications() {
    final MainShellScope? shell = MainShellScope.maybeOf(context);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (routeContext) => NotificationsScreen(
          repository: _notificationsRepository,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: AppColors.primaryGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 20, 12, 105),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
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
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.darkGreen, AppColors.mediumGreen],
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
                      onTap: _openNotifications,
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
                    top: 2,
                    right: 2,
                    child: IgnorePointer(
                      child: StreamBuilder<int>(
                        stream: _unreadCount,
                        builder: (context, snapshot) {
                          final int count = snapshot.data ?? 0;

                          if (count == 0) {
                            return const SizedBox.shrink();
                          }

                          return _UnreadBadge(count: count);
                        },
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
                  value: Formatters.kilograms(_recycledKg),
                  label: 'Kg reciclados',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatisticCard(
                  icon: Icons.eco_outlined,
                  value: _activeCampaigns?.toString() ?? '-',
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.23)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 20),
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
              style: const TextStyle(color: Colors.white, fontSize: 9.5),
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
              onTap: () => _openTab(AppTab.reciclaje),
            ),
            _buildActionCard(
              title: 'Aprende a Reciclar',
              description: 'Guías y tutoriales sencillos',
              icon: Icons.menu_book_outlined,
              borderColor: const Color(0xFF66E79A),
              backgroundColor: const Color(0xFFF1FFF6),
              iconColor: const Color(0xFF00C968),
              onTap: () => _openTab(AppTab.aprender),
            ),
            _buildActionCard(
              title: 'Campañas Activas',
              description: 'Jornadas y eventos ecológicos',
              icon: Icons.park_outlined,
              borderColor: const Color(0xFF3EDDC4),
              backgroundColor: const Color(0xFFF1FFFC),
              iconColor: const Color(0xFF00AE92),
              badgeText: (_activeCampaigns ?? 0) > 0
                  ? '$_activeCampaigns activas'
                  : null,
              onTap: () => _openTab(AppTab.campanas),
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
            border: Border.all(color: borderColor, width: 1.4),
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
                    child: Icon(icon, color: iconColor, size: 25),
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
          colors: [Color(0xFF009E68), Color(0xFF10BD7E)],
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
          onPressed: _openMyReports,
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
    if (_recentReports.isEmpty) {
      return _buildWelcomeCard();
    }

    return Column(
      children: _recentReports
          .map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildReportActivity(report),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReportActivity(Report report) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openMyReports,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.lightGreen,
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${report.colony} · '
                      '${Formatters.relativeDate(report.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              ReportStatusChip(status: report.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.lightGreen,
            child: Icon(Icons.eco_outlined, color: AppColors.primaryGreen),
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
