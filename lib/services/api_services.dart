import 'dart:convert';
import 'package:http/http.dart' as http;

// API DE INICIO DE SESIÓN CON ARCUS

class ApiException implements Exception {
  final String message;
  final int status;
  final String? body;
  ApiException(this.message, {required this.status, this.body});
  @override
  String toString() => '$message (HTTP $status)';
}

class ApiService {
  static const String _baseArcus = 'https://arcus.fiberlux.pe:8080';
  static const String _baseFiberlux = 'http://200.1.179.157:3000';

  /// Login contra Arcus
  static Future<Map<String, dynamic>> arcusLogin({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$_baseArcus/api/login');

    http.Response res;
    try {
      res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException(
        'No se pudo conectar al servicio de autenticación: $e',
        status: -1,
      );
    }

    if (res.statusCode == 200) {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json;
    } else if (res.statusCode == 400) {
      throw ApiException(
        'Usuario o contraseña incorrectos',
        status: 400,
        body: res.body,
      );
    } else {
      throw ApiException(
        'Error de autenticación',
        status: res.statusCode,
        body: res.body,
      );
    }
  }

  /// Registro de token FCM por RUC
  ///
  /// POST -> http://200.1.179.157:3000/FCM
  /// Body:
  /// {
  ///   "ruc": "<string>",
  ///   "tokenFcm": "<string>",
  ///   "grupo": "<string>",
  ///   "vistaRuc": false
  /// }

  static Future<void> sendFcmRegistration({
    required String ruc,
    required String tokenFcm,
    String? grupo,
    bool vistaRuc = false,
  }) async {
    final url = Uri.parse('$_baseFiberlux/FCM');
    final payload = {
      'ruc': ruc,
      'tokenFcm': tokenFcm,
      'grupo': (grupo ?? '').trim(),
      'vistaRuc': vistaRuc,
    };

    http.Response res;
    try {
      res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw ApiException('No se pudo conectar a /FCM: $e', status: -1);
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Error al registrar FCM',
        status: res.statusCode,
        body: res.body,
      );
    }
  }
}
