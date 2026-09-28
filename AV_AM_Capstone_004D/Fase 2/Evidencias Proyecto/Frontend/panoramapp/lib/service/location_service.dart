import 'package:geocoding/geocoding.dart' as geo;

class LocationService {
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
