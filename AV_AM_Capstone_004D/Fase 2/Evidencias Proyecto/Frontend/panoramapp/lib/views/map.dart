import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:capstone/service/location_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadLocationPermission();
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

    await controller.addCircles([
      CircleOptions(
        geometry: const LatLng(-33.4623913, -70.6113274),
        circleColor: '#FF6B6B',
        circleRadius: 10,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
      CircleOptions(
        geometry: const LatLng(-33.465134, -70.659357),
        circleColor: '#FF8FB1',
        circleRadius: 10,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mapStyle = isDarkMode ? _darkMapStyle : _lightMapStyle;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MapLibreMap(
        key: ValueKey('$mapStyle-$_locationPermissionGranted'),
        initialCameraPosition: const CameraPosition(
          target: _santiagoCenter,
          zoom: 12,
        ),
        minMaxZoomPreference: const MinMaxZoomPreference(3, 18),
        styleString: mapStyle,
        myLocationEnabled: _locationPermissionGranted,
        myLocationTrackingMode: MyLocationTrackingMode.none,
        locationEnginePlatforms: LocationService.androidLocationSettings,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        onUserLocationUpdated: _onUserLocationUpdated,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: FloatingActionButton(
          backgroundColor: isDarkMode ? const Color(0x33FFFFFF) : Colors.grey
          ,
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

            await controller.animateCamera(
              CameraUpdate.newLatLngZoom(currentLocation, 15),
            );
          },
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
    );
  }
}