import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/colonies.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/report.dart';
import '../data/reports_repository.dart';
import 'my_reports_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.repository,
    this.locationService = const LocationService(),
  });

  /// Si es null se usa Supabase. Las pruebas inyectan uno falso.
  final ReportsRepository? repository;
  final LocationService locationService;

  /// Tamaño máximo de foto aceptado (10 MB).
  static const int maxPhotoBytes = 10 * 1024 * 1024;

  /// Longitud mínima de la descripción.
  static const int minDescriptionLength = 10;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final ReportsRepository _repository =
      widget.repository ?? SupabaseReportsRepository();
  final ImagePicker _imagePicker = ImagePicker();

  int _currentStep = 0;
  bool _showAsGrid = true;
  bool _isLocating = false;
  bool _isSubmitting = false;

  GeoPoint? _location;
  Uint8List? _photoBytes;
  String _photoExtension = 'jpg';

  ReportProblem? _selectedProblem;
  String? _selectedColony;
  String _folio = '';

  bool get _locationEnabled => _location != null;
  bool get _photoSelected => _photoBytes != null;

  final List<ReportProblem> _problems = const [
    ReportProblem(
      title: 'Basura acumulada',
      icon: Icons.delete_outline_rounded,
      borderColor: Color(0xFFFF9B3D),
      backgroundColor: Color(0xFFFFF7ED),
      iconColor: Color(0xFFFF8A00),
    ),
    ReportProblem(
      title: 'Zona descuidada',
      icon: Icons.warning_amber_rounded,
      borderColor: Color(0xFFFF8A3D),
      backgroundColor: Color(0xFFFFF7EE),
      iconColor: Color(0xFFFF6D00),
    ),
    ReportProblem(
      title: 'Área verde dañada',
      icon: Icons.eco_outlined,
      borderColor: Color(0xFF57D98A),
      backgroundColor: Color(0xFFF0FFF5),
      iconColor: Color(0xFF00B95C),
    ),
    ReportProblem(
      title: 'Problema de agua',
      icon: Icons.water_drop_outlined,
      borderColor: Color(0xFF79AFFF),
      backgroundColor: Color(0xFFF0F6FF),
      iconColor: Color(0xFF126CFF),
    ),
    ReportProblem(
      title: 'Árbol caído/dañado',
      icon: Icons.park_outlined,
      borderColor: Color(0xFF35D8C2),
      backgroundColor: Color(0xFFF0FFFC),
      iconColor: Color(0xFF00A891),
    ),
    ReportProblem(
      title: 'Otro problema',
      icon: Icons.report_problem_outlined,
      borderColor: Color(0xFFC8D2DE),
      backgroundColor: Color(0xFFF7F9FC),
      iconColor: Color(0xFF71849C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_refreshDescriptionState);
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_refreshDescriptionState);
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshDescriptionState() {
    setState(() {});
  }

  bool get _canContinue {
    switch (_currentStep) {
      case 0:
        return _selectedProblem != null;
      case 1:
        return _selectedColony != null &&
            _descriptionController.text.trim().length >=
                ReportScreen.minDescriptionLength;
      case 2:
        return !_isSubmitting;
      default:
        return false;
    }
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleBack() {
    if (_isSubmitting) {
      return;
    }

    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    _goToStep(_currentStep - 1);
  }

  Future<void> _cancelReport() async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('¿Cancelar el reporte?'),
          content: const Text(
            'Los datos capturados en este reporte se perderán.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Seguir editando'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancelar reporte'),
            ),
          ],
        );
      },
    );

    if (shouldCancel == true && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _continueReport() async {
    if (!_canContinue) {
      if (_currentStep == 0) {
        _showMessage('Selecciona un tipo de problema.');
      } else if (_selectedColony == null) {
        _showMessage('Selecciona la colonia o zona.');
      } else {
        _showMessage('La descripción debe tener al menos 10 caracteres.');
      }
      return;
    }

    if (_currentStep < 2) {
      _goToStep(_currentStep + 1);
      return;
    }

    await _submitReport();
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final Report report = await _repository.submit(
        NewReport(
          category: _selectedProblem!.title,
          colony: _selectedColony!,
          description: _descriptionController.text,
          latitude: _location?.latitude,
          longitude: _location?.longitude,
          photoBytes: _photoBytes,
          photoExtension: _photoExtension,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _folio = report.folio;
        _currentStep = 3;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'No se pudo enviar el reporte. Revisa tu conexión e inténtalo de nuevo.',
        isError: true,
      );
      debugPrint('Error al enviar reporte: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
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

  Future<void> _handleLocationButton() async {
    if (_isLocating) {
      return;
    }

    if (_locationEnabled) {
      setState(() {
        _location = null;
      });
      _showMessage('Ubicación quitada del reporte.');
      return;
    }

    final bool? shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F2F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_outlined,
              color: Color(0xFF7D8782),
              size: 30,
            ),
          ),
          title: const Text(
            '¿Activar tu ubicación?',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'EcoCuajimalpa utilizará tu ubicación para ayudarte a '
            'detectar la colonia donde ocurre el problema.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Ahora no',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkGreen,
              ),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Activar'),
            ),
          ],
        );
      },
    );

    if (shouldEnable != true || !mounted) {
      return;
    }

    setState(() {
      _isLocating = true;
    });

    try {
      final GeoPoint location = await widget.locationService
          .getCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _location = location;
      });
      _showMessage('Ubicación agregada al reporte.');
    } on LocationException catch (error) {
      if (mounted) {
        _showMessage(error.message, isError: true);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'No pudimos obtener tu ubicación. Inténtalo de nuevo.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _choosePhoto() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
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
              if (_photoSelected)
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
        );
      },
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == 'remove') {
      setState(() {
        _photoBytes = null;
      });
      _showMessage('Foto eliminada del reporte.');
      return;
    }

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (file == null) {
        return;
      }

      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.length > ReportScreen.maxPhotoBytes) {
        _showMessage('La foto supera los 10 MB.', isError: true);
        return;
      }

      setState(() {
        _photoBytes = bytes;
        _photoExtension = file.name.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpg';
      });
    } catch (_) {
      if (mounted) {
        _showMessage(
          'No se pudo abrir la cámara o la galería. Revisa los permisos.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 3) {
      return _buildSuccessScreen();
    }

    return PopScope(
      canPop: _currentStep == 0 && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              sliver: SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: switch (_currentStep) {
                    0 => _buildStepOne(),
                    1 => _buildStepTwo(),
                    _ => _buildStepThree(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 11),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _handleBack,
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.darkGreen,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hacer Reporte',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paso ${_currentStep + 1} de 3',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(3, (index) {
              final bool completed = index <= _currentStep;

              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: completed
                        ? AppColors.primaryGreen
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      key: const ValueKey('step-one'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué tipo de problema es?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Selecciona la opción que mejor describe la situación',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Forma de visualización',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              ),
            ),
            _buildViewToggle(),
          ],
        ),
        const SizedBox(height: 15),
        if (_showAsGrid) _buildProblemGrid() else _buildProblemList(),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _viewToggleButton(
            icon: Icons.grid_view_rounded,
            selected: _showAsGrid,
            onTap: () {
              setState(() {
                _showAsGrid = true;
              });
            },
          ),
          _viewToggleButton(
            icon: Icons.view_list_rounded,
            selected: !_showAsGrid,
            onTap: () {
              setState(() {
                _showAsGrid = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _viewToggleButton({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppColors.primaryGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 34,
          height: 32,
          child: Icon(
            icon,
            size: 19,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProblemGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 11,
      mainAxisSpacing: 11,
      childAspectRatio: 1.42,
      children: _problems.map(_buildProblemGridCard).toList(),
    );
  }

  Widget _buildProblemGridCard(ReportProblem problem) {
    final bool selected = _selectedProblem == problem;

    return Material(
      color: problem.backgroundColor,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedProblem = problem;
          });
        },
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? problem.iconColor : problem.borderColor,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _problemIcon(problem),
                  const Spacer(),
                  Text(
                    problem.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: problem.iconColor,
                    size: 21,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProblemList() {
    return Column(
      children: _problems.map((problem) {
        final bool selected = _selectedProblem == problem;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: problem.backgroundColor,
            borderRadius: BorderRadius.circular(17),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedProblem = problem;
                });
              },
              borderRadius: BorderRadius.circular(17),
              child: Container(
                constraints: const BoxConstraints(minHeight: 68),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected ? problem.iconColor : problem.borderColor,
                    width: selected ? 2 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    _problemIcon(problem),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        problem.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: problem.iconColor,
                        size: 21,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _problemIcon(ReportProblem problem) {
    return Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(problem.icon, color: problem.iconColor, size: 21),
    );
  }

  Widget _buildStepTwo() {
    final bool descriptionIsValid =
        _descriptionController.text.trim().length >=
        ReportScreen.minDescriptionLength;

    return Column(
      key: const ValueKey('step-two'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Dónde ocurre?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Indica la ubicación y describe el problema',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 22),
        const Text(
          'Colonia / zona',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cuajimalpaColonies.map((colony) {
            final bool selected = _selectedColony == colony;

            return ChoiceChip(
              label: Text(colony),
              selected: selected,
              selectedColor: AppColors.primaryGreen,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? AppColors.primaryGreen : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) {
                setState(() {
                  _selectedColony = colony;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _buildLocationButton(),
        const SizedBox(height: 18),
        const Text(
          'Descripción del problema',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLength: 500,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            hintText:
                'Describe brevemente el problema. Ej: Hay basura acumulada desde hace 3 días en la esquina de...',
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
            filled: true,
            fillColor: const Color(0xFFF0F6F2),
            alignLabelWithHint: true,
            counterText:
                '${_descriptionController.text.length}/500 · mín. 10 caracteres',
            counterStyle: TextStyle(
              color: descriptionIsValid
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              fontSize: 10,
            ),
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
          ),
        ),
      ],
    );
  }

  Widget _buildLocationButton() {
    final bool active = _locationEnabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleLocationButton,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE9FFF5) : const Color(0xFFF0F2F1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(0xFF62DFA0) : const Color(0xFFD0D6D3),
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryGreen
                      : const Color(0xFF9AA4A0),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        active
                            ? Icons.location_on_outlined
                            : Icons.location_off_outlined,
                        color: Colors.white,
                        size: 25,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLocating
                          ? 'Obteniendo ubicación...'
                          : active
                          ? 'Ubicación agregada'
                          : 'Agregar mi ubicación (opcional)',
                      style: TextStyle(
                        color: active
                            ? AppColors.primaryGreen
                            : const Color(0xFF6E7773),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      active
                          ? '${_location!.latitude.toStringAsFixed(5)}, '
                                '${_location!.longitude.toStringAsFixed(5)} · '
                                'toca para quitarla'
                          : 'Ayuda a ubicar el problema con precisión',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                active
                    ? Icons.check_circle_outline_rounded
                    : Icons.chevron_right_rounded,
                color: active
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepThree() {
    return Column(
      key: const ValueKey('step-three'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Agrega una foto (opcional)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Una imagen ayuda a que tu reporte sea atendido más rápido',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 18),
        GestureDetector(
          onTap: _isSubmitting ? null : _choosePhoto,
          child: CustomPaint(
            painter: _DashedRoundedBorderPainter(
              color: _photoSelected
                  ? AppColors.primaryGreen
                  : const Color(0xFF69DFA9),
              radius: 17,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                color: _photoSelected
                    ? const Color(0xFFE9FFF5)
                    : const Color(0xFFF0FFF8),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Column(
                children: [
                  if (_photoSelected)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.memory(
                        _photoBytes!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _photoSelected
                        ? 'Foto seleccionada'
                        : 'Tomar foto o seleccionar',
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _photoSelected
                        ? 'Toca para cambiarla o quitarla'
                        : 'JPG, PNG hasta 10 MB',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildReportSummary(),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            'Tu reporte será enviado a las autoridades de la Alcaldía '
            'Cuajimalpa para su atención.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen del reporte',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _summaryRow(
            label: 'Problema:',
            value: _selectedProblem?.title ?? '-',
          ),
          const SizedBox(height: 12),
          _summaryRow(label: 'Ubicación:', value: _selectedColony ?? '-'),
          const SizedBox(height: 12),
          _summaryRow(
            label: 'GPS:',
            value: _locationEnabled ? 'Incluido' : 'No incluido',
          ),
          const SizedBox(height: 12),
          _summaryRow(
            label: 'Foto:',
            value: _photoSelected ? 'Incluida' : 'Sin foto',
          ),
          const SizedBox(height: 12),
          _summaryRow(
            label: 'Descripción:',
            value: _descriptionController.text.trim(),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 73,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    final String primaryText = _currentStep == 2
        ? 'Enviar reporte'
        : 'Continuar';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _cancelReport,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFFB7BC)),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _canContinue ? _continueReport : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  disabledBackgroundColor: const Color(0xFFD2DBD7),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        primaryText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 85, 22, 30),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9FFF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF62DFA0)),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.primaryGreen,
                  size: 52,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '¡Reporte enviado!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu reporte ha sido registrado y será atendido por las '
                'autoridades de Cuajimalpa. Gracias por cuidar tu comunidad.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _successRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Tipo de reporte',
                      value: _selectedProblem?.title ?? '-',
                    ),
                    const SizedBox(height: 14),
                    _successRow(
                      icon: Icons.location_on_outlined,
                      label: 'Ubicación',
                      value: _selectedColony ?? '-',
                    ),
                    const SizedBox(height: 14),
                    _successRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Estado',
                      value: 'Pendiente · Folio #$_folio',
                      valueColor: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const MyReportsScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkGreen,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Ver mis reportes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Volver al inicio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _successRow({
    required IconData icon,
    required String label,
    required String value,
    Color valueColor = AppColors.textPrimary,
  }) {
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: const Color(0xFFE9FFF5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: valueColor, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class ReportProblem {
  const ReportProblem({
    required this.title,
    required this.icon,
    required this.borderColor,
    required this.backgroundColor,
    required this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color borderColor;
  final Color backgroundColor;
  final Color iconColor;
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final RRect roundedRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(roundedRect);

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;

      while (distance < metric.length) {
        final double nextDistance = (distance + 7)
            .clamp(0, metric.length)
            .toDouble();

        canvas.drawPath(metric.extractPath(distance, nextDistance), paint);

        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
