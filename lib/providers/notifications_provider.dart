import 'package:fiberlux_new_app/services/preticket_local_store.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsProvider extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];

  // 👇 quién soy yo (Arcus user_id)
  int? _currentUserId;
  String? _currentDeviceToken;

  // Mensajes enviados localmente (para deduplicar notificaciones si no hay user_id)
  List<_LocalSentMessage> _recentSent = [];
  final Map<String, bool> _ownershipCache = {}; // cache de author_id por push

  // ====== GETTERS ======
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  bool get hasUnread => _notifications.any((n) => !n.isRead);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // ====== USER ACTUAL (para filtrar mensajes propios) ======
  void setCurrentUserId(int? id) {
    _currentUserId = id;
  }

  void setCurrentDeviceToken(String? token) {
    final t = (token ?? '').trim();
    _currentDeviceToken = t.isEmpty ? null : t;
  }

  void registerLocalSentPreticketMessage({
    required int preticketId,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _pruneRecentSent();
    _recentSent.insert(
      0,
      _LocalSentMessage(
        preticketId: preticketId,
        text: trimmed,
        timestamp: DateTime.now(),
      ),
    );
    // Evitar crecimiento infinito
    if (_recentSent.length > 40) {
      _recentSent = _recentSent.take(40).toList();
    }
  }

  void _pruneRecentSent() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 45));
    _recentSent = _recentSent.where((m) => m.timestamp.isAfter(cutoff)).toList();
  }

  bool _isLocalEcho({
    required int preticketId,
    required String? bodyText,
    required String? dataMessage,
  }) {
    _pruneRecentSent();
    String _norm(String? s) =>
        s == null ? '' : s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    final normalizedIncoming = _norm(
      (bodyText != null && bodyText.isNotEmpty) ? bodyText : dataMessage,
    );
    if (normalizedIncoming.isEmpty) return false;

    for (final m in _recentSent) {
      if (m.preticketId != preticketId) continue;
      if (_norm(m.text) == normalizedIncoming) return true;
    }
    return false;
  }

  bool _isOwnPreticketMessage(Map<String, dynamic> data) {
    // 1) Si el backend manda token de dispositivo, filtramos por eso
    final senderToken = data['sender_device_token'] ??
        data['device_token'] ??
        data['sender_fcm_token'];
    if (_currentDeviceToken != null &&
        senderToken != null &&
        senderToken.toString().isNotEmpty &&
        senderToken.toString() == _currentDeviceToken) {
      return true;
    }

    // 2) Fallback: comparar por user_id
    if (_currentUserId == null) return false;

    // El backend puede mandar user_id o author_id
    final raw =
        data['user_id'] ??
        data['author_id'] ??
        data['authorId'] ??
        data['userId'];

    if (raw == null) return false;

    final msgUserId = int.tryParse(raw.toString());
    if (msgUserId == null) return false;

    return msgUserId == _currentUserId;
  }

  bool _hasSenderInfo(Map<String, dynamic> data) {
    final senderToken = data['sender_device_token'] ??
        data['device_token'] ??
        data['sender_fcm_token'];
    final hasToken =
        senderToken != null && senderToken.toString().trim().isNotEmpty;

    final rawUser = data['user_id'] ??
        data['author_id'] ??
        data['authorId'] ??
        data['userId'];
    final hasUser =
        rawUser != null && rawUser.toString().trim().isNotEmpty;

    return hasToken || hasUser;
  }

  Future<int?> _fetchLastAuthorId({
    required int preticketId,
    required String authToken,
  }) async {
    final uri = Uri.parse(
      'https://arcus.fiberlux.pe:8080/api/v1/client/preticket-message/mobile/list/$preticketId/',
    );

    final resp = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $authToken',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) return null;
    final data = decoded['data'];
    if (data is! List || data.isEmpty) return null;

    final last = data.last;
    if (last is! Map) return null;

    final rawAuthor = last['author_id'] ??
        last['user_id'] ??
        last['authorId'] ??
        last['userId'];
    if (rawAuthor == null) return null;

    return int.tryParse(rawAuthor.toString());
  }

  Future<bool> _isOwnByBackendCheck({
    required int preticketId,
    required String authToken,
    required int currentUserId,
    required String cacheKey,
  }) async {
    if (_ownershipCache.containsKey(cacheKey)) {
      return _ownershipCache[cacheKey] ?? false;
    }
    try {
      final authorId = await _fetchLastAuthorId(
        preticketId: preticketId,
        authToken: authToken,
      );
      final isMine = (authorId != null && authorId == currentUserId);
      _ownershipCache[cacheKey] = isMine;
      return isMine;
    } catch (e) {
      debugPrint('⚠️ Error consultando author_id backend: $e');
      return false; // en duda, mostramos la notificación
    }
  }

  // ====== CRUD BÁSICO ======
  void addNotification(NotificationItem item) {
    _notifications.insert(0, item); // arriba del todo
    notifyListeners();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllRead() {
    bool changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAll() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    notifyListeners();
  }

  // ====== Construir desde RemoteMessage de FCM ======
  Future<void> addFromRemoteMessage(
    RemoteMessage msg, {
    int? currentUserId,
    String? authToken,
  }) async {
    final data = msg.data;

    if (currentUserId != null) _currentUserId ??= currentUserId;

    final title = msg.notification?.title ?? 'Notificación Fiberlux';
    final body = msg.notification?.body ?? '';

    final type = data['type']?.toString();

    // preticket / preticket_id
    final preticketStr =
        data['preticket']?.toString() ?? data['preticket_id']?.toString();
    final preticketId = preticketStr != null
        ? int.tryParse(preticketStr)
        : null;

    String? route;
    IconData icon = Icons.notifications;

    if (type == 'preticket_message' && preticketId != null && preticketId > 0) {
      // Siempre queremos guardar el mensaje en el store local del chat
      PreticketLocalStore.appendFromPush(data);

      // 👇 PERO si el mensaje lo envié yo, NO generamos notificación
      if (_isOwnPreticketMessage(data)) {
        debugPrint(
          '🔕 Ignorando notificación de mi propio mensaje (preticket)',
        );
        return;
      }

      // 🔍 Si no vino user_id / token, consulta author_id al backend y filtra
      final cacheKey = msg.messageId ??
          'preticket_${preticketId}_${body.hashCode}';
      final shouldCheckBackend = !_hasSenderInfo(data) &&
          currentUserId != null &&
          authToken != null;
      if (shouldCheckBackend) {
        final isMine = await _isOwnByBackendCheck(
          preticketId: preticketId,
          authToken: authToken,
          currentUserId: currentUserId,
          cacheKey: cacheKey,
        );
        if (isMine) {
          debugPrint(
            '🔕 Ignorando notificación (author_id backend coincide con currentUserId)',
          );
          return;
        }
      }

      // 👇 Heurística offline: si coincide con un mensaje que acabo de enviar,
      // asumimos que es eco del mismo dispositivo y no notificamos.
      final incomingBody =
          (body.isNotEmpty ? body : data['message']?.toString() ?? '');
      if (_isLocalEcho(
        preticketId: preticketId,
        bodyText: incomingBody,
        dataMessage: data['message']?.toString(),
      )) {
        debugPrint(
          '🔕 Ignorando notificación (eco local sin user_id) preticket=$preticketId',
        );
        return;
      }

      // Notificación de chat para mensajes de OTROS
      route = 'preticket_chat';
      icon = Icons.chat_bubble_outline;
    } else {
      // Notificación genérica
      route = data['route'];
    }

    final item = NotificationItem(
      id: msg.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      subtitle: body,
      icon: icon,
      timestamp: DateTime.now(),
      route: route,
      data: data,
      isRead: false,
    );

    addNotification(item);
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final DateTime timestamp;
  final String? route;
  final Map<String, dynamic>? data;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.timestamp,
    this.route,
    this.data,
    this.isRead = false,
  });

  NotificationItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    IconData? icon,
    DateTime? timestamp,
    String? route,
    Map<String, dynamic>? data,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      timestamp: timestamp ?? this.timestamp,
      route: route ?? this.route,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
    );
  }
}

class _LocalSentMessage {
  final int preticketId;
  final String text;
  final DateTime timestamp;

  _LocalSentMessage({
    required this.preticketId,
    required this.text,
    required this.timestamp,
  });
}
