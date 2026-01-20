import 'dart:math' as math;
import 'package:flutter/material.dart';

String _textValue(dynamic value, {String fallback = '-'}) {
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? fallback : raw;
}

String _serviceId(Map<String, dynamic> svc) {
  final raw =
      svc['ID_Servicio'] ??
      svc['id_servicio'] ??
      svc['IdServicio'] ??
      svc['ServicioId'] ??
      svc['servicio_id'];
  final id = _textValue(raw, fallback: '');
  return id.isEmpty ? 'Sin ID' : id;
}

String _serviceName(Map<String, dynamic> svc) {
  final raw = svc['Servicio'] ?? svc['servicio'];
  return _textValue(raw);
}

String _serviceEstado(Map<String, dynamic> svc) {
  final raw = svc['Estado'] ?? svc['estado'];
  return _textValue(raw);
}

String _serviceCantidad(Map<String, dynamic> svc) {
  final raw = svc['Cantidad'] ?? svc['cantidad'];
  return _textValue(raw);
}

String _serviceUm(Map<String, dynamic> svc) {
  final raw = svc['UM'] ?? svc['um'];
  return _textValue(raw);
}

Map<String, String> _addressFields(Map<String, dynamic> svc) {
  final raw = svc['direccion'];
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    return {
      'Direccion': _textValue(map['direccion']),
      'Distrito': _textValue(map['distrito']),
      'Provincia': _textValue(map['provincia']),
      'Departamento': _textValue(map['departamento']),
    };
  }
  final addr = _textValue(raw);
  return {
    'Direccion': addr,
    'Distrito': '-',
    'Provincia': '-',
    'Departamento': '-',
  };
}

String _addressText(Map<String, dynamic> svc) {
  final fields = _addressFields(svc);
  final parts = <String>[];
  for (final value in fields.values) {
    if (value != '-' && value.isNotEmpty) parts.add(value);
  }
  return parts.isEmpty ? 'Sin direccion' : parts.join(', ');
}

class ValoresAgregadosListScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> services;

  const ValoresAgregadosListScreen({
    super.key,
    required this.title,
    required this.services,
  });

  List<Map<String, dynamic>> _sortedServices() {
    final list = services.map((e) => Map<String, dynamic>.from(e)).toList();
    list.sort((a, b) => _serviceId(a).compareTo(_serviceId(b)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final items = _sortedServices();
    final borderColor = Colors.grey.shade200;
    const accent = Color(0xFF8B4A9C);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F8),
      appBar: AppBar(title: const Text('Servicios agregados')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              title,
              softWrap: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Sin servicios'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final delay = (index * 0.06).clamp(0.0, 0.6);
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 550),
                        curve: Interval(delay, 1.0, curve: Curves.easeOut),
                        builder: (context, value, child) {
                          return Opacity(opacity: value, child: child);
                        },
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ValoresAgregadosDetailScreen(
                                    service: item,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _serviceId(item),
                                          softWrap: true,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _addressText(item),
                                          softWrap: true,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black26,
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
      ),
    );
  }
}

class ValoresAgregadosDetailScreen extends StatelessWidget {
  final Map<String, dynamic> service;

  const ValoresAgregadosDetailScreen({super.key, required this.service});
  //
  @override
  Widget build(BuildContext context) {
    final id = _serviceId(service);
    final name = _serviceName(service);
    final estado = _serviceEstado(service);
    final cantidad = _serviceCantidad(service);
    final um = _serviceUm(service);
    final address = _addressFields(service);
    const accent = Color(0xFF8B4A9C);
    final borderColor = Colors.grey.shade200;

    Widget headerStat(String label, String value) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    Widget infoTile(String label, String value, IconData icon) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(0.8),
                    const Color(0xFFB91FA7).withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.zero,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B4A9C), Color(0xFFB91FA7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: _PlexusBackground(opacity: 0.45),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ID Servicio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      id,
                                      softWrap: true,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.45),
                                  ),
                                ),
                                child: Text(
                                  estado,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: headerStat('Cantidad', cantidad)),
                              const SizedBox(width: 10),
                              Expanded(child: headerStat('UM', um)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoTile(
                      'Direccion',
                      address['Direccion'] ?? '-',
                      Icons.location_on,
                    ),
                    infoTile(
                      'Distrito',
                      address['Distrito'] ?? '-',
                      Icons.apartment,
                    ),
                    infoTile(
                      'Provincia',
                      address['Provincia'] ?? '-',
                      Icons.location_city,
                    ),
                    infoTile(
                      'Departamento',
                      address['Departamento'] ?? '-',
                      Icons.public,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlexusBackground extends StatefulWidget {
  final double opacity;

  const _PlexusBackground({this.opacity = 0.5});

  @override
  State<_PlexusBackground> createState() => _PlexusBackgroundState();
}

class _PlexusBackgroundState extends State<_PlexusBackground>
    with SingleTickerProviderStateMixin {
  final List<_PlexusPoint> _points = [];
  final int _nodeCount = 20;
  final double _connectionDistance = 100;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _generatePoints();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..addListener(_updatePoints)
          ..repeat();
  }

  void _generatePoints() {
    final random = math.Random();
    for (int i = 0; i < _nodeCount; i++) {
      _points.add(
        _PlexusPoint(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 300,
          vx: (random.nextDouble() - 0.5) * 1.2,
          vy: (random.nextDouble() - 0.5) * 1.2,
        ),
      );
    }
  }

  void _updatePoints() {
    for (var point in _points) {
      point.x += point.vx;
      point.y += point.vy;

      if (point.x < 0 || point.x > 400) {
        point.vx *= -1;
      }
      if (point.y < 0 || point.y > 300) {
        point.vy *= -1;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Opacity(
        opacity: widget.opacity,
        child: CustomPaint(
          painter: _PlexusPainter(_points, _connectionDistance),
        ),
      ),
    );
  }
}

class _PlexusPoint {
  double x;
  double y;
  double vx;
  double vy;

  _PlexusPoint({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });
}

class _PlexusPainter extends CustomPainter {
  final List<_PlexusPoint> points;
  final double connectionDistance;

  _PlexusPainter(this.points, this.connectionDistance);

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
