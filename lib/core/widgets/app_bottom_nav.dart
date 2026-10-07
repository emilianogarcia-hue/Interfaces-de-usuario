import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pestañas principales de la app. "Reportar" no es una pestaña: abre el
/// flujo de reporte encima de la pestaña actual.
enum AppTab { inicio, reciclaje, aprender, campanas, perfil }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
    required this.onReport,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelected;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
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
              _item(
                tab: AppTab.inicio,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Inicio',
              ),
              _item(
                tab: AppTab.reciclaje,
                icon: Icons.recycling_outlined,
                selectedIcon: Icons.recycling_rounded,
                label: 'Reciclaje',
              ),
              _NavItem(
                icon: Icons.description_outlined,
                label: 'Reportar',
                selected: false,
                onTap: onReport,
              ),
              _item(
                tab: AppTab.aprender,
                icon: Icons.menu_book_outlined,
                selectedIcon: Icons.menu_book_rounded,
                label: 'Aprender',
              ),
              _item(
                tab: AppTab.campanas,
                icon: Icons.campaign_outlined,
                selectedIcon: Icons.campaign_rounded,
                label: 'Campañas',
              ),
              _item(
                tab: AppTab.perfil,
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({
    required AppTab tab,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final bool selected = tab == current;

    return _NavItem(
      icon: selected ? selectedIcon : icon,
      label: label,
      selected: selected,
      onTap: () => onSelected(tab),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? AppColors.primaryGreen
        : AppColors.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
