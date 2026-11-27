import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_event.dart';

class ApibenjaService {
  static const List<String> _urls = [
    'https://mi-api-311188719547.us-central1.run.app/eventos', // Pegar la URL y agregar /eventos
  ];

  static Future<ApiEvent> getEventDetails(String eventId) async {
    final uri = Uri.parse('${_urls.first}/${Uri.encodeComponent(eventId)}');
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'No se pudo cargar el detalle del evento (${response.statusCode}).',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException(
        'El detalle del evento no tiene formato válido.',
      );
    }
    final responseMap = Map<String, dynamic>.from(decoded);
    final data = responseMap['data'] is Map
        ? Map<String, dynamic>.from(responseMap['data'] as Map)
        : responseMap;
    return parseEvent(data);
  }

  static Future<List<String>> getEventDateIds(ApiEvent event) async {
    final dateIds = <String>{...event.fechaIds};
    if (dateIds.isNotEmpty) return dateIds.toList();

    if (event.apiEventId != null && event.apiEventId!.isNotEmpty) {
      try {
        final details = await getEventDetails(event.apiEventId!);
        dateIds.addAll(details.fechaIds);
      } catch (_) {
        // Try resolving by the event title if the stored backend ID is stale.
      }
    }
    if (dateIds.isNotEmpty) return dateIds.toList();

    final normalizedName = _normalizeEventName(event.nombre);
    if (normalizedName.isEmpty) return [];

    final matches = await getEvents();
    final matchingEvents = matches
        .where(
          (candidate) =>
              _normalizeEventName(candidate.nombre) == normalizedName,
        )
        .toList();
    for (final candidate in matchingEvents) {
      final candidateId = candidate.apiEventId ?? candidate.id;
      if (candidateId == null || candidateId.isEmpty) continue;

      final details = await getEventDetails(candidateId);
      dateIds.addAll(details.fechaIds);
    }
    return dateIds.toList();
  }

  static String _normalizeEventName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static Future<List<ApiEvent>> getEvents() async {
    for (final url in _urls) {
      int attempts = 0;
      while (attempts < 2) {
        attempts++;
        try {
          final rspta = await http
              .get(Uri.parse(url), headers: {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 25));

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

            print(
              'Eventos obtenidos desde API Benja ($url): ${eventsJson.length}',
            );
            return eventsJson
                .whereType<Map<String, dynamic>>()
                .map(parseEvent)
                .toList();
          } else {
            print('Error en la API Benja ($url): ${rspta.statusCode}');
            break;
          }
        } catch (e) {
          print(
            'Excepción al consumir API Benja ($url) [Intento $attempts/2]: $e',
          );
          if (attempts >= 2) break;
          // Espera breve antes de reintentar si el servidor estaba encendiendo (Cold Start)
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    return <ApiEvent>[];
  }

  static ApiEvent parseEvent(Map<String, dynamic> json) {
    // 1. EXTRAER ID Y NOMBRE
    final id = (json['id_evento'] ?? json['id'] ?? '').toString();
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
    final nestedDates = json['fechas'] is List
        ? (json['fechas'] as List).whereType<Map>().toList()
        : <Map>[];
    final nestedStartDates = nestedDates
        .map((fecha) => _asString(fecha['fecha_inicio']))
        .where((date) => date.isNotEmpty)
        .toList();
    String startDate = _asString(
      json['fecha_inicio'] ??
          json['fechaInicio'] ??
          json['date'] ??
          json['fecha'],
    );
    if (nestedStartDates.isNotEmpty) {
      startDate = nestedStartDates.join('\n');
    }
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
    if (endDate.isEmpty) {
      final nestedEndDates = nestedDates
          .map((fecha) => _asString(fecha['fecha_termino']))
          .where((date) => date.isNotEmpty)
          .toList();
      if (nestedEndDates.isNotEmpty) {
        endDate = nestedEndDates.reduce(
          (latest, candidate) =>
              (DateTime.tryParse(candidate) ?? DateTime(0)).isAfter(
                DateTime.tryParse(latest) ?? DateTime(0),
              )
              ? candidate
              : latest,
        );
      }
    }

    // 4. EXTRAER LOCALIZACIÓN Y COORDENADAS
    String venueName = 'Lugar por confirmar';
    String? lat =
        json['latitud']?.toString() ??
        json['latitude']?.toString() ??
        json['lat']?.toString();
    String? lng =
        json['longitud']?.toString() ??
        json['longitude']?.toString() ??
        json['lng']?.toString() ??
        json['lon']?.toString();

    if (json['localizacion'] != null && json['localizacion'] is String) {
      venueName = json['localizacion'];
    } else if (json['direccion'] is String) {
      venueName = json['direccion'];
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
      venueName = _asString(venue['name'], fallback: 'Lugar por confirmar');
      if (venue['location'] != null) {
        lat ??= venue['location']['latitude']?.toString();
        lng ??= venue['location']['longitude']?.toString();
      }
    }

    // 5. EXTRAER IMAGEN
    String imageUrl = _asString(
      json['imagen'] ?? json['imagen_url'] ?? json['image'] ?? json['imageUrl'],
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
      json['fuente_info'] ??
          json['fuenteInfo'] ??
          json['url_pagina_compra'] ??
          json['url'],
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
      apiEventId: id.isEmpty ? null : id,
      nombre: nombre,
      descripcion: description,
      fechaInicio: startDate,
      fechaTermino: endDate,
      hora: startTime,
      localizacion: venueName,
      latitude: lat,
      longitude: lng,
      fechaId: (json['id_fecha'] ?? json['fecha_id'] ?? json['idFecha'])
          ?.toString(),
      fechaIds: nestedDates
          .map((fecha) => _asString(fecha['id_fecha']))
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(),
      schedules: nestedDates
          .map(
            (fecha) => ApiEventSchedule(
              idFecha: fecha['id_fecha']?.toString(),
              start: _asString(fecha['fecha_inicio']),
              end: fecha['fecha_termino']?.toString(),
              price: fecha['precio_desde']?.toString(),
            ),
          )
          .where((date) => date.start.isNotEmpty)
          .toList(),
      imagen: imageUrl,
      fuenteInfo: eventUrl,
      organizador: promoter,
      comuna: _asString(json['nombre_comuna'] ?? json['comuna']),
      tipoEvento: _asString(
        json['nombre_tipo_evento'] ??
            json['tipo_evento'] ??
            json['tipo_evento_nombre'],
      ),
      creatorId:
          json['id_usuario_creador']?.toString() ??
          json['creador_id']?.toString() ??
          json['id_usuario']?.toString(),
    );
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value.toString();
    return result.isEmpty ? fallback : result;
  }
}
