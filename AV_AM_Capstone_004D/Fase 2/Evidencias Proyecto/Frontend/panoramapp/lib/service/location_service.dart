import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';

class AddressSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String? comuna;

  const AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.comuna,
  });
}

class LocationService {
  static const Map<String, AddressSuggestion> _lugaresConocidos = {
    'plaza de renca': AddressSuggestion(
      displayName: 'Plaza Renca, Renca, Santiago, Chile',
      latitude: -33.4050667,
      longitude: -70.7039275,
      comuna: 'Renca',
    ),
    'plaza renca': AddressSuggestion(
      displayName: 'Plaza Renca, Renca, Santiago, Chile',
      latitude: -33.4050667,
      longitude: -70.7039275,
      comuna: 'Renca',
    ),
    'plaza del encuentro renca': AddressSuggestion(
      displayName: 'Plaza del Encuentro, Renca, Santiago, Chile',
      latitude: -33.4042655,
      longitude: -70.7807345,
      comuna: 'Renca',
    ),
  };
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
        'plaza de renca': const LatLng(-33.4050667, -70.7039275),
        'plaza renca': const LatLng(-33.4050667, -70.7039275),
        'plaza del encuentro': const LatLng(-33.4042655, -70.7807345),
        'movistar arena': const LatLng(-33.4578, -70.6598),
        'estadio nacional': const LatLng(-33.4651, -70.6127),
        'estadio nacional julio martínez prádanos': const LatLng(
          -33.4651,
          -70.6127,
        ),
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
        List<geo.Location> ubicaciones = await geo.Geocoding()
            .locationFromAddress(direccion);
        if (ubicaciones.isNotEmpty) {
          geo.Location ubicacion = ubicaciones.first;
          return LatLng(ubicacion.latitude, ubicacion.longitude);
        }
      } catch (_) {}

      // Intentar agregando ", Santiago, Chile"
      try {
        List<geo.Location> ubicaciones = await geo.Geocoding()
            .locationFromAddress('$direccion, Santiago, Chile');
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

  static Future<List<AddressSuggestion>> buscarDirecciones(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];

    final suggestions = <AddressSuggestion>[];
    final seen = <String>{};
    final normalizedQuery = trimmedQuery.toLowerCase();

    for (final entry in _lugaresConocidos.entries) {
      if (entry.key.contains(normalizedQuery) ||
          normalizedQuery.contains(entry.key)) {
        final suggestion = entry.value;
        final key =
            '${suggestion.displayName}|${suggestion.latitude}|${suggestion.longitude}';
        seen.add(key);
        suggestions.add(suggestion);
      }
    }

    // Nominatim puede interpretar "calle número" como una calle genérica
    // fuera de Santiago. Se prueban variantes con el contexto local para
    // priorizar la dirección que el usuario está buscando.
    final queries = <String>{
      trimmedQuery,
      '$trimmedQuery, Santiago, Chile',
      '${_moveNumberBeforeStreet(trimmedQuery)}, Santiago, Chile',
    };

    for (final searchQuery in queries) {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': searchQuery,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '10',
        'countrycodes': 'cl',
        'dedupe': '1',
      });

      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'PanoramAPP/1.0 (event address search)',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) continue;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) continue;

      for (final item in decoded.whereType<Map<String, dynamic>>()) {
        final latitude = double.tryParse(item['lat']?.toString() ?? '');
        final longitude = double.tryParse(item['lon']?.toString() ?? '');
        final displayName = item['display_name']?.toString().trim() ?? '';
        final address = item['address'] is Map
            ? item['address'] as Map
            : const <String, dynamic>{};
        final comuna = _extractComuna(address);
        final key = '$displayName|$latitude|$longitude';

        if (latitude != null &&
            longitude != null &&
            displayName.isNotEmpty &&
            seen.add(key)) {
          suggestions.add(
            AddressSuggestion(
              displayName: displayName,
              latitude: latitude,
              longitude: longitude,
              comuna: comuna,
            ),
          );
        }
      }
    }

    await _addPhotonSuggestions(trimmedQuery, suggestions, seen);

    suggestions.sort((a, b) {
      final aSantiago = a.displayName.toLowerCase().contains('santiago');
      final bSantiago = b.displayName.toLowerCase().contains('santiago');
      if (aSantiago != bSantiago) return aSantiago ? -1 : 1;

      final aStreet = a.displayName.toLowerCase().contains(
        trimmedQuery.split(RegExp(r'\s+\d')).first.toLowerCase(),
      );
      final bStreet = b.displayName.toLowerCase().contains(
        trimmedQuery.split(RegExp(r'\s+\d')).first.toLowerCase(),
      );
      if (aStreet != bStreet) return aStreet ? -1 : 1;
      return a.displayName.length.compareTo(b.displayName.length);
    });

    return suggestions.take(10).toList();
  }

  static Future<void> _addPhotonSuggestions(
    String query,
    List<AddressSuggestion> suggestions,
    Set<String> seen,
  ) async {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': '$query, Santiago, Chile',
      'limit': '10',
    });

    try {
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'PanoramAPP/1.0 (event address search)',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['features'] is! List) return;

      for (final feature in decoded['features']) {
        if (feature is! Map ||
            feature['geometry'] is! Map ||
            feature['properties'] is! Map) {
          continue;
        }
        final coordinates = feature['geometry']['coordinates'];
        if (coordinates is! List || coordinates.length < 2) continue;

        final longitude = double.tryParse(coordinates[0].toString());
        final latitude = double.tryParse(coordinates[1].toString());
        final properties = feature['properties'] as Map;
        final name = properties['name']?.toString();
        final street = properties['street']?.toString();
        final city = properties['city']?.toString();
        final comuna = _extractComuna(properties);
        final displayName = [
          name,
          street,
          city,
          'Chile',
        ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
        final key = '$displayName|$latitude|$longitude';

        if (latitude != null &&
            longitude != null &&
            displayName.isNotEmpty &&
            seen.add(key)) {
          suggestions.add(
            AddressSuggestion(
              displayName: displayName,
              latitude: latitude,
              longitude: longitude,
              comuna: comuna,
            ),
          );
        }
      }
    } catch (_) {
      // Nominatim remains the primary provider if Photon is unavailable.
    }
  }

  static String _moveNumberBeforeStreet(String value) {
    final match = RegExp(r'^(.+?)\s+(\d+[A-Za-z]?)$').firstMatch(value);
    if (match == null) return value;
    return '${match.group(2)} ${match.group(1)}';
  }

  static String? _extractComuna(Map address) {
    for (final key in [
      'municipality',
      'city_district',
      'district',
      'suburb',
      'town',
      'city',
    ]) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
