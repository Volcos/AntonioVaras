import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  // Controlador para poder mover el mapa programáticamente si es necesario
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Manteniendo el estilo oscuro de la app
      // Quitamos el AppBar para que sea pantalla completa y se luzca el mapa
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          // initialCenter define donde empieza el mapa. He puesto Santiago de Chile.
          initialCenter: const LatLng(-33.4488897, -70.6692655), 
          initialZoom: 12.0, // Nivel de zoom inicial (calles principales)
          maxZoom: 18.0, // Nivel máximo de zoom (nivel calle)
          minZoom: 3.0,  // Nivel mínimo de zoom (nivel continente)
          
          // onTap: (tapPosition, latLng) {
          //   print("Tocaste en las coordenadas: ${latLng.latitude}, ${latLng.longitude}");
          // },
        ),
        children: [
          // Capa base de los mapas (Tiles). OpenStreetMap es gratis y no requiere API Key
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.capstone', 
            
            // Si el dispositivo está en modo oscuro, aplicamos un filtro invertido al mapa
            tileBuilder: Theme.of(context).brightness == Brightness.dark
                ? (context, tileWidget, tile) {
                    return ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,  0,  0, 0, 255, // Red
                         0, -1,  0, 0, 255, // Green
                         0,  0, -1, 0, 255, // Blue
                         0,  0,  0, 1,   0, // Alpha
                      ]),
                      child: tileWidget,
                    );
                  }
                : null,
          ),
          
          // Capa de marcadores (pines) en el mapa
          MarkerLayer(
            markers: [
              // Marcador de ejemplo en el Estadio Nacional
              Marker(
                point: const LatLng(-33.4623913, -70.6113274), // Coordenadas del Estadio
                width: 50,
                height: 50,
                child: const Icon(
                  Icons.location_on, // Ícono de pin de Material
                  color: Colors.red,
                  size: 40.0,
                ),
              ),
              // Marcador de ejemplo en Movistar Arena
              Marker(
                point: const LatLng(-33.465134, -70.659357),
                width: 50,
                height: 50,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.pinkAccent,
                  size: 40.0,
                ),
              ),
            ],
          ),
          
          // Atribución obligatoria para usar OpenStreetMap
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
          ),
        ],
      ),
      
      // Ejemplo de botón flotante para centrar la cámara
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0), // Padding para no tapar el Navbar de Home.dart
        child: FloatingActionButton(
          backgroundColor: const Color(0x33FFFFFF), // Estilo glass
          elevation: 0,
          onPressed: () {
            // Mueve la cámara de vuelta al centro de Santiago
            _mapController.move(const LatLng(-33.4488897, -70.6692655), 12.0);
          },
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
    );
  }
}
