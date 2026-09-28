import 'api_event.dart';
import 'ticketmaster_service.dart';

class Webservice {
  // Este servicio ahora actúa como "Orquestador".
  static Future<List<ApiEvent>> getEvents() async {
    List<ApiEvent> allEvents = [];

    // 1. Recolectar eventos de Ticketmaster
    final ticketmasterEvents = await TicketmasterService.getEvents();
    allEvents.addAll(ticketmasterEvents);

    // 2. Aquí se colocaran más servicios de API o a scrapers en el futuro
    // final eventridEvents = await EventridService.getEvents();
    // allEvents.addAll(eventridEvents);

    // 3. Agrupar solamente registros del mismo evento de Ticketmaster.
    return _groupEvents(allEvents);
  }

  // Combina fechas repetidas del mismo ID sin mezclar eventos homónimos.
  static List<ApiEvent> _groupEvents(List<ApiEvent> rawEvents) {
    Map<String, ApiEvent> groupedMap = {};

    for (var event in rawEvents) {
      final String key = event.id != null && event.id!.isNotEmpty
          ? event.id!
          : '${event.nombre.trim().toLowerCase()}|${event.fechaInicio}';

      if (groupedMap.containsKey(key)) {
        // El evento ya existe en el mapa, agregamos la nueva fecha/hora a la lista
        var existingEvent = groupedMap[key]!;

        // Formateamos la nueva fecha y hora para agregarla
        String newDateTime = event.fechaInicio;
        if (event.hora.isNotEmpty) {
          newDateTime += " ${event.hora}";
        }

        // Si la nueva fecha no está ya en la lista de fechas agrupadas (para evitar repetidos exactos)
        if (newDateTime.isNotEmpty &&
            !existingEvent.fechaInicio.contains(newDateTime)) {
          // Añadimos un salto de línea y la nueva fecha
          existingEvent.fechaInicio += "\n$newDateTime";
        }
      } else {
        // Es la primera vez que vemos este evento, lo formateamos y lo guardamos
        // Para que el primer registro también tenga el formato consistente "Fecha Hora"
        if (event.hora.isNotEmpty) {
          event.fechaInicio += " ${event.hora}";
          // Limpiamos el campo de hora individual ya que ahora está agrupado en fechaInicio
          event.hora = '';
        }
        groupedMap[key] = event;
      }
    }

    return groupedMap.values.toList();
  }
}
