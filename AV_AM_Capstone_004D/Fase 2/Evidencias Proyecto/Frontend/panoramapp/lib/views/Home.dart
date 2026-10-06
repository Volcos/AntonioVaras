import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/service/web_service.dart';
import 'package:capstone/service/bookmark_manager.dart'; // Importamos el manager de guardados
import 'package:capstone/service/location_service.dart';
import 'package:capstone/views/event_detail_screen.dart';
import 'package:capstone/views/saved_events.dart'; // Importamos la nueva vista de guardados
import 'package:capstone/views/map.dart'; // Importamos la vista del mapa

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
    // Guardamos el future de los eventos acá. Así evitamos que la API se llame de nuevo cada vez que hagamos setState.
    _eventsFuture = Webservice.getEvents();
  }

  @override
  Widget build(BuildContext context) {
    // Esto fuerza a que la barra de estado superior (hora, batería) se dibuje de color blanco ya que nuestro fondo es oscuro.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // IndexedStack mantiene el estado de todas las vistas, pero solo muestra una a la vez.
            IndexedStack(
              index: _currentIndex,
              children: [
                _buildListaEventos(),
                const MapView(), // Usamos la vista del mapa en el índice 1 (Explorar)
                const SavedEventsView(), // Usamos la vista separada en el índice 2 (Guardados)
                _buildPlaceholder('Ajustes'), // Índice 3
              ],
            ),

            if (_currentIndex == 0) ...[
              // Degradados para mejorar el contraste del buscador y del navbar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 1.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 190,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Buscador flotante en la vista Home (tipo isla)
            if (_currentIndex == 0)
              Positioned(
                top: 60,
                left: 20,
                right: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    // Le damos este blur grosero para que se mezcle con el fondo
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0x33FFFFFF),
                          width: 0.5,
                        ),
                      ),
                      child: const TextField(
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar eventos...',
                          hintStyle: TextStyle(color: Color(0x80FFFFFF)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          suffixIcon: Icon(
                            CupertinoIcons.search,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // navbar custom tipo luquid glass
            Positioned(
              key: const ValueKey(
                'bottom_nav_bar',
              ), // animacion
              bottom: 30,
              left: 20,
              right: 20,
              child: GlassNavBar(
                currentIndex: _currentIndex,
                onIndexChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: [
                  NavItem(CupertinoIcons.home, 'Inicio'),
                  NavItem(CupertinoIcons.map, 'Explorar'),
                  NavItem(CupertinoIcons.bookmark, 'Guardados'),
                  NavItem(CupertinoIcons.gear, 'Ajustes'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w200,
        ),
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
          padding: const EdgeInsets.only(
            top: 130,
            left: 20,
            right: 20,
            bottom: 120,
          ),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventCard(
              event,
              context,
            ); // Reusamos el diseño de la tarjeta
          },
        );
      },
    );
  }

  // Extrajimos el contenedor de la tarjeta para poder usarlo tanto en Home como en Guardados
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
                      // Usamos el manager para guardar/borrar el evento
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
                      // Escuchamos si este evento en particular está guardado para pintarlo o no
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
                              FutureBuilder<String?>(
                                future: LocationService.obtenerDireccion(
                                  event.latitude,
                                  event.longitude,
                                ),
                                builder: (context, snapshot) {
                                  final location =
                                      snapshot.data?.isNotEmpty == true
                                      ? snapshot.data!
                                      : (event.localizacion.isNotEmpty
                                            ? event.localizacion
                                            : 'Lugar por confirmar');
                                  return Text(
                                    event.fechaInicio.contains('\n')
                                        ? 'Múltiples Fechas • $location'
                                        : '${event.fechaInicio} • $location',
                                    style: const TextStyle(
                                      color: Color(0xB3FFFFFF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
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

class NavItem {
  final IconData icon;
  final String label;

  NavItem(this.icon, this.label);
}

class GlassNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final List<NavItem> items;

  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.items,
  });

  @override
  State<GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<GlassNavBar> {
  double _dragX = 0;
  bool _isDragging = false;
  bool _hasInitialized = false;

  void _onPanStart(DragStartDetails details, double maxWidth) {
    setState(() {
      _isDragging = true;
      final tabWidth = maxWidth / widget.items.length;
      _dragX = details.localPosition.dx - (tabWidth / 2);
      _dragX = _dragX.clamp(0.0, maxWidth - tabWidth);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, double maxWidth) {
    setState(() {
      _isDragging = true;
      _dragX += details.delta.dx;

      final tabWidth = maxWidth / widget.items.length;
      final maxDrag = maxWidth - tabWidth;

      // El clamp evita que la burbuja se arranque fuera de la pantalla.
      _dragX = _dragX.clamp(0.0, maxDrag);
    });
  }

  void _onPanEnd(DragEndDetails details, double maxWidth) {
    final tabWidth = maxWidth / widget.items.length;
    // Lógica para que al soltar la burbuja "se enganche" al ícono más cercano.
    final targetIndex = ((_dragX + tabWidth / 2) / tabWidth).floor().clamp(
      0,
      widget.items.length - 1,
    );

    setState(() {
      _isDragging = false;
    });

    widget.onIndexChanged(targetIndex);
  }

  void _onTapDown(TapDownDetails details, double maxWidth) {
    // Ya no hacemos lógica de set state acá, porque GestureDetector está consumiendo todos los taps,
    // incluso si ocurren en el index actual, causando glitch visual por reseteos.
    // Dejaremos que el _dragX se alinee cuando sea necesario y que la animación se dispare por el currentIndex natural.
  }

  @override
  Widget build(BuildContext context) {
    // Usamos LayoutBuilder para sacar el ancho disponible que tiene el nav y dividirlo.
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / widget.items.length;
        final targetX = widget.currentIndex * tabWidth;

        if (!_hasInitialized) {
          _dragX = targetX;
          _hasInitialized = true;
        }

        // Si NO estamos arrastrando (ej: hubo un tap), usa targetX para que el TweenAnimationBuilder anime hasta ahí.
        final currentX = _isDragging ? _dragX : targetX;

        return GestureDetector(
          onPanStart: (d) => _onPanStart(d, constraints.maxWidth),
          onPanUpdate: (d) => _onPanUpdate(d, constraints.maxWidth),
          onPanEnd: (d) => _onPanEnd(d, constraints.maxWidth),
          // Quitamos onTapDown del detector global de arrastre,
          // usaremos los GestureDetector de cada ícono individual que ya teníamos creados para manejar los taps.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                height: 75,
                decoration: BoxDecoration(
                  color: const Color(0x331C1C1E),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: const Color(0x33FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: TweenAnimationBuilder<double>(
                  duration: _isDragging
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(end: currentX),
                  builder: (context, xOffset, child) {
                    // el Stack sobrepone 3 capas
                    return Stack(
                      children: [
                        // Capa 1: Fondo (íconos y textos apagados)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: widget.items.asMap().entries.map((entry) {
                            int index = entry.key;
                            NavItem item = entry.value;

                            // Agregamos un GestureDetector indivual a la base de cada ícono
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  // Al tocar, sincronizamos el arrastre y avisamos el cambio para iniciar la animación fluida
                                  setState(() {
                                    _isDragging = false;
                                    _dragX = currentX;
                                  });
                                  widget.onIndexChanged(index);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: _buildIcon(item, isActive: false),
                              ),
                            );
                          }).toList(),
                        ),

                        // Capa 2: La lente (burbuja que distorsiona la Capa 1).
                        // Ojo acá, los offset manejan que sobrepase su tab y tenga forma alargada.
                        Positioned(
                          left: xOffset - 5.0,
                          top: 4,
                          bottom: 4,
                          width: tabWidth + 10.0,
                          child: _buildLensBubble(),
                        ),

                        // Capa 3: Íconos y textos prendidos (Rosados y grandes).
                        // Esta capa está ENMASCARADA por el clipper, así que sólo se ve lo que queda dentro de la lupa.
                        ClipRect(
                          clipper: BubbleClipper(x: xOffset, width: tabWidth),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: widget.items
                                .map(
                                  (item) => Expanded(
                                    child: _buildIcon(item, isActive: true),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLensBubble() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 0.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        // Borde falso de aberración (es un sweep gradient transparente con colores). Si se quiere cambiar de color, es acá.
        gradient: const SweepGradient(
          colors: [
            Color(0x99FF0055),
            Color(0x00000000),
            Color(0x9900FFCC),
            Color(0x00000000),
            Color(0x995500FF),
            Color(0x99FF0055),
          ],
          stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            // El filtro destructor para simular una gota esférica oscura.
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                gradient: RadialGradient(
                  center: const Alignment(-0.5, -0.5),
                  radius: 1.5,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(NavItem item, {required bool isActive}) {
    // Acá armamos la seccion del RGB split. Si estamos deslizando de la barra y el ícono es el seleccionado, prende la sombra.
    final shadows = (_isDragging && isActive)
        ? [
            const Shadow(
              color: Color(0xCCFF0055),
              offset: Offset(-2.0, 0),
              blurRadius: 4,
            ),
            const Shadow(
              color: Color(0xCC00FFCC),
              offset: Offset(2.0, 0),
              blurRadius: 4,
            ),
          ]
        : null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          item.icon,
          size: isActive ? 28 : 26,
          color: isActive ? Colors.pinkAccent : const Color(0x80FFFFFF),
          shadows: shadows,
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: TextStyle(
            color: isActive ? Colors.pinkAccent : const Color(0x80FFFFFF),
            fontSize: isActive ? 11 : 10,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            shadows: shadows,
          ),
        ),
      ],
    );
  }
}

// Esta clase se encarga de recortar la capa superior de íconos prendidos.
class BubbleClipper extends CustomClipper<Rect> {
  final double x;
  final double width;

  BubbleClipper({required this.x, required this.width});

  @override
  Rect getClip(Size size) {
    // modificar segun gusto
    return Rect.fromLTWH(x - 5.0, 4, width + 10.0, size.height - 8);
  }

  @override
  bool shouldReclip(BubbleClipper oldClipper) {
    return oldClipper.x != x || oldClipper.width != width;
  }
}
