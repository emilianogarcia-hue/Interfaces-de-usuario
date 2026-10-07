import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../recycling/presentation/recycling_centers_screen.dart';
import '../../shell/main_shell.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int? _expandedIndex = 0;

  final List<LearningCategory> _categories = const [
    LearningCategory(
      title: 'Orgánicos',
      subtitle: 'Restos de comida y materiales biodegradables',
      containerLabel: 'Bote verde',
      icon: Icons.eco_outlined,
      color: Color(0xFF00C85A),
      lightColor: Color(0xFFEFFFF4),
      items: [
        'Cáscaras de frutas y verduras',
        'Restos de comida cocida o cruda',
        'Bolsas de té y café molido',
        'Flores y plantas',
        'Servilletas usadas',
      ],
      tip:
          'Estos residuos se convierten en composta. ¡Son ideales para nutrir jardines!',
    ),
    LearningCategory(
      title: 'Inorgánicos',
      subtitle: 'Materiales no biodegradables que no se reciclan',
      containerLabel: 'Bote gris o negro',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF68768D),
      lightColor: Color(0xFFF3F5F8),
      items: [
        'Pañales y toallas sanitarias',
        'Papel encerado o plastificado',
        'Envases de comida con grasa',
        'Unicel / poliestireno',
        'Colillas de cigarro',
      ],
      tip:
          'Aunque no se reciclan, deben separarse de los orgánicos para facilitar su disposición.',
    ),
    LearningCategory(
      title: 'Plástico',
      subtitle: 'Envases y materiales plásticos reciclables',
      containerLabel: 'Contenedor azul',
      icon: Icons.recycling_rounded,
      color: Color(0xFF1E78FF),
      lightColor: Color(0xFFEAF3FF),
      items: [
        'Botellas de refresco y agua',
        'Bolsas de plástico limpias',
        'Envases de shampoo y detergente',
        'Frascos de medicamentos vacíos',
        'Tapas y popotes',
      ],
      tip:
          'Enjuaga los envases antes de reciclarlos. El plástico sucio no puede procesarse.',
    ),
    LearningCategory(
      title: 'Papel y Cartón',
      subtitle: 'Materiales de papel y cartón reciclables',
      containerLabel: 'Contenedor amarillo',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFFFF9800),
      lightColor: Color(0xFFFFF4E5),
      items: [
        'Hojas y cuadernos sin plástico',
        'Cajas de cartón limpias',
        'Periódicos y revistas',
        'Sobres de papel',
        'Tubos de cartón',
      ],
      tip:
          'Mantén el papel y el cartón secos. Aplasta las cajas para ahorrar espacio.',
    ),
    LearningCategory(
      title: 'Vidrio',
      subtitle: 'Botellas y frascos de vidrio',
      containerLabel: 'Contenedor verde o café',
      icon: Icons.bolt_rounded,
      color: Color(0xFF00A3C7),
      lightColor: Color(0xFFE8FAFE),
      items: [
        'Botellas de bebidas',
        'Frascos de conservas y mermelada',
        'Botellas de vino y cerveza',
        'Frascos de salsas',
      ],
      tip: '¡El vidrio se puede reciclar infinitas veces sin perder calidad!',
    ),
    LearningCategory(
      title: 'Residuos especiales',
      subtitle: 'Materiales que requieren manejo especial',
      containerLabel: 'Centro de acopio especializado',
      icon: Icons.error_outline_rounded,
      color: Color(0xFFFF2D3D),
      lightColor: Color(0xFFFFECEE),
      items: [
        'Pilas y baterías',
        'Medicamentos vencidos',
        'Aceite de cocina usado',
        'Electrónicos viejos',
        'Pinturas y solventes',
      ],
      tip:
          'Nunca tires estos materiales en el bote regular. Lleva las pilas y electrónicos a los centros de reciclaje.',
    ),
    LearningCategory(
      title: 'Cuida el agua',
      subtitle: 'Consejos para el uso responsable del agua',
      containerLabel: 'Ahorro diario',
      icon: Icons.water_drop_outlined,
      color: Color(0xFF00BDAA),
      lightColor: Color(0xFFE9FFFC),
      items: [
        'Cierra la llave mientras te cepillas',
        'Repara fugas lo antes posible',
        'Reutiliza agua para limpiar o regar',
        'Toma duchas más cortas',
        'No viertas aceite en el drenaje',
      ],
      tip:
          'Pequeños cambios diarios pueden ahorrar muchos litros de agua cada semana.',
    ),
  ];

  void _openRecycling() {
    final MainShellScope? shell = MainShellScope.maybeOf(context);

    if (shell != null) {
      shell.selectTab(AppTab.reciclaje);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const RecyclingCentersScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(15, 16, 15, 105),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildIntroductionCard(),
                  const SizedBox(height: 14),
                  ...List.generate(
                    _categories.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _buildCategoryCard(index),
                    ),
                  ),
                  _buildHelpCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 14),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            Material(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(14),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: AppColors.darkGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aprende a Reciclar',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Guías de separación de residuos',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.darkGreen, AppColors.mediumGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.recycling_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Por qué separar la basura?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'En Cuajimalpa generamos toneladas de residuos cada semana. '
                  'Separar correctamente permite reciclar más y contaminar menos. '
                  '¡Tú marcas la diferencia!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(int index) {
    final LearningCategory category = _categories[index];
    final bool expanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: expanded ? category.color : AppColors.border,
          width: expanded ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 9,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedIndex = expanded ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: Colors.white, size: 21),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category.subtitle,
                            maxLines: expanded ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            child: expanded
                ? _buildExpandedContent(category)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(LearningCategory category) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text(
                  'Contenedor:',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      category.containerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...category.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: category.color,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: category.lightColor,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: category.color.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    category.tip,
                    style: TextStyle(
                      color: category.color,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF009E68), Color(0xFF12BE82)],
        ),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Text(
            '¿Tienes una duda?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Consulta los centros de reciclaje para saber dónde llevar tus residuos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 10.5, height: 1.35),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openRecycling,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
            icon: const Icon(Icons.location_on_outlined, size: 17),
            label: const Text('Ver centros'),
          ),
        ],
      ),
    );
  }
}

class LearningCategory {
  const LearningCategory({
    required this.title,
    required this.subtitle,
    required this.containerLabel,
    required this.icon,
    required this.color,
    required this.lightColor,
    required this.items,
    required this.tip,
  });

  final String title;
  final String subtitle;
  final String containerLabel;
  final IconData icon;
  final Color color;
  final Color lightColor;
  final List<String> items;
  final String tip;
}
