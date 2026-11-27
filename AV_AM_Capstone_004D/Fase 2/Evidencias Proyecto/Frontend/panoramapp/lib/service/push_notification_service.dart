import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:capstone/service/auth_service.dart';
import 'package:capstone/service/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static bool _initialized = false;
  static Future<void> Function(Map<String, dynamic>)? _onEventOpened;

  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<bool> registerDevice(String jwtToken) async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase no entregó un token para este dispositivo.');
    }

    await _sendDeviceRequest(
      method: 'POST',
      jwtToken: jwtToken,
      body: {'fcm_token': token, 'plataforma': _platformName},
    );
    return true;
  }

  static Future<void> unregisterDevice(String jwtToken) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await _sendDeviceRequest(
      method: 'DELETE',
      jwtToken: jwtToken,
      body: {'fcm_token': token},
    );
  }

  static Future<bool> toggleReminder({
    required String jwtToken,
    required String fechaId,
    required bool activar,
    int horasAntes = 24,
  }) async {
    final uri = Uri.parse(
      '${AuthService.apiBaseUrl}/fechas/${Uri.encodeComponent(fechaId)}/recordatorio',
    );
    final response = await http
        .post(
          uri,
          headers: _headers(jwtToken),
          body: jsonEncode({'activar': activar, 'horas_antes': horasAntes}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo actualizar el recordatorio (${response.statusCode}).',
        uri: uri,
      );
    }
    return true;
  }

  static Future<void> initialize({
    required Future<void> Function(Map<String, dynamic>) onEventOpened,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _onEventOpened = onEventOpened;

    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundMessage(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_dispatchOpen(message.data));
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_registerRefreshedToken(token));
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      unawaited(_dispatchOpen(initialMessage.data));
    }
  }

  static Future<void> _showForegroundMessage(RemoteMessage message) async {
    try {
      await NotificationService().showPushMessage(message);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push notifications',
          context: ErrorDescription(
            'while displaying a foreground FCM message',
          ),
        ),
      );
    }
  }

  static Future<void> _dispatchOpen(Map<String, dynamic> data) async {
    final eventId = data['id_evento']?.toString();
    if (eventId == null || eventId.isEmpty) return;
    await _onEventOpened?.call({'id_evento': eventId});
  }

  static Future<void> _registerRefreshedToken(String token) async {
    try {
      final jwtToken = await AuthService.getToken();
      if (jwtToken == null || jwtToken.isEmpty) return;
      await _sendDeviceRequest(
        method: 'POST',
        jwtToken: jwtToken,
        body: {'fcm_token': token, 'plataforma': _platformName},
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'push notifications',
          context: ErrorDescription('while registering a refreshed FCM token'),
        ),
      );
    }
  }

  static Future<void> _sendDeviceRequest({
    required String method,
    required String jwtToken,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('${AuthService.apiBaseUrl}/usuarios/dispositivo');
    final response = method == 'POST'
        ? await http
              .post(uri, headers: _headers(jwtToken), body: jsonEncode(body))
              .timeout(const Duration(seconds: 15))
        : await http
              .delete(uri, headers: _headers(jwtToken), body: jsonEncode(body))
              .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo ${method == 'POST' ? 'registrar' : 'desvincular'} el dispositivo '
        '(${response.statusCode}).',
        uri: uri,
      );
    }
  }

  static Map<String, String> _headers(String jwtToken) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $jwtToken',
  };

  static String get _platformName {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    throw UnsupportedError('Las notificaciones push requieren Android o iOS.');
  }
}
