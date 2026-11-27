import 'api_event.dart';
import 'ticketmaster_service.dart';
import 'apibenja_service.dart';
import 'package:flutter/foundation.dart';

class Webservice {
  static Future<List<ApiEvent>>? _eventsRequest;
  static List<ApiEvent>? _cachedEvents;
  static final Map<String, ApiEvent> _locallyCreatedEvents = {};
  static final ValueNotifier<int> eventRevision = ValueNotifier<int>(0);

  static List<ApiEvent> get cachedEvents => _cachedEvents == null
      ? <ApiEvent>[]
      : List<ApiEvent>.from(_cachedEvents!);

  static void upsertEvent(ApiEvent event) {
    if (event.id != null && event.id!.isNotEmpty) {
      _locallyCreatedEvents[event.id!] = event;
    }
    _cachedEvents = _consolidateEvents([...?_cachedEvents, event]);
    eventRevision.value++;
  }

  static void removeEventFromCache(String? eventId) {
    if (eventId == null || eventId.isEmpty) return;
    _locallyCreatedEvents.remove(eventId);
    if (_cachedEvents != null) {
      _cachedEvents!.removeWhere((event) => event.id == eventId);
      eventRevision.value++;
    }
  }

  // Este servicio actúa como "Orquestador".
  static Future<List<ApiEvent>> getEvents({bool forceRefresh = false}) {
    if (!forceRefresh && _cachedEvents != null) {
      return Future.value(_cachedEvents!);
    }
    final cachedRequest = _eventsRequest;
    if (!forceRefresh && cachedRequest != null) {
      return cachedRequest;
    }

    final request = _loadEventsWithCache();
    _eventsRequest = request;
    request.then((events) {
      if (events.isEmpty) {
        _eventsRequest = null;
      }
    });
    return request;
  }

  static Future<List<ApiEvent>> refreshEvents() async {
    final events = await getEvents(forceRefresh: true);
    eventRevision.value++;
    return events;
  }

  static Future<List<ApiEvent>> _loadEventsWithCache() async {
    try {
      var events = await _loadEvents();

      // Una fuente puede tardar en responder durante el primer arranque.
      // Reintentamos una vez antes de considerar vacia la carga.
      if (events.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        events = await _loadEvents();
      }

      final mergedEvents = _mergeLocallyCreatedEvents(events);
      if (mergedEvents.isNotEmpty) {
        _cachedEvents = mergedEvents;
      } else {
        _cachedEvents = null;
        _eventsRequest = null;
      }
      return mergedEvents;
    } catch (_) {
      _eventsRequest = null;
      rethrow;
    }
  }

  static Future<List<ApiEvent>> _loadEvents() async {
    List<ApiEvent> ticketmasterEvents = [];
    List<ApiEvent> benjaEvents = [];

    void publishPartialEvents() {
      final allEvents = <ApiEvent>[...ticketmasterEvents, ...benjaEvents];
      if (allEvents.isEmpty) return;

      final consolidated = _mergeLocallyCreatedEvents(allEvents);
      if (consolidated.isEmpty) return;

      _cachedEvents = consolidated;
      eventRevision.value++;
    }

    final ticketmasterRequest = TicketmasterService.getEvents()
        .catchError((e) {
          print('Error al obtener eventos de Ticketmaster: $e');
          return <ApiEvent>[];
        })
        .then((events) {
          ticketmasterEvents = events;
          publishPartialEvents();
          return events;
        });

    final benjaRequest = ApibenjaService.getEvents()
        .catchError((e) {
          print('Error al obtener eventos de API Benja: $e');
          return <ApiEvent>[];
        })
        .then((events) {
          benjaEvents = events;
          publishPartialEvents();
          return events;
        });

    final results = await Future.wait([ticketmasterRequest, benjaRequest]);

    final allEvents = <ApiEvent>[...results[0], ...results[1]];

    print('Total de eventos consolidados: ${allEvents.length}');

    final consolidated = _mergeLocallyCreatedEvents(allEvents);
    if (consolidated.isNotEmpty) {
      _cachedEvents = consolidated;
      eventRevision.value++;
    }
    return consolidated;
  }

  static List<ApiEvent> _mergeLocallyCreatedEvents(List<ApiEvent> events) {
    final merged = List<ApiEvent>.from(events);
    final indexedEvents = <String, ApiEvent>{
      for (final event in merged)
        if (event.id != null && event.id!.isNotEmpty) event.id!: event,
    };

    for (final localEvent in _locallyCreatedEvents.values) {
      final id = localEvent.id;
      if (id == null || id.isEmpty) continue;

      final remoteEvent = indexedEvents[id];
      if (remoteEvent == null) {
        merged.add(localEvent);
      } else if ((remoteEvent.creatorId == null ||
              remoteEvent.creatorId!.isEmpty) &&
          localEvent.creatorId != null &&
          localEvent.creatorId!.isNotEmpty) {
        remoteEvent.creatorId = localEvent.creatorId;
      }
    }

    return _consolidateEvents(merged);
  }

