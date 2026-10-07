import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_event.dart';

class ApibenjaService {
  static const List<String> _urls = [
    'https://a1b2-c3-d4.ngrok-free.app/eventos', // Pega la URL de Ngrok y agrégale /eventos
    'http://10.155.25.222:3000/eventos',
    'http://10.0.2.2:3000/eventos',
  ];

  static Future<List<ApiEvent>> getEvents() async {
    for (final url in _urls) {
      try {
        final rspta = await http
            .get(
              Uri.parse(url),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 5));

        if (rspta.statusCode == 200) {
          final dynamic rsptaJson = jsonDecode(rspta.body);
          List<dynamic> eventsJson = [];

          if (rsptaJson is List) {
            eventsJson = rsptaJson;
          } else if (rsptaJson is Map<String, dynamic>) {
            if (rsptaJson['value'] is List) {
              eventsJson = rsptaJson['value'];
            } else if (rsptaJson['eventos'] is List) {
              eventsJson = rsptaJson['eventos'];
            } else if (rsptaJson['events'] is List) {
              eventsJson = rsptaJson['events'];
            } else if (rsptaJson['data'] is List) {
              eventsJson = rsptaJson['data'];
            } else if (rsptaJson['items'] is List) {
              eventsJson = rsptaJson['items'];
            } else if (rsptaJson['results'] is List) {
              eventsJson = rsptaJson['results'];
            } else if (rsptaJson['_embedded'] != null &&
                rsptaJson['_embedded']['events'] is List) {
              eventsJson = rsptaJson['_embedded']['events'];
            }
          }

          print('Eventos obtenidos desde API Benja ($url): ${eventsJson.length}');
          return eventsJson
              .whereType<Map<String, dynamic>>()
              .map((e) => _mapToApiEvent(e))
              .toList();
        } else {
          print('Error en la API Benja ($url): ${rspta.statusCode}');
        }
      } catch (e) {
        print('Excepción al consumir API Benja ($url): $e');
      }
    }

    return <ApiEvent>[];
  }

  static ApiEvent _mapToApiEvent(Map<String, dynamic> json) {
    // 1. EXTRAER ID Y NOMBRE
    final id = json['id']?.toString() ?? '';
    final nombre = _asString(
      json['nombre'] ?? json['name'] ?? json['title'],
      fallback: 'Sin nombre',
    );

    // 2. EXTRAER DESCRIPCIÓN
    String description = _asString(
      json['descripcion'] ?? json['description'] ?? json['info'],
    );
    if (description.isEmpty) {
      if (json['classifications'] != null &&
          json['classifications'] is List &&
          json['classifications'].isNotEmpty) {
        var classification = json['classifications'][0];
        String genre = _asString(classification['genre']?['name']);
        String subGenre = _asString(classification['subGenre']?['name']);
        description =
            'Evento de $genre ${subGenre.isNotEmpty ? "($subGenre)" : ""}';
      } else {
        description = 'Sin descripción disponible.';
      }
    }

    // 3. EXTRAER FECHA Y HORA
    String startDate = _asString(
      json['fecha_inicio'] ??
          json['fechaInicio'] ??
          json['date'] ??
          json['fecha'],
    );
    String startTime = _asString(json['hora'] ?? json['time']);

    if (startDate.isEmpty &&
        json['dates'] != null &&
        json['dates']['start'] != null) {
      startDate = _asString(json['dates']['start']['localDate']);
      if (startTime.isEmpty) {
        startTime = _asString(json['dates']['start']['localTime']);
      }
    }

    String endDate = _asString(
      json['fecha_termino'] ?? json['fechaTermino'] ?? '',
    );

    // 4. EXTRAER LOCALIZACIÓN Y COORDENADAS
    String venueName = 'Lugar por confirmar';
    String? lat = json['latitude']?.toString() ?? json['lat']?.toString();
    String? lng =
        json['longitude']?.toString() ??
        json['lng']?.toString() ??
        json['lon']?.toString();

    if (json['localizacion'] != null && json['localizacion'] is String) {
      venueName = json['localizacion'];
    } else if (json['location'] != null && json['location'] is String) {
      venueName = json['location'];
    } else if (json['venue'] != null) {
      if (json['venue'] is String) {
        venueName = json['venue'];
      } else if (json['venue'] is Map) {
        venueName = _asString(
          json['venue']['name'],
          fallback: 'Lugar por confirmar',
        );
        lat ??= json['venue']['latitude']?.toString();
        lng ??= json['venue']['longitude']?.toString();
      }
    } else if (json['_embedded'] != null &&
        json['_embedded']['venues'] != null &&
        json['_embedded']['venues'] is List &&
        json['_embedded']['venues'].isNotEmpty) {
      var venue = json['_embedded']['venues'][0];
      venueName = _asString(
        venue['name'],
        fallback: 'Lugar por confirmar',
      );
      if (venue['location'] != null) {
        lat ??= venue['location']['latitude']?.toString();
        lng ??= venue['location']['longitude']?.toString();
      }
    }

    // 5. EXTRAER IMAGEN
    String imageUrl = _asString(
      json['imagen'] ?? json['image'] ?? json['imageUrl'],
    );

    if (imageUrl.isEmpty &&
        json['images'] != null &&
        json['images'] is List &&
        json['images'].isNotEmpty) {
      var imageList = json['images'] as List;
      var preferredImage = imageList.firstWhere(
        (img) =>
            img is Map &&
            img['ratio'] == '16_9' &&
            img['width'] != null &&
            (img['width'] is num && img['width'] > 600),
        orElse: () => imageList[0],
      );
      if (preferredImage is Map) {
        imageUrl = _asString(preferredImage['url']);
      }
    }

    // 6. EXTRAER FUENTE DE INFORMACIÓN / URL
    final String eventUrl = _asString(
      json['fuente_info'] ?? json['fuenteInfo'] ?? json['url'],
      fallback: 'API Benja',
    );

    // 7. EXTRAER ORGANIZADOR
    String promoter = _asString(json['organizador']);
    if (promoter.isEmpty) {
      if (json['_embedded'] != null &&
          json['_embedded']['attractions'] != null &&
          json['_embedded']['attractions'] is List &&
          json['_embedded']['attractions'].isNotEmpty) {
        promoter = _asString(json['_embedded']['attractions'][0]['name']);
      } else if (json['promoter'] != null && json['promoter'] is Map) {
        promoter = _asString(json['promoter']['name']);
      }
    }

    return ApiEvent(
      id: id,
      nombre: nombre,
      descripcion: description,
      fechaInicio: startDate,
      fechaTermino: endDate,
      hora: startTime,
      localizacion: venueName,
      latitude: lat,
      longitude: lng,
      imagen: imageUrl,
      fuenteInfo: eventUrl,
      organizador: promoter,
    );
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value.toString();
    return result.isEmpty ? fallback : result;
  }
}
