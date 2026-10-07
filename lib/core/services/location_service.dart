import 'package:geolocator/geolocator.dart';

/// Punto geográfico simple, independiente del paquete de ubicación.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Obtiene la ubicación del teléfono y traduce los errores a mensajes
/// que se pueden mostrar al usuario.
class LocationService {
  const LocationService();

  /// Centro de la alcaldía Cuajimalpa, usado cuando no hay GPS.
  static const GeoPoint cuajimalpaCenter = GeoPoint(19.3553, -99.2962);

  Future<GeoPoint> getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationException(
        'La ubicación del dispositivo está apagada. Actívala e inténtalo de nuevo.',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationException('No diste permiso para usar tu ubicación.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'El permiso de ubicación está bloqueado. Actívalo desde los ajustes del teléfono.',
      );
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return GeoPoint(position.latitude, position.longitude);
  }
}