  static List<ApiEvent> _consolidateEvents(List<ApiEvent> events) =>
      _filterExpiredEvents(_groupEvents(events));

  static List<ApiEvent> _filterExpiredEvents(List<ApiEvent> events) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final activeEvents = <ApiEvent>[];

    for (final event in events) {
      if (event.schedules.isNotEmpty) {
        event.schedules.removeWhere((schedule) {
          final referenceDate =
              _extractDate(schedule.end ?? '') ?? _extractDate(schedule.start);
          return referenceDate != null && referenceDate.isBefore(todayStart);
        });
        if (event.schedules.isEmpty) continue;
        event.fechaInicio = event.schedules
            .map((schedule) => schedule.start)
            .join('\n');
        activeEvents.add(event);
        continue;
      }

      final lines = event.fechaInicio
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isNotEmpty) {
        final activeLines = lines.where((line) {
          final date = _extractDate(line);
          if (date == null) return true;
          final endDate = _extractDate(event.fechaTermino);
          final referenceDate = endDate ?? date;
          return !referenceDate.isBefore(todayStart);
        }).toList();

        if (activeLines.isEmpty) continue;
        event.fechaInicio = activeLines.join('\n');
      } else {
        final endDate = _extractDate(event.fechaTermino);
        final startDate = _extractDate(event.fechaInicio);
        final referenceDate = endDate ?? startDate;
        if (referenceDate != null && referenceDate.isBefore(todayStart)) {
          continue;
        }
      }

      activeEvents.add(event);
    }

    return activeEvents;
  }

  static DateTime? _extractDate(String value) {
    final match = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    ).firstMatch(value);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    final dayFirst = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(value);
    if (dayFirst != null) {
      return DateTime(
        int.parse(dayFirst.group(3)!),
        int.parse(dayFirst.group(2)!),
        int.parse(dayFirst.group(1)!),
      );
    }

    return null;
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
      final String key =
          (normalizedName.isNotEmpty && normalizedName != 'sin nombre')
          ? normalizedName
          : (normalizedUrl.isNotEmpty ? normalizedUrl : (event.id ?? ''));

      if (key.isNotEmpty && groupedMap.containsKey(key)) {
        var existingEvent = groupedMap[key]!;
        if (event.id != null &&
            event.id!.isNotEmpty &&
            event.id != existingEvent.id &&
            !existingEvent.alternateIds.contains(event.id)) {
          existingEvent.alternateIds.add(event.id!);
        }
        for (final alternateId in event.alternateIds) {
          if (!existingEvent.alternateIds.contains(alternateId)) {
            existingEvent.alternateIds.add(alternateId);
          }
        }
        existingEvent.apiEventId ??= event.apiEventId;
        for (final fechaId in event.fechaIds) {
          if (!existingEvent.fechaIds.contains(fechaId)) {
            existingEvent.fechaIds.add(fechaId);
          }
        }
        for (final schedule in event.schedules) {
          if (!existingEvent.schedules.any(
            (existing) => _sameScheduleStart(existing.start, schedule.start),
          )) {
            existingEvent.schedules.add(schedule);
          }
        }
        existingEvent.fechaId ??= event.fechaId;
        if (existingEvent.schedules.isNotEmpty) {
          existingEvent.fechaInicio = existingEvent.schedules
              .map((schedule) => schedule.start)
              .join('\n');
        }
      } else {
        if (event.schedules.isNotEmpty) {
          event.fechaInicio = event.schedules
              .map((schedule) => schedule.start)
              .join('\n');
          event.hora = '';
        } else if (event.hora.isNotEmpty) {
          event.fechaInicio += " ${event.hora}";
          event.hora = '';
        }
        final mapKey = key.isNotEmpty ? key : 'unique_${groupedMap.length}';
        groupedMap[mapKey] = event;
      }
    }

    return groupedMap.values.toList();
  }

  static bool _sameScheduleStart(String first, String second) {
    final firstDate = DateTime.tryParse(first);
    final secondDate = DateTime.tryParse(second);
    if (firstDate != null && secondDate != null) {
      return firstDate.isAtSameMomentAs(secondDate);
    }
    return first.trim() == second.trim();
  }
}
