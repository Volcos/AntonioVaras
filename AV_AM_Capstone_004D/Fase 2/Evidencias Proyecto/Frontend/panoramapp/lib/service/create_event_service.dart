import 'dart:convert';

import 'package:http/http.dart' as http;
import 'apibenja_service.dart';
import 'web_service.dart';

String _withOffset(DateTime value) {
  final local = value.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final iso = local.toIso8601String().split('.').first;
  return '$iso$sign$hours:$minutes';
}

class EventDateInput {
  final DateTime fechaInicio;
  final DateTime? fechaTermino;
  final double? precioDesde;
  final int? idFecha;

  const EventDateInput({
    required this.fechaInicio,
    this.fechaTermino,
    this.precioDesde,
    this.idFecha,
  });

  Map<String, dynamic> toJson() => {
    'fecha_inicio': _withOffset(fechaInicio),
    'fecha_termino': fechaTermino == null ? null : _withOffset(fechaTermino!),
    'precio_desde': precioDesde,
  };
}

class CreateEventService {
  static const String _endpoint =
      'https://mi-api-311188719547.us-central1.run.app/eventos';

  static Future<Map<String, dynamic>> createEvent({
    required String nombre,
    required String descripcion,
    required String direccion,
    required String imagenUrl,
    required String eventUrl,
    required String comuna,
    required String tipoEvento,
    double? latitud,
    double? longitud,
    required String organizador,
    String? creatorId,
    required List<EventDateInput> fechas,
  }) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'nombre': nombre.trim(),
            'descripcion': descripcion.trim().isEmpty
                ? null
                : descripcion.trim(),
            'direccion': direccion.trim(),
            'imagen_url': imagenUrl.trim().isEmpty ? null : imagenUrl.trim(),
            'url_pagina_compra': eventUrl.trim().isEmpty
                ? null
                : eventUrl.trim(),
            'comuna': comuna.trim(),
            'tipo_evento': tipoEvento.trim(),
            'latitud': latitud,
            'longitud': longitud,
            'organizador': organizador.trim().isEmpty
                ? null
                : organizador.trim(),
            'id_usuario_creador': creatorId,
            'fechas': fechas.map((fecha) => fecha.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw Exception(
        message ?? 'No se pudo crear el evento (${response.statusCode}).',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('La respuesta del servidor no tiene un formato válido.');
    }
    if (decoded['success'] == false) {
      throw Exception(
        decoded['message']?.toString() ?? 'No se pudo crear el evento.',
      );
    }

    try {
      final responseData = decoded['data'];
      if (responseData is! Map) {
        throw const FormatException('Faltan los datos del evento actualizado.');
      }
      final apiEvent = ApibenjaService.parseEvent(
        Map<String, dynamic>.from(responseData),
      )..creatorId = creatorId;
      Webservice.upsertEvent(apiEvent);
    } on FormatException catch (error) {
      throw Exception(error.message);
    }

    return decoded;
  }

  static Future<void> deleteEvent({
    required String eventId,
    required String token,
  }) async {
    final response = await http
        .delete(
          Uri.parse('$_endpoint/$eventId'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'])?.toString()
          : null;
      throw Exception(
        message ?? 'No se pudo eliminar el evento (${response.statusCode}).',
      );
    }
  }

  static Future<Map<String, dynamic>> updateEvent({
    required String eventId,
    required String token,
    required String nombre,
    required String descripcion,
    required String direccion,
    required String imagenUrl,
    required String eventUrl,
    required String comuna,
    required String tipoEvento,
    double? latitud,
    double? longitud,
    required String organizador,
    String? creatorId,
    required List<EventDateInput> fechas,
  }) async {
    final bodyMap = {
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim().isEmpty ? null : descripcion.trim(),
      'direccion': direccion.trim(),
      'imagen_url': imagenUrl.trim().isEmpty ? null : imagenUrl.trim(),
      'url_pagina_compra': eventUrl.trim().isEmpty ? null : eventUrl.trim(),
      'comuna': comuna.trim(),
      'tipo_evento': tipoEvento.trim(),
      'latitud': latitud,
      'longitud': longitud,
      'organizador': organizador.trim().isEmpty ? null : organizador.trim(),
      'fechas': fechas.map((fecha) => fecha.toJson()).toList(),
    };

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    headers['Authorization'] = 'Bearer $token';

    final response = await http
        .put(
          Uri.parse('$_endpoint/$eventId'),
          headers: headers,
          body: jsonEncode(bodyMap),
        )
        .timeout(const Duration(seconds: 15));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['error'])?.toString()
          : null;
      throw Exception(
        message ?? 'No se pudo actualizar el evento (${response.statusCode}).',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('La respuesta del servidor no tiene un formato válido.');
    }
    if (decoded['success'] == false) {
      throw Exception(
        decoded['message']?.toString() ?? 'No se pudo actualizar el evento.',
      );
    }

    try {
      final responseData = decoded['data'];
      if (responseData is! Map) {
        throw const FormatException('Faltan los datos del evento actualizado.');
      }
      final apiEvent = ApibenjaService.parseEvent(
        Map<String, dynamic>.from(responseData),
      )..creatorId = creatorId;
      Webservice.upsertEvent(apiEvent);
    } on FormatException catch (error) {
      throw Exception(error.message);
    }

    return decoded;
  }

  static Future<List<String>> getEventTypes() async {
    final response = await http
        .get(
          Uri.parse(_endpoint.replaceFirst('/eventos', '/tipos-evento')),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudieron cargar los tipos de evento.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('La respuesta de tipos de evento no es válida.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((item) => item['nombre_tipo_evento']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }
}
