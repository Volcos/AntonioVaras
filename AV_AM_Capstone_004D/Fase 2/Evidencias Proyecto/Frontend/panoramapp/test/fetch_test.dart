import 'package:capstone/service/web_service.dart';
import 'package:capstone/service/api_event.dart';

void main() async {
  print('Iniciando fetch...');
  try {
    List<ApiEvent> events = await Webservice.getEvents();
    print('Eventos obtenidos: \${events.length}');
    for (var e in events) {
      print('- \${e.nombre} | \${e.fechaInicio} | \${e.localizacion}');
    }
  } catch (e) {
    print('Error: \$e');
  }
}
