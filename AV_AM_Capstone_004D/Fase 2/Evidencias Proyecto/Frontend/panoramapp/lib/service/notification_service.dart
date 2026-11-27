import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:capstone/service/api_event.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  void Function(String?)? _onNotificationTap;
  final Set<String> _notifiedNearbyEventIds = {};

  // Configuración de preferencias
  bool notificationsEnabled = true;
  bool newEventsNotificationsEnabled = true;
  bool nearbyNotificationsEnabled = true;
  bool savedEventsNotificationsEnabled = true;
  double nearbyRadiusKm = 5.0;
  bool showRadiusCircle = true;
  final ValueNotifier<double> radiusNotifier = ValueNotifier<double>(5.0);
  final ValueNotifier<bool> showRadiusNotifier = ValueNotifier<bool>(true);

  static const String _keyEnabled = 'notif_enabled';
  static const String _keyNewEvents = 'notif_new_events';
  static const String _keyNearby = 'notif_nearby';
  static const String _keySaved = 'notif_saved';
  static const String _keyRadius = 'notif_radius';
  static const String _keyShowRadius = 'notif_show_radius';

  Future<void> init({void Function(String?)? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap ?? _onNotificationTap;
    if (_initialized) return;

    await loadSettings();

    // Inicializar zona horaria para notificaciones programadas
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _onNotificationTap?.call(response.payload);
      },
    );

    // Solicitar permiso de notificaciones en Android 13+
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    _initialized = true;
  }

  Future<void> showPushMessage(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        'Nuevo aviso';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        'Tienes una nueva notificación.';
    final eventId = message.data['id_evento']?.toString();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'push_messages_channel',
        'Notificaciones push',
        channelDescription: 'Avisos y recordatorios de eventos',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: eventId,
    );
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled = prefs.getBool(_keyEnabled) ?? true;
    newEventsNotificationsEnabled = prefs.getBool(_keyNewEvents) ?? true;
    nearbyNotificationsEnabled = prefs.getBool(_keyNearby) ?? true;
    savedEventsNotificationsEnabled = prefs.getBool(_keySaved) ?? true;
    nearbyRadiusKm = prefs.getDouble(_keyRadius) ?? 5.0;
    showRadiusCircle = prefs.getBool(_keyShowRadius) ?? true;
    radiusNotifier.value = nearbyRadiusKm;
    showRadiusNotifier.value = showRadiusCircle;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    if (!value) {
      await _notificationsPlugin.cancelAll();
    }
  }

  Future<void> setNewEventsNotificationsEnabled(bool value) async {
    newEventsNotificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNewEvents, value);
  }

  Future<void> setNearbyNotificationsEnabled(bool value) async {
    nearbyNotificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNearby, value);
  }

  Future<void> setSavedEventsNotificationsEnabled(bool value) async {
    savedEventsNotificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySaved, value);
  }

  Future<void> setNearbyRadiusKm(double radius) async {
    nearbyRadiusKm = radius;
    radiusNotifier.value = radius;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyRadius, radius);
  }

  Future<void> setShowRadiusCircle(bool value) async {
    showRadiusCircle = value;
    showRadiusNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowRadius, value);
  }

  // ===========================================================================
  // 1. NOTIFICACIONES PARA USUARIOS NORMALES (Clientes y Invitados)
  // ===========================================================================

  /// A) Eventos que se van agregando:
  Future<void> showNewEventAddedNotification({
    required String eventName,
    String? comuna,
  }) async {
    if (!notificationsEnabled || !newEventsNotificationsEnabled) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'user_new_events_channel',
          'Nuevos Eventos',
          channelDescription: 'Alertas de nuevos panoramas y eventos agregados',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final body = (comuna != null && comuna.trim().isNotEmpty)
        ? '¡Se ha publicado "$eventName" en $comuna! Descúbrelo ahora.'
        : '¡Se ha publicado el evento "$eventName"! Descúbrelo ahora.';

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '¡Nuevo Panorama Agregado! 📍',
      body,
      platformDetails,
    );
  }

  /// B) Eventos cercanos a su ubicación (utiliza el radio configurado):
  Future<void> checkAndNotifyNearbyEvents({
    required List<ApiEvent> events,
    required double userLat,
    required double userLng,
  }) async {
    if (!notificationsEnabled || !nearbyNotificationsEnabled) return;

    for (final event in events) {
      final lat = double.tryParse(event.latitude ?? '');
      final lng = double.tryParse(event.longitude ?? '');
      if (lat == null || lng == null) continue;

      final distance = _calculateDistanceKm(userLat, userLng, lat, lng);
      final eventId = event.id ?? '${event.nombre}_${event.fechaInicio}';

      if (distance <= nearbyRadiusKm &&
          !_notifiedNearbyEventIds.contains(eventId)) {
        _notifiedNearbyEventIds.add(eventId);
        await showNearbyEventNotification(
          eventId: eventId,
          eventName: event.nombre,
          distanceKm: distance.toStringAsFixed(1),
        );
      }
    }
  }

  Future<void> showNearbyEventNotification({
    required String eventId,
    required String eventName,
    required String distanceKm,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'user_nearby_channel',
          'Eventos Cercanos',
          channelDescription:
              'Notificaciones sobre eventos cercanos a tu ubicación',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      eventId.hashCode.remainder(100000),
      '¡Evento cerca de ti! 🗺️',
      'El panorama "$eventName" está a solo $distanceKm km de tu ubicación.',
      platformDetails,
    );
  }

  /// C) Eventos guardados próximos a realizarse:
  Future<void> scheduleSavedEventUpcomingNotification({
    required ApiEvent event,
  }) async {
    if (!notificationsEnabled || !savedEventsNotificationsEnabled) return;

    final startDate = _parseDate(event.fechaInicio);
    if (startDate == null) return;

    final notifyTime = startDate.subtract(const Duration(hours: 2));
    final now = DateTime.now();

    final notificationId = (event.id ?? event.nombre).hashCode.remainder(
      100000,
    );

    if (startDate.isBefore(now)) return;

    final scheduledTime = notifyTime.isBefore(now)
        ? now.add(const Duration(minutes: 1))
        : notifyTime;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'user_saved_upcoming_channel',
          'Eventos Guardados Próximos',
          channelDescription:
              'Recordatorios de inicio para los eventos que guardaste',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '¡Tu evento guardado es hoy! 📌',
        'Recordatorio: "${event.nombre}" comenzará muy pronto.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '¡Tu evento guardado es hoy! 📌',
        'Recordatorio: "${event.nombre}" comenzará muy pronto.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelSavedEventNotification(ApiEvent event) async {
    final notificationId = (event.id ?? event.nombre).hashCode.remainder(
      100000,
    );
    await _notificationsPlugin.cancel(notificationId);
  }

  // ===========================================================================
  // 2. NOTIFICACIONES EXCLUSIVAS PARA ORGANIZADORES / ADMINISTRADORES
  // ===========================================================================

  Future<void> showOrganizerEventCreatedNotification({
    required String eventName,
  }) async {
    if (!notificationsEnabled) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'organizer_management_channel',
          'Gestión de Organizadores',
          channelDescription:
              'Confirmaciones de publicación y gestión de eventos',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '¡Tu evento ha sido publicado! 🚀',
      'El evento "$eventName" ya se encuentra visible para todos los usuarios.',
      platformDetails,
    );
  }

  // ===========================================================================
  // MÉTODOS AUXILIARES
  // ===========================================================================

  double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin(...)
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
  }
}
