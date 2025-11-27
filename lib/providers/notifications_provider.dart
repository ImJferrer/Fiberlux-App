import 'package:fiberlux_new_app/services/preticket_local_store.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsProvider extends ChangeNotifier {
  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  bool get hasUnread => _notifications.any((n) => !n.isRead);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

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

  // 👇 NUEVO: eliminar una sola notificación
  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // 👇 NUEVO: eliminar todas las notificaciones
  void clearAll() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    notifyListeners();
  }

  // Para construir desde un RemoteMessage de FCM
  void addFromRemoteMessage(RemoteMessage msg) {
    final data = msg.data;

    final title = msg.notification?.title ?? 'Notificación Fiberlux';
    final body = msg.notification?.body ?? '';

    // Tipo de notificación
    final type = data['type']?.toString();

    // Intentamos extraer preticket si viene
    final preticketStr =
        data['preticket']?.toString() ?? data['preticket_id']?.toString();
    final preticketId = preticketStr != null
        ? int.tryParse(preticketStr)
        : null;

    String? route;
    IconData icon = Icons.notifications;

    if (type == 'preticket_message' && preticketId != null && preticketId > 0) {
      // 🔹 Notificación de chat de PRETICKET
      route = 'preticket_chat';
      icon = Icons.chat_bubble_outline;

      // Guardamos también el mensaje en el store local del chat
      // (no esperamos el Future, lo disparamos "fire & forget")
      PreticketLocalStore.appendFromPush(data);
    } else {
      // Notificación genérica
      route = data['route']; // por si tú ya mandas uno
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
