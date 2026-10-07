import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../shell/main_shell.dart';
import '../data/campaign.dart';
import '../data/campaigns_repository.dart';

/// Lista de campañas y jornadas ecológicas con opción de inscribirse.
class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key, this.repository});

  final CampaignsRepository? repository;

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  late final CampaignsRepository _repository =
      widget.repository ?? SupabaseCampaignsRepository();

  List<Campaign> _campaigns = <Campaign>[];
  final Set<int> _busyIds = <int>{};
  bool _isLoading = true;
  bool _hasError = false;
  bool _onlyJoined = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final List<Campaign> campaigns = await _repository.activeCampaigns();

      if (!mounted) {
        return;
      }

      setState(() {
        _campaigns = campaigns;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleJoin(Campaign campaign) async {
    if (_busyIds.contains(campaign.id)) {
      return;
    }

    setState(() {
      _busyIds.add(campaign.id);
    });

    try {
      if (campaign.joined) {
        await _repository.leave(campaign.id);
      } else {
        await _repository.join(campaign.id);
      }

      if (!mounted) {
        return;
      }

      final Campaign updated = campaign.copyWith(
        joined: !campaign.joined,
        participantsCount:
            campaign.participantsCount + (campaign.joined ? -1 : 1),
      );

      setState(() {
        _campaigns = _campaigns
            .map((item) => item.id == campaign.id ? updated : item)
            .toList();
      });

      MainShellScope.maybeOf(context)?.notifyDataChanged();

      _showMessage(
        updated.joined
            ? '¡Listo! Te inscribiste en "${campaign.title}".'
            : 'Cancelaste tu inscripción.',
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          'No se pudo actualizar tu inscripción. Inténtalo de nuevo.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(campaign.id);
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : AppColors.darkGreen,
        ),
      );
  }

  List<Campaign> get _visibleCampaigns {
    if (!_onlyJoined) {
      return _campaigns;
    }

    return _campaigns.where((campaign) => campaign.joined).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<Campaign> campaigns = _visibleCampaigns;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primaryGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                )
              else if (_hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'No se pudieron cargar las campañas',
                    message: 'Revisa tu conexión e inténtalo de nuevo.',
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text('Reintentar'),
                    ),
                  ),
                )
              else if (campaigns.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildMessage(
                    icon: Icons.park_outlined,
                    title: _onlyJoined
                        ? 'No estás inscrito en campañas'
                        : 'No hay campañas activas',
                    message: _onlyJoined
                        ? 'Inscríbete en una campaña para verla aquí.'
                        : 'Vuelve pronto para conocer las próximas jornadas.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 30),
                  sliver: SliverList.separated(
                    itemCount: campaigns.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildCampaignCard(campaigns[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final int joinedCount = _campaigns
        .where((campaign) => campaign.joined)
        .length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Campañas Activas',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Jornadas y eventos ecológicos en Cuajimalpa',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Todas'),
                selected: !_onlyJoined,
                selectedColor: AppColors.primaryGreen,
                labelStyle: TextStyle(
                  color: !_onlyJoined ? Colors.white : AppColors.textPrimary,
                ),
                onSelected: (_) => setState(() => _onlyJoined = false),
              ),
              ChoiceChip(
                label: Text('Mis campañas ($joinedCount)'),
                selected: _onlyJoined,
                selectedColor: AppColors.primaryGreen,
                labelStyle: TextStyle(
                  color: _onlyJoined ? Colors.white : AppColors.textPrimary,
                ),
                onSelected: (_) => setState(() => _onlyJoined = true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(Campaign campaign) {
    final bool busy = _busyIds.contains(campaign.id);
    final bool happeningNow = campaign.isHappeningAt(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: campaign.joined ? AppColors.primaryGreen : AppColors.border,
          width: campaign.joined ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (campaign.category != null) ...[
                _tag(campaign.category!, const Color(0xFF00AE92)),
                const SizedBox(width: 6),
              ],
              if (happeningNow) _tag('En curso', const Color(0xFFF58A1F)),
              const Spacer(),
              const Icon(
                Icons.people_outline_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${campaign.participantsCount}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            campaign.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            campaign.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.event_outlined,
            Formatters.eventDate(campaign.startsAt),
          ),
          const SizedBox(height: 5),
          _infoRow(
            Icons.location_on_outlined,
            campaign.colony == null
                ? campaign.location
                : '${campaign.location} · ${campaign.colony}',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: campaign.joined
                ? OutlinedButton.icon(
                    onPressed: busy ? null : () => _toggleJoin(campaign),
                    icon: busy
                        ? _smallSpinner(AppColors.primaryGreen)
                        : const Icon(Icons.check_rounded),
                    label: const Text('Inscrito · Cancelar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: busy ? null : () => _toggleJoin(campaign),
                    icon: busy
                        ? _smallSpinner(Colors.white)
                        : const Icon(Icons.add_rounded),
                    label: const Text('Inscribirme'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _smallSpinner(Color color) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(color: color, strokeWidth: 2),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 58, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }
}
