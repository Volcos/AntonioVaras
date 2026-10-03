import 'dart:async';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Completer<LatLng>? _locationCompleter;

  static const LocationEnginePlatforms androidLocationSettings =
      LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        interval: 1000,
        displacement: 0,
      );

  static Future<bool> solicitarPermisoUbicacion() async {
    final status = await Permission.locationWhenInUse.request();

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }

    return status.isGranted;
  }

  static void registrarActualizacion(UserLocation location) {
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
}
