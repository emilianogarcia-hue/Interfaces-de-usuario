import 'package:ecocuajimalpa/core/services/location_service.dart';
import 'package:ecocuajimalpa/features/recycling/data/recycling_center.dart';
import 'package:flutter_test/flutter_test.dart';

RecyclingCenter center({
  required int id,
  required String name,
  double distanceKm = 1,
  bool isOpen = true,
  double rating = 4,
  String openingHours = 'Lun-Vie 08:00-17:00',
  List<String> materials = const <String>['Plástico'],
  String colony = 'Cuajimalpa Centro',
}) {
  return RecyclingCenter(
    id: id,
    slug: 'centro-$id',
    name: name,
    address: 'Calle $id',
    colony: colony,
    latitude: 19.35,
    longitude: -99.29,
    phone: null,
    openingHours: openingHours,
    isOpen: isOpen,
    rating: rating,
    materials: materials,
    distanceKm: distanceKm,
  );
}

void main() {
  group('RecyclingCenter.fromJson', () {
    test('lee materiales anidados y calcula la distancia', () {
      final RecyclingCenter parsed = RecyclingCenter.fromJson(<String, dynamic>{
        'id': 7,
        'slug': 'punto-limpio',
        'name': 'Punto Limpio',
        'address': 'Av. Juárez 1',
        'colony': 'Cuajimalpa Centro',
        'latitude': '19.3653',
        'longitude': -99.2962,
        'phone': '55 1234 5678',
        'opening_hours': 'Lun-Sáb 09:00-18:30',
        'open_now': true,
        'rating': '4.5',
        'recycling_center_materials': <dynamic>[
          <String, dynamic>{
            'recycling_materials': <String, dynamic>{'name': 'Vidrio'},
          },
          <String, dynamic>{
            'recycling_materials': <String, dynamic>{'name': 'Cartón'},
          },
          <String, dynamic>{'recycling_materials': null},
        ],
      }, userLocation: LocationService.cuajimalpaCenter);

      expect(parsed.id, 7);
      expect(parsed.rating, 4.5);
      expect(parsed.materials, <String>['Cartón', 'Vidrio']);
      // 0.01° de latitud son ~1.11 km.
      expect(parsed.distanceKm, closeTo(1.11, 0.01));
      expect(parsed.closingHour, 18.5);
    });
  });

  test('distanceBetween da 0 para el mismo punto', () {
    expect(RecyclingCenter.distanceBetween(19.35, -99.29, 19.35, -99.29), 0);
  });

  test('withDistanceFrom recalcula la distancia', () {
    final RecyclingCenter moved = center(
      id: 1,
      name: 'A',
      distanceKm: 99,
    ).withDistanceFrom(const GeoPoint(19.35, -99.29));

    expect(moved.distanceKm, closeTo(0, 0.001));
    expect(moved.name, 'A');
  });

  group('RecyclingFilters.apply', () {
    final List<RecyclingCenter> centers = <RecyclingCenter>[
      center(
        id: 1,
        name: 'Lejano',
        distanceKm: 8,
        rating: 5,
        materials: <String>['Vidrio'],
      ),
      center(
        id: 2,
        name: 'Cercano',
        distanceKm: 0.5,
        rating: 3,
        isOpen: false,
        openingHours: 'Lun-Vie 08:00-20:00',
      ),
      center(
        id: 3,
        name: 'Medio',
        distanceKm: 3,
        rating: 4,
        materials: <String>['Pilas', 'Plástico'],
        colony: 'Santa Fe',
      ),
    ];

    List<String> names(List<RecyclingCenter> list) =>
        list.map((item) => item.name).toList();

    test('ordena por cercanía por defecto', () {
      expect(names(RecyclingFilters.apply(centers)), <String>[
        'Cercano',
        'Medio',
        'Lejano',
      ]);
    });

    test('ordena por calificación y por hora de cierre', () {
      expect(names(RecyclingFilters.apply(centers, sortBy: 'rating')), <String>[
        'Lejano',
        'Medio',
        'Cercano',
      ]);
      expect(
        names(RecyclingFilters.apply(centers, sortBy: 'closing')).first,
        'Cercano',
      );
    });

    test('busca por nombre, colonia o material sin importar mayúsculas', () {
      expect(names(RecyclingFilters.apply(centers, query: 'santa')), <String>[
        'Medio',
      ]);
      expect(names(RecyclingFilters.apply(centers, query: 'VIDRIO')), <String>[
        'Lejano',
      ]);
    });

    test('filtra abiertos ahora y materiales', () {
      expect(
        names(RecyclingFilters.apply(centers, openNowOnly: true)),
        <String>['Medio', 'Lejano'],
      );
      expect(
        names(RecyclingFilters.apply(centers, materials: <String>{'Pilas'})),
        <String>['Medio'],
      );
    });

    test('la distancia máxima solo limita por debajo del tope', () {
      expect(names(RecyclingFilters.apply(centers, maxDistance: 3)), <String>[
        'Cercano',
        'Medio',
      ]);

      final List<RecyclingCenter> far = <RecyclingCenter>[
        center(id: 9, name: 'Muy lejano', distanceKm: 40),
      ];
      expect(RecyclingFilters.apply(far), hasLength(1));
    });

    test('availableMaterials devuelve materiales únicos ordenados', () {
      expect(RecyclingFilters.availableMaterials(centers), <String>[
        'Pilas',
        'Plástico',
        'Vidrio',
      ]);
    });
  });
}
