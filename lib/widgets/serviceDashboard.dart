import '../view/entidadDashboard.dart';
import '../view/home.dart';
import 'TweenAnimationBuilder/animatedPieChart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import 'dart:math' as math;

class ServicesPieChartWidget extends StatefulWidget {
  final double centerHolePercentage;
  final List<double>? socketValores;
  final List<String>? socketLeyenda;
  final String? socketMensaje;
  final void Function(String status)? onLegendTap;

  const ServicesPieChartWidget({
    Key? key,
    this.centerHolePercentage = 0.8,
    this.socketValores,
    this.socketLeyenda,
    this.socketMensaje,
    this.onLegendTap,
  }) : super(key: key);

  @override
  State<ServicesPieChartWidget> createState() => _ServicesPieChartWidgetState();
}

class _ServicesPieChartWidgetState extends State<ServicesPieChartWidget> {
  int _refreshIndex = 0;

  void _handleLegendTap(String label) {
    final upper = label.toUpperCase();

    // 1) Si el padre definió un callback, usarlo y salir
    if (widget.onLegendTap != null) {
      widget.onLegendTap!(upper);
      return;
    }

    // 2) Comportamiento por defecto
    if (upper == 'UP') {
      // Ir a EntidadDashboard con filtro UP
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const EntidadDashboard(initialStatus: 'UP'),
        ),
      );
    } else if (upper == 'DOWN') {
      // “Solo pasen y ya”: entrar sin filtro
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const EntidadDashboard()));
    }
  }

  Widget _legendSquare({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Flecha dentro de “píldora”
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            // Etiqueta + contador grande
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .4,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1️⃣ Datos (solo UP y DOWN desde Detalle/acordeón)
    final graphProv = context.watch<GraphSocketProvider>();

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim()) ?? 0;
    }

    int upCount = 0;
    int downCount = 0;

    // 🟢 Prioridad: bloque "Grafica" del socket (ej: {"DOWN":"1","UP":"106"})
    // Asegúrate que tu provider exponga algo como: Map<String,dynamic> grafica
    // 1) Grafica (lo que necesitas para Home)
    if (graphProv.grafica.isNotEmpty) {
      final g = graphProv.grafica;
      upCount = _toInt(g['UP'] ?? g['Up'] ?? g['up']);
      downCount = _toInt(g['DOWN'] ?? g['Down'] ?? g['down']);
    }
    // 2) Fallback: agregados (leyenda/valores)
    else if (graphProv.leyenda.isNotEmpty && graphProv.valores.isNotEmpty) {
      final upIdx = graphProv.leyenda.indexWhere(
        (l) => l.toUpperCase() == 'UP',
      );
      final dnIdx = graphProv.leyenda.indexWhere(
        (l) => l.toUpperCase() == 'DOWN',
      );
      if (upIdx >= 0 && upIdx < graphProv.valores.length) {
        upCount = graphProv.valores[upIdx].toInt();
      }
      if (dnIdx >= 0 && dnIdx < graphProv.valores.length) {
        downCount = graphProv.valores[dnIdx].toInt();
      }
    }
    // 3) Fallback: conteo desde acordeón
    else if (graphProv.acordeon.isNotEmpty) {
      upCount = (graphProv.acordeon['UP'] as List?)?.length ?? 0;
      downCount = (graphProv.acordeon['DOWN'] as List?)?.length ?? 0;
    }
    // 4) Fallback: props/VM
    else {
      final rawVals =
          widget.socketValores ??
          Provider.of<DashboardViewModel>(
            context,
            listen: false,
          ).progressPercentages.map((p) => p.toDouble()).toList();
      final rawLeg = widget.socketLeyenda ?? const <String>[];
      for (int i = 0; i < rawVals.length && i < rawLeg.length; i++) {
        final l = rawLeg[i].toUpperCase();
        if (l == 'UP') upCount = rawVals[i].toInt();
        if (l == 'DOWN') downCount = rawVals[i].toInt();
      }
    }

    final valores = <double>[upCount.toDouble(), downCount.toDouble()];
    final leyenda = <String>['UP', 'DOWN'];
    final total = upCount + downCount;
    final mensaje = widget.socketMensaje ?? 'Servicios: $total';

    // 2️⃣ Controles de WebSocket
    final session = context.read<SessionProvider>();
    final ruc = session.ruc ?? '';

    final socketControls = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // 🔴/🟢 LED
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: graphProv.isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Texto estado
          Text(
            graphProv.isConnected ? 'Conectado' : 'Desconectado',
            style: TextStyle(
              color: graphProv.isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 🔌 Encender/Apagar WS
          IconButton(
            icon: Icon(
              graphProv.isConnected ? Icons.power_settings_new : Icons.power,
              color: Colors.purple,
            ),
            tooltip: graphProv.isConnected ? 'Apagar WS' : 'Encender WS',
            onPressed: () {
              if (ruc.isEmpty) return;
              graphProv.isConnected
                  ? graphProv.disconnect()
                  : graphProv.connect(ruc, graphProv.rawColors);
            },
          ),
          // 🔄 Pedir gráfica
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.purple),
            tooltip: 'Pedir gráfica',
            onPressed: graphProv.isConnected
                ? () {
                    graphProv.requestGraphData(ruc);
                    // ¡aquí forzamos un rebuild con nueva Key!
                    setState(() => _refreshIndex++);
                  }
                : null,
          ),
        ],
      ),
    );

    // 3️⃣ Colores fijos por etiqueta (siempre UP=verde, DOWN=rojo)
    Color _colorFor(String label) {
      switch (label.toUpperCase()) {
        case 'UP':
          return Colors.green;
        case 'DOWN':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    final colors = leyenda
        .map(_colorFor)
        .toList(); // ['UP','DOWN'] -> [verde, rojo]

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // — TÍTULO —
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 16, bottom: 8),
          child: Text(
            'Estado de servicios',
            style: TextStyle(
              color: Color(0xFFB91FA7),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // — CONTROLES WS —
        socketControls,

        // — GRÁFICO + LEYENDA LADO A LADO —
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ► Gráfico
              Expanded(
                flex: 5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedPieChart(
                      key: ValueKey(_refreshIndex),
                      percentages: valores,
                      colors: colors,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mensaje.split(':').last.trim(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'SERVICIOS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // ► Leyenda (up y down)
              Expanded(
                flex: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final totalH = constraints.maxHeight;
                    final boxH = ((totalH - spacing) / 2).clamp(84.0, totalH);

                    return Column(
                      children: [
                        SizedBox(
                          height: boxH,
                          child: _legendSquare(
                            label: 'UP',
                            count: upCount,
                            color: Colors.green,
                            icon: Icons.arrow_upward_rounded,
                            onTap: () => _handleLegendTap('UP'),
                          ),
                        ),
                        const SizedBox(height: spacing),
                        SizedBox(
                          height: boxH,
                          child: _legendSquare(
                            label: 'DOWN',
                            count: downCount,
                            color: Colors.red,
                            icon: Icons.arrow_downward_rounded,
                            onTap: () => _handleLegendTap('DOWN'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

/// Pintor para dona con espacios
class CirclePieChartPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;
  final double donutThickness;
  final double spaceBetweenSections;
  final double centerHolePercentage;

  CirclePieChartPainter({
    required List<double> percentages,
    required this.colors,
    this.donutThickness = 25.0,
    this.spaceBetweenSections =
        4.0, // Asegúrate de que el valor se pase correctamente
    this.centerHolePercentage = 0.6,
  }) : percentages = percentages;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.45;
    final innerRadius = outerRadius * centerHolePercentage;
    final effectiveThickness = outerRadius - innerRadius;

    // fondo blanco
    final background = Paint()..color = Colors.white;
    canvas.drawCircle(center, outerRadius, background);

    // dibuja cada arco con el espacio entre secciones
    final total = percentages.fold<double>(0, (a, b) => a + b);
    double startAngle = -math.pi / 2; // Comienza desde arriba
    for (int i = 0; i < percentages.length; i++) {
      if (percentages[i] == 0) continue;
      final sweep = 2 * math.pi * (percentages[i] / total);
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveThickness;

      // Aplica el espacio entre las secciones sumando el valor de `spaceBetweenSections` al ángulo de inicio
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: innerRadius + (effectiveThickness / 2),
        ),
        startAngle,
        sweep,
        false,
        paint,
      );

      // Aumenta el ángulo de inicio para la siguiente sección, añadiendo el espacio entre secciones
      startAngle +=
          sweep +
          (spaceBetweenSections *
              math.pi /
              180); // Esto suma el espacio entre secciones
    }

    // agujero central
    final hole = Paint()..color = Colors.white;
    canvas.drawCircle(center, innerRadius, hole);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
