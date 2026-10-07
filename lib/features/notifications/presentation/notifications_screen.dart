import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../reports/presentation/my_reports_screen.dart';
import '../data/app_notification.dart';
import '../data/notifications_repository.dart';

/// Centro de notificaciones: avisos de reportes, campañas y consejos.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.repository, this.onOpenCampaigns});

  final NotificationsRepository? repository;

  /// Lleva a la pestaña de Campañas. Si es null, el aviso solo se marca
  /// como leído.
  final VoidCallback? onOpenCampaigns;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsRepository _repository =
      widget.repository ?? SupabaseNotificationsRepository();

  List<AppNotification> _notifications = <AppNotification>[];
  bool _isLoading = true;
  bool _hasError = false;
  bool _onlyUnread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _notifications.isEmpty;
      _hasError = false;
    });

    try {
      final List<AppNotification> notifications = await _repository.list();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hasError = _notifications.isEmpty;
        _isLoading = false;
      });
    }
  }

  int get _unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  void _replace(AppNotification updated) {
    setState(() {
      _notifications = _notifications
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
    });
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      _replace(notification.markedRead(DateTime.now()));
      _repository.markRead(notification.id).catchError((_) {});
    }

    if (notification.type.opensReports) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (context) => const MyReportsScreen()),
      );
    } else if (notification.type.opensCampaigns &&
        widget.onOpenCampaigns != null) {
      widget.onOpenCampaigns!();
    }
  }

  Future<void> _markAllRead() async {
    final List<AppNotification> previous = _notifications;
    final DateTime now = DateTime.now();

    setState(() {
      _notifications = _notifications
          .map((notification) => notification.markedRead(now))
          .toList();
    });

    try {
      await _repository.markAllRead();
    } catch (_) {
      if (mounted) {
        setState(() => _notifications = previous);
        _showMessage('No se pudieron marcar como leídas.', isError: true);
      }
    }
  }

  Future<void> _delete(AppNotification notification) async {
    final List<AppNotification> previous = _notifications;

    setState(() {
      _notifications = _notifications
          .where((item) => item.id != notification.id)
          .toList();
    });

    try {
      await _repository.delete(notification.id);
    } catch (_) {
      if (mounted) {
        setState(() => _notifications = previous);
        _showMessage('No se pudo borrar la notificación.', isError: true);
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

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> visible = _onlyUnread
        ? _notifications.where((item) => !item.isRead).toList()
        : _notifications;
    final Map<NotificationGroup, List<AppNotification>> groups =
        groupNotifications(visible);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Marcar todo leído'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primaryGreen,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: !_onlyUnread,
                  selectedColor: AppColors.primaryGreen,
                  labelStyle: TextStyle(
                    color: !_onlyUnread ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() => _onlyUnread = false),
                ),
                ChoiceChip(
                  label: Text('No leídas ($_unreadCount)'),
                  selected: _onlyUnread,
                  selectedColor: AppColors.primaryGreen,
                  labelStyle: TextStyle(
                    color: _onlyUnread ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() => _onlyUnread = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              )
            else if (_hasError)
              const _EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'No se pudieron cargar tus notificaciones',
                message: 'Desliza hacia abajo para reintentar.',
              )
            else if (visible.isEmpty)
              _EmptyState(
                icon: Icons.notifications_none_rounded,
                title: _onlyUnread
                    ? 'Estás al día'
                    : 'No tienes notificaciones',
                message: _onlyUnread
                    ? 'No tienes notificaciones sin leer.'
                    : 'Aquí verás avisos de tus reportes y campañas.',
              )
            else
              for (final MapEntry<NotificationGroup, List<AppNotification>>
                  entry
                  in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                  child: Text(
                    entry.key.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final AppNotification notification in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey<int>(notification.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _delete(notification),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      child: NotificationTile(
                        notification: notification,
                        onTap: () => _open(notification),
                      ),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool unread = !notification.isRead;
    final Color color = notification.type.color;

    return Material(
      color: unread ? const Color(0xFFF2FBF6) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread ? const Color(0xFF9FE3C0) : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(notification.type.icon, color: color, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: unread ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        notification.body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      Formatters.relativeDate(notification.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(left: 6, top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 90, 20, 20),
      child: Column(
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
        ],
      ),
    );
  }
}
