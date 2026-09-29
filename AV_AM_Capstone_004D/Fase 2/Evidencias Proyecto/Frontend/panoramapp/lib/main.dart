import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone/views/Home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Iconos de batería, hora, etc. en color blanco
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


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
      
      home: Home(),
    );
  }
}
