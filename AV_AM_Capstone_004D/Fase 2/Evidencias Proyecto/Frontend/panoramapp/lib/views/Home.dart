import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Iconos de Apple
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/web_service.dart';
import 'package:capstone/views/event_detail_screen.dart'; // Importamos la nueva pantalla

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentIndex = 0;
  late Future<List<ApiEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = Webservice.getEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro profundo (minimalista)
      body: Stack(
        children: [
          // Contenido principal
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildListaEventos(),
              _buildPlaceholder('Explorar'),
              _buildPlaceholder('Guardados'),
              _buildPlaceholder('Ajustes'),
            ],
          ),

          // Search bar flotante tipo isla
          if (_currentIndex == 0)
            Positioned(
              top: 60, 
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF), // Blanco al 15%
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0x33FFFFFF), // Blanco al 20%
                        width: 0.5,
                      ),
                    ),
                    child: const TextField(
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar eventos...',
                        hintStyle: TextStyle(color: Color(0x80FFFFFF)), // Blanco al 50%
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        suffixIcon: Icon(CupertinoIcons.search, color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Navigation Bar flotante (Estilo Glassmorphism Espacial)
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF), // Blanco al 10%
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color(0x4DFFFFFF), // Blanco al 30%
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, CupertinoIcons.square_grid_2x2, 'Inicio'),
                      _buildNavItem(1, CupertinoIcons.compass, 'Explorar'),
                      _buildNavItem(2, CupertinoIcons.bookmark, 'Guardados'),
                      _buildNavItem(3, CupertinoIcons.gear, 'Ajustes'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? icon : icon, // Cupertino icons usually have _fill variants, keeping it simple
            color: isSelected ? Colors.white : const Color(0x80FFFFFF),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0x80FFFFFF),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w200),
      ),
    );
  }

  Widget _buildListaEventos() {
    return FutureBuilder<List<ApiEvent>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.white, radius: 15),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar eventos',
              style: const TextStyle(color: Colors.white54),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No hay eventos disponibles.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        final events = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 130, left: 20, right: 20, bottom: 120),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(builder: (context) => EventDetailScreen(event: event)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 25),
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  image: DecorationImage(
                    image: event.imagen.isNotEmpty
                        ? NetworkImage(event.imagen)
                        : const NetworkImage('https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000), // Negro al 30%
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Gradiente sutil para que el texto resalte
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000), // Transparente
                              Color(0x80000000), // Negro al 50%
                            ],
                            stops: [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    
                    // Botón Guardar (Top Right)
                    Positioned(
                      top: 15,
                      right: 15,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x33000000), // Negro translúcido
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                            ),
                            child: const Icon(CupertinoIcons.bookmark, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                    
                    // Panel de información flotante (Bottom)
                    Positioned(
                      bottom: 15,
                      left: 15,
                      right: 15,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0x33000000), // Negro translúcido
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: const Color(0x4DFFFFFF), width: 0.5),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        event.nombre,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        event.fechaInicio.contains('\n') 
                                            ? 'Múltiples Fechas • ${event.localizacion}'
                                            : '${event.fechaInicio} • ${event.localizacion}',
                                        style: const TextStyle(
                                          color: Color(0xB3FFFFFF), // Blanco al 70%
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Botón pequeño
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Ver',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
