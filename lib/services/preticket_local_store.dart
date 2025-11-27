import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreticketLocalStore {
  static const _prefix = 'preticket_chat_';

  static String _key(int preticketId) => '$_prefix$preticketId';

  /// Devuelve la lista "raw" de mensajes almacenados para un preticket.
  /// Cada elemento es el mismo Map que manda el backend en `data` del WS:
  /// { id, preticket, user_id, username, message, created_at, ... }
  static Future<List<Map<String, dynamic>>> loadRaw(int preticketId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(preticketId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('❌ PreticketLocalStore.loadRaw error: $e\n$st');
      return [];
    }
  }

  static Future<void> _saveAllRaw(
    int preticketId,
    List<Map<String, dynamic>> list,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(preticketId), jsonEncode(list));
  }

  /// Agrega un mensaje nuevo al historial local.
  /// Si viene con `id`, evitamos duplicados por id.
  static Future<void> appendRaw(
    int preticketId,
    Map<String, dynamic> data,
  ) async {
    final current = await loadRaw(preticketId);

    final newId = data['id'];
    if (newId != null) {
      final exists = current.any((m) => m['id'] == newId);
      if (!exists) current.add(data);
    } else {
      current.add(data);
    }

    await _saveAllRaw(preticketId, current);
  }

  /// Helper para usar directamente con payloads de FCM
  /// (donde el `preticket` viene en el propio Map de data).
  static Future<void> appendFromPush(Map<String, dynamic> data) async {
    final preticketStr =
        data['preticket']?.toString() ?? data['preticket_id']?.toString() ?? '';
    final preticketId = int.tryParse(preticketStr);
    if (preticketId == null || preticketId <= 0) return;

    await appendRaw(preticketId, data);
  }

  static Future<void> clear(int preticketId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(preticketId));
  }
}
