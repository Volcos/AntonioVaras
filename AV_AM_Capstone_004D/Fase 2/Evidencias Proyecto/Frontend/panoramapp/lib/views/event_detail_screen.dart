import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:capstone/service/api_event.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatelessWidget {
  final ApiEvent event;

  const EventDetailScreen({super.key, required this.event});

  Future<void> _launchUrl(BuildContext context) async {
    final String urlString = event.fuenteInfo;
    
    if (urlString.isEmpty || urlString == 'Ticketmaster') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL del evento no disponible')),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Imagen Full Bleed
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.65,
            child: Image.network(
              event.imagen.isNotEmpty 
                  ? event.imagen 
                  : 'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
              fit: BoxFit.cover,
            ),
          ),
          
          // Degradado suavizado hacia negro puro
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000), // Transparente
                    Color(0xFF000000), // Negro sólido
                  ],
                ),
              ),
            ),
          ),
          
          // Header Flotante (Botón volver y guardar)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(CupertinoIcons.back, () => Navigator.pop(context)),
                _buildGlassButton(CupertinoIcons.bookmark, () {}),
              ],
            ),
          ),
          
          // Contenido desplazable (Información)
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Píldoras de información
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Mostrar múltiples fechas en la pantalla de detalle
                      if (event.fechaInicio.contains('\n'))
                        _buildInfoPill(CupertinoIcons.calendar, 'Varias fechas (Ver abajo)')
                      else
                        _buildInfoPill(CupertinoIcons.calendar, event.fechaInicio),
                      
                      if (event.hora.isNotEmpty) _buildInfoPill(CupertinoIcons.clock, event.hora),
                      _buildInfoPill(CupertinoIcons.location, event.localizacion),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Mostrar el listado de fechas si el evento fue agrupado
                  if (event.fechaInicio.contains('\n')) ...[
                    const Text(
                      'Fechas disponibles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                      ),
                      child: Text(
                        event.fechaInicio, // Imprime cada fecha en una nueva línea
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 15,
                          height: 1.8,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Acerca del evento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    event.descripcion,
                    style: const TextStyle(
                      color: Color(0xB3FFFFFF), // Blanco al 70%
                      fontSize: 16,
                      height: 1.6,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  
                  const SizedBox(height: 120), // Espacio para el botón flotante
                ],
              ),
            ),
          ),
          
          // Botón de acción flotante (Comprar / Visitar)
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: GestureDetector(
                  onTap: () => _launchUrl(context),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Text(
                        'Conseguir Entradas',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x4DFFFFFF), width: 0.5),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
