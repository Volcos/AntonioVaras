import 'dart:async';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Completer<LatLng>? _locationCompleter;
  static LatLng? _lastKnownLocation;
  static final Map<String, String?> _addressCache = {};
  static final Map<String, Future<String?>> _addressRequests = {};

  static LatLng? get lastKnownLocation => _lastKnownLocation;

  static const LocationEnginePlatforms androidLocationSettings =
      LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        interval: 3000,
        displacement: 5,
      );

  static Future<bool> solicitarPermisoUbicacion() async {
    final status = await Permission.locationWhenInUse.request();

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    return status.isGranted;
  }

  static void registrarActualizacion(UserLocation location) {
    _lastKnownLocation = location.position;

    final completer = _locationCompleter;
    if (completer == null || completer.isCompleted) return;

    completer.complete(location.position);
    _locationCompleter = null;
  }

  static Future<LatLng?> obtenerUbicacionActual(
    MapLibreMapController controller,
  ) async {
    _locationCompleter = Completer<LatLng>();

    try {
      await controller.updateMyLocationTrackingMode(
        MyLocationTrackingMode.tracking,
      );

      return await _locationCompleter!.future.timeout(
        const Duration(seconds: 8),
      );
    } on TimeoutException {
      return null;
    } finally {
      _locationCompleter = null;
      await controller.updateMyLocationTrackingMode(
        MyLocationTrackingMode.none,
      );
    }
  }

  static Future<String?> obtenerDireccion(
    String? latStr,
    String? lngStr,
  ) async {
    if (latStr == null || lngStr == null || latStr.isEmpty || lngStr.isEmpty) {
      return null;
    }

    final cacheKey = '$latStr,$lngStr';
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey];
    }

    final pendingRequest = _addressRequests[cacheKey];
    if (pendingRequest != null) return pendingRequest;

    final request = _obtenerDireccionSinCache(latStr, lngStr);
    _addressRequests[cacheKey] = request;

    try {
      final address = await request;
      _addressCache[cacheKey] = address;
      return address;
    } finally {
      _addressRequests.remove(cacheKey);
    }
  }

  static Future<String?> _obtenerDireccionSinCache(
    String latStr,
    String lngStr,
  ) async {
    try {
      double lat = double.tryParse(latStr) ?? 0.0;
      double lng = double.tryParse(lngStr) ?? 0.0;

      if (lat == 0.0 && lng == 0.0) return null;

      final placemarks = await geo.Geocoding().placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isNotEmpty) {
        geo.Placemark place = placemarks[0];

        // Armar el String
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
      return null;
    } catch (e) {
      return null; // Si falla, regresamos null para usar el fallback
    }
  }
  // Convierte un texto (ej: "Plaza Ñuñoa, Santiago") en Coordenadas (LatLng)
  static Future<LatLng?> obtenerCoordenadasPorTexto(String direccion) async {
    try {
      if (direccion.isEmpty) return null;

      final String normalized = direccion.trim().toLowerCase();

      // Diccionario de lugares conocidos en Santiago
      final Map<String, LatLng> venuesConocidos = {
        'movistar arena': const LatLng(-33.4578, -70.6598),
        'estadio nacional': const LatLng(-33.4651, -70.6127),
        'estadio nacional julio martínez prádanos': const LatLng(-33.4651, -70.6127),
        'teatro caupolicán': const LatLng(-33.4552, -70.6521),
        'estadio monumental': const LatLng(-33.5078, -70.6105),
        'hipódromo chile': const LatLng(-33.4131, -70.6653),
        'parque o\'higgins': const LatLng(-33.4578, -70.6598),
        'espacio riesco': const LatLng(-33.3744, -70.6289),
        'centro cultural gam': const LatLng(-33.4437, -70.6443),
        'gam': const LatLng(-33.4437, -70.6443),
        'estadio bicentenario': const LatLng(-33.5283, -70.5975),
        'estadio bicentenario de la florida': const LatLng(-33.5283, -70.5975),
        'teatro teletón': const LatLng(-33.4489, -70.6655),
        'blondie': const LatLng(-33.4512, -70.6611),
        'arena santiago': const LatLng(-33.4578, -70.6598),
      };

      for (var entry in venuesConocidos.entries) {
        if (normalized.contains(entry.key)) {
          return entry.value;
        }
      }

      // Usar la instancia de Geocoding() para invocar el metodo
      try {
        List<geo.Location> ubicaciones = await geo.Geocoding().locationFromAddress(direccion);
        if (ubicaciones.isNotEmpty) {
          geo.Location ubicacion = ubicaciones.first;
          return LatLng(ubicacion.latitude, ubicacion.longitude);
        }
      } catch (_) {}

      // Intentar agregando ", Santiago, Chile"
      try {
        List<geo.Location> ubicaciones = await geo.Geocoding().locationFromAddress('$direccion, Santiago, Chile');
        if (ubicaciones.isNotEmpty) {
          geo.Location ubicacion = ubicaciones.first;
          return LatLng(ubicacion.latitude, ubicacion.longitude);
        }
      } catch (_) {}

    } catch (e) {
      print("No se encontraron coordenadas para: $direccion. Error: $e");
    }
    return null;
  }

}
