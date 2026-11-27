import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/service/apibenja_service.dart';
import 'package:capstone/service/api_event.dart';

void main() {
  test('ApibenjaService correctly parses JSON with value wrapper', () {
    const jsonString = '''
    {
      "value": [
        {
          "id": "7",
          "nombre": "Noche de Stand-up Comedy",
          "descripcion": "Divertida rutina con los mejores comediantes locales del circuito nacional.",
          "fecha_inicio": "2026-11-15",
          "fecha_termino": "2026-11-22",
          "hora": "01:00",
          "localizacion": "Constitución 183, Providencia",
          "latitude": "-33.43420000",
          "longitude": "-70.63410000",
          "imagen": "https://images.unsplash.com/photo-1585699324551-f6c309eedeca",
          "fuente_info": "https://www.centromori.cl",
          "organizador": "Centro Mori Bellavista"
        }
      ],
      "Count": 1
    }
    ''';

    final dynamic decoded = jsonDecode(jsonString);
    final List<dynamic> eventsJson = decoded['value'];

    expect(eventsJson.length, equals(1));
    final item = eventsJson[0] as Map<String, dynamic>;

    final ApiEvent event = ApiEvent(
      id: item['id']?.toString() ?? '',
      nombre: item['nombre'] ?? '',
      descripcion: item['descripcion'] ?? '',
      fechaInicio: item['fecha_inicio'] ?? '',
      fechaTermino: item['fecha_termino'] ?? '',
      hora: item['hora'] ?? '',
      localizacion: item['localizacion'] ?? '',
      latitude: item['latitude']?.toString(),
      longitude: item['longitude']?.toString(),
      imagen: item['imagen'] ?? '',
      fuenteInfo: item['fuente_info'] ?? '',
      organizador: item['organizador'] ?? '',
    );

    expect(event.nombre, equals('Noche de Stand-up Comedy'));
    expect(event.localizacion, equals('Constitución 183, Providencia'));
    expect(event.latitude, equals('-33.43420000'));
  });

  test('parses event IDs and nested date IDs from the API response', () {
    final event = ApibenjaService.parseEvent({
      'id_evento': '42',
      'nombre': 'COMIENZO',
      'direccion': 'Teatro Zoco - Lo Barnechea',
      'nombre_comuna': 'Lo Barnechea',
      'nombre_tipo_evento': 'Teatro',
      'imagen_url': 'https://example.com/event.jpg',
      'fechas': [
        {
          'id_fecha': 49,
          'fecha_inicio': '2026-11-12T22:30:00+00:00',
          'fecha_termino': '2026-11-29T22:30:00+00:00',
          'precio_desde': 12000,
        },
        {
          'id_fecha': 83,
          'fecha_inicio': '2026-11-26T22:30:00+00:00',
          'fecha_termino': '2026-11-29T22:30:00+00:00',
        },
      ],
    });

    expect(event.id, '42');
    expect(event.fechaIds, ['49', '83']);
    expect(
      event.fechaInicio,
      '2026-11-12T22:30:00+00:00\n2026-11-26T22:30:00+00:00',
    );
    expect(event.fechaId, '49');
    expect(event.localizacion, 'Teatro Zoco - Lo Barnechea');
    expect(event.comuna, 'Lo Barnechea');
    expect(event.tipoEvento, 'Teatro');
    expect(event.hasMultipleSchedules, isTrue);
    expect(event.schedules, hasLength(2));
    expect(event.schedules.first.idFecha, '49');
    expect(event.schedules.first.price, '12000');
  });

  test('a single schedule with start and end is one displayed date', () {
    final event = ApibenjaService.parseEvent({
      'id_evento': '83',
      'nombre': 'Prueba',
      'fechas': [
        {
          'id_fecha': 101,
          'fecha_inicio': '2026-11-27T14:04:00+00:00',
          'fecha_termino': '2026-11-27T18:00:00+00:00',
        },
      ],
    });

    expect(event.hasMultipleSchedules, isFalse);
    expect(event.displayDate, event.schedules.single.displayRange);
    expect(event.displayDate, isNot(contains('\n')));
    expect(event.schedules.single.displayRange, contains(' – '));
  });

  test('parses a newly created event response for immediate display', () {
    final event = ApibenjaService.parseEvent({
      'id_evento': 82,
      'nombre': 'prueba C 26/11',
      'descripcion': 'que se eline con tiempo',
      'direccion': 'Autopista Central, Santiago',
      'latitude': '-33.42998300',
      'longitude': '-70.66171300',
      'imagen_url': 'https://example.com/event.jpg',
      'url_pagina_compra': null,
      'organizador': 'Inaki2',
      'nombre_comuna': 'Santiago',
      'nombre_tipo_evento': 'Música',
      'fechas': [
        {
          'id_fecha': 102,
          'fecha_inicio': '2026-11-26T21:18:00-03:00',
          'fecha_termino': '2026-11-26T21:18:00-03:00',
        },
      ],
    });

    expect(event.id, '82');
    expect(event.nombre, 'prueba C 26/11');
    expect(event.localizacion, 'Autopista Central, Santiago');
    expect(event.latitude, '-33.42998300');
    expect(event.longitude, '-70.66171300');
    expect(event.fechaIds, ['102']);
  });
}
