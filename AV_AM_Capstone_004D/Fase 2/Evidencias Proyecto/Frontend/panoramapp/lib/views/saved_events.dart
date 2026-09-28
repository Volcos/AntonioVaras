import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/bookmark_manager.dart';
import 'package:capstone/views/event_detail_screen.dart';

class SavedEventsView extends StatelessWidget {
  const SavedEventsView({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en la lista global de eventos guardados
    return ValueListenableBuilder<List<ApiEvent>>(
      valueListenable: BookmarkManager().savedEvents,
      builder: (context, savedEvents, child) {
        if (savedEvents.isEmpty) {
          return const Center(
            child: Text(
              'No tienes eventos guardados aún.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          // Padding top es menor acá porque no tenemos la barra de búsqueda estorbando
          padding: const EdgeInsets.only(
            top: 60,
            left: 20,
            right: 20,
            bottom: 120,
          ),
          itemCount: savedEvents.length,
          itemBuilder: (context, index) {
            final event = savedEvents[index];
            return _buildEventCard(event, context);
          },
        );
      },
    );
  }

  // Extraemos la tarjeta para reutilizar el mismo diseño hermoso de la lista de eventos
  Widget _buildEventCard(ApiEvent event, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => EventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 25),
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          color: const Color(0xFF202020),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: Image.network(
                  event.imagen.isNotEmpty
                      ? event.imagen
                      : 'https://images.unsplash.com/photo-1549834125-82d3c48159a3?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x80000000)],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 15,
              right: 15,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: GestureDetector(
                    onTap: () {
                      BookmarkManager().toggleBookmark(event);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x33FFFFFF),
                          width: 0.5,
                        ),
                      ),
                      child: ValueListenableBuilder<List<ApiEvent>>(
                        valueListenable: BookmarkManager().savedEvents,
                        builder: (context, saved, _) {
                          final isSaved = BookmarkManager().isSaved(event);
                          return Icon(
                            isSaved
                                ? CupertinoIcons.bookmark_fill
                                : CupertinoIcons.bookmark,
                            color: isSaved ? Colors.pinkAccent : Colors.white,
                            size: 20,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

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
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: const Color(0x4DFFFFFF),
                        width: 0.5,
                      ),
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
                                  color: Color(0xB3FFFFFF),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
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
  }
}
