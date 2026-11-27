import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone/views/Home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:capstone/service/notification_service.dart';
import 'package:capstone/service/push_notification_service.dart';
import 'package:capstone/service/web_service.dart';
import 'package:capstone/service/api_event.dart';
import 'package:capstone/views/event_detail_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  PushNotificationService.registerBackgroundHandler();
  await NotificationService().init(
    onNotificationTap: (eventId) {
      if (eventId != null && eventId.isNotEmpty) {
        _openEventNotification({'id_evento': eventId});
      }
    },
  );
  runApp(const MyApp(initialHome: Home()));
  await PushNotificationService.initialize(
    onEventOpened: _openEventNotification,
  );

  Future<void> hideNavigationBar() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top],
    );
  }

  // Oculta la navegación inferior, pero conserva visible el status bar superior.
  await hideNavigationBar();

  // Android puede volver a mostrar la navegación después de un gesto.
  await SystemChrome.setSystemUIChangeCallback((
    systemOverlaysAreVisible,
  ) async {
    if (!systemOverlaysAreVisible) return;

    await Future<void>.delayed(const Duration(seconds: 2));
    await SystemChrome.restoreSystemUIOverlays();
    await hideNavigationBar();
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Android puede mostrar temporalmente la navegación durante el arranque.
  // La ocultamos nuevamente después de que la interfaz termine de aparecer.
  Future<void>.delayed(const Duration(seconds: 2), hideNavigationBar);
}

Future<void> _openEventNotification(Map<String, dynamic> data) async {
  final eventId = data['id_evento']?.toString();
  final navigator = appNavigatorKey.currentState;
  if (eventId == null || eventId.isEmpty || navigator == null) return;

  try {
    var events = await Webservice.getEvents();
    ApiEvent? event = _findEvent(events, eventId);
    if (event == null) {
      events = await Webservice.refreshEvents();
      event = _findEvent(events, eventId);
    }

    if (event == null) {
      if (navigator.mounted) {
        ScaffoldMessenger.of(navigator.context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró el evento de la notificación.'),
          ),
        );
      }
      return;
    }

    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => EventDetailScreen(event: event!)),
    );
  } catch (error) {
    if (navigator.mounted) {
      ScaffoldMessenger.of(navigator.context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el evento: $error')),
      );
    }
  }
}

ApiEvent? _findEvent(List<ApiEvent> events, String eventId) {
  for (final event in events) {
    if (event.id == eventId || event.alternateIds.contains(eventId)) {
      return event;
    }
  }
  return null;
}

class MyApp extends StatelessWidget {
  final Widget? initialHome;

  const MyApp({super.key, this.initialHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'PanoramAPP',
      debugShowCheckedModeBanner: true,

      // Tema Claro (Día)
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.light, // Fuerza el modo claro
        ),
        useMaterial3: true,
      ),

      // Tema Oscuro (Noche)
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          brightness: Brightness.dark, // Fuerza el modo oscuro
        ),
        useMaterial3: true,
      ),

      // Esta línea hace que la app detecte y aplique automáticamente
      // el tema (claro/oscuro) que el usuario tiene configurado en su celular
      themeMode: ThemeMode.system,

      home: initialHome ?? const Home(),
    );
  }
}
