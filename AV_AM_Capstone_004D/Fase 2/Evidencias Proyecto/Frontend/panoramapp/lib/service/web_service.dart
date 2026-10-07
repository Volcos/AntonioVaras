import 'api_event.dart';
import 'ticketmaster_service.dart';
import 'apibenja_service.dart';

class Webservice {
  // Este servicio actúa como "Orquestador".
  static Future<List<ApiEvent>> getEvents() async {
    List<ApiEvent> allEvents = [];

    // Recolectar eventos en paralelo con Future.wait
    final results = await Future.wait([
      TicketmasterService.getEvents().catchError((e) {
        print('Error al obtener eventos de Ticketmaster: $e');
        return <ApiEvent>[];
      }),
      ApibenjaService.getEvents().catchError((e) {
        print('Error al obtener eventos de API Benja: $e');
        return <ApiEvent>[];
      }),
    ]);

    allEvents.addAll(results[0]);
    allEvents.addAll(results[1]);

    print('Total de eventos consolidados: ${allEvents.length}');

    // Agrupar registros del mismo evento
    return _groupEvents(allEvents);
  }

  // Agrupa las distintas funciones del mismo espectáculo en una tarjeta.
  static List<ApiEvent> _groupEvents(List<ApiEvent> rawEvents) {
    Map<String, ApiEvent> groupedMap = {};

    for (var event in rawEvents) {
      final String normalizedName = event.nombre
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ');
      final String normalizedUrl = event.fuenteInfo
          .trim()
          .toLowerCase()
          .replaceFirst(RegExp(r'[?#].*$'), '')
          .replaceAll(RegExp(r'/$'), '');

      // Generamos una clave representativa
      final String key = (normalizedName.isNotEmpty && normalizedName != 'sin nombre')
          ? normalizedName
          : (normalizedUrl.isNotEmpty ? normalizedUrl : (event.id ?? ''));

      if (key.isNotEmpty && groupedMap.containsKey(key)) {
        // El evento ya existe en el mapa, agregamos la nueva fecha/hora a la lista
        var existingEvent = groupedMap[key]!;

        // Formateamos la nueva fecha y hora para agregarla
        String newDateTime = event.fechaInicio;
        if (event.hora.isNotEmpty) {
          newDateTime += " ${event.hora}";
        }

        // Si la nueva fecha no está ya en la lista de fechas agrupadas
        if (newDateTime.isNotEmpty &&
            !existingEvent.fechaInicio.contains(newDateTime)) {
          existingEvent.fechaInicio += "\n$newDateTime";
        }
      } else {
        // Es la primera vez que vemos este evento, lo formateamos y lo guardamos
        if (event.hora.isNotEmpty) {
          event.fechaInicio += " ${event.hora}";
          event.hora = '';
        }
        final mapKey = key.isNotEmpty ? key : 'unique_${groupedMap.length}';
        groupedMap[mapKey] = event;
      }
    }

    return groupedMap.values.toList();
  }
}
