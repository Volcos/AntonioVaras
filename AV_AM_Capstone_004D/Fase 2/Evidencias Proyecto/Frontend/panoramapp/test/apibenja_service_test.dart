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
}
