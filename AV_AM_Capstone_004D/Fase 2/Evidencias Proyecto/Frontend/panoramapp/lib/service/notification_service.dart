import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Inicializar zona horaria para notificaciones programadas
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: DarwinInitializationSettings(),
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Solicitar permiso de notificaciones en Android 13+
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Muestra una notificación inmediata cuando se agrega un evento.
  Future<void> showEventCreatedNotification({
    required String eventName,
    String? dateInfo,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_created_channel',
      'Eventos Creados',
      channelDescription: 'Notificaciones emitidas al crear o añadir un nuevo evento',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final body = dateInfo != null
        ? 'El evento "$eventName" ha sido agregado ($dateInfo).'
        : 'El evento "$eventName" ha sido creado exitosamente.';

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      '¡Evento Agregado! 🎉',
      body,
      platformDetails,
    );
  }

  /// Muestra una notificación inmediata cuando finaliza un evento.
  Future<void> showEventFinishedNotification({
    required String eventName,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_finished_channel',
      'Eventos Finalizados',
      channelDescription: 'Notificaciones emitidas al finalizar un evento',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Evento Finalizado ⏰',
      'El evento "$eventName" ha concluido.',
      platformDetails,
    );
  }

  /// Programa una notificación para cuando el evento finalice en el futuro.
  Future<void> scheduleEventFinishedNotification({
    required int notificationId,
    required String eventName,
    required DateTime finishTime,
  }) async {
    if (finishTime.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_finished_channel',
      'Eventos Finalizados',
      channelDescription: 'Notificaciones emitidas al finalizar un evento',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final scheduledDate = tz.TZDateTime.from(finishTime, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Evento Finalizado ⏰',
        'El evento "$eventName" ha llegado a su fin.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Fallback si la programación exacta requiere permisos adicionales
      await _notificationsPlugin.zonedSchedule(
        notificationId,
        'Evento Finalizado ⏰',
        'El evento "$eventName" ha llegado a su fin.',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
