import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:math' as math;
import '../providers/SessionProvider.dart';
import '../services/acordeon_services.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/graph_socket_provider.dart';
import 'dart:convert';

String _normStatus(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String canonStatus(String s) {
  final n = _normStatus(s);
  switch (n) {
    case 'up':
      return 'up';
    case 'down':
      return 'down';
    case 'router':
      return 'router';
    case 'power':
    case 'energia':
      return 'power';
    case 'lost':
      return 'lost';
    case 'onulos':
    case 'onu_los':
    case 'los':
    case 'onulosalarm':
      return 'onulos';
    case 'oltlos':
    case 'olt_los':
      return 'oltlos';
    case 'suspencionbaja':
    case 'suspensionbaja':
      return 'suspencionbaja';
    case 'enlacesnogpon':
    case 'nogpon':
      return 'enlacesnogpon';
    default:
      return n; // cualquier etiqueta nueva
  }
}

final Map<String, Color> kDefaultStatusColors = {
  'enlacesnogpon': Colors.blue,
  'up': Colors.green,
  'power': Colors.orange,
  'router': Color(0xFF8B4A9C),
  'down': Colors.red,
  'lost': Colors.purple,
  'onulos': Colors.deepOrange, // ⬅ color para ONULOS
  'oltlos': Colors.indigo, // ⬅ color para OLTLOS
  'suspencionbaja': Colors.amber,
};

Color _hashColor(String key) {
  final k = canonStatus(key);
  int hash = 0;
  for (final c in k.codeUnits) {
    hash = 0x1fffffff & (hash * 37 + c);
  }
  final hue = (hash % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.65, 0.45).toColor(); // color agradable
}

/// Devuelve el color de `key` buscando primero en el socket (leyenda->colors),
/// luego en el mapa por defecto y, si no hay, uno determinístico por hash.
Color statusColor(BuildContext context, String key) {
  final g = Provider.of<GraphSocketProvider>(context, listen: false);
  final target = canonStatus(key);

  if (g.isConnected && g.leyenda.isNotEmpty && g.colors.isNotEmpty) {
    final idx = g.leyenda.indexWhere((l) => canonStatus(l) == target);
    if (idx != -1 && idx < g.colors.length) {
      return g.colors[idx];
    }
  }
  return kDefaultStatusColors[target] ?? _hashColor(target);
}

IconData statusIcon(String label) {
  switch (canonStatus(label)) {
    case 'up':
      return Icons.arrow_upward_rounded;
    case 'down':
      return Icons.arrow_downward_rounded;
    case 'router':
      return Icons.router_rounded;
    case 'power':
      return Icons.bolt_rounded;
    case 'lost':
      return Icons.link_off_rounded;
    case 'onulos':
    case 'oltlos':
      return Icons.sensors_off_rounded;
    case 'suspencionbaja':
      return Icons.pause_circle_filled_rounded;
    case 'enlacesnogpon':
      return Icons.cable_rounded;
    default:
      return Icons.circle;
  }
}

class EntidadDashboard extends StatefulWidget {
  final String? initialStatus;
  final void Function(String status)? onStatusTap;

  const EntidadDashboard({Key? key, this.initialStatus, this.onStatusTap})
    : super(key: key);

  @override
  State<EntidadDashboard> createState() => EntidadDashboardState();
}

class EntidadDashboardState extends State<EntidadDashboard> {
  String? selectedStatus;
  List<Map<String, dynamic>> allServices = [];
  bool isLoadingServices = false;
  String? errorMessage;
  bool hasNotifications = true;
  late final MapController _mapController;
  bool showMap = true;
  String _composeDireccionCompleta(Map item) {
    // Si viene anidado desde el WS
    final Map<String, dynamic> d = (item['direccion'] is Map)
        ? Map<String, dynamic>.from(item['direccion'])
        : const {};

    String _firstNonEmpty(List<dynamic> vals) {
      for (final v in vals) {
        final s = (v ?? '').toString().trim();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    // en EntidadDashboardState
    void setFilter(String? status) {
      setState(() {
        selectedStatus = status; // 'UP' para filtrar, null para “solo pasar”
        _searchController.clear();
        searchQuery = '';
        isSearching = false;
      });
    }

    // Toma primero del bloque WS, luego flat, luego *_odoo (compat REST)
    final dir = _firstNonEmpty([
      d['direccion'],
      item['direccion'],
      item['direccionodoo'],
    ]);
    final dist = _firstNonEmpty([
      d['distrito'],
      item['distrito'],
      item['distritoodoo'],
    ]);
    final prov = _firstNonEmpty([
      d['provincia'],
      item['provincia'],
      item['provinciaodoo'],
    ]);
    final dpto = _firstNonEmpty([
      d['departamento'],
      item['departamento'],
      item['dptoodoo'],
    ]);

    final ubicacionParts = [
      dist,
      prov,
      dpto,
    ].where((e) => e.isNotEmpty).toList();
    final ubicacion = ubicacionParts.isEmpty ? '' : ubicacionParts.join(' - ');

    if (dir.isNotEmpty && ubicacion.isNotEmpty) return '$dir • $ubicacion';
    if (dir.isNotEmpty) return dir;
    return ubicacion.isNotEmpty ? ubicacion : 'Sin dirección';
  }

  IconData _iconForLabel(String label) => statusIcon(label);

  // ================== TICKETS: estado e helpers ==================
  List<Map<String, dynamic>> _tickets = [];
  Map<String, List<Map<String, dynamic>>> _ticketsByService = {};

  String _normalizeId(dynamic v) => v?.toString().trim() ?? '';

  Color _ticketEstadoColor(String? estado) {
    final e = (estado ?? '').toLowerCase();
    if (e.contains('pend') || e.contains('nuevo')) return Colors.orange;
    if (e.contains('en at') || e.contains('proceso')) return Colors.blue;
    if (e.contains('resu') || e.contains('cerr') || e.contains('ok'))
      return Colors.green;
    return Colors.grey;
  }

  String _formatTicketDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    // intenta parsear "dd-MM-yyyy HH:mm:ssZZZZ" u otros
    try {
      // normalizar zona si viene -0500 -> -05:00
      String s = raw.trim();
      final z = RegExp(r'([+-]\d{2})(\d{2})$');
      if (z.hasMatch(s)) {
        s = s.replaceAllMapped(z, (m) => '${m.group(1)}:${m.group(2)}');
      }
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    // fallback simple (ej. "20250722-173759")
    if (raw.length >= 8) {
      try {
        final y = raw.substring(0, 4);
        final m = raw.substring(4, 6);
        final d = raw.substring(6, 8);
        return '$d/$m/$y';
      } catch (_) {}
    }
    return raw;
  }

  // Afectados -> tickets normalizados
  List<Map<String, dynamic>> _ticketsFromAfectados(dynamic afectados) {
    if (afectados is! List) return const [];
    return afectados.whereType<Map>().map<Map<String, dynamic>>((t) {
      final servicios = (t['ServiciosAfectados'] is List)
          ? List<String>.from(
              (t['ServiciosAfectados'] as List).map(_normalizeId),
            )
          : const <String>[];
      return {
        'TicketId': _normalizeId(t['NroTicket']),
        'Estado': t['EstadoTicket']?.toString(),
        'Fecha': t['FechaCreacion']?.toString(),
        'Tipo': t['Tipo']?.toString(), // opcional
        'Servicios': servicios,
        'source': 'Afectados',
      };
    }).toList();
  }

  // Item.acordeon.tickets.results -> tickets normalizados
  List<Map<String, dynamic>> _ticketsFromItem(Map it) {
    final tk = it['tickets'];
    if (tk is! Map) return const [];
    final results = tk['results'];
    if (results is! List) return const [];
    return results.whereType<Map>().map<Map<String, dynamic>>((r) {
      return {
        'TicketId': _normalizeId(r['ticket_id'] ?? r['id'] ?? r['NroTicket']),
        'Estado': r['estado']?.toString() ?? r['EstadoTicket']?.toString(),
        'Fecha':
            r['hora_creacion']?.toString() ?? r['FechaCreacion']?.toString(),
        'Tipo': r['tipo_ticket_nombre']?.toString(),
        'Servicios':
            <
              String
            >[], // este origen no siempre trae servicios → los indexamos por el dueño (servicio actual)
        'source': 'Item',
      };
    }).toList();
  }

  // Construye índice servicio -> [tickets...]
  void _rebuildTicketIndex({
    required List<Map<String, dynamic>> services,
    required List<Map<String, dynamic>> tickets,
  }) {
    final map = <String, List<Map<String, dynamic>>>{};

    // 1) desde Afectados (tienen Servicios)
    for (final t in tickets) {
      final svcs = (t['Servicios'] is List)
          ? List<String>.from(t['Servicios'])
          : const <String>[];
      for (final sid in svcs) {
        if (sid.isEmpty) continue;
        (map[sid] ??= []).add(t);
      }
    }

    // 2) desde tickets por item (sin lista de servicios): los asignamos al dueño
    for (final svc in services) {
      final id = _normalizeId(svc['IdServicio']);
      if (id.isEmpty) continue;
      final rawItem = svc['details'];
      if (rawItem is! Map) continue;
      final perItem = _ticketsFromItem(rawItem);
      if (perItem.isEmpty) continue;
      (map[id] ??= []).addAll(perItem);
    }

    // remove duplicates por TicketId por servicio
    map.updateAll((_, list) {
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final t in list) {
        final tid = _normalizeId(t['TicketId']);
        if (tid.isEmpty || seen.contains(tid)) continue;
        seen.add(tid);
        unique.add(t);
      }
      return unique;
    });

    _ticketsByService = map;
  }

  List<Map<String, dynamic>> _ticketsForService(String idServicio) {
    final id = _normalizeId(idServicio);
    if (id.isEmpty) return const [];
    return _ticketsByService[id] ?? const [];
  }

  void _showTicketsSheet(List<Map<String, dynamic>> tickets, {String? title}) {
    if (tickets.isEmpty) return;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title ?? 'Tickets relacionados',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...tickets.map((t) {
                final estado = (t['Estado'] ?? '').toString();
                final color = _ticketEstadoColor(estado);
                final fecha = _formatTicketDate(t['Fecha']?.toString());
                final tipo = (t['Tipo'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.25)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.confirmation_number, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${t['TicketId']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            if (tipo.isNotEmpty)
                              Text(
                                tipo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            if (fecha.isNotEmpty)
                              Text(
                                fecha,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          estado.isEmpty ? '—' : estado,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Devuelve la lista de cajas a pintar, ya filtradas (solo > 0),
  /// conservando el color que viene del socket si existe.
  List<Map<String, dynamic>> _statusData(GraphSocketProvider g) {
    final items = <Map<String, dynamic>>[];
    final n = math.min(g.leyenda.length, g.valores.length);

    for (int i = 0; i < n; i++) {
      final label = g.leyenda[i];
      final value = g.valores[i].toInt();
      if (value <= 0) continue;

      final color = g.colors.isNotEmpty
          ? g.colors[i % g.colors.length]
          : Colors.grey;

      items.add({
        'label': label,
        'value': value,
        'color': color,
        'icon': _iconForLabel(label),
      });
    }
    return items;
  }

  Widget _buildStatusChipsHorizontal() {
    final g = Provider.of<GraphSocketProvider>(context);

    if (!g.isConnected || g.leyenda.isEmpty || g.valores.isEmpty) {
      return const SizedBox.shrink();
    }

    final data = _statusData(g); // <- ya filtra value > 0
    if (data.isEmpty) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: data.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final label = data[i]['label'] as String;
            final value = (data[i]['value'] as int).toString().padLeft(2, '0');
            final color = data[i]['color'] as Color;
            final isSel = selectedStatus == label;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => toggleStatusFilter(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSel
                      ? color.withOpacity(0.18)
                      : color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? color : color.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.35),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSel ? color : color.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSel ? color : color.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Método público para refrescar desde afuera (BottomNavBar / parent)
  Future<void> refresh() async {
    // Si quieres, resetea búsqueda y filtro aquí
    setState(() {
      selectedStatus = widget.initialStatus;
      _searchController.clear();
      searchQuery = '';
      isSearching = false;
    });
    await _loadAllServices();
  }

  // NUEVO: Controladores y estado para búsqueda
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.initialStatus;
    _loadAllServices();
    _mapController = MapController();
    // NUEVO: Listener para búsqueda en tiempo real
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase().trim();
        isSearching = searchQuery.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  LatLng? _parseLatLngFromService(Map<String, dynamic> svc) {
    dynamic rawLat = svc['Latitud'] ?? svc['latitud'];
    dynamic rawLng = svc['Longitud'] ?? svc['longitud'];

    // Fallback: dentro de details -> direccion (formato WS)
    if ((rawLat == null || rawLng == null) && svc['details'] is Map) {
      final det = Map<String, dynamic>.from(svc['details']);
      final dir = (det['direccion'] is Map)
          ? Map<String, dynamic>.from(det['direccion'])
          : null;
      rawLat ??= dir?['latitud'] ?? det['latitud'];
      rawLng ??= dir?['longitud'] ?? det['longitud'];
    }

    if (rawLat == null || rawLng == null) return null;

    try {
      final lat = (rawLat is num)
          ? rawLat.toDouble()
          : double.parse(rawLat.toString().replaceAll(',', '.').trim());
      final lng = (rawLng is num)
          ? rawLng.toDouble()
          : double.parse(rawLng.toString().replaceAll(',', '.').trim());
      if (lat == 0 && lng == 0) return null;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<void> _abrirEnMaps(LatLng pos, {String? label}) async {
    final q = Uri.encodeComponent(
      '${pos.latitude},${pos.longitude}${label != null ? ' ($label)' : ''}',
    );
    final google = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$q',
    );
    if (await canLaunchUrl(google)) {
      await launchUrl(google, mode: LaunchMode.externalApplication);
    }
  }

  List<Marker> _buildMarkersFromFiltered() {
    final List<Marker> markers = [];
    for (final svc in filteredServices) {
      final pos = _parseLatLngFromService(svc);
      if (pos == null) continue;

      final color = _getColorForStatusRPA(
        svc['parameterUsed']?.toString() ?? '',
      );
      markers.add(
        Marker(
          point: pos,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showServiceSheet(svc, pos, color),
            child: Icon(Icons.location_on, size: 40, color: color),
          ),
        ),
      );
    }
    return markers;
  }

  void _fitToMarkers(List<Marker> markers) {
    if (markers.isEmpty) return;
    if (markers.length == 1) {
      _mapController.move(markers.first.point, 16.5);
      return;
    }
    final points = markers.map((m) => m.point).toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(28)),
    );
  }

  void _showServiceSheet(Map<String, dynamic> svc, LatLng pos, Color color) {
    final id = (svc['IdServicio'] ?? 'N/A').toString();
    final dir = (svc['DireccionFull'] ?? svc['DireccionOdoo'] ?? '').toString();
    final tipo = (svc['parameterUsed'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.place, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      id,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tipo,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dir.isEmpty
                    ? '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
                    : dir,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _abrirEnMaps(pos, label: id),
                    icon: const Icon(Icons.map),
                    label: const Text('Google Maps'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => navigateToServiceDetail(svc),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Ver detalle'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Reemplaza la función _loadAllServices (líneas aproximadamente 60-120)
  Future<void> _loadAllServices() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.ruc == null) return;

    setState(() {
      isLoadingServices = true;
      errorMessage = null;
    });

    try {
      final g = context.read<GraphSocketProvider>();

      // Fallbacks desde Resumen
      final defaultComercial =
          (g.resumen['Comercial'] ?? g.resumen['comercial'])?.toString();
      final defaultCobranza = (g.resumen['Cobranza'] ?? g.resumen['cobranza'])
          ?.toString();

      // ================== 1) PREFERIR WS (Acordeon) ==================
      if (g.isConnected && g.acordeon.isNotEmpty) {
        final wsList = <Map<String, dynamic>>[];
        final collectedTickets = <Map<String, dynamic>>[];

        // Tickets globales (Afectados)
        collectedTickets.addAll(_ticketsFromAfectados(g.afectados));

        g.acordeon.forEach((rawParam, value) {
          final paramUpper = rawParam
              .toString()
              .toUpperCase(); // UP, DOWN, ONULOS, etc.
          final items = (value is List)
              ? value
              : (value is Map)
              ? [value]
              : const [];

          for (final it in items) {
            if (it is! Map) continue;

            final rawId = (it['ID_Servicio'] ?? it['idservicio'] ?? '')
                .toString();
            if (rawId.isEmpty) continue;

            // Evitar duplicados
            if (wsList.any((s) => (s['IdServicio']?.toString() ?? '') == rawId))
              continue;

            // Dirección (objeto "direccion")
            final dirMap = (it['direccion'] is Map)
                ? Map<String, dynamic>.from(it['direccion'])
                : const {};
            final composed = _composeDireccionCompleta({
              'direccion': dirMap['direccion'],
              'distrito': dirMap['distrito'],
              'provincia': dirMap['provincia'],
              'departamento': dirMap['departamento'],
            });

            // Tickets por item (si trae)
            final perItemTickets = _ticketsFromItem(it);
            if (perItemTickets.isNotEmpty)
              collectedTickets.addAll(perItemTickets);

            wsList.add({
              'IdServicio': rawId,

              'DireccionOdoo':
                  dirMap['direccion'] ?? it['direccionodoo'] ?? 'Sin dirección',
              'DistritoOdoo': dirMap['distrito'] ?? it['distritoodoo'],
              'ProvinciaOdoo': dirMap['provincia'] ?? it['provinciaodoo'],
              'DptoOdoo': dirMap['departamento'] ?? it['dptoodoo'],
              'DireccionFull': composed,

              'Latitud': dirMap['latitud'] ?? it['latitud'],
              'Longitud': dirMap['longitud'] ?? it['longitud'],

              'DESDE': (it['desde'] ?? it['Fecha'] ?? '').toString(),

              'StatusRPA': (it['statusrpa'] ?? '').toString(),
              'StatusOdoo': it['estado'] ?? it['Estado'] ?? 'Desconocido',

              'Comercial': (it['comercial'] ?? defaultComercial)?.toString(),
              'Cobranza': (it['cobranza'] ?? defaultCobranza)?.toString(),

              'MedioOdoo': it['medioodoo'],
              'IpWanOdoo': it['ipwanodoo'],
              'AtenuacionRPA': it['atenuacionrpa']?.toString(),
              'RouterRPA': it['routerrpa']?.toString(),
              'SerialRPA': it['serialrpa']?.toString(),

              'parameterUsed': paramUpper,
              'details': it,
            });
          }
        });

        // Indexar tickets por servicio
        _rebuildTicketIndex(services: wsList, tickets: collectedTickets);

        setState(() {
          allServices = wsList;
          _tickets = collectedTickets;
          isLoadingServices = false;
        });
        return;
      }

      // ================== 2) Fallback REST (tu código + extras) ==================
      List<Map<String, dynamic>> allServicesList = [];
      final collectedTickets = <Map<String, dynamic>>[];

      // también trae de Afectados si lo hubiera mientras tanto
      collectedTickets.addAll(_ticketsFromAfectados(g.afectados));

      for (String parameter in [
        'UP',
        'Power',
        'Router',
        'Down',
        'Lost',
        'SuspencionBaja',
        'EnlacesNoGpon',
      ]) {
        try {
          final response = await AcordeonService.getAcordeonData(
            session.ruc!,
            parameter,
          );

          if (response.statusCode == 200) {
            final dynamic decodedData = jsonDecode(response.body);
            List<dynamic> dataList = [];

            if (decodedData is List) {
              dataList = decodedData;
            } else if (decodedData is Map) {
              dataList = [decodedData];
            } else {
              print(
                'Tipo de datos inesperado para $parameter: ${decodedData.runtimeType}',
              );
              continue;
            }

            for (var item in dataList) {
              if (item is! Map<String, dynamic>) {
                print('Item no es un Map para $parameter: ${item.runtimeType}');
                continue;
              }

              final rawId = item['idservicio']?.toString() ?? 'Sin ID';
              final alreadyExists = allServicesList.any(
                (service) => (service['IdServicio']?.toString() ?? '') == rawId,
              );
              if (alreadyExists) continue;

              // (REST no suele traer tickets por item, pero si viniera en "tickets", lo indexamos)
              collectedTickets.addAll(_ticketsFromItem(item));

              allServicesList.add({
                'IdServicio': rawId,
                'DireccionOdoo': item['direccionodoo'] ?? 'Sin dirección',
                'DistritoOdoo': item['distritoodoo']?.toString(),
                'ProvinciaOdoo': item['provinciaodoo']?.toString(),
                'DptoOdoo': item['dptoodoo']?.toString(),
                'DireccionFull': _composeDireccionCompleta(item),

                'Latitud': item['latitud'],
                'Longitud': item['longitud'],

                'DESDE': item['desde']?.toString() ?? '',
                'StatusRPA': item['statusrpa']?.toString() ?? '0',
                'StatusOdoo': item['statusodoo'] ?? 'Desconocido',

                'Comercial': item['comercial'] ?? defaultComercial,
                'Cobranza': defaultCobranza,

                'MedioOdoo': item['medioodoo'] ?? 'Sin medio',
                'IpWanOdoo': item['ipwanodoo']?.toString(),
                'AtenuacionRPA': item['atenuacionrpa']?.toString(),
                'RouterRPA': item['routerrpa']?.toString(),
                'SerialRPA': item['serialrpa']?.toString(),
                'parameterUsed': parameter,
                'details': item,
              });
            }
          } else {
            print('Error HTTP para $parameter: ${response.statusCode}');
          }
        } catch (e) {
          print('Error cargando $parameter: $e');
        }
      }

      _rebuildTicketIndex(services: allServicesList, tickets: collectedTickets);

      setState(() {
        allServices = allServicesList;
        _tickets = collectedTickets;
        isLoadingServices = false;
      });

      print(
        '✅ Servicios cargados exitosamente (REST): ${allServicesList.length}',
      );
    } catch (e) {
      setState(() {
        errorMessage = 'Error al cargar servicios: $e';
        isLoadingServices = false;
        allServices = [];
      });
      print('❌ Error general cargando servicios: $e');
    }
  }

  Widget _buildIncidentsMapCard() {
    final markers = _buildMarkersFromFiltered();

    return ClipRect(
      // evita overflow durante el slide
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        reverseDuration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,

        // Apila hijos anclados arriba para que “entren/salgan” desde el top
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },

        transitionBuilder: (Widget child, Animation<double> anim) {
          // Slide siempre DESDE ARRIBA (y el saliente se va hacia ARRIBA porque anim va en reversa)
          final slide = Tween<Offset>(
            begin: const Offset(0, 0),
            end: Offset.zero,
          ).animate(anim);

          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: slide,
              child: SizeTransition(
                sizeFactor: anim, // crecimiento/encogimiento
                axisAlignment: -1.0, // <- desde el TOP
                child: child,
              ),
            ),
          );
        },

        child: !showMap
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : Container(
                key: const ValueKey('map-card'),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: markers.isNotEmpty
                            ? markers.first.point
                            : const LatLng(-12.0464, -77.0428),
                        initialZoom: 13,
                        onMapReady: () => _fitToMarkers(markers),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.maptiler.com/maps/streets/256/{z}/{x}/{y}.png?key=5zw14UfqBO9WXww5Ubv8',
                          userAgentPackageName: 'com.fiberlux.app',
                          tileProvider: NetworkTileProvider(),
                          maxZoom: 22,
                          maxNativeZoom: 22,
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // NUEVO: Lista filtrada que considera tanto el estado seleccionado como la búsqueda
  // Reemplaza la función get filteredServices (líneas aproximadamente 110-150)
  List<Map<String, dynamic>> get filteredServices {
    List<Map<String, dynamic>> services = allServices;

    // Helpers locales de normalización
    String _norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    String _canon(String s) {
      final n = _norm(s);
      switch (n) {
        case 'up':
          return 'up';
        case 'down':
          return 'down';
        case 'power':
        case 'energia':
          return 'power';
        case 'router':
          return 'router';
        case 'lost':
          return 'lost';
        case 'onulos':
        case 'onulosalarm':
        case 'onu_los':
        case 'los':
          return 'onulos';
        case 'oltlos':
        case 'olt_los':
        case 'oltloss':
          return 'oltlos';
        case 'suspencionbaja':
        case 'suspensionbaja':
          return 'suspencionbaja';
        case 'enlacesnogpon':
        case 'nogpon':
          return 'enlacesnogpon';
        default:
          return n;
      }
    }

    // Filtro por estado seleccionado (robusto a variantes)
    if (selectedStatus != null && !isSearching) {
      final sel = _canon(selectedStatus!);
      services = services.where((service) {
        final svcKey = _canon((service['parameterUsed'] ?? '').toString());
        return svcKey == sel;
      }).toList();
    }

    // Búsqueda de texto (incluye tipo/parameterUsed)
    if (isSearching && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      services = services.where((service) {
        final idServicio = (service['IdServicio']?.toString() ?? '')
            .toLowerCase();
        final direccion =
            (service['DireccionFull'] ?? service['DireccionOdoo'] ?? '')
                .toString()
                .toLowerCase();
        final comercial = (service['Comercial']?.toString() ?? '')
            .toLowerCase();
        final distrito = (service['DistritoOdoo']?.toString() ?? '')
            .toLowerCase();
        final provincia = (service['ProvinciaOdoo']?.toString() ?? '')
            .toLowerCase();
        final dpto = (service['DptoOdoo']?.toString() ?? '').toLowerCase();
        final tipo = (service['parameterUsed']?.toString() ?? '').toLowerCase();

        return idServicio.contains(q) ||
            direccion.contains(q) ||
            comercial.contains(q) ||
            distrito.contains(q) ||
            provincia.contains(q) ||
            dpto.contains(q) ||
            tipo.contains(q) ||
            _canon(tipo).contains(_canon(q));
      }).toList();
    }

    return services;
  }

  void toggleStatusFilter(String status) {
    setState(() {
      if (selectedStatus == status) {
        selectedStatus = null;
      } else {
        selectedStatus = status;
      }
      // Limpiar búsqueda al seleccionar estado
      if (!isSearching) {
        _searchController.clear();
      }
    });
  }

  // NUEVO: Función para limpiar búsqueda
  void clearSearch() {
    setState(() {
      _searchController.clear();
      searchQuery = '';
      isSearching = false;
    });
  }

  void navigateToServiceDetail(Map<String, dynamic> serviceData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicioDetailScreen(servicioData: serviceData),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      if (dateString.length >= 8) {
        final year = dateString.substring(0, 4);
        final month = dateString.substring(4, 6);
        final day = dateString.substring(6, 8);
        return '$day/$month/$year';
      }
    } catch (e) {
      return dateString;
    }

    return dateString;
  }

  Color _getColorForStatusRPA(String parameterUsed) =>
      statusColor(context, parameterUsed);

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);

    if (session.ruc == null) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        endDrawer: FiberluxDrawer(),
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 15.0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48.0,
                  color: Colors.purple,
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Acceso restringido',
                  style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Verifica tu cuenta para continuar.',
                  style: TextStyle(fontSize: 16.0, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32.0,
                      vertical: 12.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Verificar ahora',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: FiberluxDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildEntityTitle(),
            if (!isSearching) ...[
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: showMap
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Column(
                  children: [_buildStatusCards(), _buildProgressBar()],
                ),
                secondChild: Column(
                  children: [
                    _buildStatusChipsHorizontal(),
                    _buildProgressBar(),
                  ],
                ), // ⬅️ compactas arriba del mapa
              ),
            ],
            if (showMap && !isSearching) const SizedBox(height: 6),
            _buildIncidentsMapCard(),

            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh, // usa el método público
                child: _buildServicesList(),
              ),
            ),
            _buildSearchBar(),
          ],
        ),
      ),
    );
  }

  // Puedes poner esto arriba del State o como método estático
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

  Widget _buildHeader() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final rawNombre = session.nombre;
    final nombre = (rawNombre == null || rawNombre.trim().isEmpty)
        ? 'Usuario'
        : capitalizeWords(rawNombre);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/logos/logo_pequeño.png', height: 40),
              const SizedBox(width: 12),
              Text(
                '¡Hola, $nombre!',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      NotificationOverlay.isShowing
                          ? Icons.notifications
                          : Icons.notifications_outlined,
                      color: Colors.purple,
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
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.purple),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntityTitle() {
    final purple = const Color(0xFF8B4A9C);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Título a la izquierda
          Expanded(
            child: Text(
              'Pre-Diagnosticos',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 25,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),

          // Botón simple a la derecha
          TextButton.icon(
            onPressed: () => setState(() => showMap = !showMap),
            icon: Icon(
              Icons.map_outlined,
              size: 18,
              color: showMap ? purple : Colors.grey[700],
            ),
            label: Text(
              showMap ? 'Ocultar mapa' : 'Ver mapa',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: showMap ? purple : Colors.grey[700],
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // NUEVO: Barra de búsqueda funcional
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF8B4A9C).withOpacity(0.1),
            Color(0xFFB565A7).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF8B4A9C).withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: Color(0xFF8B4A9C), fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Buscar por ID, dirección o cliente...',
          hintStyle: TextStyle(
            color: Color(0xFF8B4A9C).withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.search, color: Color(0xFF8B4A9C)),
          suffixIcon: isSearching
              ? IconButton(
                  icon: Icon(Icons.clear, color: Color(0xFF8B4A9C)),
                  onPressed: clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCards() {
    final g = Provider.of<GraphSocketProvider>(context);

    if (!g.isConnected || g.leyenda.isEmpty || g.valores.isEmpty) {
      return const SizedBox.shrink();
    }

    // Reusa la lista ya filtrada (> 0) que te pasé antes
    final data = _statusData(g);
    if (data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          const minTileW = 150.0; // ancho mínimo cómodo
          const tileH = 86.0;
          // número de columnas “base” (2+)
          final cols = math.max(2, (constraints.maxWidth / minTileW).floor());
          final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;

          final rem = data.length % cols; // cuántos quedan en la última fila
          final lastIndex = data.length - 1;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(data.length, (i) {
              final item = data[i];
              final label = item['label'] as String;
              final value = item['value'] as int;
              final color = item['color'] as Color;
              final icon = item['icon'] as IconData;

              final isSel = selectedStatus == label;

              // Si la última fila tiene solo 1 ítem, que ese ocupe TODO el ancho
              final isLonelyLast = (rem == 1) && (i == lastIndex);
              final width = isLonelyLast ? constraints.maxWidth : tileW;

              return SizedBox(
                width: width,
                height: tileH,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => toggleStatusFilter(label),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSel
                          ? color.withOpacity(0.22)
                          : color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? color : color.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color.withOpacity(0.9),
                                  letterSpacing: .2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar() {
    final g = Provider.of<GraphSocketProvider>(context);

    if (!g.isConnected || g.leyenda.isEmpty || g.valores.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = g.valores.fold<double>(0, (sum, val) => sum + val);
    if (total <= 0) return const SizedBox.shrink();

    final itemCount = math.min(g.leyenda.length, g.valores.length);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(itemCount, (index) {
          final valor = g.valores[index];
          final ley = g.leyenda[index];
          final color = g.colors.isNotEmpty
              ? g.colors[index % g.colors.length]
              : Colors.grey;
          final percent = (valor / total) * 100;
          final isSelected = selectedStatus == ley;

          if (valor <= 0) return const SizedBox.shrink();

          final flexWeight = (10 + percent).toInt();

          return Expanded(
            flex: flexWeight,
            child: Container(
              margin: EdgeInsets.only(right: index < itemCount - 1 ? 5 : 0),
              child: Column(
                children: [
                  Container(
                    height: 10,
                    width: double.infinity,
                    color: selectedStatus == null || isSelected
                        ? color
                        : Colors.grey[300],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? color : Colors.grey[600],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).where((w) => w is! SizedBox).toList(),
      ),
    );
  }

  Widget _buildServicesList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 0),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(child: _buildServicesContent()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.purple.withOpacity(0.08),
                      Colors.purple.withOpacity(0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 20,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.purple.withOpacity(0.08),
                      Colors.purple.withOpacity(0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesContent() {
    if (isLoadingServices) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF8B4A9C)),
            const SizedBox(height: 16),
            Text(
              'Cargando servicios...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: TextStyle(fontSize: 16, color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadAllServices(),
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final services = filteredServices;

    if (services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.inbox_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isSearching
                  ? 'No se encontraron resultados para "$searchQuery"'
                  : selectedStatus == null
                  ? 'No hay servicios disponibles'
                  : 'No hay servicios con el estado "$selectedStatus"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Total servicios: ${allServices.length}',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            if (isSearching)
              ElevatedButton(
                onPressed: clearSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B4A9C),
                ),
                child: Text(
                  'Limpiar búsqueda',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else if (selectedStatus != null)
              ElevatedButton(
                onPressed: () => setState(() => selectedStatus = null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8B4A9C),
                ),
                child: Text(
                  'Mostrar todos',
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // NUEVO: Header con resultados de búsqueda
        if (isSearching)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF8B4A9C).withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Color(0xFF8B4A9C), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${services.length} resultado${services.length != 1 ? 's' : ''} para "$searchQuery"',
                    style: TextStyle(
                      color: Color(0xFF8B4A9C),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: clearSearch,
                  child: Text(
                    'Limpiar',
                    style: TextStyle(color: Color(0xFF8B4A9C)),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final parameterUsed = service['parameterUsed']?.toString() ?? '';
              final Color serviceColor = _getColorForStatusRPA(parameterUsed);
              final formattedDate = _formatDate(service['DESDE']);
              final serviceIdStr = (service['IdServicio'] ?? '').toString();
              final relatedTickets = _ticketsForService(serviceIdStr);
              final ticketsCount = relatedTickets.length;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 20,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => navigateToServiceDetail(service),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: serviceColor.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: serviceColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      serviceColor,
                                      serviceColor.withOpacity(0.7),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: serviceColor.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // NUEVO: Resaltar texto buscado en ID
                                    _buildHighlightedText(
                                      service['IdServicio'] as String,
                                      searchQuery,
                                      const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8B4A9C),
                                      ),
                                    ),
                                    if (isSearching)
                                      Text(
                                        'Tipo: $parameterUsed',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: serviceColor.withOpacity(0.7),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (ticketsCount > 0) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showTicketsSheet(
                                    relatedTickets,
                                    title: 'Tickets de $serviceIdStr',
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.receipt_long,
                                          size: 16,
                                          color: Colors.black54,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$ticketsCount',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              if (formattedDate.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: serviceColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: serviceColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey[400],
                                size: 24,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const SizedBox(width: 28),
                              Expanded(
                                child: Column(
                                  children: [
                                    CustomPaint(
                                      painter: DashedLinePainter(
                                        color: serviceColor.withOpacity(0.3),
                                      ),
                                      child: const SizedBox(
                                        height: 1,
                                        width: double.infinity,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildHighlightedText(
                                        (service['DireccionFull'] ??
                                                service['DireccionOdoo'] ??
                                                'Sin dirección')
                                            as String,
                                        searchQuery,
                                        TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  // NUEVO: Widget para resaltar texto buscado
  Widget _buildHighlightedText(String text, String query, TextStyle style) {
    if (query.isEmpty || !isSearching) {
      return Text(
        text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(
        text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final startIndex = lowerText.indexOf(lowerQuery);
    final endIndex = startIndex + query.length;

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, startIndex)),
          TextSpan(
            text: text.substring(startIndex, endIndex),
            style: style.copyWith(
              backgroundColor: Color(0xFF8B4A9C).withOpacity(0.2),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(endIndex)),
        ],
      ),
    );
  }
}

class ServicioDetailScreen extends StatefulWidget {
  final Map<String, dynamic> servicioData;

  const ServicioDetailScreen({Key? key, required this.servicioData})
    : super(key: key);

  @override
  State<ServicioDetailScreen> createState() => _ServicioDetailScreenState();
}

class _ServicioDetailScreenState extends State<ServicioDetailScreen> {
  static const Color primaryPurple = Color(0xFF8B4A9C);
  static const Color secondaryPurple = Color(0xFFB565A7);
  static const Color lightPurple = Color(0xFFE8D8F5);
  static const Color accentPurple = Color(0xFFD4A4E8);

  Color _ticketEstadoColor(String? estado) {
    final e = (estado ?? '').toLowerCase();
    if (e.contains('pend') || e.contains('nuevo')) return Colors.orange;
    if (e.contains('en at') || e.contains('proceso')) return Colors.blue;
    if (e.contains('resu') || e.contains('cerr') || e.contains('ok'))
      return Colors.green;
    return Colors.grey;
  }

  String _formatTicketDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      // normaliza -0500 -> -05:00
      String s = raw.trim();
      final z = RegExp(r'([+-]\d{2})(\d{2})$');
      if (z.hasMatch(s))
        s = s.replaceAllMapped(z, (m) => '${m.group(1)}:${m.group(2)}');
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    // fallback rápido para "yyyyMMdd..."
    if (raw.length >= 8) {
      try {
        final y = raw.substring(0, 4),
            m = raw.substring(4, 6),
            d = raw.substring(6, 8);
        return '$d/$m/$y';
      } catch (_) {}
    }
    return raw;
  }

  List<Map<String, dynamic>> _collectTicketsForThisService() {
    final id =
        (widget.servicioData['IdServicio'] ??
                widget.servicioData['idservicio'] ??
                '')
            .toString();
    if (id.isEmpty) return const [];

    final g = context.read<GraphSocketProvider>();
    // 1) desde Afectados
    final afectados = (g.afectados is List) ? g.afectados as List : const [];
    final fromAfectados = afectados
        .whereType<Map>()
        .where((t) {
          final svcs = (t['ServiciosAfectados'] is List)
              ? t['ServiciosAfectados'] as List
              : const [];
          return svcs.map((e) => e.toString()).contains(id);
        })
        .map<Map<String, dynamic>>((t) {
          return {
            'TicketId': (t['NroTicket'] ?? '').toString(),
            'Estado': t['EstadoTicket']?.toString(),
            'Fecha': t['FechaCreacion']?.toString(),
            'Tipo': t['Tipo']?.toString(),
            'source': 'Afectados',
          };
        })
        .toList();

    // 2) desde details.tickets
    final det = widget.servicioData['details'];
    final fromDetails = <Map<String, dynamic>>[];
    if (det is Map &&
        det['tickets'] is Map &&
        det['tickets']['results'] is List) {
      for (final r in det['tickets']['results']) {
        if (r is! Map) continue;
        fromDetails.add({
          'TicketId': (r['ticket_id'] ?? r['id'] ?? '').toString(),
          'Estado': r['estado']?.toString(),
          'Fecha': r['hora_creacion']?.toString(),
          'Tipo': r['tipo_ticket_nombre']?.toString(),
          'source': 'Item',
        });
      }
    }

    // unir sin duplicar por TicketId
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final t in [...fromAfectados, ...fromDetails]) {
      final tid = (t['TicketId'] ?? '').toString();
      if (tid.isEmpty || seen.contains(tid)) continue;
      seen.add(tid);
      out.add(t);
    }
    return out;
  }

  LatLng? _parseLatLng(Map<String, dynamic> data) {
    dynamic rawLat = data['Latitud'] ?? data['latitud'];
    dynamic rawLng = data['Longitud'] ?? data['longitud'];

    // fallback al raw
    if ((rawLat == null || rawLng == null) && data['details'] is Map) {
      final det = data['details'] as Map;
      rawLat ??= det['latitud'];
      rawLng ??= det['longitud'];
    }

    // nada que hacer
    if (rawLat == null || rawLng == null) return null;

    // normalización segura
    double? lat, lng;
    try {
      lat = rawLat is num
          ? rawLat.toDouble()
          : double.parse(rawLat.toString().replaceAll(',', '.').trim());
      lng = rawLng is num
          ? rawLng.toDouble()
          : double.parse(rawLng.toString().replaceAll(',', '.').trim());
    } catch (_) {
      return null;
    }

    // validación de rango
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    // opcional: evita (0,0)
    if (lat == 0 && lng == 0) return null;

    return LatLng(lat, lng);
  }

  Future<void> _abrirEnMaps(LatLng pos, {String? label}) async {
    final q = Uri.encodeComponent(
      '${pos.latitude},${pos.longitude}${label != null ? ' ($label)' : ''}',
    );
    final google = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$q',
    );
    if (await canLaunchUrl(google)) {
      await launchUrl(google, mode: LaunchMode.externalApplication);
    }
  }

  String _normLabel(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _canon(String s) {
    final n = _normLabel(s);
    switch (n) {
      case 'up':
        return 'up';
      case 'down':
        return 'down';
      case 'power':
      case 'energia':
        return 'power';
      case 'router':
        return 'router';
      case 'lost':
        return 'lost';
      case 'onulos':
      case 'onulosalarm':
      case 'onu_los':
      case 'los':
        return 'onulos';
      case 'oltlos':
      case 'olt_los':
      case 'oltloss':
        return 'oltlos';
      case 'suspencionbaja':
      case 'suspensionbaja':
        return 'suspencionbaja';
      case 'enlacesnogpon':
      case 'nogpon':
        return 'enlacesnogpon';
      default:
        return n; // deja pasar etiquetas nuevas sin romper
    }
  }

  Color _resolveServiceColor(String rawLabel) {
    final canon = _canon(rawLabel);
    final g = context.read<GraphSocketProvider>();

    // 1) Intentar respetar colores del socket
    if (g.isConnected && g.leyenda.isNotEmpty && g.colors.isNotEmpty) {
      final n = math.min(g.leyenda.length, g.colors.length);
      for (int i = 0; i < n; i++) {
        final lcanon = _canon(g.leyenda[i]);
        if (lcanon == canon ||
            // Mapea ONULOS/OLTLOS a LOST/DOWN si el socket usa esas etiquetas
            ((canon == 'onulos' || canon == 'oltlos') &&
                (lcanon == 'lost' || lcanon == 'down'))) {
          return g.colors[i];
        }
      }
    }

    // 2) Fallback consistente
    switch (canon) {
      case 'up':
        return Colors.green;
      case 'down':
      case 'lost':
      case 'onulos':
      case 'oltlos':
        return Colors.red;
      case 'power':
        return Colors.orange;
      case 'router':
        return const Color(0xFF8B4A9C);
      case 'suspencionbaja':
        return Colors.yellow;
      case 'enlacesnogpon':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _darken(Color c, [double amount = 0.15]) {
    final hsl = HSLColor.fromColor(c);
    final light = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(light).toColor();
  }

  Color get _serviceColor => _resolveServiceColor(
    (widget.servicioData['parameterUsed'] ??
            widget.servicioData['StatusRPA'] ??
            '')
        .toString(),
  );

  late final MapController _mapController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMapaSection() {
    final pos = _parseLatLng(widget.servicioData);

    if (pos == null) {
      // No hay coordenadas válidas
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin coordenadas válidas para este servicio',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }
    debugPrint('🗺️ POS=${pos.latitude}, ${pos.longitude}');

    final direccion =
        (widget.servicioData['DireccionFull'] ??
                widget.servicioData['DireccionOdoo'] ??
                '')
            .toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título sección
        _buildSectionHeader('Ubicación en mapa', Icons.place),

        // Mapa
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,

            child: FlutterMap(
              mapController: _mapController, // ⬅️ NUEVO
              options: MapOptions(
                initialCenter: pos,
                initialZoom: 17,
                // ⬅️ Forzamos un move cuando el mapa está listo (dispara carga de tiles)
                onMapReady: () {
                  // Si por algún motivo no pintó con initial*, movemos explícitamente
                  _mapController.move(pos, 17);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fiberlux.app',
                  tileProvider: NetworkTileProvider(),
                  errorTileCallback: (t, e, _) => debugPrint('OSM error: $e'),
                ),

                MarkerLayer(
                  markers: [
                    Marker(
                      point: pos,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Acciones
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _abrirEnMaps(
                pos,
                label: widget.servicioData['IdServicio']?.toString(),
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir en Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                direccion.isEmpty
                    ? '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}'
                    : direccion,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String? value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title: ${value ?? 'N/A'}'),
                duration: Duration(milliseconds: 800),
                backgroundColor: primaryPurple,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lightPurple.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: primaryPurple.withOpacity(0.06),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        lightPurple.withOpacity(0.8),
                        accentPurple.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPurple.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryPurple, size: 22),
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        value ?? 'N/A',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                          letterSpacing: 0.2,
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
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 20),
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryPurple, secondaryPurple],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primaryPurple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: primaryPurple,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el factor de animación basado en el scroll
    final ticketsHere = _collectTicketsForThisService();

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Header con gradiente púrpura
          SliverAppBar(
            pinned: true,
            backgroundColor: _darken(_serviceColor, 0.10),
            elevation: 0,
            title: Text(
              'Id Circuito: ${widget.servicioData['IdServicio'] ?? widget.servicioData['idservicio'] ?? 'N/A'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // Contenido principal
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoTile(
                    'Comercial',
                    widget.servicioData['Comercial'],
                    Icons.person,
                  ),
                  _buildInfoTile(
                    'Cobranza',
                    widget.servicioData['Cobranza'],
                    Icons.request_quote,
                  ),
                  _buildInfoTile(
                    'Dirección',
                    widget.servicioData['DireccionOdoo'],
                    Icons.location_on,
                  ),
                  _buildInfoTile(
                    'Ubicación',
                    [
                          widget.servicioData['DistritoOdoo'],
                          widget.servicioData['ProvinciaOdoo'],
                          widget.servicioData['DptoOdoo'],
                        ]
                        .where(
                          (e) => (e?.toString().trim().isNotEmpty ?? false),
                        )
                        .join(' - '),
                    Icons.map,
                  ),
                  const SizedBox(height: 8),

                  _buildMapaSection(), // ⬅️ AQUI
                  // ⬇️ INSERTAR AQUÍ LA SECCIÓN DE TICKETS
                  if (ticketsHere.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Tickets relacionados',
                      Icons.receipt_long,
                    ),
                    ...ticketsHere.map((t) {
                      final estado = (t['Estado'] ?? '').toString();
                      final fecha = (t['Fecha'] ?? '').toString();
                      final tipo = (t['Tipo'] ?? '').toString();
                      final color = _ticketEstadoColor(estado);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.08),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.confirmation_number, color: color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${t['TicketId']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  if (tipo.isNotEmpty)
                                    const SizedBox(height: 2),
                                  if (tipo.isNotEmpty)
                                    const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ) !=
                                            null
                                        ? Text(
                                            tipo,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  if (fecha.isNotEmpty)
                                    const SizedBox(height: 2),
                                  if (fecha.isNotEmpty)
                                    Text(
                                      _formatTicketDate(fecha),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                estado.isEmpty ? '—' : estado,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                  ],

                  // ⬆️ FIN DE LA SECCIÓN DE TICKETS
                  _buildSectionHeader('Detalles Técnicos', Icons.build),

                  _buildInfoTile(
                    'Estado Administrativo',
                    widget.servicioData['StatusOdoo'],
                    Icons
                        .verified_user, // o Icons.approval / Icons.assignment_turned_in
                  ),
                  _buildInfoTile(
                    'Último Diagnostico',
                    widget.servicioData['StatusRPA'],
                    Icons
                        .settings_backup_restore, // o Icons.robot_2 si usas material symbols
                  ),

                  _buildInfoTile(
                    'Último Diagnóstico',
                    widget.servicioData['DESDE'],
                    Icons.schedule,
                  ),

                  _buildInfoTile(
                    'IP WAN',
                    widget.servicioData['IpWanOdoo'],
                    Icons.public,
                  ),
                  _buildInfoTile(
                    'Medio',
                    widget.servicioData['MedioOdoo'],
                    Icons.cable,
                  ),

                  _buildInfoTile(
                    'Atenuación',
                    widget.servicioData['AtenuacionRPA'],
                    Icons.signal_cellular_alt,
                  ),
                  _buildInfoTile(
                    'Router',
                    widget.servicioData['RouterRPA'],
                    Icons.wifi,
                  ),
                  _buildInfoTile(
                    'Serial',
                    widget.servicioData['SerialRPA'],
                    Icons.qr_code,
                  ),

                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final Color color;
  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const double dashWidth = 4;
    const double dashSpace = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
