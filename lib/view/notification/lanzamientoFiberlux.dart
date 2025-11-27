import '../main_screen.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String imageUrl;
  final Color gradientStart;
  final Color gradientEnd;

  FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.imageUrl,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

// Pantalla principal de lanzamiento
class FiberluxLaunchScreen extends StatefulWidget {
  @override
  _FiberluxLaunchScreenState createState() => _FiberluxLaunchScreenState();
}

class _FiberluxLaunchScreenState extends State<FiberluxLaunchScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _featuresController;
  late AnimationController _plexusController;

  late Animation<double> _heroSlideAnimation;
  late Animation<double> _heroOpacityAnimation;
  late Animation<double> _featuresSlideAnimation;
  late Animation<double> _featuresOpacityAnimation;

  final List<PlexusPoint> plexusPoints = [];
  final int nodeCount = 15;

  // Características principales
  final List<FeatureItem> features = [
    FeatureItem(
      title: 'Monitoreo en Tiempo Real',
      subtitle: 'Estado completo de tus servicios al instante',
      icon: Icons.analytics_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1551288049-bebda4e38f71?ixlib=rb-4.0.3&w=800',
      gradientStart: Color(0xFF667eea),
      gradientEnd: Color(0xFF764ba2),
    ),
    FeatureItem(
      title: 'Gestión de Tickets',
      subtitle: 'Soporte técnico centralizado y eficiente',
      icon: Icons.support_agent_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?ixlib=rb-4.0.3&w=800',
      gradientStart: Color(0xFF11998e),
      gradientEnd: Color(0xFF38ef7d),
    ),
    FeatureItem(
      title: 'Facturación Digital',
      subtitle: 'Control total de tus pagos y finanzas',
      icon: Icons.receipt_long_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1554224155-6726b3ff858f?ixlib=rb-4.0.3&w=800',
      gradientStart: Color(0xFFfc466b),
      gradientEnd: Color(0xFF3f5efb),
    ),
    FeatureItem(
      title: 'Centro de Ayuda IA',
      subtitle: 'Asistencia inteligente disponible 24/7',
      icon: Icons.smart_toy_outlined,
      imageUrl:
          'https://images.unsplash.com/photo-1677442136019-21780ecad995?ixlib=rb-4.0.3&w=800',
      gradientStart: Color(0xFFa8edea),
      gradientEnd: Color(0xFFfed6e3),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generatePlexusPoints();
    _startAnimations();
  }

  void _initializeAnimations() {
    _heroController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _featuresController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _plexusController = AnimationController(
      duration: Duration(milliseconds: 16),
      vsync: this,
    )..repeat();

    _heroSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic),
    );

    _heroOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _featuresSlideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _featuresController, curve: Curves.easeOutCubic),
    );

    _featuresOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _featuresController, curve: Curves.easeOut),
    );

    _plexusController.addListener(_updatePlexus);
  }

  void _generatePlexusPoints() {
    final random = math.Random();
    for (int i = 0; i < nodeCount; i++) {
      plexusPoints.add(
        PlexusPoint(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 800,
          vx: (random.nextDouble() - 0.5) * 0.8,
          vy: (random.nextDouble() - 0.5) * 0.8,
        ),
      );
    }
  }

  void _updatePlexus() {
    for (var point in plexusPoints) {
      point.x += point.vx;
      point.y += point.vy;

      if (point.x < 0 || point.x > 400) point.vx *= -1;
      if (point.y < 0 || point.y > 800) point.vy *= -1;
    }
    if (mounted) setState(() {});
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _heroController.forward();
    await Future.delayed(Duration(milliseconds: 600));
    _featuresController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _featuresController.dispose();
    _plexusController.dispose();
    super.dispose();
  }

  void _navigateToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, _) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
      (route) => false, // Esto remueve todas las rutas anteriores
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA4238E),
              Color(0xFF8B1D7C),
              Color(0xFF732167),
              Color(0xFF5A1A52),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Plexus Background
            CustomPaint(
              painter: PlexusPainter(plexusPoints),
              size: Size.infinite,
            ),

            // Content
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroSection(),
                    SizedBox(height: 40),
                    _buildFeaturesGrid(),
                    SizedBox(height: 40),
                    _buildCallToAction(),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return AnimatedBuilder(
      animation: _heroController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _heroSlideAnimation.value),
          child: Opacity(
            opacity: _heroOpacityAnimation.value,
            child: Container(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  // Logo Section
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Image.asset(
                        'assets/logos/logoFiber.png',
                        width: 170,
                      ),
                    ),
                  ),

                  SizedBox(height: 40),

                  // Main Title
                  Text(
                    '¡La nueva aplicación llegó!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),

                  SizedBox(height: 13),

                  // Subtitle
                  Text(
                    'Entérate de todas las cosas increíbles\nque Fiberlux puede hacer por ti',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 32),

                  // Stats
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('500+', 'Empresas'),
                        _buildStatItem('99.9%', 'Uptime'),
                        _buildStatItem('24/7', 'Soporte'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return AnimatedBuilder(
      animation: _featuresController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _featuresSlideAnimation.value),
          child: Opacity(
            opacity: _featuresOpacityAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    'Todo lo que necesitas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Una plataforma completa para gestionar tu empresa',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 32),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: features.length,
                    itemBuilder: (context, index) {
                      return _buildFeatureCard(features[index], index);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard(FeatureItem feature, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  feature.gradientStart.withOpacity(0.8),
                  feature.gradientEnd.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: feature.gradientEnd.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(feature.imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                margin: EdgeInsets.all(8),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  feature.icon,
                                  color: feature.gradientEnd,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 12),

                      // Title
                      Expanded(
                        flex: 1,
                        child: Text(
                          feature.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Subtitle
                      Expanded(
                        flex: 1,
                        child: Text(
                          feature.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallToAction() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white.withOpacity(0.9)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: _navigateToDashboard,
                child: Center(
                  child: Text(
                    'Comenzar ahora',
                    style: TextStyle(
                      color: Color(0xFFA4238E),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Únete a las más de 500 empresas que confían en nosotros',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showFeatureDetails(FeatureItem feature) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [feature.gradientStart, feature.gradientEnd],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(feature.icon, color: Colors.white, size: 48),
            ),
            SizedBox(height: 20),
            Text(
              feature.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              feature.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Center(
                    child: Text(
                      'Explorar función',
                      style: TextStyle(
                        color: feature.gradientEnd,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonDialog(FeatureItem feature) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [feature.gradientStart, feature.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with animated glow
                TweenAnimationBuilder<double>(
                  duration: Duration(seconds: 2),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15 + (value * 0.1)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2 * value),
                            blurRadius: 15 * value,
                            spreadRadius: 2 * value,
                          ),
                        ],
                      ),
                      child: Icon(feature.icon, color: Colors.white, size: 48),
                    );
                  },
                ),

                SizedBox(height: 24),

                // Title
                Text(
                  '¡Algo increíble se acerca! 🚀',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 16),

                // Feature name
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    feature.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Description
                Text(
                  'Nuestro equipo de desarrolladores está trabajando día y noche para traerte esta increíble funcionalidad. ¡Será una revolución total en tu experiencia Fiberlux!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),

                SizedBox(height: 20),

                // Benefits preview
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '✨ Lo que puedes esperar:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _getComingSoonMessage(feature.title),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Close button
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: () => Navigator.pop(context),
                      child: Center(
                        child: Text(
                          '¡No puedo esperar! 🎉',
                          style: TextStyle(
                            color: feature.gradientEnd,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Subtitle
                Text(
                  'Te notificaremos cuando esté listo',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getComingSoonMessage(String featureTitle) {
    switch (featureTitle) {
      case 'Centro de Ayuda IA':
        return '• Respuestas instantáneas a tus consultas\n• Asistente inteligente que aprende de ti\n• Soporte multiidioma avanzado\n• Integración con todos tus servicios';
      case 'Programa de Beneficios':
        return '• Puntos por cada pago realizado\n• Descuentos exclusivos en servicios\n• Acceso prioritario a nuevas funciones\n• Regalos sorpresa mensuales';
      case 'Ciberseguridad Enterprise':
        return '• Protección contra amenazas en tiempo real\n• Monitoreo 24/7 de tu red\n• Alertas instantáneas de seguridad\n• Auditorías automáticas mensuales';
      default:
        return '• Funcionalidades innovadoras\n• Experiencia mejorada\n• Integración perfecta\n• Soporte premium incluido';
    }
  }
}

// Clases auxiliares
class PlexusPoint {
  double x, y, vx, vy;

  PlexusPoint({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });
}

class PlexusPainter extends CustomPainter {
  final List<PlexusPoint> points;

  PlexusPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final scaleX = size.width / 400;
    final scaleY = size.height / 800;

    // Draw connections
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final p1 = Offset(points[i].x * scaleX, points[i].y * scaleY);
        final p2 = Offset(points[j].x * scaleX, points[j].y * scaleY);
        final distance = (p2 - p1).distance;

        if (distance < 120) {
          final opacity = (1.0 - (distance / 120)) * 0.3;
          final linePaint = Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..strokeWidth = 0.5;

          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }

    // Draw points
    for (var point in points) {
      canvas.drawCircle(
        Offset(point.x * scaleX, point.y * scaleY),
        2,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
