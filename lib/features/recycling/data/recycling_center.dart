import 'dart:math' as math;

import '../../../core/services/location_service.dart';

class RecyclingCenter {
  const RecyclingCenter({
    required this.id,
    required this.slug,
    required this.name,
    required this.address,
    required this.colony,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.openingHours,
    required this.isOpen,
    required this.rating,
    required this.materials,
    this.distanceKm = 0,
  });

  factory RecyclingCenter.fromJson(
    Map<String, dynamic> json, {
    required GeoPoint userLocation,
  }) {
    final double latitude = double.tryParse(json['latitude'].toString()) ?? 0;
    final double longitude = double.tryParse(json['longitude'].toString()) ?? 0;

    final List<String> materials = <String>[];
    final dynamic relationships = json['recycling_center_materials'];

    if (relationships is List) {
      for (final dynamic relationship in relationships) {
        if (relationship is Map) {
          final dynamic material = relationship['recycling_materials'];

          if (material is Map && material['name'] != null) {
            materials.add(material['name'].toString());
          }
        }
      }
    }

    materials.sort();

    return RecyclingCenter(
      id: (json['id'] as num).toInt(),
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      colony: json['colony']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      phone: json['phone']?.toString(),
      openingHours: json['opening_hours']?.toString() ?? '',
      isOpen: json['open_now'] == true,
      rating: double.tryParse(json['rating'].toString()) ?? 0,
      materials: materials,
      distanceKm: distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        latitude,
        longitude,
      ),
    );
  }

  final int id;
  final String slug;
  final String name;
  final String address;
  final String colony;
  final double latitude;
  final double longitude;
  final String? phone;
  final String openingHours;
  final bool isOpen;
  final double rating;
  final List<String> materials;
  final double distanceKm;

  double get closingHour {
    final List<RegExpMatch> matches = RegExp(
      r'(\d{1,2}):(\d{2})',
    ).allMatches(openingHours).toList();

    if (matches.isEmpty) {
      return 0;
    }

    final RegExpMatch last = matches.last;
    final int hour = int.tryParse(last.group(1) ?? '') ?? 0;
    final int minute = int.tryParse(last.group(2) ?? '') ?? 0;

    return hour + (minute / 60);
  }

  /// Copia del centro con la distancia recalculada desde [userLocation].
  RecyclingCenter withDistanceFrom(GeoPoint userLocation) {
    return RecyclingCenter(
      id: id,
      slug: slug,
      name: name,
      address: address,
      colony: colony,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      openingHours: openingHours,
      isOpen: isOpen,
      rating: rating,
      materials: materials,
      distanceKm: distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        latitude,
        longitude,
      ),
    );
  }

  /// Distancia en km entre dos coordenadas (fórmula de Haversine).
  static double distanceBetween(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const double earthRadiusKm = 6371;

    final double latitudeDifference = _degreesToRadians(latitude2 - latitude1);
    final double longitudeDifference = _degreesToRadians(
      longitude2 - longitude1,
    );

    final double a =
        math.sin(latitudeDifference / 2) * math.sin(latitudeDifference / 2) +
        math.cos(_degreesToRadians(latitude1)) *
            math.cos(_degreesToRadians(latitude2)) *
            math.sin(longitudeDifference / 2) *
            math.sin(longitudeDifference / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}

class FilterSelection {
  const FilterSelection({
    required this.openNowOnly,
    required this.sortBy,
    required this.maxDistance,
    required this.materials,
  });

  final bool openNowOnly;
  final String sortBy;
  final double maxDistance;
  final Set<String> materials;
}

/// Distancia máxima del filtro. En este valor el filtro no limita resultados.
const double maxDistanceFilterKm = 10;

class RecyclingFilters {
  RecyclingFilters._();

  /// Materiales distintos aceptados por los centros, en orden alfabético.
  static List<String> availableMaterials(List<RecyclingCenter> centers) {
    final Set<String> materials = <String>{};

    for (final RecyclingCenter center in centers) {
      materials.addAll(center.materials);
    }

    return materials.toList()..sort();
  }

  /// Aplica búsqueda, filtros y orden a la lista de centros.
  static List<RecyclingCenter> apply(
    List<RecyclingCenter> centers, {
    String query = '',
    bool openNowOnly = false,
    double maxDistance = maxDistanceFilterKm,
    Set<String> materials = const <String>{},
    String sortBy = 'nearest',
  }) {
    final String normalizedQuery = query.trim().toLowerCase();

    final List<RecyclingCenter> result = centers.where((center) {
      final bool matchesSearch =
          normalizedQuery.isEmpty ||
          center.name.toLowerCase().contains(normalizedQuery) ||
          center.address.toLowerCase().contains(normalizedQuery) ||
          center.colony.toLowerCase().contains(normalizedQuery) ||
          center.materials.any(
            (material) => material.toLowerCase().contains(normalizedQuery),
          );

      final bool matchesOpen = !openNowOnly || center.isOpen;
      final bool matchesDistance =
          maxDistance >= maxDistanceFilterKm ||
          center.distanceKm <= maxDistance;

      final bool matchesMaterials =
          materials.isEmpty || center.materials.any(materials.contains);

      return matchesSearch &&
          matchesOpen &&
          matchesDistance &&
          matchesMaterials;
    }).toList();

    switch (sortBy) {
      case 'rating':
        result.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'closing':
        result.sort((a, b) => b.closingHour.compareTo(a.closingHour));
        break;
      case 'nearest':
      default:
        result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }

    return result;
  }
}
