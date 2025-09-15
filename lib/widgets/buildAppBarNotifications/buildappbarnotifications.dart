import '../../models/notifications.dart';
import '../../view/notification/lanzamientoFiberlux.dart';
import 'package:flutter/material.dart';

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

  // Lista de notificaciones con isRead incluido
  List<NotificationItem> notifications = [
    NotificationItem(
      id: '1', // ⭐ Esta es la especial
      title: '¡La nueva aplicación llegó!',
      subtitle: 'Enterate de todas las cosas que puede hacer fiberlux para ti',
      icon: Icons.star,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
      route: '/launch',
      isRead: false,
    ),
    NotificationItem(
      id: '2',
      title: '¡Nuevo descuento!',
      subtitle: 'Hemos agregado un nuevo descuento para tu empresa',
      icon: Icons.local_offer_outlined,
      timestamp: DateTime.now().subtract(Duration(hours: 2)),
      isRead: false,
    ),
    NotificationItem(
      id: '3',
      title: 'Ingresa al sorteo de...',
      subtitle: 'Te brindamos los mejores beneficios para tu empresa',
      icon: Icons.star_outline,
      timestamp: DateTime.now().subtract(Duration(days: 1)),
      isRead: true,
    ),
  ];

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

  void _closeDropdown() async {
    await _animationController.reverse();
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  // 🎯 NUEVA NAVEGACIÓN - CORREGIDA SIN DELAY PROBLEMÁTICO
  void _handleNotificationTap(NotificationItem notification) {
    // Marcar como leída primero
    if (mounted) {
      setState(() {
        final index = notifications.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          notifications[index] = NotificationItem(
            id: notification.id,
            title: notification.title,
            subtitle: notification.subtitle,
            icon: notification.icon,
            timestamp: notification.timestamp,
            route: notification.route,
            data: notification.data,
            isRead: true,
          );
        }
      });
    }

    // 🎯 NAVEGACIÓN ESPECIAL PARA LA NOTIFICACIÓN ID '1' - SIN DELAY
    if (notification.id == '1') {
      // Guardar el contexto antes de cerrar
      final navigatorContext = Navigator.of(context);

      // Cerrar dropdown y navegar inmediatamente
      _closeDropdown();

      // Navegar usando el contexto guardado
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
          transitionDuration: Duration(milliseconds: 600),
        ),
      );
    } else {
      // Para otras notificaciones, solo cerrar
      _closeDropdown();
      print('Notificación normal tapped: ${notification.title}');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Notificaciones',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Spacer(),
                                if (notifications.any((n) => !n.isRead))
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${notifications.where((n) => !n.isRead).length}',
                                      style: TextStyle(
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
                                      return _buildNotificationItem(
                                        notification,
                                      );
                                    },
                                  ),
                          ),

                          // Footer opcional
                          if (notifications.length > 3)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  _closeDropdown();
                                },
                                child: Center(
                                  child: Text(
                                    'Ver todas las notificaciones',
                                    style: TextStyle(
                                      color: const Color(0xFFA4238E),
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
    bool isSpecial = notification.id == '1';

    return InkWell(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSpecial
              ? LinearGradient(
                  colors: [
                    Color(0xFFA4238E).withOpacity(0.1),
                    Color(0xFF8B1D7C).withOpacity(0.05),
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
                    ? LinearGradient(
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
                          color: Color(0xFFA4238E).withOpacity(0.3),
                          blurRadius: 6,
                          offset: Offset(0, 2),
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
                      color: isSpecial ? Color(0xFFA4238E) : Colors.black,
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
                      color: isSpecial ? Color(0xFF8B1D7C) : Colors.grey[600],
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
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFA4238E), Color(0xFF8B1D7C)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFA4238E),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (isSpecial) ...[
                  SizedBox(height: 4),
                  Icon(
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
          SizedBox(height: 12),
          Text(
            'No hay notificaciones',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
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

// Tu clase NotificationOverlay (sin cambios)
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
