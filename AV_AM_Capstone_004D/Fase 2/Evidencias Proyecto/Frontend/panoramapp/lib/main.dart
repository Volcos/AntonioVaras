import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone/views/Home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:capstone/service/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(const MyApp(initialHome: Home()));

  Future<void> hideNavigationBar() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top],
    );
  }

  // Oculta la navegación inferior, pero conserva visible el status bar superior.
  await hideNavigationBar();

  // Android puede volver a mostrar la navegación después de un gesto.
  await SystemChrome.setSystemUIChangeCallback(
    (systemOverlaysAreVisible) async {
      if (!systemOverlaysAreVisible) return;

      await Future<void>.delayed(const Duration(seconds: 2));
      await SystemChrome.restoreSystemUIOverlays();
      await hideNavigationBar();
    },
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Android puede mostrar temporalmente la navegación durante el arranque.
  // La ocultamos nuevamente después de que la interfaz termine de aparecer.
  Future<void>.delayed(const Duration(seconds: 2), hideNavigationBar);
}

class MyApp extends StatelessWidget {
  final Widget? initialHome;

  const MyApp({
    super.key,
    this.initialHome,
  });


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
