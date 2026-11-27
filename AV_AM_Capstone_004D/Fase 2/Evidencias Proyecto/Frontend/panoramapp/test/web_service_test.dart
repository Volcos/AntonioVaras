import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/web_service.dart';

void main() {
  test('upsert replaces cached event data so map uses updated coordinates', () {
    ApiEvent makeEvent({
      required String location,
      required String latitude,
      required String longitude,
    }) {
      return ApiEvent(
        id: 'map-update-regression',
        nombre: 'Map update regression',
        descripcion: '',
        fechaInicio: '2030-01-01',
        fechaTermino: '',
        hora: '',
        localizacion: location,
        latitude: latitude,
        longitude: longitude,
        imagen: '',
        fuenteInfo: '',
        organizador: '',
      );
    }

    Webservice.upsertEvent(
      makeEvent(
        location: 'Dirección anterior',
        latitude: '-33.4',
        longitude: '-70.6',
      ),
    );
    Webservice.upsertEvent(
      makeEvent(
        location: 'Dirección actualizada',
        latitude: '-33.5',
        longitude: '-70.7',
      ),
    );

    final event = Webservice.cachedEvents.singleWhere(
      (candidate) => candidate.id == 'map-update-regression',
    );
    expect(event.localizacion, 'Dirección actualizada');
    expect(event.latitude, '-33.5');
    expect(event.longitude, '-70.7');
  });
}
