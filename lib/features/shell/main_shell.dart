import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/app_bottom_nav.dart';
import '../auth/presentation/home_screen.dart';
import '../campaigns/presentation/campaigns_screen.dart';
import '../learning/presentation/learn_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../recycling/presentation/recycling_centers_screen.dart';
import '../reports/presentation/report_screen.dart';

/// Contenedor principal después de iniciar sesión: mantiene las pestañas
/// vivas con su estado y muestra una sola barra de navegación.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppTab _current = AppTab.inicio;

  // Las pestañas se construyen la primera vez que se visitan, así Reciclaje
  // no pide la ubicación hasta que el usuario entra.
  final Set<AppTab> _visited = <AppTab>{AppTab.inicio};

  // Se incrementa cuando cambian datos del usuario (reporte enviado,
  // campaña o perfil actualizados) para que las pestañas recarguen.
  final ValueNotifier<int> _dataVersion = ValueNotifier<int>(0);

  @override
  void dispose() {
    _dataVersion.dispose();
    super.dispose();
  }

  void _selectTab(AppTab tab) {
    setState(() {
      _current = tab;
      _visited.add(tab);
    });
  }

  Future<void> _openReport() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (context) => const ReportScreen()),
    );

    _notifyDataChanged();
  }

  void _notifyDataChanged() {
    _dataVersion.value++;
  }

  Widget _buildTab(AppTab tab) {
    if (!_visited.contains(tab)) {
      return const SizedBox.shrink();
    }

    switch (tab) {
      case AppTab.inicio:
        return const HomeScreen();
      case AppTab.reciclaje:
        return const RecyclingCentersScreen();
      case AppTab.aprender:
        return const LearnScreen();
      case AppTab.campanas:
        return const CampaignsScreen();
      case AppTab.perfil:
        return const ProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      currentTab: _current,
      selectTab: _selectTab,
      openReport: _openReport,
      notifyDataChanged: _notifyDataChanged,
      dataVersion: _dataVersion,
      child: PopScope(
        canPop: _current == AppTab.inicio,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _selectTab(AppTab.inicio);
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: AppTab.values.indexOf(_current),
            children: AppTab.values.map(_buildTab).toList(),
          ),
          bottomNavigationBar: AppBottomNav(
            current: _current,
            onSelected: _selectTab,
            onReport: _openReport,
          ),
        ),
      ),
    );
  }
}

/// Permite que las pantallas dentro de [MainShell] cambien de pestaña,
/// abran el flujo de reporte y avisen o escuchen cambios de datos.
class MainShellScope extends InheritedWidget {
  const MainShellScope({
    super.key,
    required this.currentTab,
    required this.selectTab,
    required this.openReport,
    required this.notifyDataChanged,
    required this.dataVersion,
    required super.child,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> selectTab;
  final Future<void> Function() openReport;
  final VoidCallback notifyDataChanged;
  final ValueListenable<int> dataVersion;

  /// Devuelve null cuando la pantalla se usa fuera del contenedor (por
  /// ejemplo, en pruebas o abierta con Navigator.push).
  static MainShellScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<MainShellScope>();
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) {
    return currentTab != oldWidget.currentTab;
  }
}
