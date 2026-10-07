import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_event.dart';

class TicketmasterService {
  // Aqui se pone la api key de Ticketmaster
  static const String _apiKey = 'LoNltEvDNX9eFft89sBUqZpXpwYpxaAG';

  static Future<List<ApiEvent>> getEvents() async {
    final url =
        'https://app.ticketmaster.com/discovery/v2/events.json?countryCode=CL&apikey=$_apiKey';

    try {
      final rspta = await http
          .get(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (rspta.statusCode == 200) {
        final rsptaJson = jsonDecode(rspta.body);

        if (rsptaJson['_embedded'] != null &&
            rsptaJson['_embedded']['events'] != null) {
          List<dynamic> eventsJson = rsptaJson['_embedded']['events'];

          return eventsJson.map((e) => _mapToApiEvent(e)).toList();
        }
      } else {
        print('Error en la API de Ticketmaster: ${rspta.statusCode}');
      }
    } catch (e) {
      print('Excepción al consumir Ticketmaster: $e');
    }

    return <ApiEvent>[];
  }

  // Mapeo específico de la estructura de Ticketmaster a nuestro modelo genérico
  static ApiEvent _mapToApiEvent(Map<String, dynamic> json) {
    // 1. EXTRAER IMAGEN (Priorizar la de mayor calidad, usualmente 16_9 de ancho grande)
    String imageUrl = '';
    if (json['images'] != null && json['images'].isNotEmpty) {
      var imageList = json['images'] as List;
      // Intenta encontrar una imagen 16_9 de buena resolución, si no, agarra la primera
      var preferredImage = imageList.firstWhere(
        (img) =>
            img['ratio'] == '16_9' &&
            img['width'] != null &&
            img['width'] > 600,
        orElse: () => imageList[0],
      );
      imageUrl = _asString(preferredImage['url']);
    }

    // 2. EXTRAER LOCALIZACIÓN (Venue / Estadio)
    String venueName = 'Lugar por confirmar';
    String? lat;
    String? lng;
    if (json['_embedded'] != null &&
        json['_embedded']['venues'] != null &&
        json['_embedded']['venues'].isNotEmpty) {
      var venue = json['_embedded']['venues'][0];
      venueName = _asString(
        venue['name'],
        fallback: 'Lugar por confirmar',
      );
      if (venue['location'] != null) {
        lat = venue['location']['latitude']?.toString();
        lng = venue['location']['longitude']?.toString();
      }
    }

    // 3. EXTRAER FECHAS Y HORAS
    String startDate = '';
    String startTime = '';
    if (json['dates'] != null && json['dates']['start'] != null) {
      startDate = _asString(json['dates']['start']['localDate']);
      startTime = _asString(json['dates']['start']['localTime']);
    }

    // 4. EXTRAER ORGANIZADOR / ARTISTA (En tu JSON viene dentro de _embedded.attractions)
    String promoter = '';
    if (json['_embedded'] != null &&
        json['_embedded']['attractions'] != null &&
        json['_embedded']['attractions'].isNotEmpty) {
      promoter = _asString(json['_embedded']['attractions'][0]['name']);
    } else if (json['promoter'] != null) {
      promoter = _asString(json['promoter']['name']);
    }

    // 5. EXTRAER DESCRIPCIÓN (Tu JSON no tiene el campo "info", pero sí "classifications")
    String description = 'Sin descripción disponible.';
    if (json['info'] != null) {
      description = _asString(json['info']);
    } else if (json['classifications'] != null &&
        json['classifications'].isNotEmpty) {
      var classification = json['classifications'][0];
      String genre = _asString(classification['genre']?['name']);
      String subGenre = _asString(classification['subGenre']?['name']);
      description =
          'Evento de $genre ${subGenre.isNotEmpty ? "($subGenre)" : ""}';
    }

    // 6. URL DEL EVENTO
    final String eventUrl = _asString(json['url'], fallback: 'Ticketmaster');

    return ApiEvent(
      id: json['id']?.toString() ?? '',
      nombre: _asString(json['name'], fallback: 'Sin nombre'),
      descripcion: description,
      fechaInicio: startDate,
      fechaTermino: '',
      hora: startTime,
      localizacion: venueName,
      latitude: lat,
      longitude: lng,
      imagen: imageUrl,
      fuenteInfo: _asString(eventUrl, fallback: 'Ticketmaster'),
      organizador: promoter,
    );
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value.toString();
    return result.isEmpty ? fallback : result;
  }
}
