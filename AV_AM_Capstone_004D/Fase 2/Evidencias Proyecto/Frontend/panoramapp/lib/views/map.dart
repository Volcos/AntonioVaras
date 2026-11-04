import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:capstone/service/location_service.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/web_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const LatLng _santiagoCenter = LatLng(-33.4488897, -70.6692655);
  static const String _lightMapStyle =
      'https://tiles.openfreemap.org/styles/liberty';
  static const String _darkMapStyle =
      'https://tiles.openfreemap.org/styles/fiord';

  MapLibreMapController? _mapController;
  bool _locationPermissionGranted = false;
  MyLocationTrackingMode _trackingMode = MyLocationTrackingMode.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLocationPermission();
      }
    });
  }

  // Convierte la imagen URL a un avatar circular con borde blanco
  Future<Uint8List?> _getCircularImageBytes(String url) async {
    Future<Uint8List?> tryGet(String targetUrl) async {
      try {
        if (targetUrl.isEmpty) return null;
        final file = await DefaultCacheManager().getSingleFile(targetUrl);
        final bytes = await file.readAsBytes();

        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120, targetHeight: 120);
        final frameInfo = await codec.getNextFrame();
        final image = frameInfo.image;

        final pictureRecorder = ui.PictureRecorder();
        final canvas = Canvas(pictureRecorder);
        final paint = Paint()..isAntiAlias = true;

        const radius = 60.0;
        const center = Offset(radius, radius);

        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
        canvas.drawImage(image, Offset.zero, paint);

        final borderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 6.0
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
        canvas.drawCircle(center, radius - 3.0, borderPaint);

        final img = await pictureRecorder.endRecording().toImage(120, 120);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }

    // 1. Intentar con la URL original
    Uint8List? result = await tryGet(url);
    if (result != null) return result;

    // 2. Intentar con fallback de Unsplash si falló la original
    const fallbackUrl = 'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=120&q=80';
    result = await tryGet(fallbackUrl);
    if (result != null) return result;

    // 3. Respaldo definitivo: Dibujar un círculo sólido con color de acento si todo lo demás falla
    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const radius = 60.0;
      const center = Offset(radius, radius);

      final bgPaint = Paint()
        ..color = Colors.pinkAccent
        ..isAntiAlias = true;
      canvas.drawCircle(center, radius, bgPaint);

      final borderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      canvas.drawCircle(center, radius - 3.0, borderPaint);

      final img = await pictureRecorder.endRecording().toImage(120, 120);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error generando imagen de respaldo: $e");
      return null;
    }
  }

  Future<void> _loadLocationPermission() async {
    final granted = await LocationService.solicitarPermisoUbicacion();
    if (!mounted) return;

    setState(() {
      _locationPermissionGranted = granted;
    });
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onUserLocationUpdated(UserLocation location) {
    LocationService.registrarActualizacion(location);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;

    try {
      // 1. Obtenemos todos los eventos usando tu Webservice (el mismo que usa home.dart)
      final eventos = await Webservice.getEvents();

      // 2. Por cada evento...
      for (int i = 0; i < eventos.length; i++) {
        var evento = eventos[i];
        try {
          LatLng? coordenada;

          // Intentar usar latitud y longitud si vienen del backend
          if (evento.latitude != null && evento.longitude != null &&
              evento.latitude!.isNotEmpty && evento.longitude!.isNotEmpty) {
            double lat = double.tryParse(evento.latitude!) ?? 0.0;
            double lng = double.tryParse(evento.longitude!) ?? 0.0;
            if (lat != 0.0 && lng != 0.0) {
              coordenada = LatLng(lat, lng);
            }
          }

          // Si no traía coordenadas pero sí texto de "localización", lo buscamos.
          if (coordenada == null && evento.localizacion.isNotEmpty) {
            coordenada = await LocationService.obtenerCoordenadasPorTexto(evento.localizacion);
          }

          // 3. Si logramos obtener una ubicación en el mapa
          if (coordenada != null) {
            
            // Descargamos y convertimos su imagen a una burbuja circular
            String imageUrl = evento.imagen.isNotEmpty 
                ? evento.imagen 
                : 'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=120&q=80'; // fallback de tu home.dart

            final imageBytes = await _getCircularImageBytes(imageUrl);
            
            if (imageBytes != null) {
              final String cleanId = (evento.id != null && evento.id!.isNotEmpty) ? evento.id! : 'idx_$i';
              final String imageId = 'evento_img_${cleanId}_${evento.nombre.hashCode}';
              
              // Agregamos la imagen generada a la memoria del mapa
              try {
                await controller.addImage(imageId, imageBytes);
              } catch (_) {
                // Si la imagen ya existe, ignoramos
              }

              // Dibujamos el pin (símbolo) en el mapa
              await controller.addSymbol(
                SymbolOptions(
                  geometry: coordenada,
                  iconImage: imageId,
                  iconSize: 0.8, // Escala un poco el círculo si es necesario
                  textField: evento.nombre, // Le agregamos el título debajo del círculo
                  textSize: 12.0,
                  textOffset: const Offset(0, 1.5), // Para que quede bajo la imagen
                  textHaloColor: '#FFFFFF', // Borde blanco en las letras para que sea legible
                  textHaloWidth: 2.0,
                  textColor: '#000000',
                ),
              );
            }
          }
        } catch (e) {
          debugPrint("Error dibujando evento ${evento.nombre} en mapa: $e");
        }
      }
    } catch (e) {
      debugPrint("Error dibujando eventos en mapa: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mapStyle = isDarkMode ? _darkMapStyle : _lightMapStyle;

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MapLibreMap(
          initialCameraPosition: const CameraPosition(
            target: _santiagoCenter,
            zoom: 12,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(3, 18),
          styleString: mapStyle,
          myLocationEnabled: _locationPermissionGranted,
          myLocationTrackingMode: _trackingMode,
          onCameraTrackingDismissed: () {
            // Cuando el usuario mueve el mapa manualmente con el dedo,
            // el mapa deja de seguir el GPS automáticamente.
            if (mounted) {
              setState(() {
                _trackingMode = MyLocationTrackingMode.none;
              });
            }
          },
          locationEnginePlatforms: LocationService.androidLocationSettings,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onUserLocationUpdated: _onUserLocationUpdated,
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 100.0),
          child: FloatingActionButton(
            backgroundColor: isDarkMode ? const Color(0x33FFFFFF) : Colors.grey,
            elevation: isDarkMode ? 0 : 4,
            onPressed: () async {
              final controller = _mapController;
              final messenger = ScaffoldMessenger.of(context);
              if (controller == null) return;

              if (!_locationPermissionGranted) {
                await _loadLocationPermission();
                if (!_locationPermissionGranted || !mounted) return;
              }

              final currentLocation =
                  await LocationService.obtenerUbicacionActual(controller);

              if (currentLocation == null) {
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No se pudo obtener tu ubicación. Verifica que el GPS esté activado.',
                    ),
                  ),
                );
                return;
              }

              // 1. Primero animamos la cámara hacia la ubicación con el zoom ideal
              await controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: currentLocation, zoom: 15.0),
                ),
              );

              // 2. Una vez que termina la animación, activamos el seguimiento en tiempo real.
              // Si lo activábamos antes de la animación, el movimiento manual lo cancelaba de inmediato.
              if (mounted) {
                setState(() {
                  _trackingMode = MyLocationTrackingMode.tracking;
                });
              }
            },
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
