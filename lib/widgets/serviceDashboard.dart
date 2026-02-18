import 'package:fiberlux_new_app/view/home.dart';
import '../view/entidadDashboard.dart';
import '../view/valoresAgregadosList.dart';
import 'TweenAnimationBuilder/animatedPieChart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import 'dart:convert';
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
  bool _showValoresAgregadosList = false;

  // Snapshot del “deseo” (no del estado actual del socket)
  bool? _lastWantGroup;
  String? _lastWantRuc;
  String? _lastWantGrupo;
  String? _lastNoFibraRuc;

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

  void _openValoresAgregadosList(
    String title,
    List<Map<String, dynamic>> services,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ValoresAgregadosListScreen(title: title, services: services),
      ),
    );
  }

  double _fitFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required TextDirection textDirection,
    TextScaler? textScaler,
    double minFontSize = 8,
    double maxFontSize = 11,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) return minFontSize;
    double low = minFontSize;
    double high = maxFontSize;
    for (var i = 0; i < 6; i++) {
      final mid = (low + high) / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: mid),
        ),
        textDirection: textDirection,
        textScaler: textScaler ?? TextScaler.noScaling,
      )..layout(maxWidth: maxWidth);
      if (tp.size.height <= maxHeight) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  void _maybeFetchNoFibra(SessionProvider session, GraphSocketProvider g) {
    final ruc = (session.ruc ?? '').trim();
    final selectedGroup = (g.selectedGroupRuc ?? '').trim();
    final fallback = (g.ruc ?? '').trim();
    final targetRuc = ruc.isNotEmpty
        ? ruc
        : (selectedGroup.isNotEmpty ? selectedGroup : fallback);

    if (targetRuc.isEmpty) return;
    if (_lastNoFibraRuc == targetRuc) return;
    _lastNoFibraRuc = targetRuc;
    g.fetchNoFibraForRuc(targetRuc);
  }

  Widget _legendSquare({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
    bool dense = false,
  }) {
    final padding = dense ? 8.0 : 14.0;
    final iconBox = dense ? 26.0 : 35.0;
    final iconSize = dense ? 18.0 : 26.0;
    final labelSize = dense ? 9.0 : 10.0;
    final countSize = dense ? 18.0 : 24.0;
    final spacing = dense ? 8.0 : 12.0;
    final labelSpacing = dense ? 1.0 : 2.0;
    final chevronSize = dense ? 18.0 : 24.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
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
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelSize,
                      letterSpacing: .4,
                      fontWeight: FontWeight.w600,
                      color: color.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: labelSpacing),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: countSize,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.black26,
              size: chevronSize,
            ),
          ],
        ),
      ),
    );
  }

  Widget _svaSquare({
    required int count,
    VoidCallback? onTap,
    bool dense = false,
  }) {
    final padding = dense ? 8.0 : 14.0;
    final countSize = dense ? 18.0 : 24.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFB91FA7), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: countSize,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const Positioned(
              right: 0,
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.black38,
              ),
            ),
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
      _maybeFetchNoFibra(session, graphProv);
    });

    final isGroup = session.grupoEconomicoOrRuc; // ← usamos la intención

    int _toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      final s = v.toString().trim();
      return int.tryParse(s) ?? 0;
    }

    Map<String, dynamic> _asMap(dynamic v) {
      if (v is Map) return Map<String, dynamic>.from(v);
      if (v is String) {
        final s = v.trim();
        if (s.startsWith('{') && s.endsWith('}')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      }
      return {};
    }

    List<dynamic> _asList(dynamic v) {
      if (v is List) return v;
      if (v is String) {
        final s = v.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) return decoded;
          } catch (_) {}
        }
      }
      return const [];
    }

    String _normServiceKey(String s) =>
        s.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

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

    final noFibraRaw =
        graphProv.extra['NoFibra'] ??
        graphProv.extra['No_Fibra'] ??
        graphProv.extra['NO_FIBRA'] ??
        graphProv.extra['noFibra'] ??
        graphProv.extra['NOFIBRA'] ??
        graphProv.resumen['NoFibra'] ??
        graphProv.resumen['noFibra'] ??
        graphProv.detalle['NoFibra'] ??
        graphProv.detalle['noFibra'];

    final noFibraMap = _asMap(noFibraRaw);

    // Agrupar por servicio y contar IDs únicos
    final countByKey = <String, int>{};
    final displayByKey = <String, String>{};
    final idsByKey = <String, Set<String>>{};
    final itemsByKey = <String, List<Map<String, dynamic>>>{};

    final rawDetalle = noFibraMap['Detalle'] ?? noFibraMap['detalle'];
    final detalleList = _asList(rawDetalle);

    for (final item in detalleList) {
      if (item is! Map) continue;

      final name = (item['Servicio'] ?? item['servicio'] ?? '')
          .toString()
          .trim();
      if (name.isEmpty) continue;

      final key = _normServiceKey(name);
      displayByKey.putIfAbsent(key, () => name);

      final id =
          (item['ID_Servicio'] ??
                  item['id_servicio'] ??
                  item['IdServicio'] ??
                  item['ServicioId'] ??
                  item['servicio_id'] ??
                  '')
              .toString()
              .trim();

      if (id.isNotEmpty) {
        final set = idsByKey.putIfAbsent(key, () => <String>{});
        if (set.add(id)) {
          countByKey[key] = (countByKey[key] ?? 0) + 1;
          itemsByKey
              .putIfAbsent(key, () => <Map<String, dynamic>>[])
              .add(Map<String, dynamic>.from(item));
        }
      } else {
        countByKey[key] = (countByKey[key] ?? 0) + 1;
        itemsByKey
            .putIfAbsent(key, () => <Map<String, dynamic>>[])
            .add(Map<String, dynamic>.from(item));
      }
    }

    // entries finales (con el nombre original “bonito”)
    final otherEntries =
        countByKey.entries
            .map((e) => MapEntry(displayByKey[e.key] ?? e.key, e.value))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)); // opcional
    final valoresAgregadosTotal = otherEntries.fold<int>(
      0,
      (sum, e) => sum + e.value,
    );
    bool _isTipService(String name) {
      final norm = _normServiceKey(name);
      if (RegExp(r'TELEFONI[ÍI]A IP').hasMatch(norm)) return true;
      return RegExp(r'(^|[^A-Z0-9])TIP([0-9]|[^A-Z0-9]|$)').hasMatch(norm);
    }

    final tipEntries = <MapEntry<String, int>>[];
    final filteredEntries = <MapEntry<String, int>>[];
    int tipInsertIndex = -1;

    for (final entry in otherEntries) {
      if (_isTipService(entry.key)) {
        tipEntries.add(entry);
        if (tipInsertIndex == -1) {
          tipInsertIndex = filteredEntries.length;
        }
      } else {
        filteredEntries.add(entry);
      }
    }

    final displayEntries = <_ServiceListItem>[];
    for (final entry in filteredEntries) {
      final key = _normServiceKey(entry.key);
      displayEntries.add(
        _ServiceListItem(
          label: entry.key,
          count: entry.value,
          items: itemsByKey[key] ?? const [],
        ),
      );
    }
    if (tipEntries.isNotEmpty) {
      final tipTotal = tipEntries.fold<int>(0, (sum, e) => sum + e.value);
      final tipItems = <Map<String, dynamic>>[];
      final tipChildren = <_ServiceListItem>[];

      for (final entry in tipEntries) {
        final key = _normServiceKey(entry.key);
        final items = itemsByKey[key] ?? const [];
        tipItems.addAll(items);
        tipChildren.add(
          _ServiceListItem(label: entry.key, count: entry.value, items: items),
        );
      }
      final insertIndex = tipInsertIndex >= 0 ? tipInsertIndex : 0;
      displayEntries.insert(
        insertIndex,
        _ServiceListItem(
          label: 'TIP',
          count: tipTotal,
          items: tipItems,
          children: tipChildren,
        ),
      );
    }
    displayEntries.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.label.compareTo(b.label);
    });
    final listNameStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey[800],
    );
    final listChildNameStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.grey[700],
    );
    const listCountStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Color(0xFF8B4A9C),
    );
    Widget _countChevron(int count) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count.toString(), style: listCountStyle),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Colors.black38,
          ),
        ],
      );
    }

    Widget _serviceRow({
      required String label,
      required TextStyle labelStyle,
      required int count,
      required VoidCallback onTap,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 4),
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              _countChevron(count),
            ],
          ),
        ),
      );
    }

    Widget _animatedListItem({required int index, required Widget child}) {
      final delay = (index * 0.06).clamp(0.0, 0.6).toDouble();
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
        builder: (context, value, animatedChild) {
          final dx = (1 - value) * -24;
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: animatedChild,
            ),
          );
        },
        child: child,
      );
    }

    const maxVisibleItems = 4;
    const listItemHeight = 35.0;
    const listSpacing = 12.0;
    final listMaxHeight =
        (listItemHeight * maxVisibleItems) +
        (listSpacing * (maxVisibleItems - 1));
    final listScrollable = displayEntries.length > maxVisibleItems;

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
            'Servicios de Conectividad',
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
        SizedBox(height: 24),

        if (otherEntries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              bottom: 6,
              top: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Servicios de Valor Agregado',
                  style: TextStyle(
                    color: Color(0xFFB91FA7),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Transform.translate(
                      offset: Offset(0, _showValoresAgregadosList ? -5 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: _showValoresAgregadosList ? 120 : 170,
                        constraints: BoxConstraints(
                          minHeight: _showValoresAgregadosList ? 60 : 72,
                        ),
                        child: _svaSquare(
                          count: valoresAgregadosTotal,
                          dense: _showValoresAgregadosList,
                          onTap: () {
                            setState(() {
                              _showValoresAgregadosList =
                                  !_showValoresAgregadosList;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1.0,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _showValoresAgregadosList
                            ? ConstrainedBox(
                                key: const ValueKey('valores-agregados-list'),
                                constraints: listScrollable
                                    ? BoxConstraints(maxHeight: listMaxHeight)
                                    : const BoxConstraints(),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: listScrollable
                                      ? const ClampingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  itemCount: displayEntries.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 12),
                                  itemBuilder: (context, index) {
                                    final item = displayEntries[index];
                                    Widget itemWidget;
                                    if (item.children.isNotEmpty) {
                                      itemWidget = Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          tilePadding: EdgeInsets.zero,
                                          childrenPadding:
                                              const EdgeInsets.only(
                                                left: 12,
                                                right: 0,
                                                bottom: 6,
                                              ),
                                          title: Text(
                                            item.label,
                                            style: listNameStyle,
                                          ),
                                          trailing: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () =>
                                                _openValoresAgregadosList(
                                                  item.label,
                                                  item.items,
                                                ),
                                            child: _countChevron(item.count),
                                          ),
                                          children: item.children.map((entry) {
                                            return _serviceRow(
                                              label: entry.label,
                                              labelStyle: listChildNameStyle,
                                              count: entry.count,
                                              onTap: () =>
                                                  _openValoresAgregadosList(
                                                    entry.label,
                                                    entry.items,
                                                  ),
                                            );
                                          }).toList(),
                                        ),
                                      );
                                    } else {
                                      itemWidget = _serviceRow(
                                        label: item.label,
                                        labelStyle: listNameStyle,
                                        count: item.count,
                                        onTap: () => _openValoresAgregadosList(
                                          item.label,
                                          item.items,
                                        ),
                                      );
                                    }
                                    return _animatedListItem(
                                      index: index,
                                      child: itemWidget,
                                    );
                                  },
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('valores-agregados-empty'),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

class _ServiceListItem {
  final String label;
  final int count;
  final List<_ServiceListItem> children;
  final List<Map<String, dynamic>> items;

  const _ServiceListItem({
    required this.label,
    required this.count,
    this.children = const [],
    this.items = const [],
  });
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
