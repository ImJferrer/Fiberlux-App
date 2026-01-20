import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/custom_loader.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';
import 'package:fiberlux_new_app/widgets/serviceDashboard.dart';

import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import '../providers/nox_data_provider.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../models/nox_data_model.dart';
import 'package:shimmer/shimmer.dart';

// Plexus animation classes
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
        2,
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

// Modelo de Promotion actualizado para trabajar con Firestore
class Promotion {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  bool active; // Campo mutable para controlar si se muestra o no

  Promotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.active = true, // Por defecto la promoción está activada
  });

  // Crear una Promotion desde un documento de Firestore, incluyendo el campo "active"
  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      imageUrl: data['imageUrl'] ?? 'assets/images/default_promo.png',
      active: data['active'] ?? true,
    );
  }

  // Convertir la Promotion a un Map para guardar en Firestore, incluyendo el campo "active"
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'active': active,
    };
  }

  // Función para alternar el estado "active" en Firestore
  Future<void> toggleActiveStatus() async {
    active = !active;
    await FirebaseFirestore.instance.collection('promotions').doc(id).update({
      'active': active,
    });
  }
}

// ViewModel actualizado para cargar promociones desde Firestore
class DashboardViewModel extends ChangeNotifier {
  String currentLocation = '';
  List<Promotion> promotions = [];
  bool isLoading = true;
  String? errorMessage;
  NoxDataModel? noxData;

  // Propiedades calculadas
  int get activeServices => noxData?.up ?? 0;
  int get currentIssues => noxData?.down ?? 0;
  int get zonalIssues => noxData?.rpaRouter ?? 0;
  int get fiberIssues => noxData?.rpaOltlos ?? 0;
  int get totalServices =>
      activeServices + currentIssues + zonalIssues + fiberIssues;

  List<int> get progressPercentages {
    final total = totalServices;
    if (total == 0) return [0, 0, 0, 0];
    return [
      (activeServices * 100 ~/ total),
      (currentIssues * 100 ~/ total),
      (zonalIssues * 100 ~/ total),
      (fiberIssues * 100 ~/ total),
    ];
  }

  // Constructor
  DashboardViewModel({NoxDataModel? noxData}) {
    this.noxData = noxData;
    fetchPromotions();
    if (noxData != null) {
      currentLocation = 'RUC: ${noxData.ruc}';
    }
  }

  // Método para cargar promociones desde Firestore
  Future<void> fetchPromotions() async {
    try {
      isLoading = true;
      notifyListeners();

      // Referencia a la colección 'promotions' en Firestore
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('promotions')
          .orderBy('createdAt', descending: true)
          .get();

      // Convertir documentos a objetos Promotion
      promotions = querySnapshot.docs
          .map((doc) => Promotion.fromFirestore(doc))
          .where((promo) => promo.active)
          .toList();

      // Si no hay promociones en Firestore, usar promociones predeterminadas
      if (promotions.isEmpty) {
        promotions = [
          Promotion(
            id: 'default1',
            title: 'Transfiere tus archivos',
            subtitle: 'de manera fácil y rápida',
            imageUrl: 'assets/images/Frame_4.png',
          ),
          Promotion(
            id: 'default2',
            title: 'Ciberseguridad',
            subtitle: 'para tu empresa',
            imageUrl: 'assets/images/Frame_5.png',
          ),
        ];
      }

      isLoading = false;
      errorMessage = null;
    } catch (e) {
      // En caso de error, cargar promociones predeterminadas
      promotions = [
        Promotion(
          id: 'default1',
          title: 'Transfiere tus archivos',
          subtitle: 'de manera fácil y rápida',
          imageUrl: 'assets/images/Frame_4.png',
        ),
        Promotion(
          id: 'default2',
          title: 'Ciberseguridad',
          subtitle: 'para tu empresa',
          imageUrl: 'assets/images/Frame_5.png',
        ),
      ];

      isLoading = false;
      errorMessage = 'No se pudieron cargar las promociones: ${e.toString()}';
      print('Error al cargar promociones: $e');
    }
    notifyListeners();
  }
}

// Enhanced Dashboard with plexus animation
class DashboardWidget extends StatefulWidget {
  final void Function(String status)? onStatusTap; // <<< lo añades

  const DashboardWidget({
    Key? key,
    this.onStatusTap, // <<< lo recibes
  }) : super(key: key);

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final plexusState = PlexusState();

  final colors = <String>[
    '#f8f9fa',
    '#333333',
    '#ffffff',
    '#0056b3',
    '#007bff',
    '#17a2b8',
    '#138496',
    '#28a745',
    '#218838',
    '#f1f1f1',
    '#fefefe',
    '#cccccc',
    '#dddddd',
    '#f5f5f5',
  ];

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..repeat()
          ..addListener(_updatePoints);
    // ¡no conectes aquí!
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
    final session = Provider.of<SessionProvider>(context, listen: false);
    final noxData = Provider.of<NoxDataProvider>(
      context,
      listen: false,
    ).noxData;

