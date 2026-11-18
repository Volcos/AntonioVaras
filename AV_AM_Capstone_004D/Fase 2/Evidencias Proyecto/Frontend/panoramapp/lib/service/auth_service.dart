import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String rut;
  final int? userType;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.rut,
    this.userType,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final user = json['usuario'] is Map
        ? Map<String, dynamic>.from(json['usuario'] as Map)
        : json['user'] is Map
            ? Map<String, dynamic>.from(json['user'] as Map)
            : json['data'] is Map
                ? Map<String, dynamic>.from(json['data'] as Map)
                : json;

    return AuthUser(
      id: (user['id'] ?? user['id_usuario'] ?? '').toString(),
      name: (user['nombre'] ?? user['nombre_usuario'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      rut: (user['rut'] ?? '').toString(),
      userType: user['id_tipo_usuario'] is num
          ? (user['id_tipo_usuario'] as num).toInt()
          : int.tryParse(user['id_tipo_usuario']?.toString() ?? ''),
    );
  }
}

class AuthService {
  static const String _baseUrl =
      'https://mi-api-311188719547.us-central1.run.app';
  static const String _loginUrl = '$_baseUrl/login';
  static const String _usersUrl = '$_baseUrl/usuarios';
  static const String _sessionUserKey = 'panoramapp.auth.user';
  static const String _sessionTokenKey = 'panoramapp.auth.token';

  static Future<AuthUser> login({
    required String name,
    required String password,
  }) async {
    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_loginUrl),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'nombre': name.trim(),
              'contrasena': password,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const AuthException(
        'El servidor tardó demasiado en responder. Intenta nuevamente.',
      );
    } on SocketException {
      throw const AuthException(
        'No hay conexión con el servidor. Revisa tu conexión a Internet.',
      );
    } on HttpException {
      throw const AuthException(
        'No se pudo completar la conexión con el servidor.',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        'Error de conexión: ${error.message}',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'])?.toString()
          : null;
      if (response.statusCode == 429) {
        throw const AuthException(
          'Demasiados intentos. Espera un momento antes de volver a intentar.',
        );
      }
      throw AuthException(
        message ?? 'No se pudo iniciar sesión (${response.statusCode}).',
      );
    }

    if (decoded is! Map) {
      throw const AuthException('La respuesta de inicio de sesión no es válida.');
    }

    final userMap = Map<String, dynamic>.from(decoded);
    final user = AuthUser.fromJson(userMap);
    final token = userMap['token']?.toString();

    if (user.id.isEmpty) {
      throw const AuthException(
        'El login fue válido, pero la API no devolvió el ID del usuario.',
      );
    }

    await _saveSession(user, token);
    return user;
  }

  static Future<AuthUser?> getUserById({
    required String userId,
    String? token,
  }) async {
    final uri = Uri.parse('$_usersUrl/$userId');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return null;
    }

    if (decoded is! Map) return null;
    final responseMap = Map<String, dynamic>.from(decoded);
    final user = AuthUser.fromJson(responseMap);
    return user.id.isEmpty ? null : user;
  }

  static Future<AuthUser> register({
    required String name,
    required String rut,
    required String email,
    required String password,
    required int userType,
  }) async {
    final response = await http
        .post(
          Uri.parse(_usersUrl),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'nombre': name.trim(),
            'rut': rut.trim(),
            'email': email.trim(),
            'contrasena': password,
            'id_tipo_usuario': userType,
            'tipo_usuario': userType == 2 ? 'Cliente' : 'Organizador',
          }),
        )
        .timeout(const Duration(seconds: 12));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'])?.toString()
          : null;
      throw AuthException(
        message ?? 'No se pudo crear el usuario (${response.statusCode}).',
      );
    }

    if (decoded is! Map) {
      throw const AuthException('La respuesta de registro no es válida.');
    }

    final responseMap = Map<String, dynamic>.from(decoded);
    if (responseMap['success'] == false) {
      throw AuthException(
        responseMap['message']?.toString() ??
            'No se pudo crear el usuario.',
      );
    }

    final user = AuthUser.fromJson(responseMap);
    if (user.id.isEmpty) {
      throw const AuthException(
        'El usuario fue creado, pero la API no devolvió su ID.',
      );
    }
    return user;
  }

  static Future<void> _saveSession(AuthUser user, String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sessionUserKey,
        jsonEncode({
          'id': user.id,
          'nombre': user.name,
          'email': user.email,
          'rut': user.rut,
          'id_tipo_usuario': user.userType,
        }),
      );
      if (token != null && token.isNotEmpty) {
        await prefs.setString(_sessionTokenKey, token);
      } else {
        await prefs.remove(_sessionTokenKey);
      }
    } on MissingPluginException {
      return;
    }
  }

  static Future<AuthUser?> getSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionUserKey);
      if (raw == null || raw.isEmpty) return null;

      try {
        return AuthUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        await prefs.remove(_sessionUserKey);
        await prefs.remove(_sessionTokenKey);
        return null;
      }
    } on MissingPluginException {
      return null;
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_sessionTokenKey);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionUserKey);
      await prefs.remove(_sessionTokenKey);
    } on MissingPluginException {
      return;
    }
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}
