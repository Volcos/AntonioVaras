import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/service/web_service.dart';
import 'package:capstone/service/api_event.dart';

void main() {
  test('Check Iron Maiden image and fields', () async {
    List<ApiEvent> events = await Webservice.getEvents(forceRefresh: true);
    for (var e in events) {
      if (e.nombre.toLowerCase().contains('iron maiden')) {
        print('FOUND IRON MAIDEN:');
        print('Name: ${e.nombre}');
        print('Image: ${e.imagen}');
        print('Lat: ${e.latitude}, Lng: ${e.longitude}');
        print('Localizacion: ${e.localizacion}');
      }
    }
  });
}
