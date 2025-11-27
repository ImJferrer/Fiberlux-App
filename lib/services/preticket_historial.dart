import 'dart:convert';
import 'package:fiberlux_new_app/models/preticket_chat.dart';
import 'package:http/http.dart' as http;

class PreticketChatService {
  // Base del backend de Arcus
  static const String _baseUrl = 'https://arcus.fiberlux.pe:8080';

  static Future<List<PreticketMessage>> getMessages({
    required int preticketId,
    String? token, // por si tienes JWT o similar
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/api/v1/client/preticket-message/mobile/list/$preticketId/',
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      // Si más adelante necesitas auth, descomentas:
      // if (token != null) 'Authorization': 'Bearer $token',
    };

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception('Error HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;

    // Opcional: validar el "status" del payload
    final apiStatus = decoded['status'];
    if (apiStatus != 200) {
      final msg = decoded['message'] ?? 'Error al obtener mensajes';
      throw Exception('API status $apiStatus: $msg');
    }

    final data = decoded['data'];
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => PreticketMessage.fromJson(e))
        .toList();
  }
}
