import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../view/login.dart'; // ajusta el path según tu estructura

class SplashScreen extends StatefulWidget {
  final Widget nextScreen; // Pantalla a la que navegar después del splash

  const SplashScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<PlexusPoint> _points = [];
  final int nodeCount = 25;
  final double connectionDistance = 100;

  @override
  void initState() {
    super.initState();

    // Inicializar los puntos para el plexus
    _generatePoints();

    // Crear controlador de animación para el plexus
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..repeat();

    // Crear controlador para la animación de fade
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Duración del fade
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    // Actualizar en cada frame
    _animationController.addListener(_updatePoints);

    // Programar la navegación después de un tiempo
    // Reemplaza el Timer en initState por este:
    Timer(const Duration(seconds: 3), () async {
      Widget destination = widget.nextScreen;

      // Solo verificar si el nextScreen NO es LoginScreen
      // (si ya va al login, no tiene sentido verificar)
      if (widget.nextScreen is! LoginScreen) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final numeroDocumento = prefs.getString('saved_username') ?? '';

          if (numeroDocumento.isNotEmpty) {
            final response = await http
                .post(
                  Uri.parse('https://zeus.fiberlux.pe/api/verify-session'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'numeroDocumento': numeroDocumento}),
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['sessionValid'] == false) {
                // Pánico activado: limpiar sesión y mandar al login
                await prefs.clear();
                destination = const LoginScreen();
              }
            }
          }
        } catch (_) {
          // Si el servidor no responde, dejamos pasar (no bloqueamos el acceso)
        }
      }

      if (!mounted) return;
      _fadeController.forward().then((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                destination,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    });
  }

  void _generatePoints() {
    final random = math.Random();

    for (int i = 0; i < nodeCount; i++) {
      _points.add(
        PlexusPoint(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 200, // Restringir a la parte inferior
          vx: (random.nextDouble() - 0.5) * 1.3,
          vy: (random.nextDouble() - 0.5) * 1.3,
        ),
      );
    }
  }

  void _updatePoints() {
    for (var point in _points) {
      // Actualizar posición
      point.x += point.vx;
      point.y += point.vy;

      // Rebote en los bordes (simular un canvas de 400x200)
      if (point.x < 0 || point.x > 400) {
        point.vx *= -1;
      }
      if (point.y < 0 || point.y > 200) {
        point.vy *= -1;
      }
    }
    setState(() {}); // Forzar redibujo
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo (cityscape con degradado púrpura)
          Image.asset(
            'assets/images/splash_background.png', // Asegúrate de que la ruta sea correcta
            fit: BoxFit.cover,
          ),

          // Efecto Plexus - solo en la parte inferior púrpura
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height:
                MediaQuery.of(context).size.height *
                0.4, // Ajustar según la imagen
            child: CustomPaint(
              painter: SimplePlexusPainter(_points, connectionDistance),
              size: Size.infinite,
            ),
          ),

          // Logo centrado
          Center(child: Image.asset('assets/logos/logoFiber.png', width: 200)),

          // Overlay para fade out
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              // Si el fade aún no ha comenzado, no renderizamos nada
              if (_fadeController.value == 0) {
                return const SizedBox.shrink();
              }

              // Sino, mostramos un container que se vuelve opaco
              return Container(
                color: Colors.white.withOpacity(_fadeAnimation.value),
              );
            },
          ),
        ],
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

    // Factor de escala para mapear de 400x200 al tamaño real
    final scaleX = size.width / 400;
    final scaleY = size.height / 200;

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
