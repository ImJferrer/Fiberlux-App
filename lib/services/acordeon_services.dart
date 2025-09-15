// services/acordeon_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AcordeonService {
  static const String _baseUrl = 'http://200.1.179.157:3000';

  static Future<http.Response> getAcordeonData(
      String ruc, String parametro) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/Acordeon/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'RUC': ruc,
          'Parametro': parametro,
        }),
      );

      return response;
    } catch (e) {
      throw Exception('Error al obtener datos del acordeón: $e');
    }
  }
}