    return ChangeNotifierProvider(
      create: (_) => DashboardViewModel(noxData: noxData),
      child: Consumer<DashboardViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFA4238E),
            endDrawer: FiberluxDrawer(),
            body: Stack(
              children: [
                Container(color: const Color(0xFFA4238E)),
                Column(
                  children: [
                    _buildAppBar(context, viewModel),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Stack(
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 150,
                                child: CustomPaint(
                                  painter: SimplePlexusPainter(
                                    plexusState.points,
                                    plexusState.connectionDistance,
                                  ),
                                  size: Size(constraints.maxWidth, 150),
                                ),
                              ),
                              Positioned.fill(
                                top: 0,
                                child: _buildBody(context, viewModel),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String capitalizeWords(String? s) {
    if (s == null) return '';
    return s
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  Widget _buildAppBar(BuildContext context, DashboardViewModel viewModel) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final notifProv = Provider.of<NotificationsProvider>(context); // 👈 NUEVO

    final rawNombre = session.nombre;
    final nombre = (rawNombre == null || rawNombre.trim().isEmpty)
        ? 'Usuario'
        : capitalizeWords(rawNombre);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: const Color(0xFFA4238E),
        child: SafeArea(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Image.asset(
                  'assets/logos/logo_pequeño.png',
                  width: 40,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    '¡Hola, $nombre!',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),

              // 🔔 Campanita de notificaciones
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      NotificationOverlay.isShowing
                          ? Icons.notifications
                          : Icons.notifications_outlined,
                      color: Colors.white, // o tu color
                      size: 28,
                    ),
                    onPressed: () {
                      final notifProv = context.read<NotificationsProvider>();

                      if (NotificationOverlay.isShowing) {
                        // Si ya está abierta, la cerramos normal
                        NotificationOverlay.hide();
                      } else {
                        // 👇 Apenas se abre la campanita, marcamos todas como leídas
                        notifProv.markAllRead();

                        NotificationOverlay.show(
                          context,
                          // el onClose ahora puede quedar vacío o solo para otras cosas
                          onClose: () {
                            // aquí ya NO necesitas tocar las notificaciones
                          },
                        );
                      }
                    },
                  ),

                  // 👇 ESTE ES EL PUNTO ROJO GLOBAL
                  Consumer<NotificationsProvider>(
                    builder: (_, notifProv, __) {
                      if (!notifProv.hasUnread) return const SizedBox.shrink();
                      return Positioned(
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
                      );
                    },
                  ),
                ],
              ),

              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessRestricted() {
    return Container(
      height: 200,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.2),
                blurRadius: 15.0,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48.0, color: Colors.purple),
              SizedBox(height: 16.0),
              Text(
                'Acceso restringido',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.0),
              Text(
                'Verifica tu cuenta para continuar.',
                style: TextStyle(fontSize: 16.0, color: Colors.grey[600]),
              ),
              SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Verificar ahora'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DashboardViewModel viewModel) {
    final session = Provider.of<SessionProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrentLocation(viewModel),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
              ),
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // =================== ESTADOS DEL SERVICIO (ARRIBA) ===================
                if (session.ruc != null) ...[
                  Consumer<GraphSocketProvider>(
                    builder: (_, graphProv, __) {
                      return SizedBox(
                        width: double.infinity,
                        child: ServicesPieChartWidget(
                          socketValores: graphProv.valores
                              .map((e) => e.toDouble())
                              .toList(),
                          socketLeyenda: graphProv.leyenda,
                          onLegendTap: widget.onStatusTap,
                        ),
                      );
                    },
                  ),
                ] else ...[
                  SizedBox(height: 250, child: _buildAccessRestricted()),
                ],

                // =================== NOVEDADES (ABAJO) ===================
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8,
                  ),
                  child: Text(
                    "Novedades",
                    style: TextStyle(
                      color: const Color.fromARGB(255, 185, 31, 167),
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _buildPromotionCards(viewModel),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentLocation(
    DashboardViewModel viewModel, {
    String? socketMessage,
  }) {
    final g = Provider.of<GraphSocketProvider>(context);
    final locationMsg = g.msg.isNotEmpty ? g.msg : viewModel.currentLocation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              'Estás en',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 25.0,
                vertical: 5.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationMsg,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 185, 31, 167),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildPromotionCards(DashboardViewModel viewModel) {
    if (viewModel.isLoading) {
      return SizedBox(
        height: 196,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA4238E)),
          ),
        ),
      );
    }

    if (viewModel.errorMessage != null) {
      // Si hay un error, mostrar un mensaje y las promociones predeterminadas
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Usando promociones guardadas localmente',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          _buildPromotionCarousel(viewModel.promotions),
        ],
      );
    }

    return _buildPromotionCarousel(viewModel.promotions);
  }

  Widget _buildWaitingData() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1) Loader con tu color corporativo
          SizedBox(width: 50, height: 50, child: CustomLoader()),

          const SizedBox(height: 16),

          // 2) Texto con efecto Shimmer
          Shimmer.fromColors(
            baseColor: Colors.purple.shade300,
            highlightColor: Colors.purple.shade100,
            period: const Duration(milliseconds: 1700),
            child: Text(
              'Esperando datos…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para construir el carrusel de promociones
  Widget _buildPromotionCarousel(List<Promotion> promotions) {
    return SizedBox(
      height: 195,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: promotions.length,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemBuilder: (context, index) {
          final promo = promotions[index];
          return Container(
            width: 260,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple[50]!,
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: promo.imageUrl.startsWith('assets/')
                      ? Image.asset(
                          promo.imageUrl,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          promo.imageUrl,
                          height: 105,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 105,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 105,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 20,
                        ),
                      ),
                      Text(promo.subtitle, style: TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
