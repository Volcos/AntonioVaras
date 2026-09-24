# Capstone - Panoramapp

Aplicación móvil desarrollada en Flutter para la visualización y gestión de eventos (estilo Ticketmaster), implementando un diseño minimalista "Glassmorphism" inspirado en ecosistemas modernos (iOS).

##  Requisitos Previos

Para poder ejecutar y compilar este proyecto en otro ordenador, necesitas instalar las siguientes herramientas:

1. **Flutter SDK**: [Descargar e instalar Flutter](https://docs.flutter.dev/get-started/install)
   *Nota: El lenguaje Dart viene incluido automáticamente con la instalación de Flutter.*
2. **Android Studio**: [Descargar Android Studio](https://developer.android.com/studio)
   *Necesario para obtener el SDK de Android y crear emuladores virtuales.*

##  Configuración del Entorno (Paso a Paso)

### 1. Clonar el repositorio
Abre tu terminal y ejecuta:
```bash
git clone <URL_DE_TU_REPOSITORIO>
cd panoramapp
```

### 2. Instalar las dependencias
Desde la raíz del proyecto, descarga todas las librerías necesarias con el manejador de paquetes de Flutter:
```bash
flutter pub get
```

### 3. Configurar el Emulador (Android Studio)
1. Abre **Android Studio**.
2. Dirígete a **Device Manager** (Tools > Device Manager o el ícono de móvil en la barra superior).
3. Haz clic en **Create Virtual Device** (Crear Dispositivo Virtual).
4. Elige un modelo de teléfono (ej. Pixel 7) y pulsa "Next".
5. Descarga una imagen de sistema reciente (ej. API 34 o 35) y pulsa "Next" y luego "Finish".
6. Inicia el emulador dándole al botón de **Play** (▶️) en la lista de tus dispositivos.

##  Ejecutar la Aplicación

Con el emulador abierto (o un teléfono físico conectado mediante cable/WiFi con la Depuración USB activada):

Opción 1: Desde la **Terminal**:
```bash
flutter run
```

Opción 2: Desde **Android Studio** o **VS Code**:
Abre el archivo `lib/main.dart` y presiona el botón de **Run** (Play) o la tecla `F5`.

##  Construir el APK (Instalación Manual)

Si deseas generar el archivo ejecutable (`.apk`) para instalar la aplicación en un teléfono físico Android:

Para una versión de **Pruebas** (Debug):
```bash
flutter build apk --debug
```
*El archivo se generará en: `build/app/outputs/flutter-apk/app-debug.apk`*

Para la versión final de **Producción** (Release, requiere configuración de firmado/keystore en el futuro):
```bash
flutter build apk --release
```

##  Arquitectura

Este frontend está diseñado para consumir APIs orquestadas mediante microservicios.
La lógica de conexión a las APIs se encuentra centralizada en el directorio `lib/service/`, de forma que cada scraper (ej. Ticketmaster) tenga su propio archivo de servicio aislado antes de ser unificado por el archivo `web_service.dart`.
