import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/recycling_center.dart';

class RecyclingCentersScreen extends StatefulWidget {
  const RecyclingCentersScreen({super.key});

  @override
  State<RecyclingCentersScreen> createState() => _RecyclingCentersScreenState();
}

class _RecyclingCentersScreenState extends State<RecyclingCentersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  final MapController _mapController = MapController();

  // Mientras no haya GPS se mide desde el centro de Cuajimalpa.
  GeoPoint _userLocation = LocationService.cuajimalpaCenter;
  bool _usingRealLocation = false;

  List<RecyclingCenter> _centers = <RecyclingCenter>[];

  bool _isLoading = true;
  String? _errorMessage;

  bool _openNowOnly = false;
  String _sortBy = 'nearest';
  double _maxDistance = maxDistanceFilterKm;
  Set<String> _selectedMaterials = <String>{};

  int? _selectedCenterId;
  int? _expandedCenterId;

  @override
  void initState() {
    super.initState();
    _loadCenters().then((_) => _locateUser(silent: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadCenters() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> response = await _supabase
          .from('recycling_centers')
          .select('''
            id,
            slug,
            name,
            address,
            colony,
            latitude,
            longitude,
            phone,
            opening_hours,
            open_now,
            rating,
            recycling_center_materials (
              recycling_materials (
                name
              )
            )
          ''')
          .eq('active', true)
          .order('name');

      final List<RecyclingCenter> loadedCenters = response
          .map(
            (dynamic row) => RecyclingCenter.fromJson(
              Map<String, dynamic>.from(row as Map),
              userLocation: _userLocation,
            ),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _centers = loadedCenters;
        _isLoading = false;

        if (_expandedCenterId == null && loadedCenters.isNotEmpty) {
          _expandedCenterId = loadedCenters.first.id;
        }
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  List<String> get _availableMaterials =>
      RecyclingFilters.availableMaterials(_centers);

  List<RecyclingCenter> get _filteredCenters => RecyclingFilters.apply(
    _centers,
    query: _searchController.text,
    openNowOnly: _openNowOnly,
    maxDistance: _maxDistance,
    materials: _selectedMaterials,
    sortBy: _sortBy,
  );

  int get _activeFilterCount {
    int count = 0;

    if (_openNowOnly) {
      count++;
    }

    count += _selectedMaterials.length;

    if (_maxDistance < maxDistanceFilterKm) {
      count++;
    }

    if (_sortBy != 'nearest') {
      count++;
    }

    return count;
  }

  Future<void> _locateUser({bool silent = false}) async {
    try {
      final GeoPoint location = await const LocationService()
          .getCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _userLocation = location;
        _usingRealLocation = true;
        _centers = _centers
            .map((center) => center.withDistanceFrom(location))
            .toList();
      });

      _mapController.move(LatLng(location.latitude, location.longitude), 13);
    } on LocationException catch (error) {
      if (mounted && !silent) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted && !silent) {
        _showMessage('No pudimos obtener tu ubicación.');
      }
    }
  }

  Future<void> _openDirections(RecyclingCenter center) async {
    final Uri uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
      'api': '1',
      'destination': '${center.latitude},${center.longitude}',
    });

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      _showMessage('No se pudo abrir el mapa.');
    }
  }

  Future<void> _callCenter(RecyclingCenter center) async {
    final String digits = center.phone!.replaceAll(RegExp(r'[^0-9+]'), '');
    final bool opened = await launchUrl(Uri(scheme: 'tel', path: digits));

    if (!opened && mounted) {
      _showMessage('Teléfono: ${center.phone}');
    }
  }

  Future<void> _openFilters() async {
    final FilterSelection? result = await showModalBottomSheet<FilterSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool tempOpenNow = _openNowOnly;
        String tempSortBy = _sortBy;
        double tempMaxDistance = _maxDistance;
        Set<String> tempMaterials = Set<String>.from(_selectedMaterials);

        return StatefulBuilder(
          builder: (context, setModalState) {
            int previewCount() {
              return _centers.where((center) {
                final bool matchesOpen = !tempOpenNow || center.isOpen;
                final bool matchesDistance =
                    center.distanceKm <= tempMaxDistance;
                final bool matchesMaterials =
                    tempMaterials.isEmpty ||
                    center.materials.any(tempMaterials.contains);

                return matchesOpen && matchesDistance && matchesMaterials;
              }).length;
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.86,
              minChildSize: 0.60,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Filtrar centros',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                          children: [
                            _sectionTitle('Materiales aceptados'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: _availableMaterials.map((material) {
                                final bool selected = tempMaterials.contains(
                                  material,
                                );

                                return FilterChip(
                                  label: Text(material),
                                  selected: selected,
                                  showCheckmark: true,
                                  checkmarkColor: Colors.white,
                                  selectedColor: AppColors.primaryGreen,
                                  backgroundColor: AppColors.background,
                                  side: BorderSide(
                                    color: selected
                                        ? AppColors.primaryGreen
                                        : AppColors.border,
                                  ),
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  onSelected: (value) {
                                    setModalState(() {
                                      if (value) {
                                        tempMaterials.add(material);
                                      } else {
                                        tempMaterials.remove(material);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 25),
                            Row(
                              children: [
                                Expanded(
                                  child: _sectionTitle('Distancia máxima'),
                                ),
                                Text(
                                  _distanceLabel(tempMaxDistance),
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: tempMaxDistance,
                              min: 1,
                              max: maxDistanceFilterKm,
                              divisions: 9,
                              activeColor: AppColors.primaryGreen,
                              label: _distanceLabel(tempMaxDistance),
                              onChanged: (value) {
                                setModalState(() {
                                  tempMaxDistance = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            _sectionTitle('Disponibilidad'),
                            SwitchListTile.adaptive(
                              value: tempOpenNow,
                              activeThumbColor: AppColors.primaryGreen,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Abiertos ahora'),
                              onChanged: (value) {
                                setModalState(() {
                                  tempOpenNow = value;
                                });
                              },
                            ),
                            const SizedBox(height: 18),
                            _sectionTitle('Ordenar resultados'),
                            const SizedBox(height: 10),
                            _sortOption(
                              title: 'Más cercanos',
                              value: 'nearest',
                              selectedValue: tempSortBy,
                              onTap: () {
                                setModalState(() {
                                  tempSortBy = 'nearest';
                                });
                              },
                            ),
                            _sortOption(
                              title: 'Mejor calificados',
                              value: 'rating',
                              selectedValue: tempSortBy,
                              onTap: () {
                                setModalState(() {
                                  tempSortBy = 'rating';
                                });
                              },
                            ),
                            _sortOption(
                              title: 'Cierran más tarde',
                              value: 'closing',
                              selectedValue: tempSortBy,
                              onTap: () {
                                setModalState(() {
                                  tempSortBy = 'closing';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 13, 20, 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setModalState(() {
                                    tempOpenNow = false;
                                    tempSortBy = 'nearest';
                                    tempMaxDistance = maxDistanceFilterKm;
                                    tempMaterials.clear();
                                  });
                                },
                                child: const Text('Limpiar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: () {
                                  Navigator.pop(
                                    sheetContext,
                                    FilterSelection(
                                      openNowOnly: tempOpenNow,
                                      sortBy: tempSortBy,
                                      maxDistance: tempMaxDistance,
                                      materials: tempMaterials,
                                    ),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                ),
                                child: Text(
                                  'Mostrar ${previewCount()} centros',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _openNowOnly = result.openNowOnly;
      _sortBy = result.sortBy;
      _maxDistance = result.maxDistance;
      _selectedMaterials = result.materials;
    });
  }

  String _distanceLabel(double distance) {
    if (distance >= maxDistanceFilterKm) {
      return 'Sin límite';
    }

    return '${distance.toStringAsFixed(0)} km';
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _sortOption({
    required String title,
    required String value,
    required String selectedValue,
    required VoidCallback onTap,
  }) {
    final bool selected = value == selectedValue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightGreen : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _openNowOnly = false;
      _sortBy = 'nearest';
      _maxDistance = maxDistanceFilterKm;
      _selectedMaterials.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.darkGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<RecyclingCenter> centers = _filteredCenters;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCenters,
          color: AppColors.primaryGreen,
          child: _isLoading
              ? const _LoadingView()
              : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _loadCenters)
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopSection(centers.length)),
                    SliverToBoxAdapter(child: _buildMap(centers)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 105),
                      sliver: centers.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final RecyclingCenter center = centers[index];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildCenterCard(center),
                                );
                              }, childCount: centers.length),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTopSection(int resultCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 12),
      child: Column(
        children: [
          Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Centros de Reciclaje',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _usingRealLocation
                          ? 'Cerca de ti · $resultCount encontrados'
                          : 'Cuajimalpa, CDMX · $resultCount encontrados',
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
          const SizedBox(height: 13),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar centro, colonia o material',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: _openNowOnly,
                  label: const Text('Abiertos ahora'),
                  selectedColor: AppColors.primaryGreen,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _openNowOnly ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (value) {
                    setState(() {
                      _openNowOnly = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  selected: _sortBy == 'nearest',
                  label: const Text('Más cercanos'),
                  selectedColor: AppColors.primaryGreen,
                  labelStyle: TextStyle(
                    color: _sortBy == 'nearest'
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _sortBy = 'nearest';
                    });
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  onPressed: _openFilters,
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Filtros'),
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_activeFilterCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(List<RecyclingCenter> centers) {
    final RecyclingCenter? selectedCenter = _selectedCenterId == null
        ? null
        : centers.cast<RecyclingCenter?>().firstWhere(
            (center) => center?.id == _selectedCenterId,
            orElse: () => null,
          );

    return SizedBox(
      height: 215,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                _userLocation.latitude,
                _userLocation.longitude,
              ),
              initialZoom: 13,
              onTap: (_, _) {
                if (_selectedCenterId != null) {
                  setState(() {
                    _selectedCenterId = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecocuajimalpa',
              ),
              MarkerLayer(
                markers: [
                  ...centers.map((center) {
                    final bool selected = center.id == _selectedCenterId;

                    return Marker(
                      point: LatLng(center.latitude, center.longitude),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCenterId = selected ? null : center.id;
                          });
                        },
                        child: Center(
                          child: _MapMarker(
                            isSelected: selected,
                            isOpen: center.isOpen,
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_usingRealLocation)
                    Marker(
                      point: LatLng(
                        _userLocation.latitude,
                        _userLocation.longitude,
                      ),
                      width: 45,
                      height: 45,
                      child: const _CurrentLocationMarker(),
                    ),
                ],
              ),
            ],
          ),
          if (selectedCenter != null)
            Positioned(
              top: 10,
              left: 70,
              right: 22,
              child: _MapInfoCard(
                center: selectedCenter,
                onClose: () {
                  setState(() {
                    _selectedCenterId = null;
                  });
                },
              ),
            ),
          Positioned(
            right: 11,
            bottom: 38,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                tooltip: 'Usar mi ubicación',
                onPressed: () => _locateUser(),
                icon: Icon(
                  _usingRealLocation
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
          Positioned(
            right: 11,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '© Colaboradores de OpenStreetMap',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterCard(RecyclingCenter center) {
    final bool expanded = _expandedCenterId == center.id;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedCenterId = expanded ? null : center.id;
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _statusBadge(center.isOpen),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB02E),
                    size: 17,
                  ),
                  Text(
                    center.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Color(0xFFFF9D00),
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  _distanceBadge(center.distanceKm),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      center.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.chevron_right_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                center.address,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      center.openingHours,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 13),
                const Divider(color: AppColors.border),
                const SizedBox(height: 10),
                const Text(
                  'Materiales aceptados:',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: center.materials.map((material) {
                    return Chip(
                      label: Text(material),
                      backgroundColor: const Color(0xFFF0FFF7),
                      side: const BorderSide(color: Color(0xFF7CE8B2)),
                      labelStyle: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 10.5,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          _openDirections(center);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('Cómo llegar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: center.phone == null
                            ? null
                            : () {
                                _callCenter(center);
                              },
                        icon: const Icon(Icons.phone_outlined),
                        label: const Text('Llamar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFF0FFF7) : const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? const Color(0xFF7CE8B2) : const Color(0xFFFFB4B4),
        ),
      ),
      child: Text(
        isOpen ? 'Abierto' : 'Cerrado',
        style: TextStyle(
          color: isOpen ? AppColors.primaryGreen : Colors.red,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _distanceBadge(double distance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF83E9B5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.near_me_outlined,
            color: AppColors.primaryGreen,
            size: 15,
          ),
          const SizedBox(width: 4),
          Text(
            '${distance.toStringAsFixed(1)} km',
            style: const TextStyle(
              color: AppColors.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: AppColors.textSecondary,
            size: 54,
          ),
          const SizedBox(height: 13),
          const Text(
            'No encontramos centros',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Cambia la búsqueda, la distancia o los materiales.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _clearFilters,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}

class _MapInfoCard extends StatelessWidget {
  const _MapInfoCard({required this.center, required this.onClose});

  final RecyclingCenter center;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF7CE8B2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  center.isOpen ? '● Abierto' : '● Cerrado',
                  style: TextStyle(
                    color: center.isOpen ? AppColors.primaryGreen : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  center.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${center.distanceKm.toStringAsFixed(1)} km de ti',
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  center.openingHours,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.isSelected, required this.isOpen});

  final bool isSelected;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: isSelected ? 43 : 35,
      height: isSelected ? 43 : 35,
      decoration: BoxDecoration(
        color: isOpen ? AppColors.primaryGreen : const Color(0xFF9FA7AC),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 19),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.20),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: const Color(0xFF4D8DFF),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primaryGreen),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(
          Icons.cloud_off_rounded,
          color: AppColors.textSecondary,
          size: 64,
        ),
        const SizedBox(height: 15),
        const Text(
          'No se pudieron cargar los centros',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
