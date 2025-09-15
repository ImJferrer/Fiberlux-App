import 'package:flutter/material.dart';

class NotificationItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final DateTime timestamp;
  final String? route;
  final Map<String, dynamic>? data;
  final bool isRead; // ⭐ AGREGA ESTA LÍNEA

  NotificationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.timestamp,
    this.route,
    this.data,
    this.isRead = false, // ⭐ AGREGA ESTA LÍNEA CON DEFAULT false
  });
}
