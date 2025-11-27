import 'package:fiberlux_new_app/view/home.dart';
import '../view/entidadDashboard.dart';
import 'TweenAnimationBuilder/animatedPieChart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import 'dart:math' as math;

/// —————————————————————————————————————————————————————————————
///  ServicesPieChartWidget (auto-sync RUC/Grupo)
/// —————————————————————————————————————————————————————————————
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

  // Snapshot del “deseo” (no del estado actual del socket)
  bool? _lastWantGroup;
  String? _lastWantRuc;
  String? _lastWantGrupo;

  // Intenta reconectar el socket según la PREFERENCIA (SessionProvider),
  // no según el estado actual del socket.
  void _maybeAutoSyncSocket(
    SessionProvider session,
    GraphSocketProvider g,
  ) async {
    final wantGroup = session.grupoEconomicoOrRuc;

    final wantRuc = (session.ruc ?? g.ruc ?? '').trim();
    String wantGrupo =
        (session.grupoNombre ?? g.grupo ?? g.currentGroupName ?? '').trim();

    // Nada cambió en la intención: no toques el socket.
    final nothingChanged =
        (_lastWantGroup == wantGroup) &&
        (_lastWantRuc == wantRuc) &&
        (_lastWantGrupo == wantGrupo);

    if (nothingChanged) return;

    // Guarda snapshot de intención
    _lastWantGroup = wantGroup;
    _lastWantRuc = wantRuc;
    _lastWantGrupo = wantGrupo;

    // Si queremos Grupo pero aún no hay nombre: hidrata usando RUC, luego salta a Grupo
    if (wantGroup && wantGrupo.isEmpty) {
      if (wantRuc.isEmpty) return; // no hay forma de hidratar

      // 1) Conecta por RUC si hace falta
      if (!g.isConnected || g.usingGroup) {
        await g.connect(wantRuc, g.rawColors);
        try {
          await g.waitUntilConnected();
        } catch (_) {}
      }

      // 2) Pide datos para que llegue el resumen con el nombre de grupo
      g.requestGraphData(wantRuc);

      // 3) Revisa en breve si ya apareció el nombre del grupo y salta
      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        if (!session.grupoEconomicoOrRuc) return; // el usuario lo desactivó

        final resolvedGrupo =
            (session.grupoNombre ?? g.currentGroupName ?? g.grupo ?? '').trim();

        if (resolvedGrupo.isNotEmpty) {
          // persiste para futuras pantallas
          if ((session.grupoNombre ?? '').trim().isEmpty) {
            context.read<SessionProvider>().setGrupoNombre(resolvedGrupo);
          }
          await g.connectByGroup(resolvedGrupo, g.rawColors);
          try {
            await g.waitUntilConnected();
          } catch (_) {}
          g.fetchGroupSummary();
          if (mounted) setState(() => _refreshIndex++);
        }
      });

      return; // salimos por ahora; la reconexión a grupo se intentará en el delayed
    }

    // Conexión directa al destino deseado
    if (wantGroup) {
      if (wantGrupo.isEmpty) return;
      await g.connectByGroup(wantGrupo, g.rawColors);
      try {
        await g.waitUntilConnected();
      } catch (_) {}
      g.fetchGroupSummary();
    } else {
      if (wantRuc.isEmpty) return;
      await g.connect(wantRuc, g.rawColors);
      try {
        await g.waitUntilConnected();
      } catch (_) {}
      g.requestGraphData(wantRuc);
    }

    if (mounted) setState(() => _refreshIndex++);
  }

  void _handleLegendTap(String label) {
    final upper = label.toUpperCase();
    if (widget.onLegendTap != null) {
      widget.onLegendTap!(upper);
      return;
    }
    switch (upper) {
      case 'UP':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EntidadDashboard()));
        break;
      case 'DOWN':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EntidadDashboard()));
        break;
      case 'ALL':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const EntidadDashboard()));
        break;
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
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
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
    final graphProv = context.watch<GraphSocketProvider>();
    final session = context.watch<SessionProvider>();

    // Auto-sync tras cada build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoSyncSocket(session, graphProv);
    });

    final isGroup = session.grupoEconomicoOrRuc; // ← usamos la intención

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s) ?? 0;
    }

    // ——————————————————————————————————
    // SERIES para el gráfico
    // ——————————————————————————————————
    List<String> seriesLabels = [];
    List<double> seriesValues = [];
    List<Color> seriesColors = [];

    if (isGroup &&
        graphProv.leyenda.isNotEmpty &&
        graphProv.valores.isNotEmpty) {
      seriesLabels = List<String>.from(graphProv.leyenda);
      seriesValues = List<double>.from(graphProv.valores);
      if (graphProv.colors.isNotEmpty &&
          graphProv.colors.length >= seriesLabels.length) {
        seriesColors = List<Color>.from(
          graphProv.colors.take(seriesLabels.length),
        );
      } else {
        seriesColors = seriesLabels.map((l) {
          switch (l.toUpperCase()) {
            case 'UP':
              return Colors.green;
            case 'DOWN':
              return Colors.red;
            default:
              return Colors.grey;
          }
        }).toList();
      }
    } else if (graphProv.detalle.isNotEmpty) {
      final d = graphProv.detalle;
      final up = _toInt(d['UP'] ?? d['Up'] ?? d['up']);
      int otros = 0;
      d.forEach((k, v) {
        final key = k.toString().toUpperCase();
        if (key != 'UP') otros += _toInt(v);
      });
      seriesLabels = const ['DOWN', 'UP'];
      seriesValues = [otros.toDouble(), up.toDouble()];
      seriesColors = [Colors.red, Colors.green];
    } else if (graphProv.grafica.isNotEmpty) {
      final g = graphProv.grafica;
      final up = _toInt(g['UP'] ?? g['Up'] ?? g['up']);
      final dn = _toInt(g['DOWN'] ?? g['Down'] ?? g['down']);
      seriesLabels = const ['DOWN', 'UP'];
      seriesValues = [dn.toDouble(), up.toDouble()];
      seriesColors = [Colors.red, Colors.green];
    } else {
      final rawVals =
          widget.socketValores ??
          Provider.of<DashboardViewModel>(
            context,
            listen: false,
          ).progressPercentages.map((p) => p.toDouble()).toList();
      final rawLeg = widget.socketLeyenda ?? const <String>[];
      if (rawLeg.isNotEmpty && rawVals.isNotEmpty) {
        seriesLabels = List<String>.from(rawLeg.take(rawVals.length));
        seriesValues = rawVals.take(seriesLabels.length).toList();
      } else {
        seriesLabels = const ['DOWN', 'UP'];
        seriesValues = [0, 0];
      }
      seriesColors = seriesLabels.map((l) {
        switch (l.toUpperCase()) {
          case 'UP':
            return Colors.green;
          case 'DOWN':
            return Colors.red;
          default:
            return Colors.grey;
        }
      }).toList();
    }

    // Conteos derivados
    int upCount = 0;
    int downCount = 0;
    final upIdx = seriesLabels.indexWhere((l) => l.toUpperCase() == 'UP');
    final dnIdx = seriesLabels.indexWhere((l) => l.toUpperCase() == 'DOWN');
    if (upIdx >= 0 && upIdx < seriesValues.length)
      upCount = seriesValues[upIdx].toInt();
    if (dnIdx >= 0 && dnIdx < seriesValues.length)
      downCount = seriesValues[dnIdx].toInt();

    final total = seriesValues.fold<int>(0, (a, b) => a + b.toInt());
    final centerBigText = total.toString();

    // Controles WS (usamos intención + fallbacks)
    final wantRuc = (session.ruc ?? graphProv.ruc ?? '').trim();
    final wantGrupo =
        (session.grupoNombre ??
                graphProv.grupo ??
                graphProv.currentGroupName ??
                '')
            .trim();

    final socketControls = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: graphProv.isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            graphProv.isConnected ? 'Conectado' : 'Desconectado',
            style: TextStyle(
              color: graphProv.isConnected ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              graphProv.isConnected ? Icons.power_settings_new : Icons.power,
              color: Colors.purple,
            ),
            tooltip: graphProv.isConnected ? 'Apagar WS' : 'Encender WS',
            onPressed: () async {
              if (graphProv.isConnected) {
                graphProv.disconnect();
                return;
              }
              if (isGroup) {
                if (wantGrupo.isEmpty) return;
                await graphProv.connectByGroup(wantGrupo, graphProv.rawColors);
                graphProv.fetchGroupSummary();
              } else {
                if (wantRuc.isEmpty) return;
                await graphProv.connect(wantRuc, graphProv.rawColors);
                graphProv.requestGraphData(wantRuc);
              }
              if (mounted) setState(() => _refreshIndex++);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.purple),
            tooltip: 'Pedir gráfica',
            onPressed: graphProv.isConnected
                ? () {
                    if (isGroup) {
                      graphProv.fetchGroupSummary();
                    } else {
                      if (wantRuc.isEmpty) return;
                      graphProv.requestGraphData(wantRuc);
                    }
                    setState(() => _refreshIndex++);
                  }
                : null,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 10, top: 16, bottom: 4),
          child: Text(
            'Estado de servicios',
            style: TextStyle(
              color: Color(0xFFB91FA7),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        socketControls,
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ► Gráfico
              Expanded(
                flex: 5,
                child: GestureDetector(
                  onTap: () => _handleLegendTap('ALL'),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedPieChart(
                        key: ValueKey(_refreshIndex),
                        percentages: seriesValues,
                        colors: seriesColors,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centerBigText,
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
              ),
              const SizedBox(width: 16),
              // ► Tarjetas UP / DOWN
              Expanded(
                flex: 4,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final totalH = constraints.maxHeight;
                    final boxH = ((totalH - spacing) / 2).clamp(84.0, totalH);

                    Color _colorForTag(String tag) {
                      final i = seriesLabels.indexWhere(
                        (l) => l.toUpperCase() == tag.toUpperCase(),
                      );
                      if (i >= 0 && i < seriesColors.length)
                        return seriesColors[i];
                      switch (tag.toUpperCase()) {
                        case 'UP':
                          return Colors.green;
                        case 'DOWN':
                          return Colors.red;
                        default:
                          return Colors.grey;
                      }
                    }

                    return Column(
                      children: [
                        SizedBox(
                          height: boxH,
                          child: _legendSquare(
                            label: 'UP',
                            count: upCount,
                            color: _colorForTag('UP'),
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
                            color: _colorForTag('DOWN'),
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
    this.spaceBetweenSections = 4.0,
    this.centerHolePercentage = 0.6,
  }) : percentages = percentages;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width * 0.45;
    final innerRadius = outerRadius * centerHolePercentage;
    final effectiveThickness = outerRadius - innerRadius;

    final background = Paint()..color = Colors.white;
    canvas.drawCircle(center, outerRadius, background);

    final total = percentages.fold<double>(0, (a, b) => a + b);
    double startAngle = -math.pi / 2;
    for (int i = 0; i < percentages.length; i++) {
      if (percentages[i] == 0) continue;
      final sweep = 2 * math.pi * (percentages[i] / total);
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = effectiveThickness;

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

      startAngle += sweep + (spaceBetweenSections * math.pi / 180);
    }

    final hole = Paint()..color = Colors.white;
    canvas.drawCircle(center, innerRadius, hole);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
