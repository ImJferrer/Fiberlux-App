import 'package:flutter/material.dart';
import 'dart:math' as math;

// Singleton para mantener el estado del plexus en toda la aplicación
class PlexusState {
  // Instancia singleton
  static final PlexusState _instance = PlexusState._internal();
  factory PlexusState() => _instance;
  PlexusState._internal() {
    _generatePoints();
  }

  // Estado compartido
  final List<PlexusPoint> points = [];
  final int nodeCount = 30;
  final double connectionDistance = 100;
  bool isInitialized = false;

  void _generatePoints() {
    if (isInitialized) return; // Solo generar una vez

    final random = math.Random();
    for (int i = 0; i < nodeCount; i++) {
      points.add(
        PlexusPoint(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 300,
          vx: (random.nextDouble() - 0.5) * 0.8,
          vy: (random.nextDouble() - 0.5) * 0.8,
        ),
      );
    }

    isInitialized = true;
  }

  void updatePoints() {
    for (var point in points) {
      // Actualizar posición
      point.x += point.vx;
      point.y += point.vy;

      // Rebote en los bordes (simular un canvas de 400x300)
      if (point.x < 0 || point.x > 400) {
        point.vx *= -1;
      }
      if (point.y < 0 || point.y > 300) {
        point.vy *= -1;
      }
    }
  }
}

class FiberluxBaseLayout extends StatefulWidget {
  final Widget child;

  const FiberluxBaseLayout({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<FiberluxBaseLayout> createState() => _FiberluxBaseLayoutState();
}

class _FiberluxBaseLayoutState extends State<FiberluxBaseLayout>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final plexusState = PlexusState(); // Usar la instancia singleton

  @override
  void initState() {
    super.initState();

    // Crear controlador de animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..repeat();

    // Actualizar en cada frame
    _animationController.addListener(_updatePoints);
  }

  void _updatePoints() {
    plexusState.updatePoints(); // Actualizar puntos en el singleton
    setState(() {}); // Forzar redibujo
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Fondo con gradiente
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.fromARGB(
                          255, 128, 42, 118), // Color morado más claro
                      Color(0xFF772D8B), // Color morado más oscuro
                    ],
                  ),
                ),
              ),
            ),

            // Efecto Plexus - en la parte superior
            Positioned(
              top: 0,
              bottom: MediaQuery.of(context).size.height * 0.5,
              left: 0,
              right: 0,
              child: CustomPaint(
                painter: SimplePlexusPainter(
                    plexusState.points, plexusState.connectionDistance),
                size: Size.infinite,
              ),
            ),

            // Contenido principal
            Column(
              children: [
                // Sección del logo (fija)
                Expanded(
                  flex: 3,
                  child: Container(
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/logos/logoFiber.png',
                      width: 200,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Sección del contenido (variable)
                Expanded(
                  flex: 7,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

    // Factor de escala para mapear de 400x300 al tamaño real
    final scaleX = size.width / 400;
    final scaleY = size.height / 300;

    // Dibujar cada punto
    for (var point in points) {
      canvas.drawCircle(
        Offset(point.x * scaleX, point.y * scaleY),
        2, // Radio del punto
        pointPaint,
      );
    }

    // Dibujar conexiones entre puntos
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final p1 = Offset(points[i].x * scaleX, points[i].y * scaleY);
        final p2 = Offset(points[j].x * scaleX, points[j].y * scaleY);

        final distance = (p2 - p1).distance;

        if (distance < connectionDistance) {
          final opacity = 1.0 - (distance / connectionDistance);
          final linePaint = Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..strokeWidth = 1;

          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
