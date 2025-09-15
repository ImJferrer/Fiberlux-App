import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';

import '../providers/SessionProvider.dart';
import '../providers/googleUser_provider.dart';
import '../providers/graph_socket_provider.dart';
import '../services/auth_service.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:provider/provider.dart';

// Plexus animation classes (reused from your code)
class PlexusState {
  static final PlexusState _instance = PlexusState._internal();
  factory PlexusState() => _instance;
  PlexusState._internal() {
    _generatePoints();
  }

  final List<PlexusPoint> points = [];
  final int nodeCount = 20;
  final double connectionDistance = 100;
  bool isInitialized = false;

  void _generatePoints() {
    if (isInitialized) return;

    final random = math.Random();
    for (int i = 0; i < nodeCount; i++) {
      points.add(
        PlexusPoint(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 300,
          vx: (random.nextDouble() - 0.5) * 1.2,
          vy: (random.nextDouble() - 0.5) * 1.2,
        ),
      );
    }

    isInitialized = true;
  }

  void updatePoints() {
    for (var point in points) {
      point.x += point.vx;
      point.y += point.vy;

      if (point.x < 0 || point.x > 400) {
        point.vx *= -1;
      }
      if (point.y < 0 || point.y > 300) {
        point.vy *= -1;
      }
    }
  }
}

class PlexusPoint {
  double x;
  double y;
  double vx;
  double vy;

  PlexusPoint({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });
}

class SimplePlexusPainter extends CustomPainter {
  final List<PlexusPoint> points;
  final double connectionDistance;

  SimplePlexusPainter(this.points, this.connectionDistance);

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 400;
    final scaleY = size.height / 300;

    for (var point in points) {
      canvas.drawCircle(
        Offset(point.x * scaleX, point.y * scaleY),
        1.5,
        pointPaint,
      );
    }

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final p1 = Offset(points[i].x * scaleX, points[i].y * scaleY);
        final p2 = Offset(points[j].x * scaleX, points[j].y * scaleY);

        final distance = (p2 - p1).distance;

        if (distance < connectionDistance) {
          final opacity = 1.0 - (distance / connectionDistance);
          final linePaint = Paint()
            ..color = Colors.white.withOpacity(opacity * 0.7)
            ..strokeWidth = 0.8;

          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// User Profile Screen
class UserProfileWidget extends StatefulWidget {
  const UserProfileWidget({Key? key}) : super(key: key);

  @override
  State<UserProfileWidget> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final plexusState = PlexusState();
  bool hasNotifications = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();

    _animationController.addListener(_updatePoints);
  }

  void _verificarUsuario() {
    // Limpia la navegación y lleva al login
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _updatePoints() {
    plexusState.updatePoints();
    setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    final google = Provider.of<GoogleUserProvider>(context);

    final ruc = session.ruc ?? "N/A";
    final usuario = session.usuario ?? "Desconocido";
    final nombre = session.nombre ?? google.user?.displayName ?? "Desconocido";
    final apellido = session.apellido ?? "";
    final nombreCompleto = '$nombre $apellido'.trim();
    final rol =
        session.rol ??
        (session.isValidated ? "DESCONOCIDO" : "Verifique su Cuenta");
    final correo = session.email ?? session.usuario ?? 'No disponible';
    final fotoUrl = session.photoUrl ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: FiberluxDrawer(),
      body: Stack(
        children: [
          // Purple background with plexus animation
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFA4238E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(80),
                  bottomRight: Radius.circular(80),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: CustomPaint(
                  painter: SimplePlexusPainter(
                    plexusState.points,
                    plexusState.connectionDistance,
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Back arrow and top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Row(
                        children: [
                          // CAMPANITA CON FUNCIONALIDAD
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  NotificationOverlay.isShowing
                                      ? Icons.notifications
                                      : Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  if (NotificationOverlay.isShowing) {
                                    NotificationOverlay.hide();
                                  } else {
                                    NotificationOverlay.show(
                                      context,
                                      onClose: () {
                                        setState(() {
                                          hasNotifications = false;
                                        });
                                      },
                                    );
                                  }
                                },
                              ),
                              if (hasNotifications)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // MENÚ HAMBURGUESA
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () =>
                                  Scaffold.of(context).openEndDrawer(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Profile title
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Perfil de usuario',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Profile card with avatar inside
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      child: Column(
                        children: [
                          // Profile info card with avatar inside
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(
                                color: const Color(0xFFA4238E).withOpacity(0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFA4238E,
                                  ).withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 30),

                                // Avatar inside the card
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(0xFFA4238E).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: fotoUrl.isNotEmpty
                                        ? Image.network(
                                            fotoUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.person_outline,
                                            size: 50,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                _buildInfoRow('RUC:', ruc),
                                const SizedBox(height: 10),
                                _buildInfoRow('Usuario:', usuario),
                                const SizedBox(height: 10),
                                _buildInfoRow(
                                  'Nombre:',
                                  nombreCompleto.isNotEmpty
                                      ? nombreCompleto
                                      : "Desconocido",
                                ),
                                const SizedBox(height: 10),

                                _buildInfoRow('Rol:', rol),
                                const SizedBox(height: 10),

                                _buildInfoRow('Correo:', correo),

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Action buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFA4238E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: const BorderSide(
                                    color: Color(0xFFA4238E),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Modificar contraseña',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          ElevatedButton.icon(
                            onPressed: _verificarUsuario,
                            icon: Icon(Icons.verified_user),
                            label: Text('Verificar cuenta'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFA4238E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () async {
                              try {
                                await AuthService().signOut();
                              } catch (e) {}

                              final sessionProv = Provider.of<SessionProvider>(
                                context,
                                listen: false,
                              );
                              final googleProv =
                                  Provider.of<GoogleUserProvider>(
                                    context,
                                    listen: false,
                                  );

                              // AGREGAR: Desconectar y limpiar el GraphSocketProvider
                              final graphProv =
                                  Provider.of<GraphSocketProvider>(
                                    context,
                                    listen: false,
                                  );

                              // Desconectar el WebSocket
                              graphProv.disconnect();

                              // Limpiar todos los datos del provider
                              graphProv.clearData();

                              sessionProv.logout();
                              googleProv.clearUser();

                              if (!context.mounted) return;

                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            child: const Text(
                              'Cerrar sesión',
                              style: TextStyle(
                                color: Color(0xFFA4238E),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFA4238E),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
