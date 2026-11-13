import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:capstone/service/location_service.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/web_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:capstone/views/event_detail_screen.dart';

class MapView extends StatefulWidget {
  final ApiEvent? selectedEvent;

  const MapView({super.key, this.selectedEvent});

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
  _RouteMode _routeMode = _RouteMode.driving;
  LatLng? _routeDestination;
  bool _routeLoading = false;
  String? _routeDistance;
  String? _routeDuration;
  Line? _routeLine;
  final Map<String, ApiEvent> _eventsBySymbolId = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadLocationPermission();
      }
    });
  }

  @override
  void dispose() {
    _mapController?.onSymbolTapped.remove(_onEventSymbolTapped);
    _eventsBySymbolId.clear();
    super.dispose();
  }

  // Convierte la imagen URL a un avatar circular con borde blanco
  Future<Uint8List?> _getCircularImageBytes(String url) async {
    Future<Uint8List?> tryGet(String targetUrl) async {
      try {
        if (targetUrl.isEmpty) return null;
        final file = await DefaultCacheManager().getSingleFile(targetUrl);
        final bytes = await file.readAsBytes();

        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 120,
          targetHeight: 120,
        );
        final frameInfo = await codec.getNextFrame();
        final image = frameInfo.image;

        final pictureRecorder = ui.PictureRecorder();
        final canvas = Canvas(pictureRecorder);
        final paint = Paint()..isAntiAlias = true;

        const radius = 60.0;
        const center = Offset(radius, radius);

        canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        );
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
    const fallbackUrl =
        'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=120&q=80';
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
    controller.onSymbolTapped.add(_onEventSymbolTapped);
  }

  void _onEventSymbolTapped(Symbol symbol) {
    final event = _eventsBySymbolId[symbol.id];
    if (event == null || !mounted) return;

    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => EventDetailScreen(event: event)),
    );
  }

  void _onUserLocationUpdated(UserLocation location) {
    LocationService.registrarActualizacion(location);
  }

  Future<_EventMarker?> _prepareEventMarker(ApiEvent event, int index) async {
    try {
      LatLng? coordinate;
      final latitude = double.tryParse(event.latitude ?? '');
      final longitude = double.tryParse(event.longitude ?? '');
      if (latitude != null &&
          longitude != null &&
          latitude != 0 &&
          longitude != 0) {
        coordinate = LatLng(latitude, longitude);
      }
      coordinate ??= event.localizacion.isEmpty
          ? null
          : await LocationService.obtenerCoordenadasPorTexto(
              event.localizacion,
            );
      if (coordinate == null) return null;

      final imageUrl = event.imagen.isNotEmpty
          ? event.imagen
          : 'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=120&q=80';
      return _EventMarker(
        event: event,
        index: index,
        coordinate: coordinate,
        imageBytes: await _getCircularImageBytes(imageUrl),
      );
    } catch (error) {
      debugPrint('Error preparando evento ${event.nombre}: $error');
      return null;
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;

    _eventsBySymbolId.clear();
    try {
      final destination = await _focusSelectedEvent(controller);
      // 1. Obtenemos todos los eventos usando tu Webservice (el mismo que usa home.dart)
      final eventos = await Webservice.getEvents();

      for (var start = 0; start < eventos.length; start += 6) {
        final end = (start + 6).clamp(0, eventos.length);
        final batch = eventos.sublist(start, end);
        final markers = await Future.wait(
          batch.asMap().entries.map(
            (entry) => _prepareEventMarker(entry.value, start + entry.key),
          ),
        );

        for (final marker in markers) {
          if (marker == null) continue;
          final evento = marker.event;
          try {
            if (marker.imageBytes != null) {
              final String cleanId =
                  (evento.id != null && evento.id!.isNotEmpty)
                  ? evento.id!
                  : 'idx_${marker.index}';
              final String imageId =
                  'evento_img_${cleanId}_${evento.nombre.hashCode}';

              try {
                await controller.addImage(imageId, marker.imageBytes!);
              } catch (_) {}

              final symbol = await controller.addSymbol(
                SymbolOptions(
                  geometry: marker.coordinate,
                  iconImage: imageId,
                  iconSize: 0.8, // Escala un poco el círculo si es necesario
                  textField: evento
                      .nombre, // Le agregamos el título debajo del círculo
                  textSize: 12.0,
                  textOffset: const Offset(
                    0,
                    1.5,
                  ), // Para que quede bajo la imagen
                  textHaloColor:
                      '#FFFFFF', // Borde blanco en las letras para que sea legible
                  textHaloWidth: 2.0,
                  textColor: '#000000',
                ),
              );
              _eventsBySymbolId[symbol.id] = evento;
            }
          } catch (e) {
            debugPrint('Error dibujando evento ${evento.nombre} en mapa: $e');
          }
        }
      }
      if (destination != null) {
        _routeDestination = destination;
        await _drawRouteToDestination(controller, destination);
      }
    } catch (e) {
      debugPrint("Error dibujando eventos en mapa: $e");
    }
  }

  Future<LatLng?> _focusSelectedEvent(MapLibreMapController controller) async {
    final event = widget.selectedEvent;
    if (event == null) return null;

    LatLng? destination;
    if (event.latitude != null && event.longitude != null) {
      final latitude = double.tryParse(event.latitude!);
      final longitude = double.tryParse(event.longitude!);
      if (latitude != null && longitude != null) {
        destination = LatLng(latitude, longitude);
      }
    }
    destination ??= await LocationService.obtenerCoordenadasPorTexto(
      event.localizacion,
    );
    if (destination == null) return null;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: destination, zoom: 16),
      ),
    );
    return destination;
  }

  Future<void> _drawRouteToDestination(
    MapLibreMapController controller,
    LatLng destination,
  ) async {
    if (!_locationPermissionGranted) {
      await _loadLocationPermission();
    }
    if (!_locationPermissionGranted) return;

    final origin = await LocationService.obtenerUbicacionActual(controller);
    if (origin == null) return;

    if (mounted) setState(() => _routeLoading = true);
    final uri = Uri.https(
      'routing.openstreetmap.de',
      '/${_routeMode.router}/route/v1/driving/${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'},
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final route = decoded['routes']?[0];
      final coordinates = route?['geometry']?['coordinates'];
      if (coordinates is! List || coordinates.isEmpty) return;

      final points = coordinates
          .whereType<List>()
          .where((point) => point.length >= 2)
          .map(
            (point) => LatLng(
              double.parse(point[1].toString()),
              double.parse(point[0].toString()),
            ),
          )
          .toList();
      if (points.length < 2) return;

      _routeDistance = _formatDistance(route['distance']);
      _routeDuration = _formatDuration(route['duration']);
      if (mounted) setState(() {});

      final previousLine = _routeLine;
      if (previousLine != null) {
        await controller.removeLine(previousLine);
      }
      _routeLine = await controller.addLine(
        LineOptions(
          geometry: points,
          lineColor: '#E91E63',
          lineWidth: 5,
          lineOpacity: 0.85,
        ),
      );
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  Future<void> _changeRouteMode(_RouteMode mode) async {
    final destination = _routeDestination;
    final controller = _mapController;
    if (destination == null || controller == null || _routeMode == mode) return;
    setState(() {
      _routeMode = mode;
      _routeDistance = null;
      _routeDuration = null;
    });
    await _drawRouteToDestination(controller, destination);
  }

  String _formatDistance(dynamic meters) {
    final value = (meters as num).toDouble() / 1000;
    return value < 1 ? '${meters.round()} m' : '${value.toStringAsFixed(1)} km';
  }

  String _formatDuration(dynamic seconds) {
    final minutes = ((seconds as num) / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  Widget _routeOptions() {
    if (_routeDestination == null) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 105,
      child: Card(
        color: Colors.black.withValues(alpha: 0.88),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.alt_route, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Cómo llegar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_routeLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<_RouteMode>(
                segments: _RouteMode.values
                    .map(
                      (mode) => ButtonSegment(
                        value: mode,
                        icon: Icon(mode.icon),
                        label: Text(mode.label),
                      ),
                    )
                    .toList(),
                selected: {_routeMode},
                onSelectionChanged: (selected) {
                  if (selected.isNotEmpty) _changeRouteMode(selected.first);
                },
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
              ),
              if (_routeDistance != null && _routeDuration != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$_routeDuration • $_routeDistance',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
        body: Stack(
          children: [
            MapLibreMap(
              initialCameraPosition: const CameraPosition(
                target: _santiagoCenter,
                zoom: 12,
              ),
              minMaxZoomPreference: const MinMaxZoomPreference(3, 18),
              styleString: mapStyle,
              myLocationEnabled: _locationPermissionGranted,
              myLocationTrackingMode: _trackingMode,
              onCameraTrackingDismissed: () {
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
            _routeOptions(),
          ],
        ),
      ),
    );
  }
}

class _EventMarker {
  final ApiEvent event;
  final int index;
  final LatLng coordinate;
  final Uint8List? imageBytes;

  const _EventMarker({
    required this.event,
    required this.index,
    required this.coordinate,
    required this.imageBytes,
  });
}

enum _RouteMode {
  driving('Auto', 'routed-car', Icons.directions_car),
  walking('A pie', 'routed-foot', Icons.directions_walk),
  cycling('Bicicleta', 'routed-bike', Icons.directions_bike);

  final String label;
  final String router;
  final IconData icon;

  const _RouteMode(this.label, this.router, this.icon);
}
