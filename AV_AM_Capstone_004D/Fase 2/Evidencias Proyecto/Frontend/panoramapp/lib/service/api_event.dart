class ApiEvent {
  final String? id;
  String nombre;
  String descripcion;
  String fechaInicio;
  String fechaTermino;
  String hora;
  String localizacion;
  String? latitude;
  String? longitude;
  String? apiEventId;
  String? fechaId;
  final List<String> fechaIds;
  final List<ApiEventSchedule> schedules;
  final List<String> alternateIds = [];
  String imagen;
  String fuenteInfo;
  String organizador;
  String comuna;
  String tipoEvento;
  String? creatorId;

  ApiEvent({
    this.id = '',
    required this.nombre,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaTermino,
    required this.hora,
    required this.localizacion,
    this.latitude,
    this.longitude,
    this.apiEventId,
    String? fechaId,
    List<String>? fechaIds,
    List<ApiEventSchedule>? schedules,
    required this.imagen,
    required this.fuenteInfo,
    required this.organizador,
    this.comuna = '',
    this.tipoEvento = '',
    this.creatorId,
  }) : fechaId =
           fechaId ??
           (fechaIds == null || fechaIds.isEmpty ? null : fechaIds.first),
       schedules = List<ApiEventSchedule>.of(
         schedules ?? const <ApiEventSchedule>[],
       ),
       fechaIds = <String>{
         ...?fechaIds,
         if (fechaId != null && fechaId.isNotEmpty) fechaId,
       }.toList();

  bool get hasMultipleSchedules => schedules.length > 1;

  String get displayDate {
    if (schedules.isNotEmpty) return schedules.first.displayRange;
    return fechaInicio.split('\n').first.trim();
  }

  static ApiEvent objJson(Map<String, dynamic> json) {
    return ApiEvent(
      id: (json['id_evento'] ?? json['id'])?.toString() ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaInicio:
          _parseDates(json['fechas'], 'fecha_inicio') ??
          json['fecha_inicio'] ??
          json['fechaInicio'] ??
          '',
      fechaTermino:
          _parseDates(json['fechas'], 'fecha_termino') ??
          json['fecha_termino'] ??
          json['fechaTermino'] ??
          '',
      hora: json['hora'] ?? '',
      localizacion: json['localizacion'] ?? '',
      latitude:
          json['latitud']?.toString() ??
          json['latitude']?.toString() ??
          json['lat']?.toString(),
      longitude:
          json['longitud']?.toString() ??
          json['longitude']?.toString() ??
          json['lng']?.toString() ??
          json['lon']?.toString(),
      fechaId: (json['id_fecha'] ?? json['fecha_id'] ?? json['idFecha'])
          ?.toString(),
      imagen: json['imagen'] ?? '',
      fuenteInfo: json['fuente_info'] ?? json['fuenteInfo'] ?? '',
      organizador: json['organizador'] ?? '',
      fechaIds: _parseFechaIds(json['fechas']),
      schedules: _parseSchedules(json),
      creatorId:
          json['id_usuario_creador']?.toString() ??
          json['creador_id']?.toString() ??
          json['id_usuario']?.toString(),
      comuna: (json['nombre_comuna'] ?? json['comuna'])?.toString() ?? '',
      tipoEvento:
          (json['nombre_tipo_evento'] ??
                  json['tipo_evento'] ??
                  json['tipo_evento_nombre'])
              ?.toString() ??
          '',
    );
  }

  static List<ApiEventSchedule> _parseSchedules(Map<String, dynamic> json) {
    final rawFechas = json['fechas'];
    if (rawFechas is List) {
      return rawFechas
          .whereType<Map>()
          .map((fecha) {
            return ApiEventSchedule(
              idFecha: fecha['id_fecha']?.toString(),
              start: fecha['fecha_inicio']?.toString() ?? '',
              end: fecha['fecha_termino']?.toString(),
              price: fecha['precio_desde']?.toString(),
            );
          })
          .where((date) => date.start.isNotEmpty)
          .toList();
    }

    final start =
        (json['fecha_inicio'] ?? json['fechaInicio'])?.toString() ?? '';
    if (start.isEmpty) return [];
    return [
      ApiEventSchedule(
        idFecha: json['id_fecha']?.toString(),
        start: start,
        end: (json['fecha_termino'] ?? json['fechaTermino'])?.toString(),
        price: json['precio_desde']?.toString(),
      ),
    ];
  }

  static List<String> _parseFechaIds(dynamic rawFechas) {
    if (rawFechas is! List) return [];
    return rawFechas
        .whereType<Map>()
        .map((fecha) => fecha['id_fecha']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  static String? _parseDates(dynamic rawFechas, String key) {
    if (rawFechas is! List) return null;
    final dates = rawFechas
        .whereType<Map>()
        .map((fecha) => fecha[key]?.toString() ?? '')
        .where((date) => date.isNotEmpty)
        .toList();
    return dates.isEmpty ? null : dates.join('\n');
  }
}

class ApiEventSchedule {
  final String? idFecha;
  final String start;
  final String? end;
  final String? price;

  const ApiEventSchedule({
    this.idFecha,
    required this.start,
    this.end,
    this.price,
  });

  String get displayRange {
    final startDate = DateTime.tryParse(start)?.toLocal();
    if (startDate == null) return start;

    final formattedStart = _formatScheduleDate(startDate);
    final endValue = end?.trim() ?? '';
    if (endValue.isEmpty) return formattedStart;

    final endDate = DateTime.tryParse(endValue)?.toLocal();
    if (endDate == null) return formattedStart;

    final formattedEnd =
        startDate.year == endDate.year &&
            startDate.month == endDate.month &&
            startDate.day == endDate.day
        ? '${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}'
        : _formatScheduleDate(endDate);
    return '$formattedStart – $formattedEnd';
  }
}

String _formatScheduleDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
