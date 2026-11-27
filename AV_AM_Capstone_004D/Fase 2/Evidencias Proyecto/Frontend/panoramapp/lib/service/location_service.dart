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
    // Renca y Sector Norte
    'plaza de renca': AddressSuggestion(
      displayName: 'Plaza de Renca, Renca, Santiago, Chile',
      latitude: -33.4050667,
      longitude: -70.7039275,
      comuna: 'Renca',
    ),
    'plaza renca': AddressSuggestion(
      displayName: 'Plaza de Renca, Renca, Santiago, Chile',
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
    'municipalidad de renca': AddressSuggestion(
      displayName: 'Municipalidad de Renca, Renca, Santiago, Chile',
      latitude: -33.4045,
      longitude: -70.7042,
      comuna: 'Renca',
    ),
    'espacio riesco': AddressSuggestion(
      displayName: 'Espacio Riesco, Huechuraba, Santiago, Chile',
      latitude: -33.3744,
      longitude: -70.6289,
      comuna: 'Huechuraba',
    ),
    'hipodromo chile': AddressSuggestion(
      displayName: 'Hipódromo Chile, Independencia, Santiago, Chile',
      latitude: -33.4131,
      longitude: -70.6653,
      comuna: 'Independencia',
    ),

    // Santiago Centro y Santiago Poniente
    'movistar arena': AddressSuggestion(
      displayName: 'Movistar Arena, Parque O\'Higgins, Santiago, Chile',
      latitude: -33.4578,
      longitude: -70.6598,
      comuna: 'Santiago',
    ),
    'parque o\'higgins': AddressSuggestion(
      displayName: 'Parque O\'Higgins, Santiago, Chile',
      latitude: -33.4578,
      longitude: -70.6598,
      comuna: 'Santiago',
    ),
    'plaza de armas': AddressSuggestion(
      displayName: 'Plaza de Armas, Santiago, Chile',
      latitude: -33.4378,
      longitude: -70.6504,
      comuna: 'Santiago',
    ),
    'teatro caupolican': AddressSuggestion(
      displayName: 'Teatro Caupolicán, San Diego 850, Santiago, Chile',
      latitude: -33.4552,
      longitude: -70.6521,
      comuna: 'Santiago',
    ),
    'centro cultural gam': AddressSuggestion(
      displayName: 'Centro Cultural GAM, Alameda 227, Santiago, Chile',
      latitude: -33.4437,
      longitude: -70.6443,
      comuna: 'Santiago',
    ),
    'gam': AddressSuggestion(
      displayName: 'Centro Cultural GAM, Alameda 227, Santiago, Chile',
      latitude: -33.4437,
      longitude: -70.6443,
      comuna: 'Santiago',
    ),
    'teatro teleton': AddressSuggestion(
      displayName: 'Teatro Teletón, Rosas 1531, Santiago, Chile',
      latitude: -33.4489,
      longitude: -70.6655,
      comuna: 'Santiago',
    ),
    'teatro municipal de santiago': AddressSuggestion(
      displayName: 'Teatro Municipal de Santiago, Agustinas 794, Santiago, Chile',
      latitude: -33.4414,
      longitude: -70.6473,
      comuna: 'Santiago',
    ),
    'centro cultural la moneda': AddressSuggestion(
      displayName: 'Centro Cultural La Moneda, Santiago, Chile',
      latitude: -33.4431,
      longitude: -70.6539,
      comuna: 'Santiago',
    ),
    'estacion mapocho': AddressSuggestion(
      displayName: 'Centro Cultural Estación Mapocho, Santiago, Chile',
      latitude: -33.4331,
      longitude: -70.6548,
      comuna: 'Santiago',
    ),
    'parque quinta normal': AddressSuggestion(
      displayName: 'Parque Quinta Normal, Matucana 520, Santiago, Chile',
      latitude: -33.4432,
      longitude: -70.6811,
      comuna: 'Santiago',
    ),
    'matucana 100': AddressSuggestion(
      displayName: 'Centro Cultural Matucana 100, Estación Central, Santiago, Chile',
      latitude: -33.4452,
      longitude: -70.6787,
      comuna: 'Estación Central',
    ),
    'blondie': AddressSuggestion(
      displayName: 'Discotheque Blondie, Alameda 2879, Estación Central, Santiago, Chile',
      latitude: -33.4512,
      longitude: -70.6611,
      comuna: 'Estación Central',
    ),
    'club hipico': AddressSuggestion(
      displayName: 'Club Hípico de Santiago, Blanco Encalada 2540, Santiago, Chile',
      latitude: -33.4633,
      longitude: -70.6698,
      comuna: 'Santiago',
    ),

    // Sector Oriente y Ñuñoa
    'estadio nacional': AddressSuggestion(
      displayName: 'Estadio Nacional Julio Martínez Prádanos, Ñuñoa, Santiago, Chile',
      latitude: -33.4651,
      longitude: -70.6127,
      comuna: 'Ñuñoa',
    ),
    'plaza nuñoa': AddressSuggestion(
      displayName: 'Plaza Ñuñoa, Ñuñoa, Santiago, Chile',
      latitude: -33.4563,
      longitude: -70.5985,
      comuna: 'Ñuñoa',
    ),
    'plaza italia': AddressSuggestion(
      displayName: 'Plaza Baquedano (Plaza Italia), Providencia, Santiago, Chile',
      latitude: -33.4370,
      longitude: -70.6346,
      comuna: 'Providencia',
    ),
    'teatro nescafe de las artes': AddressSuggestion(
      displayName: 'Teatro Nescafé de las Artes, Manuel Montt 032, Providencia, Santiago, Chile',
      latitude: -33.4357,
      longitude: -70.6226,
      comuna: 'Providencia',
    ),
    'parque bicentenario vitacura': AddressSuggestion(
      displayName: 'Parque Bicentenario, Vitacura, Santiago, Chile',
      latitude: -33.4025,
      longitude: -70.5986,
      comuna: 'Vitacura',
    ),
    'parque araucano': AddressSuggestion(
      displayName: 'Parque Araucano, Presidente Riesco 5698, Las Condes, Santiago, Chile',
      latitude: -33.4022,
      longitude: -70.5706,
      comuna: 'Las Condes',
    ),
    'san carlos de apoquindo': AddressSuggestion(
      displayName: 'Estadio San Carlos de Apoquindo (Claro Arena), Las Condes, Santiago, Chile',
      latitude: -33.3956,
      longitude: -70.5002,
      comuna: 'Las Condes',
    ),

    // Sector Sur / Cordillera
    'estadio monumental': AddressSuggestion(
      displayName: 'Estadio Monumental David Arellano, Macul, Santiago, Chile',
      latitude: -33.5078,
      longitude: -70.6105,
      comuna: 'Macul',
    ),
    'estadio bicentenario la florida': AddressSuggestion(
      displayName: 'Estadio Bicentenario de La Florida, La Florida, Santiago, Chile',
      latitude: -33.5283,
      longitude: -70.5975,
      comuna: 'La Florida',
    ),
    'plaza de maipu': AddressSuggestion(
      displayName: 'Plaza de Maipú, Maipú, Santiago, Chile',
      latitude: -33.5109,
      longitude: -70.7573,
      comuna: 'Maipú',
    ),
    'plaza de puente alto': AddressSuggestion(
      displayName: 'Plaza de Puente Alto, Puente Alto, Santiago, Chile',
      latitude: -33.6117,
      longitude: -70.5758,
      comuna: 'Puente Alto',
    ),

    // Regiones
    'quinta vergara': AddressSuggestion(
      displayName: 'Quinta Vergara, Viña del Mar, Región de Valparaíso, Chile',
      latitude: -33.0289,
      longitude: -71.5528,
      comuna: 'Viña del Mar',
    ),
    'estadio sausalito': AddressSuggestion(
      displayName: 'Estadio Sausalito, Viña del Mar, Región de Valparaíso, Chile',
      latitude: -33.0136,
      longitude: -71.5428,
      comuna: 'Viña del Mar',
    ),
    'estadio ester roa': AddressSuggestion(
      displayName: 'Estadio Ester Roa Rebolledo, Concepción, Chile',
      latitude: -36.8153,
      longitude: -73.0264,
      comuna: 'Concepción',
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

    final double? lat = double.tryParse(latStr);
    final double? lng = double.tryParse(lngStr);
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) return null;

    final cacheKey = '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey];
    }

    final pendingRequest = _addressRequests[cacheKey];
    if (pendingRequest != null) return pendingRequest;

    final request = _obtenerDireccionSinCache(lat, lng);
    _addressRequests[cacheKey] = request;

    try {
      final address = await request;
      if (address != null && address.isNotEmpty) {
        _addressCache[cacheKey] = address;
      }
      return address;
    } finally {
      _addressRequests.remove(cacheKey);
    }
  }

  static Future<String?> _obtenerDireccionSinCache(
    double lat,
    double lng,
  ) async {
    // 1. Intentar Geocodificación inversa precisa vía HTTP con OpenStreetMap (Nominatim)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=es',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'PanoramAPP/1.0 (event address search)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          // Extraer únicamente calles / vías reales (sin fallback a la comuna)
          final String? roadName = address['road']?.toString() ??
              address['street']?.toString() ??
              address['pedestrian']?.toString() ??
              address['footway']?.toString() ??
              address['path']?.toString() ??
              address['residential']?.toString() ??
              address['highway']?.toString() ??
              address['square']?.toString() ??
              address['amenity']?.toString() ??
              address['building']?.toString();

          final String houseNumber = address['house_number']?.toString() ?? '';

          // Extraer la comuna o localidad
          final String? comunaName = address['suburb']?.toString() ??
              address['city_district']?.toString() ??
              address['town']?.toString() ??
              address['city']?.toString() ??
              address['county']?.toString();

          List<String> parts = [];

          if (roadName != null && roadName.isNotEmpty) {
            final streetStr = houseNumber.isNotEmpty ? '$roadName $houseNumber' : roadName;
            parts.add(streetStr);
          }

          if (comunaName != null && comunaName.isNotEmpty) {
            // Prevenir duplicados (ej: evitar "Renca, Renca")
            if (parts.isEmpty || parts.last.toLowerCase() != comunaName.toLowerCase()) {
              parts.add(comunaName);
            }
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }

          if (data['display_name'] != null) {
            final rawDisplay = data['display_name'].toString();
            final displaySet = <String>{};
            for (final item in rawDisplay.split(',')) {
              final trimmed = item.trim();
              if (trimmed.isNotEmpty) displaySet.add(trimmed);
            }
            return displaySet.take(2).join(', ');
          }
        }
      }
    } catch (_) {}

    // 2. Respaldo con plugin nativo
    try {
      final placemarks = await geo.Geocoding().placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isNotEmpty) {
        geo.Placemark place = placemarks[0];
        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        final subLoc = (place.subLocality != null && place.subLocality!.isNotEmpty)
            ? place.subLocality
            : place.locality;
        if (subLoc != null && subLoc.isNotEmpty) {
          if (addressParts.isEmpty || addressParts.last.toLowerCase() != subLoc.toLowerCase()) {
            addressParts.add(subLoc);
          }
        }

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
    } catch (_) {}

    return null;
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
    final centerLat = _lastKnownLocation?.latitude ?? -33.4489;
    final centerLng = _lastKnownLocation?.longitude ?? -70.6693;

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
        'lat': centerLat.toString(),
        'lon': centerLng.toString(),
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
    final centerLat = _lastKnownLocation?.latitude ?? -33.4489;
    final centerLng = _lastKnownLocation?.longitude ?? -70.6693;

    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': '$query, Santiago, Chile',
      'lat': centerLat.toString(),
      'lon': centerLng.toString(),
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
