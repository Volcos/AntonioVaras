import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:capstone/service/location_service.dart';

class MapLocationPickerView extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapLocationPickerView({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapLocationPickerView> createState() => _MapLocationPickerViewState();
}

class _MapLocationPickerViewState extends State<MapLocationPickerView> {
  static const LatLng _santiagoCenter = LatLng(-33.4488897, -70.6692655);
  static const String _mapStyle = 'https://tiles.openfreemap.org/styles/fiord';

  MapLibreMapController? _mapController;
  late LatLng _selectedLocation;
  String? _addressPreview;
  bool _loadingAddress = false;
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _selectedLocation = _santiagoCenter;
    }
    _reverseGeocode(_selectedLocation);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _onMapClick(Point<double> point, LatLng latLng) {
    _selectedLocation = latLng;
    _updateSelectedLocationMarker(latLng);
    _reverseGeocode(latLng);
  }

  void _onCameraMove(CameraPosition position) {
    _selectedLocation = position.target;
  }

  void _onCameraIdle() {
    _reverseGeocode(_selectedLocation);
  }

  void _updateSelectedLocationMarker(LatLng latLng) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(latLng),
    );
  }

  void _reverseGeocode(LatLng location) {
    _geocodeDebounce?.cancel();
    if (!mounted) return;
    setState(() => _loadingAddress = true);
    _geocodeDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final address = await LocationService.obtenerDireccion(
          location.latitude.toString(),
          location.longitude.toString(),
        );
        if (mounted) {
          setState(() {
            _addressPreview = (address != null && address.isNotEmpty)
                ? address
                : 'Lat: ${location.latitude.toStringAsFixed(5)}, Lng: ${location.longitude.toStringAsFixed(5)}';
            _loadingAddress = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _addressPreview = 'Lat: ${location.latitude.toStringAsFixed(5)}, Lng: ${location.longitude.toStringAsFixed(5)}';
            _loadingAddress = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Seleccionar Ubicación'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.check_mark_circled, color: Colors.pinkAccent, size: 28),
            onPressed: () {
              Navigator.pop(context, _selectedLocation);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation,
              zoom: 14,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(3, 18),
            styleString: _mapStyle,
            trackCameraPosition: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onMapClick: _onMapClick,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
          ),

          // Pin fijo en el centro del mapa
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Icon(
                CupertinoIcons.location_solid,
                color: Colors.pinkAccent,
                size: 44,
              ),
            ),
          ),

          // Panel flotante inferior con vista previa de la dirección y botón de confirmación
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.map_pin_ellipse, color: Colors.pinkAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadingAddress
                              ? 'Buscando dirección...'
                              : (_addressPreview ?? 'Ubicación seleccionada'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context, _selectedLocation);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 20),
                    label: const Text(
                      'Confirmar este punto',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
