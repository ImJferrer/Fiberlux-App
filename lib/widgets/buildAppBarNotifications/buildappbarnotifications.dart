import 'package:fiberlux_new_app/view/preticket_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notifications_provider.dart';
import '../../view/notification/lanzamientoFiberlux.dart';

class NotificationsDropdown extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationsDropdown({Key? key, this.onClose}) : super(key: key);

  @override
  State<NotificationsDropdown> createState() => _NotificationsDropdownState();
}

class _NotificationsDropdownState extends State<NotificationsDropdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _closeDropdown() async {
    await _animationController.reverse();
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Marcar como leída en el provider
    context.read<NotificationsProvider>().markAsRead(notification.id);

    // 1️⃣ Primero: si es notificación de chat de PRETICKET
    if (notification.route == 'preticket_chat') {
      final data = notification.data ?? {};

      final preticketStr =
          data['preticket']?.toString() ?? data['preticket_id']?.toString();
      final preticketId = preticketStr != null
          ? int.tryParse(preticketStr)
          : null;

      debugPrint(
        '🧭 [Dropdown] tap preticket_chat, preticketId=$preticketId, data=$data',
      );

      if (preticketId != null && preticketId > 0) {
        final navigator = Navigator.of(context);

        // cierro el dropdown ANTES de navegar
        _closeDropdown();

        navigator.push(
          MaterialPageRoute(
            builder: (_) => PreticketChatScreen(
              preticketId: preticketId,
              ticketCode: data['ticket_code']?.toString(), // opcional
            ),
          ),
        );
        return; // 👈 MUY IMPORTANTE: no seguir con la lógica de launch
      }
    }

    // 2️⃣ Lógica especial que ya tenías para la notificación "destacada"
    final shouldLaunch =
        notification.id == '1' || notification.route == '/launch';

    if (shouldLaunch) {
      final navigatorContext = Navigator.of(context);

      _closeDropdown();

      navigatorContext.push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              FiberluxLaunchScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      _closeDropdown();
      debugPrint('🔔 Notificación normal tapped: ${notification.title}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationsProvider>();
    final notifications = notifProv.notifications;

    return Stack(
      children: [
        // Overlay invisible para cerrar al tocar fuera
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeDropdown,
            child: Container(color: Colors.transparent),
          ),
        ),

        // Dropdown container
        Positioned(
          top: 90,
          right: 16,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value * 20),
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Material(
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 320,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFA4238E).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header del dropdown
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA4238E).withOpacity(0.05),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Notificaciones',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const Spacer(),
                                if (notifications.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      notifProv.clearAll();
                                    },
                                    child: const Text(
                                      'Eliminar todas',
                                      style: TextStyle(
                                        color: Color(0xFFA4238E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (notifProv.hasUnread)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${notifProv.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Lista de notificaciones
                          Flexible(
                            child: notifications.isEmpty
                                ? _buildEmptyState()
                                : ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: notifications.length,
                                    separatorBuilder: (context, index) =>
                                        Divider(
                                          color: Colors.grey[200],
                                          thickness: 0.5,
                                          height: 0.5,
                                        ),
                                    itemBuilder: (context, index) {
                                      final notification = notifications[index];
                                      return Dismissible(
                                        key: ValueKey(notification.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                          ),
                                          color: Colors.redAccent,
                                          child: const Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                          ),
                                        ),
                                        onDismissed: (_) {
                                          context
                                              .read<NotificationsProvider>()
                                              .removeNotification(
                                                notification.id,
                                              );
                                        },
                                        child: _buildNotificationItem(
                                          notification,
                                        ),
                                      );
                                    },
                                  ),
                          ),

                          // Footer: Ver todas las notificaciones
                          if (notifications.length > 0)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  _closeDropdown();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AllNotificationsScreen(),
                                    ),
                                  );
                                },
                                child: const Center(
                                  child: Text(
                                    'Ver todas las notificaciones',
                                    style: TextStyle(
                                      color: Color(0xFFA4238E),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    // 🎯 LA NOTIFICACIÓN ESPECIAL SE VE DIFERENTE
    final bool isSpecial =
        notification.id == '1' || notification.route == '/launch';

    return InkWell(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSpecial
              ? LinearGradient(
                  colors: [
                    const Color(0xFFA4238E).withOpacity(0.1),
                    const Color(0xFF8B1D7C).withOpacity(0.05),
                  ],
                )
              : null,
          color: isSpecial
              ? null
              : (notification.isRead
                    ? Colors.white
                    : Colors.blue[50]?.withOpacity(0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono de la notificación
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: isSpecial
                    ? const LinearGradient(
                        colors: [Color(0xFFA4238E), Color(0xFF8B1D7C)],
                      )
                    : null,
                color: isSpecial
                    ? null
                    : const Color(0xFFA4238E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSpecial
                    ? [
                        BoxShadow(
                          color: const Color(0xFFA4238E).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                notification.icon,
                color: isSpecial ? Colors.white : const Color(0xFFA4238E),
                size: isSpecial ? 22 : 20,
              ),
            ),

            const SizedBox(width: 12),

            // Contenido de la notificación
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: isSpecial ? 15 : 14,
                      fontWeight: isSpecial
                          ? FontWeight.w700
                          : (notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w600),
                      color: isSpecial ? const Color(0xFFA4238E) : Colors.black,
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSpecial
                          ? const Color(0xFF8B1D7C)
                          : Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      if (isSpecial) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFA4238E), Color(0xFF8B1D7C)],
                            ),
                          ),
                          child: const Text(
                            'NUEVO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Indicador de no leída + flecha
            Column(
              children: [
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFA4238E),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isSpecial) ...[
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFA4238E),
                    size: 12,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No hay notificaciones',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Te notificaremos cuando tengas algo nuevo',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

// =========== Overlay helper ===========

class NotificationOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {VoidCallback? onClose}) {
    if (_overlayEntry != null) {
      hide();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => NotificationsDropdown(
        onClose: () {
          hide();
          if (onClose != null) onClose();
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static bool get isShowing => _overlayEntry != null;
}

// =========== PANTALLA COMPLETA: TODAS LAS NOTIFICACIONES ===========

class AllNotificationsScreen extends StatelessWidget {
  const AllNotificationsScreen({Key? key}) : super(key: key);

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, notifProv, _) {
        final notifications = notifProv.notifications;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Notificaciones',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            actions: [
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () {
                    notifProv.clearAll();
                  },
                  child: const Text(
                    'Eliminar todas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          body: notifications.isEmpty
              ? Center(
                  child: Text(
                    'No tienes notificaciones',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.grey[200], height: 0.5),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isSpecial =
                        notification.id == '1' ||
                        notification.route == '/launch';

                    return Dismissible(
                      key: ValueKey(notification.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        color: Colors.redAccent,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        context
                            .read<NotificationsProvider>()
                            .removeNotification(notification.id);
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSpecial
                              ? const Color(0xFFA4238E)
                              : const Color(0xFFA4238E).withOpacity(0.1),
                          child: Icon(
                            notification.icon,
                            color: isSpecial ? Colors.white : Colors.purple,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              notification.subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontFamily: 'Poppins',
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(notification.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        trailing: !notification.isRead
                            ? Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFA4238E),
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () {
                          // marcar como leída
                          context.read<NotificationsProvider>().markAsRead(
                            notification.id,
                          );

                          // misma lógica de navegación especial si quieres
                          final shouldLaunch =
                              notification.id == '1' ||
                              notification.route == '/launch';

                          if (shouldLaunch) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FiberluxLaunchScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
