import 'dart:async';

import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'dart:math' as math;
import '../view/ticketsScreen.dart';
import '../providers/SessionProvider.dart';
import '../services/acordeon_services.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/graph_socket_provider.dart';
import 'dart:convert';

enum EntidadViewMode { grouped, classic }

String _normStatus(String s) {
  // De-acentúa primero para no perder letras (energía -> energia)
  final noAccents = s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâã]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöôõ]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'[ñ]'), 'n');
  // Luego elimina todo lo que no sea a–z / 0–9 (incluye guiones y underscores)
  return noAccents.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String canonStatus(String s) {
  final n = _normStatus(s);
  switch (n) {
    case 'up':
      return 'up';

    case 'peenergia':
    case 'energia':
    case 'power':
      return 'pe_energia';

    case 'pefibra':
    case 'onulos':
    case 'oltlos':
    case 'lost':
      return 'pe_fibra';

    case 'endiagnostico':
    case 'down':
      return 'down';

    case 'enatencion':
      return 'en_atencion';

    // 👇 Nuevo: OBS
    case 'obs':
    case 'observacion': // por si el socket manda texto largo
    case 'observaciones':
      return 'obs';

    case 'noprecisa':
      return 'no_precisa';

    case 'router':
      return 'router';
    case 'enlacesnogpon':
    case 'nogpon':
      return 'enlacesnogpon';

    default:
      return n;
  }
}

final Map<String, Color> kDefaultStatusColors = {
  'up': Colors.green,
  'pe_energia': Colors.orange, // Posible Falla Eléctrica
  'pe_fibra': Colors.indigo, // Posible evento de Fibra
  'en_diagnostico': Colors.deepPurple, // En Diagnóstico
  'en_atencion':
      Colors.orangeAccent, // ← NUEVO (coincide con WS #FFA500 aproximado)
  'down': Colors.red, // DOWN
  // compat
  'router': const Color(0xFF8B4A9C),
  'enlacesnogpon': Colors.blueGrey,
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
    case 'pe_energia':
      return Icons.bolt_rounded;
    case 'down':
      return Icons.arrow_downward_rounded;
    case 'pe_fibra':
      return Icons.sensors_off_rounded;
    case 'en_diagnostico':
      return Icons.build_circle_rounded;
    case 'en_atencion':
      return Icons.pending_actions_rounded; // <— NUEVO
    case 'no_precisa':
      return Icons.help_outline_rounded;
    case 'router':
      return Icons.router_rounded;
    case 'enlacesnogpon':
      return Icons.cable_rounded;
    default:
      return Icons.circle;
  }
}

// clave de grupo (lo que filtra): 'UP', 'PE_Energia', 'PE_Fibra', 'En_Diagnostico', 'No_Precisa'
// Clave de grupo
String _groupKeyFromCanon(String canon) {
  switch (canon) {
    case 'up':
      return 'UP';
    case 'pe_energia':
      return 'PE_Energia';
    case 'down':
      return 'DOWN';
    case 'pe_fibra':
      return 'PE_Fibra';
    case 'en_diagnostico':
      return 'En_Diagnostico';
    case 'en_atencion':
      return 'En_Atencion'; // <— NUEVO
    case 'obs':
      return 'OBS';
    default:
      if (canon == 'router' || canon == 'enlacesnogpon') return 'No_Precisa';
      return 'DOWN';
  }
}

// Etiqueta mostrable
String _groupPretty(String key) {
  switch (key) {
    case 'DOWN':
      return 'DOWN';
    case 'UP':
      return 'UP';
    case 'PE_Energia':
      return 'Posible Falla Eléctrica';
    case 'OBS':
      return 'OBS';
    case 'PE_Fibra':
      return 'Posible evento de Fibra';
    case 'En_Diagnostico':
      return 'En Diagnóstico';
    case 'En_Atencion':
      return 'En atención'; // <— NUEVO (nombre intacto)

    default:
      return key;
  }
}

IconData _groupIconByKey(String key) {
  switch (canonStatus(key)) {
    case 'up':
      return Icons.arrow_upward_rounded;
    case 'pe_energia':
      return Icons.bolt_rounded;
    case 'pe_fibra':
      return Icons.sensors_off_rounded;
    case 'en_diagnostico':
      return Icons.build_circle_rounded;
    case 'en_atencion':
      return Icons.pending_actions_rounded; // <— NUEVO
    case 'no_precisa':
      return Icons.help_outline_rounded;
    case 'down':
      return Icons.arrow_downward_rounded;
    case 'OBS':
      return Icons.search;
    default:
      return Icons.circle;
  }
}

const double _rowExtent = 96.0;

double _visiblePanelHeightFor(int itemsLen) {
  final visible = itemsLen >= 3 ? 3 : itemsLen;
  return visible * _rowExtent + 8; // +8 de respiro
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
  bool? _lastGrupoPref; // recuerda el último valor del switch Grupo/RUC
  List<Map<String, dynamic>> allServices = [];
  bool isLoadingServices = false;
  String? errorMessage;
  bool? _lastGrupoFlag; // ⬅️ NUEVO
  bool hasNotifications = false;
  late final MapController _mapController;
  bool showMap = false;
  GraphSocketProvider? _g;
  VoidCallback? _gListener;
  String? _selectedRuc;
  // Al inicio del State
  final GlobalKey _mapBoxKey = GlobalKey();

  bool _isActiveTicketStatus(String? estado) {
    final e = (estado ?? '').toLowerCase();
    if (e.isEmpty) return true;
    final closed = ['solucion', 'resuelt', 'cerr', 'ok', 'cancel'];
    return !closed.any(e.contains);
  }

  DateTime? _parseTicketDateEntidad(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();

    // Formato típico: "dd-MM-yyyy HH:mm:ss-0500"
    final re = RegExp(
      r'^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})([+-]\d{2})(\d{2})$',
    );
    final m = re.firstMatch(s);
    if (m != null) {
      final dd = m.group(1);
      final MM = m.group(2);
      final yyyy = m.group(3);
      final hh = m.group(4);
      final mm = m.group(5);
      final ss = m.group(6);
      final tzH = m.group(7); // +05 / -05
      final tzM = m.group(8); // 00 / 30, etc.
      final iso =
          '$yyyy-$MM-$dd'
          'T$hh:$mm:$ss'
          '${tzH!}:${tzM!}';
      try {
        return DateTime.parse(iso);
      } catch (_) {}
    }

    // fallback genérico
    try {
      String z = s;
      final zre = RegExp(r'([+-]\d{2})(\d{2})$');
      if (zre.hasMatch(z)) {
        z = z.replaceAllMapped(zre, (m) => '${m.group(1)}:${m.group(2)}');
      }
      return DateTime.tryParse(z);
    } catch (_) {
      return null;
    }
  }

  String _fmtDDMMYYEntidad(DateTime? dt, {String fallback = ''}) {
    if (dt == null) return fallback;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = (dt.year % 100).toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  String _twoLineUpperEntidad(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return 'TICKET';
    final up = t.toUpperCase();
    final idx = up.indexOf(' ');
    if (idx > 0) {
      return '${up.substring(0, idx)}\n${up.substring(idx + 1)}';
    }
    return up;
  }

  void _showTicketFromEntidad(BuildContext context, Map<String, dynamic> t) {
    // === 1) Mapear el JSON crudo / normalizado al modelo del TicketCard ===

    final code =
        (t['TicketId'] ?? t['NroTicket'] ?? t['ticket_id'] ?? t['id'] ?? '')
            .toString()
            .trim();

    final estado = (t['Estado'] ?? t['EstadoTicket'] ?? t['estado'] ?? '')
        .toString()
        .trim();

    final tipoRaw =
        (t['Tipo'] ?? t['tipo_ticket_nombre'] ?? t['TipoTicket'] ?? 'Ticket')
            .toString();

    final issueType = _twoLineUpperEntidad(tipoRaw);

    final area = (t['area'] ?? t['Area'] ?? t['equipo'] ?? '')
        .toString()
        .trim();

    final created = _parseTicketDateEntidad(
      (t['FechaCreacion'] ?? t['Fecha'] ?? t['hora_creacion'])?.toString(),
    );

    final date = _fmtDDMMYYEntidad(
      created,
      fallback: (t['FechaCreacion'] ?? t['Fecha'] ?? t['hora_creacion'] ?? '')
          .toString(),
    );

    int affected = 0;

    // 1) si viene como nroServicios
    if (t['nroServicios'] is num) {
      affected = (t['nroServicios'] as num).toInt();
    }

    // 2) si viene como lista de ServiciosAfectados
    String serviciosAfectadosText = '';
    if (t['ServiciosAfectados'] is List) {
      final list = (t['ServiciosAfectados'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      serviciosAfectadosText = list.join(', ');
      if (affected == 0) affected = list.length;
    } else if (t['Servicios'] is List) {
      // cuando lo normalizaste, guardaste solo "Servicios"
      final list = (t['Servicios'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      serviciosAfectadosText = list.join(', ');
      if (affected == 0) affected = list.length;
    }

    final isActive = _isActiveTicketStatus(estado);

    // Si no hay código, mejor no mostrar nada
    if (code.isEmpty) return;

    // === 2) Mostrar TicketCard en modal “mini” ===
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: bottom + 12,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420, // 👈 más angosto
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Detalle del ticket',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 👇 Aquí metemos el TicketCard “escalado”
                    Transform.scale(
                      scale: 0.85, // ajusta 0.8–0.9 a tu gusto
                      alignment: Alignment.topCenter,
                      child: TicketCard(
                        code: code,
                        date: date,
                        affectedStores: affected,
                        issueType: issueType,
                        status: estado.isEmpty ? '—' : estado,
                        isActive: isActive,
                        serviciosAfectados: serviciosAfectadosText,
                        area: area,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Código: $code',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'Estado: ${estado.isEmpty ? '—' : estado}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (serviciosAfectadosText.isNotEmpty)
                            Text(
                              'Servicios afectados: $serviciosAfectadosText',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          if (area.isNotEmpty)
                            Text(
                              'Área: $area',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRatesSheet({
    required String idServicio,
    required double uploadMbps,
    required double downloadMbps,
  }) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) {
        String _fmt(double v) => v.isFinite ? v.toStringAsFixed(1) : '—';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: const [
                    Icon(Icons.speed),
                    SizedBox(width: 8),
                    Text(
                      'Análisis BW',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BigRateCard(
                        label: 'Upload (Mbps)',
                        value: _fmt(uploadMbps),
                        icon: Icons.upload,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BigRateCard(
                        label: 'Download (Mbps)',
                        value: _fmt(downloadMbps),
                        icon: Icons.download,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Servicio: $idServicio',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  EdgeInsets _safeMapPadding() {
    final box = _mapBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return EdgeInsets.zero;
    final size = box.size;
    if (size.width <= 2 || size.height <= 2) return EdgeInsets.zero;
    final h = math.max(0.0, math.min(28.0, size.width / 2 - 1));
    final v = math.max(0.0, math.min(28.0, size.height / 2 - 1));
    if (h.isInfinite || h.isNaN || v.isInfinite || v.isNaN)
      return EdgeInsets.zero;
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  String _prettyCategory(String? raw) {
    if (raw == null) return '';
    final s = raw.trim().replaceAll('_', ' ');

    if (s.isEmpty) return '';

    // Opcional: ponerlo bonito en Title Case
    return s
        .split(' ')
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  /// POST con HttpClient respetando connectTimeout y commandTimeout
  /// POST /BW usando IdServicio (el backend resuelve la WAN)
  Future<Map<String, dynamic>> _fetchBandwidthMetricsById({
    required String idServicio,
    bool? save,
    int connectTimeoutMs = 10000,
    int commandTimeoutMs = 20000,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = Duration(milliseconds: connectTimeoutMs);
    final uri = Uri.parse('http://200.1.179.157:3000/BW');

    try {
      final req = await client.postUrl(uri);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );

      final payload = <String, dynamic>{'IdServicio': idServicio};
      if (save != null) payload['save'] = save;

      req.add(utf8.encode(jsonEncode(payload)));

      final res = await req.close().timeout(
        Duration(milliseconds: commandTimeoutMs),
      );
      final body = await utf8.decoder.bind(res).join();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw 'HTTP ${res.statusCode}';
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['ok'] != true) throw 'Respuesta inesperada del servidor';

      // el backend mantiene "metrics" con los mismos campos
      return Map<String, dynamic>.from((data['metrics'] as Map?) ?? const {});
    } on TimeoutException {
      throw 'Tiempo de espera agotado';
    } on SocketException {
      throw 'No se pudo conectar al host';
    } finally {
      client.close(force: true);
    }
  }

  /// Diálogo de carga simple (devuelve función para cerrarlo)
  VoidCallback _showBwLoadingDialog({required String title, String? subtitle}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );

    return () {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _chip(String label, String value) {
    final c = const Color(0xFF8B4A9C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        border: Border.all(color: c.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: c, fontWeight: FontWeight.w700),
          ),
          Text(value),
        ],
      ),
    );
  }

  void _scheduleFitToMarkers() {
    if (!showMap) return;
    final markers = _buildMarkersFromFiltered();
    if (markers.length < 2) return; // 0/1 no necesita fit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _mapBoxKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return; // aún sin tamaño → no hacemos nada
      final size = box.size;
      if (size.width <= 2 || size.height <= 2) return;

      final bounds = LatLngBounds.fromPoints(
        markers.map((m) => m.point).toList(),
      );
      try {
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: _safeMapPadding()),
        );
      } catch (_) {
        /* ignorar si el layout todavía cambia */
      }
    });
  }

  // ⬇️ NUEVO: elige un RUC preferido para el grupo activo
  String? _pickPreferredRuc(SessionProvider sp, GraphSocketProvider ws) {
    // 1) si el usuario ya eligió uno
    if (_selectedRuc != null && _selectedRuc!.isNotEmpty) return _selectedRuc;

    // 2) el que tenga en sesión o el que conocía el WS
    if ((sp.ruc ?? '').toString().isNotEmpty) return sp.ruc;
    if ((ws.ruc ?? '').toString().isNotEmpty) return ws.ruc;

    // 3) primero de la lista "bonita"
    for (final e in ws.rucsRazonesList) {
      final r = (e['ruc'] ?? e['RUC'] ?? '').toString();
      if (r.isNotEmpty) return r;
    }

    // 4) RUCs del resumen
    final rucs =
        (ws.resumen['RUCs'] as List?)?.map((e) => e.toString()).toList() ??
        const [];
    if (rucs.isNotEmpty) return rucs.first;

    // 5) RUCs_Razones del resumen
    final list = (ws.resumen['RUCs_Razones'] as List?) ?? const [];
    for (final it in list) {
      if (it is Map) {
        final r = (it['RUC'] ?? it['ruc'] ?? '').toString();
        if (r.isNotEmpty) return r;
      }
    }
    return null;
  }

  // Extrae una clave canónica SOLO NUMÉRICA del id de ticket (para deduplicar)
  String _canonTicketKey(dynamic raw) {
    final s = (raw ?? '').toString().toUpperCase().trim();
    if (s.isEmpty) return '';
    final cleaned = s.replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    ); // quita espacios, guiones, etc.
    final m = RegExp(
      r'(\d{4,})$',
    ).firstMatch(cleaned); // parte numérica final (>=4 dígitos)
    return m?.group(1) ?? cleaned; // fallback: todo el cleaned si no hay match
  }

  // Construye la etiqueta a mostrar (prefijo + número) respetando el tipo si existe
  String _ticketDisplayLabel(Map<String, dynamic> t) {
    final raw = (t['TicketId'] ?? t['NroTicket'] ?? t['id'] ?? '').toString();
    final num = _canonTicketKey(raw);
    final tipo = (t['Tipo'] ?? t['tipo_ticket_nombre'] ?? '')
        .toString()
        .toUpperCase();
    // 1) si el crudo ya trae prefijo (INC/SOL/etc) lo respetamos
    final prefFromRaw = RegExp(r'^[A-Z]+').firstMatch(raw)?.group(0) ?? '';
    if (prefFromRaw.isNotEmpty) return '$prefFromRaw$num';
    // 2) si no, inferimos por tipo
    String pref = '';
    if (tipo.contains('INC'))
      pref = 'INC';
    else if (tipo.contains('SOL'))
      pref = 'SOL';
    return pref.isEmpty ? num : '$pref$num';
  }

  // Merge simple: rellena campos vacíos del 'a' con los de 'b'
  Map<String, dynamic> _mergeTicketMaps(Map a, Map b) {
    final out = Map<String, dynamic>.from(a);
    for (final k in [
      'Estado',
      'Fecha',
      'Tipo',
      'ServiciosAfectados',
      'nroServicios',
      'Area',
    ]) {
      final av = (out[k]?.toString() ?? '').trim();
      final bv = (b[k]?.toString() ?? '').trim();
      if (av.isEmpty && bv.isNotEmpty) out[k] = b[k];
    }
    // conserva el TicketId más “rico” (con prefijo) si es que uno de los dos lo tiene
    final aid = (a['TicketId'] ?? '').toString();
    final bid = (b['TicketId'] ?? '').toString();
    final aHasPref = RegExp(r'^[A-Z]+').hasMatch(aid);
    final bHasPref = RegExp(r'^[A-Z]+').hasMatch(bid);
    if (!aHasPref && bHasPref) out['TicketId'] = bid;
    return out;
  }

  // ⚠️ Reemplaza por completo tu _loadAllServices con este
  Future<void> _loadAllServices() async {
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();

    setState(() {
      isLoadingServices = true;
      errorMessage = null;
    });

    try {
      if (sp.grupoEconomicoOrRuc) {
        final String? grupo = _grupoRawFromWs(ws); // ← con espacios

        if (grupo == null || grupo.isEmpty) {
          final ruc = sp.ruc;
          if (ruc == null || ruc.isEmpty) {
            setState(() {
              isLoadingServices = false;
              errorMessage = 'No hay RUC ni Grupo definidos.';
            });
            return;
          }
          if (!ws.isConnected && !ws.isConnecting) ws.connect(ruc);
          ws.requestGraphData(ruc); // poblar resumen con GRUPO
        } else {
          // Conecta por GRUPO y luego pide acordeón para un RUC preferido del grupo
          ws.connectByGroup(grupo, ws.rawColors); // ← con espacios

          final rPrefer = _pickPreferredRuc(sp, ws);
          if (rPrefer != null && rPrefer.isNotEmpty) {
            ws.requestGraphDataForSelection(ruc: rPrefer, grupo: grupo);
          } else {
            // al menos traer el resumen del grupo
            ws.requestGraphDataForSelection(grupo: grupo);
          }
        }
      } else {
        // Modo RUC
        final ruc = sp.ruc;
        if (ruc == null || ruc.isEmpty) {
          setState(() {
            isLoadingServices = false;
            errorMessage = 'No hay RUC configurado.';
          });
          return;
        }
        if (!ws.isConnected && !ws.isConnecting) ws.connect(ruc);
        ws.requestGraphData(ruc);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error WebSocket: $e';
        isLoadingServices = false;
        allServices = [];
        _tickets = [];
      });
    }
  }

  // ⚠️ Reemplaza por completo tu _activarModoGrupo con este
  Future<void> _activarModoGrupo() async {
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();

    if (mounted) {
      setState(() {
        isLoadingServices = true;
        errorMessage = null;
      });
    }

    // 1) Intentar leer el grupo (con espacios) del Resumen.
    String? grupo = _grupoRawFromWs(ws);

    // 2) Si aún no hay grupo, pide gráfica por RUC para poblar Resumen.
    if (grupo == null || grupo.isEmpty) {
      final ruc = sp.ruc;
      if (ruc == null || ruc.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay RUC para descubrir el GRUPO.')),
        );
        return;
      }
      if (!ws.isConnected && !ws.isConnecting) ws.connect(ruc);
      ws.requestGraphData(ruc);

      final ok = await _waitFor(
        () => (_grupoRawFromWs(ws) ?? '').isNotEmpty,
        timeout: const Duration(seconds: 3),
        poll: const Duration(milliseconds: 120),
      );
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontró GRUPO en el Resumen. Refresca Pre-Diagnósticos.',
            ),
          ),
        );
        return;
      }
      grupo = _grupoRawFromWs(ws);
    }

    // 3) Conecta por grupo y pide acordeón para un RUC del grupo
    ws.connectByGroup(grupo!, ws.rawColors); // ← con espacios

    final rPrefer = _pickPreferredRuc(sp, ws);
    if (rPrefer != null && rPrefer.isNotEmpty) {
      ws.requestGraphDataForSelection(ruc: rPrefer, grupo: grupo);
    } else {
      ws.requestGraphDataForSelection(grupo: grupo);
    }
  }

  // Enfoque de un único servicio (toggle)
  String? _focusedServiceId;

  void _toggleFocusServiceByMap(Map<String, dynamic> svc) {
    final id = (svc['IdServicio'] ?? svc['idservicio'] ?? '').toString();
    if (id.isEmpty) return;
    setState(() {
      // al tocar nuevamente el mismo servicio, se limpia
      _focusedServiceId = (_focusedServiceId == id) ? null : id;

      // para evitar conflictos, limpia búsqueda y chips de estado
      _searchController.clear();
      searchQuery = '';
      isSearching = false;
      selectedStatus = null;
    });
  }

  EntidadViewMode _view = EntidadViewMode.grouped; // ← nueva vista por defecto

  void setViewMode(EntidadViewMode mode) => setState(() => _view = mode);
  void toggleViewMode() => setState(
    () => _view = _view == EntidadViewMode.grouped
        ? EntidadViewMode.classic
        : EntidadViewMode.grouped,
  );

  Future<bool> _waitFor(
    bool Function() test, {
    Duration timeout = const Duration(seconds: 2),
    Duration poll = const Duration(milliseconds: 120),
  }) async {
    final limit = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(limit)) {
      if (test()) return true;
      await Future.delayed(poll);
    }
    return false;
  }

  // === Helpers GRUPO/RUC ===

  // Devuelve el grupo exactamente como lo espera el backend (con espacios).
  String? _grupoRawFromWs(GraphSocketProvider ws) {
    final r = ws.resumen;
    final raw = (r['GRUPO'] ?? r['GRUPO_ECONOMICO'] ?? r['Grupo_Empresarial'])
        ?.toString()
        .trim();
    if (raw != null && raw.isNotEmpty) return raw;

    // Fallback: si el provider guarda "GRUPO_WONG", lo denormalizamos a "GRUPO WONG"
    final cur = ws.currentGroupName?.toString();
    if (cur != null && cur.isNotEmpty) return cur.replaceAll('_', ' ').trim();

    return null;
  }

  Future<void> _volverAModoRuc() async {
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();
    final ruc = sp.ruc ?? ws.ruc;

    if (mounted) {
      setState(() {
        isLoadingServices = true;
        errorMessage = null;
      });
    }

    setState(() => _selectedRuc = null);

    if (ruc == null || ruc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay RUC configurado para reconectar.'),
        ),
      );
      return;
    }

    ws.connect(ruc); // <-- sin await
    ws.requestGraphData(ruc); // <-- sin await
  }

  void _openGrupoEmpresarialSheet() {
    final ws = context.read<GraphSocketProvider>();

    final String? grupo =
        (ws.resumen['GRUPO'] ?? ws.resumen['Grupo_Empresarial'])?.toString();
    if (grupo == null || grupo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay “GRUPO” disponible aún. Refresca.'),
        ),
      );
      return;
    }

    // 1) Prefiere la lista "RUCs_Razones"
    final List<Map<String, String?>> items =
        ((ws.resumen['RUCs_Razones'] as List?) ?? const [])
            .whereType<Map>()
            .map<Map<String, String?>>((e) {
              final m = Map<String, dynamic>.from(e);
              return {
                'ruc': m['RUC']?.toString(),
                'razon': m['Razon_Social']?.toString(),
              };
            })
            .toList();

    // 2) Fallback con RUCs + Map
    List<Map<String, String?>> lista = items;
    if (lista.isEmpty) {
      final rucs =
          (ws.resumen['RUCs'] as List?)?.map((e) => e.toString()).toList() ??
          const [];
      final mapRaz = Map<String, dynamic>.from(
        (ws.resumen['RUCs_Razones_Map'] as Map?) ?? const {},
      );
      lista = rucs
          .map((r) => {'ruc': r, 'razon': mapRaz[r]?.toString()})
          .toList();
    }

    if (lista.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El grupo no tiene RUCs listados')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      builder: (ctx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final ruc = lista[i]['ruc'] ?? '';
              final razon = lista[i]['razon'] ?? '—';
              final esActual = ruc == ws.ruc;

              return ListTile(
                dense: true,
                title: Text(razon),
                subtitle: Text(ruc),
                trailing: esActual
                    ? const Icon(Icons.check, color: Color(0xFF8B4A9C))
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  // Pedimos gráfica del RUC seleccionado DENTRO del grupo activo
                  await context
                      .read<GraphSocketProvider>()
                      .requestGraphDataForSelection(ruc: ruc, grupo: grupo);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mostrando servicios de: $razon ($ruc)'),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEconomicGroupsBar() {
    final ws = context.watch<GraphSocketProvider>();
    final enGrupo = ws.usingGroup;
    final groupName = (ws.currentGroupName ?? 'Grupo Empresarial').replaceAll(
      '_',
      ' ',
    );

    // 1) Lista “bonita” del provider
    List<Map<String, String>> items = ws.rucsRazonesList
        .map<Map<String, String>>(
          (e) => {
            'ruc': (e['ruc'] ?? '').toString(),
            'nombre': (e['nombre'] ?? e['razon'] ?? e['Razon_Social'] ?? '—')
                .toString(),
          },
        )
        .toList();

    // 2) Fallbacks desde resumen si está vacío
    if (items.isEmpty) {
      final rucs =
          (ws.resumen['RUCs'] as List?)?.map((e) => e.toString()).toList() ??
          const [];
      final mapRaz = Map<String, dynamic>.from(
        (ws.resumen['RUCs_Razones_Map'] as Map?) ?? const {},
      );
      if (rucs.isNotEmpty) {
        items = rucs
            .map<Map<String, String>>(
              (r) => {'ruc': r, 'nombre': (mapRaz[r]?.toString() ?? '—')},
            )
            .toList();
      } else {
        final list = (ws.resumen['RUCs_Razones'] as List?) ?? const [];
        items = list.whereType<Map>().map<Map<String, String>>((m) {
          final mm = Map<String, dynamic>.from(m);
          return {
            'ruc': (mm['RUC'] ?? '').toString(),
            'nombre': (mm['Razon_Social'] ?? '—').toString(),
          };
        }).toList();
      }
    }

    // Barra selectora de RUC
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: (!enGrupo || items.isEmpty)
            ? null
            : () {
                showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  builder: (ctx) {
                    final grupoRaw =
                        _grupoRawFromWs(ws) ?? groupName.replaceAll('_', ' ');
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            groupName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),

                          // 🔹 Opción para TODOS los RUCs del grupo
                          ListTile(
                            title: const Text('Ver todos'),
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _selectedRuc = null);
                              ws.clearSelectedGroupRuc();
                              ws.requestGraphDataForSelection(grupo: grupoRaw);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mostrando todos los RUCs del grupo',
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),

                          // Lista de RUCs
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final ruc = items[i]['ruc']!;
                                final nombre = items[i]['nombre']!;
                                return ListTile(
                                  title: Text(
                                    nombre,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(ruc),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    setState(() {
                                      _selectedRuc = ruc;
                                      selectedStatus = null;
                                      _focusedServiceId = null; // limpia foco
                                      _searchController.clear();
                                      searchQuery = '';
                                      isSearching = false;
                                      isLoadingServices = true;
                                    });
                                    ws.requestGraphDataForSelection(
                                      grupo: grupoRaw,
                                      ruc: ruc, // filtro dentro del grupo
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: enGrupo ? Colors.white : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  enGrupo
                      ? '$groupName — ${items.length} RUC${items.length == 1 ? '' : 's'}'
                      : 'Grupo Empresarial (activa el switch en Perfil)',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                enGrupo && items.isNotEmpty
                    ? Icons.expand_more
                    : Icons.chevron_right,
                size: 20,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );

    // Chips auxiliares (foco de servicio y RUC filtrado)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_view == EntidadViewMode.grouped && _focusedServiceId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.filter_center_focus),
                label: Text(
                  'Viendo solo servicio: $_focusedServiceId  •  Quitar',
                ),
                onPressed: () => setState(() => _focusedServiceId = null),
              ),
            ),
          ),

        // 🔹 Chip para quitar filtro por RUC (si hay uno seleccionado)
        if (ws.usingGroup && _selectedRuc != null && _selectedRuc!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.filter_alt_off),
                label: Text('RUC: $_selectedRuc  •  Quitar'),
                onPressed: () {
                  final grupoRaw =
                      _grupoRawFromWs(ws) ?? groupName.replaceAll('_', ' ');
                  setState(() => _selectedRuc = null);
                  ws.clearSelectedGroupRuc();
                  ws.requestGraphDataForSelection(grupo: grupoRaw);
                },
              ),
            ),
          ),

        bar,
      ],
    );
  }

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

  /// Elimina sufijos de zona horaria al FINAL de la cadena, incluyendo:
  ///  - " -0500", " -05:00", "+0530"
  ///  - "GMT-0500", "UTC -05:00"
  ///  - "(UTC -05:00)" o similares entre paréntesis
  ///  - el terco " 0500" sin signo
  String _stripTzSuffix(String s) {
    var out = s.trimRight();

    // (GMT/UTC ±HH[:mm]) entre paréntesis al final
    out = out.replaceAll(
      RegExp(r'\s*\((?:GMT|UTC)?\s*[+-]?\d{2}:?\d{2}\)\s*$'),
      '',
    );

    // "GMT-0500" o "UTC -05:00" al final (opcionalmente con texto extra entre GMT/UTC y el offset)
    out = out.replaceAll(
      RegExp(r'\s*(?:GMT|UTC)[^0-9+-]*[+-]\d{2}:?\d{2}\s*$'),
      '',
    );

    // Offset simple con signo al final, p.ej. " -0500" o " +05:30"
    out = out.replaceAll(RegExp(r'\s*[+-]\d{2}:?\d{2}\s*$'), '');

    // El " 0500" sin signo al final (cuatro dígitos pegados)
    out = out.replaceAll(RegExp(r'\s\d{4}\s*$'), '');

    // Si queda un paréntesis huérfano al final, también límpialo
    out = out.replaceAll(RegExp(r'\s*\([^)]+\)\s*$'), '');

    return out.trimRight();
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');

  String _fmtLocal(DateTime dt) =>
      '${_pad2(dt.day)}/${_pad2(dt.month)}/${dt.year} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';

  /// Intenta parsear múltiples formatos y devuelve DateTime en local.
  DateTime? _parseAnyDate(String v) {
    v = v.trim();
    if (v.isEmpty) return null;

    // 1) Solo dígitos: detectar con orden correcto para evitar falsos positivos
    final onlyDigits = RegExp(r'^\d+$');
    if (onlyDigits.hasMatch(v)) {
      // yyyyMMddHHmmss (14) — priorizar antes que "milisegundos"
      if (v.length == 14 && v.startsWith(RegExp(r'(19|20)'))) {
        final y = int.parse(v.substring(0, 4));
        final m = int.parse(v.substring(4, 6));
        final d = int.parse(v.substring(6, 8));
        final hh = int.parse(v.substring(8, 10));
        final mm = int.parse(v.substring(10, 12));
        final ss = int.parse(v.substring(12, 14));
        return DateTime(y, m, d, hh, mm, ss);
      }

      // yyyyMMdd (8)
      if (v.length == 8 && v.startsWith(RegExp(r'(19|20)'))) {
        final y = int.parse(v.substring(0, 4));
        final m = int.parse(v.substring(4, 6));
        final d = int.parse(v.substring(6, 8));
        return DateTime(y, m, d);
      }

      // Época en ms (13) o s (10). Se asume UTC.
      if (v.length == 13) {
        final n = int.tryParse(v);
        if (n != null) {
          return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toLocal();
        }
      }
      if (v.length == 10) {
        final n = int.tryParse(v);
        if (n != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            n * 1000,
            isUtc: true,
          ).toLocal();
        }
      }
    }

    // 2) ISO sin 'T' -> ponle 'T'
    if (RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}').hasMatch(v)) {
      v = v.replaceFirst(' ', 'T');
    }

    // 3) Normaliza "-0500" -> "-05:00" al final (si aún quedara)
    v = v.replaceAllMapped(
      RegExp(r'([+-]\d{2})(\d{2})$'),
      (m) => '${m.group(1)}:${m.group(2)}',
    );

    // 4) ISO/Z/offset estándar
    final iso = DateTime.tryParse(v);
    if (iso != null) return iso.isUtc ? iso.toLocal() : iso;

    // 5) dd/MM/yyyy (opcional hh:mm[:ss])
    final dmy = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$',
    );
    final mD = dmy.firstMatch(v);
    if (mD != null) {
      final d = int.parse(mD.group(1)!);
      final m = int.parse(mD.group(2)!);
      final y = int.parse(mD.group(3)!);
      final hh = int.tryParse(mD.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(mD.group(5) ?? '0') ?? 0;
      final ss = int.tryParse(mD.group(6) ?? '0') ?? 0;
      return DateTime(y, m, d, hh, mm, ss);
    }

    // 6) yyyy/MM/dd (opcional hh:mm[:ss])
    final ymdSlash = RegExp(
      r'^(\d{4})/(\d{2})/(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$',
    );
    final mY = ymdSlash.firstMatch(v);
    if (mY != null) {
      final y = int.parse(mY.group(1)!);
      final m = int.parse(mY.group(2)!);
      final d = int.parse(mY.group(3)!);
      final hh = int.tryParse(mY.group(4) ?? '0') ?? 0;
      final mm = int.tryParse(mY.group(5) ?? '0') ?? 0;
      final ss = int.tryParse(mY.group(6) ?? '0') ?? 0;
      return DateTime(y, m, d, hh, mm, ss);
    }

    return null;
  }

  /// Formatea una fecha heterogénea en "dd/MM/yyyy HH:mm" (hora local).
  /// - Limpia sufijos TZ al final (incluyendo " 0500").
  /// - Soporta epoch (s/ms), ISO, "yyyyMMdd", "yyyyMMddHHmmss",
  ///   "dd/MM/yyyy[ HH:mm[:ss]]", "yyyy/MM/dd[ HH:mm[:ss]]".
  String _formatTicketDate(String? raw) {
    if (raw == null) return '';
    String s = raw.trim();
    if (s.isEmpty) return '';

    // 1) Limpieza de basura TZ al final (incluye " 0500" sin signo)
    final cleaned = _stripTzSuffix(s);

    // 2) Intentos de parseo
    final dt = _parseAnyDate(cleaned);
    if (dt != null) return _fmtLocal(dt);

    // 3) Último recurso: si arranca con yyyyMMdd..., al menos muestra dd/MM/yyyy
    if (cleaned.length >= 8 && RegExp(r'^\d{8}').hasMatch(cleaned)) {
      try {
        final y = cleaned.substring(0, 4);
        final m = cleaned.substring(4, 6);
        final d = cleaned.substring(6, 8);
        return '$d/$m/$y';
      } catch (_) {
        /* ignore */
      }
    }

    // 4) Devuelve sin TZ basura (aunque no se pueda parsear)
    return cleaned;
  }

  // Afectados -> tickets normalizados
  List<Map<String, dynamic>> _ticketsFromAfectados(dynamic afectados) {
    if (afectados is! List) return const [];

    return afectados.whereType<Map>().map<Map<String, dynamic>>((t) {
      final servicios = (t['ServiciosAfectados'] is List)
          ? (t['ServiciosAfectados'] as List)
                .map((e) => _normalizeId(e))
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[];

      // 👇 IdAfectados tal como viene del backend
      final idAfectados =
          t['IdAfectados'] ?? t['IDAfectados'] ?? t['idAfectados'];

      final rawArea = (t['Area'] ?? t['area'] ?? t['Equipo'] ?? t['equipo'])
          ?.toString();

      final map = <String, dynamic>{
        'TicketId': _normalizeId(t['NroTicket']),
        'Estado': t['EstadoTicket']?.toString(),
        'Fecha': t['FechaCreacion']?.toString(),
        'Tipo': t['Tipo']?.toString(), // opcional
        'Servicios': servicios,
        // 👇 compat con _miniTicket
        'IdAfectados': idAfectados,
        'IDAfectados': idAfectados,
        'ServiciosAfectados': t['ServiciosAfectados'],
        'source': 'Afectados',
      };

      if (rawArea != null && rawArea.trim().isNotEmpty) {
        map['Area'] = rawArea.trim();
      }

      return map;
    }).toList();
  }

  // Item.acordeon.tickets.results -> tickets normalizados
  List<Map<String, dynamic>> _ticketsFromItem(Map it) {
    final tk = it['tickets'];
    if (tk is! Map) return const [];
    final results = tk['results'];
    if (results is! List) return const [];

    return results.whereType<Map>().map<Map<String, dynamic>>((r) {
      // Área: primero del ticket, si no del item padre
      final rawArea =
          (r['Area'] ??
                  r['area'] ??
                  it['Area'] ??
                  it['area'] ??
                  it['Equipo'] ??
                  it['equipo'])
              ?.toString();

      // 👇 IdAfectados puede venir en el ticket o en el item
      final idAfectados =
          r['IdAfectados'] ??
          r['IDAfectados'] ??
          it['IdAfectados'] ??
          it['IDAfectados'];

      final map = <String, dynamic>{
        'TicketId': _normalizeId(r['ticket_id'] ?? r['id'] ?? r['NroTicket']),
        'Estado': r['estado']?.toString() ?? r['EstadoTicket']?.toString(),
        'Fecha':
            r['hora_creacion']?.toString() ?? r['FechaCreacion']?.toString(),
        'Tipo': r['tipo_ticket_nombre']?.toString(),
        'Servicios': <String>[], // este origen no siempre trae servicios
        'IdAfectados': idAfectados,
        'IDAfectados': idAfectados,
        'ServiciosAfectados':
            r['ServiciosAfectados'] ?? it['ServiciosAfectados'],
        'source': 'Item',
      };

      if (rawArea != null && rawArea.trim().isNotEmpty) {
        map['Area'] = rawArea.trim();
      }

      return map;
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
    // remove duplicates por TicketId CANÓNICO por servicio
    map.updateAll((_, list) {
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final t in list) {
        final key = _canonTicketKey(t['TicketId']);
        if (key.isEmpty) continue;
        final idx = unique.indexWhere(
          (u) => _canonTicketKey(u['TicketId']) == key,
        );
        if (idx == -1) {
          unique.add(Map<String, dynamic>.from(t));
          seen.add(key);
        } else {
          unique[idx] = _mergeTicketMaps(
            unique[idx],
            t,
          ); // completa info (área, tipo, etc.)
        }
      }
      return unique;
    });

    _ticketsByService = map;
  }

  Widget _miniTicket(Map<String, dynamic> t) {
    final estado = (t['Estado'] ?? t['EstadoTicket'] ?? '').toString();
    final estadoColor = _ticketEstadoColor(estado);
    final fecha = _formatTicketDate(t['Fecha']?.toString());
    final tipo = (t['Tipo'] ?? '').toString();
    final code = _ticketDisplayLabel(t); // INC/SOL + número normalizado

    final afectados =
        (t['IdAfectados'] ?? t['IDAfectados'] ?? t['ServiciosAfectados'] ?? '')
            .toString();

    final area = (t['Area'] ?? t['area'] ?? '').toString().trim();
    final isActive = _isActiveTicketStatus(estado);

    const accent = Color(0xFFBA0DB4); // tu fucsia

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 1.3),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== Fila superior: código + tipo + chip ACTIVO ==========
          Row(
            children: [
              // Pastilla de código
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Tipo de ticket (INC / SOL / etc)
              if (tipo.isNotEmpty)
                Expanded(
                  child: Text(
                    tipo.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),

          const SizedBox(height: 6),

          // ========== ID Afectados (si existe) ==========
          if (afectados.isNotEmpty) ...[
            Text(
              'ID Afectados: $afectados',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ========== Fecha + Área + Estado a la derecha ==========
          Row(
            children: [
              Expanded(
                child: Text(
                  [if (fecha.isNotEmpty) fecha].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),

              Expanded(
                child: Text(
                  [if (area.isNotEmpty) area].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),

              const SizedBox(width: 6),
              Text(
                estado.isEmpty ? '—' : estado,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: estadoColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _resolveAreaForTickets(
    List<Map<String, dynamic>> tickets, {
    String? fallbackArea,
  }) {
    // Busca el primer ticket que tenga área en cualquiera de estas claves
    for (final t in tickets) {
      final a = (t['Area'] ?? t['area'] ?? t['Equipo'] ?? t['equipo'])
          ?.toString()
          .trim();
      if (a != null && a.isNotEmpty) return a;
    }
    // Si ninguno la tiene, usa el fallback (por ejemplo, del servicio)
    return fallbackArea ?? '';
  }

  List<Map<String, dynamic>> _ticketsForService(String idServicio) {
    final id = _normalizeId(idServicio);
    if (id.isEmpty) return const [];
    return _ticketsByService[id] ?? const [];
  }

  void _showTicketsSheet(
    List<Map<String, dynamic>> tickets, {
    String? title,
    String? areaOverride, // 👈 NUEVO
  }) {
    if (tickets.isEmpty) return;
    debugPrint('FIRST TICKET SHEET: ${tickets.first}');

    // 👇 En vez de usar solo tickets.first, resolvemos bien el área
    final area = _resolveAreaForTickets(tickets, fallbackArea: areaOverride);

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.receipt_long, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? 'Tickets relacionados',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (area.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            area,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...tickets.map(
                (t) => InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showTicketFromEntidad(context, t);
                  },
                  child: SafeArea(child: _miniTicket(t)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === Agrupación SOLO PARA LEYENDA (visual) ===
  // ONULOS + OLTLOS (+ LOST si aparece)  -> "Posible evento de Fibra"
  // POWER (o ENERGIA)                    -> "Posible Falla Eléctrica"
  // Todo lo que no sea UP ni lo anterior -> "No Precisa"
  // UP                                   -> "UP"

  String? _svcRuc(Map<String, dynamic> svc) {
    final direct =
        svc['RUC'] ?? svc['ruc'] ?? svc['cliente_ruc'] ?? svc['ruc_cliente'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final det = svc['details'];
    if (det is Map) {
      final m = Map<String, dynamic>.from(det);
      final v = m['RUC'] ?? m['ruc'] ?? m['cliente_ruc'] ?? m['ruc_cliente'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _statusData(GraphSocketProvider g) {
    final counts = <String, int>{};

    final n = math.min(g.leyenda.length, g.valores.length);
    for (int i = 0; i < n; i++) {
      final raw = g.leyenda[i].toString();
      final val = g.valores[i].toInt();
      if (val <= 0) continue;

      final canon = canonStatus(raw);
      final key = _groupKeyFromCanon(canon); // 'PE_Fibra', etc.
      counts[key] = (counts[key] ?? 0) + val;
    }

    // orden visual
    const order = [
      'UP',
      'PE_Fibra',
      'PE_Energia',
      'En_Diagnostico',
      'En_Atencion', // <— NUEVO
      'No_Precisa',
    ];

    final keys = [
      ...order.where(counts.containsKey),
      ...counts.keys.where((k) => !order.contains(k)),
    ];

    return keys.map((key) {
      final color = _groupColorFromSocketOrDefault(key);

      return {
        'key': key, // para filtrar
        'label': _groupPretty(key), // para mostrar
        'value': counts[key]!,
        'color': color,
        'icon': _groupIconByKey(key),
      };
    }).toList();
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
            final key = data[i]['key'] as String; // 'PE_Fibra'
            final label =
                data[i]['label'] as String; // 'Posible evento de Fibra'
            final value = (data[i]['value'] as int).toString().padLeft(2, '0');
            final color = data[i]['color'] as Color;
            final isSel = selectedStatus == key;

            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => toggleStatusFilter(key), // ← filtra por clave
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
    _mapController = MapController();
    _lastGrupoFlag = context
        .read<SessionProvider>()
        .grupoEconomicoOrRuc; // ⬅️ NUEVO
    final preferModern = context.read<SessionProvider>().preferModernView;
    _view = preferModern ? EntidadViewMode.grouped : EntidadViewMode.classic;

    _lastGrupoPref = context.read<SessionProvider>().grupoEconomicoOrRuc; // 👈

    // Búsqueda
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase().trim();
        isSearching = searchQuery.isNotEmpty;
      });
    });

    // 🔗 Suscripción al provider + conexión inicial (respeta Grupo vs RUC)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _g = context.read<GraphSocketProvider>();
      _gListener = () => _recomputeFromWs(_g!);
      _g!.addListener(_gListener!);

      // banderita de carga
      if (mounted) {
        setState(() {
          isLoadingServices = true;
          errorMessage = null;
        });
      }

      final sp = context.read<SessionProvider>();

      if (sp.grupoEconomicoOrRuc) {
        // Arrancar directo en modo GRUPO si el switch ya venía activo
        _activarModoGrupo(); // sin await
      } else {
        // Modo RUC clásico
        final ruc = sp.ruc;
        if (ruc != null && ruc.isNotEmpty) {
          if (!_g!.isConnected && !_g!.isConnecting) {
            _g!.connect(ruc); // sin await
          }
          if (_g!.acordeon.isNotEmpty) {
            _recomputeFromWs(_g!);
          } else {
            _g!.requestGraphData(ruc); // sin await
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final sp = context.watch<SessionProvider>();

    // Mantén esto: solo sincroniza la vista
    final desired = sp.preferModernView
        ? EntidadViewMode.grouped
        : EntidadViewMode.classic;
    if (_view != desired) {
      setState(() => _view = desired); // setState aquí es válido
    }

    // ⬇️ Mover toda mutación de Provider a post-frame
    if (_lastGrupoFlag != sp.grupoEconomicoOrRuc) {
      _lastGrupoFlag = sp.grupoEconomicoOrRuc;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (_lastGrupoFlag == true) {
          // ✅ ahora es seguro tocar el provider
          _activarModoGrupo(); // esta no toca SessionProvider
        } else {
          _volverAModoRuc(); // esta tampoco toca SessionProvider
        }
      });
    }
  }

  @override
  void dispose() {
    if (_g != null && _gListener != null) {
      _g!.removeListener(_gListener!);
    }
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

  Color _groupColorFromSocketOrDefault(String groupKey) {
    final g = context.read<GraphSocketProvider>();
    final canonGroup = canonStatus(groupKey); // 'pe_fibra', 'pe_energia', ...

    // 0) Si el WS mandó colorMap, intenta por clave exacta y por canon
    final byExact = g.colorOf(groupKey);
    if (byExact != null) return byExact;
    final byCanon = g.colorOf(canonGroup);
    if (byCanon != null) return byCanon;

    // 1) Paleta fija por canon (consistencia visual)
    final fixed = kDefaultStatusColors[canonGroup];
    if (fixed != null) return fixed;

    // 2) Último recurso: color determinístico (nunca gris)
    return _hashColor(canonGroup);
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
    final svcs = filteredServices;
    const cap = 800; // ajusta a tu device
    final take = svcs.length > cap ? svcs.take(cap) : svcs;
    return [
      for (final svc in take)
        if (_parseLatLngFromService(svc) case final pos?)
          Marker(
            point: pos,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showServiceSheet(
                svc,
                pos,
                _getColorForStatusRPA(
                  svc['parameterUsed']?.toString() ??
                      svc['StatusRPA']?.toString() ??
                      '',
                ),
              ),
              child: Icon(
                Icons.location_on,
                size: 40,
                color: _getColorForStatusRPA(
                  svc['parameterUsed']?.toString() ??
                      svc['StatusRPA']?.toString() ??
                      '',
                ),
              ),
            ),
          ),
    ];
  }

  void _fitToMarkers(List<Marker> markers) {
    if (markers.isEmpty) return;

    if (markers.length == 1) {
      _mapController.move(markers.first.point, 16.5);
      return;
    }

    final pts = markers.map((m) => m.point).toList();
    final first = pts.first;
    final allEqual = pts.every(
      (p) => p.latitude == first.latitude && p.longitude == first.longitude,
    );
    if (allEqual) {
      _mapController.move(first, 17);
      return;
    }

    final bounds = LatLngBounds.fromPoints(pts);

    // Protección extra: si por algún motivo los bounds no son válidos
    if (bounds.southWest == bounds.northEast) {
      _mapController.move(first, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: _safeMapPadding()),
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

  void _recomputeFromWs(GraphSocketProvider g) {
    if (!mounted) return;

    // Si no hay acordeón, no marcamos error; solo seguimos esperando.
    if (g.acordeon.isEmpty) return;

    // Reconstruye lista de servicios + tickets

    final wsList = <Map<String, dynamic>>[];
    final collectedTickets = <Map<String, dynamic>>[];
    final seen = <String>{};

    final defaultComercial = (g.resumen['Comercial'] ?? g.resumen['comercial'])
        ?.toString();
    final defaultCobranza = (g.resumen['Cobranza'] ?? g.resumen['cobranza'])
        ?.toString();

    // Tickets globales (Afectados)
    collectedTickets.addAll(_ticketsFromAfectados(g.afectados));

    g.acordeon.forEach((rawParam, value) {
      final paramUpper = rawParam.toString().toUpperCase(); // e.g., EN_ATENCION
      final items = (value is List)
          ? value
          : (value is Map)
          ? [value]
          : const [];

      for (final itDyn in items) {
        if (itDyn is! Map) continue;
        final it = Map<String, dynamic>.from(itDyn as Map);

        final rawId = (it['ID_Servicio'] ?? it['idservicio'] ?? '').toString();
        if (rawId.isEmpty || seen.contains(rawId)) continue;
        seen.add(rawId);

        final dirMap = (it['direccion'] is Map)
            ? Map<String, dynamic>.from(it['direccion'])
            : const {};
        final composed = _composeDireccionCompleta({
          'direccion': dirMap['direccion'] ?? it['direccionodoo'],
          'distrito': dirMap['distrito'] ?? it['distritoodoo'],
          'provincia': dirMap['provincia'] ?? it['provinciaodoo'],
          'departamento': dirMap['departamento'] ?? it['dptoodoo'],
        });

        // Tickets por ítem
        final perItemTickets = _ticketsFromItem(it);
        if (perItemTickets.isNotEmpty) collectedTickets.addAll(perItemTickets);

        final rucIt =
            (it['RUC'] ??
                    it['ruc'] ??
                    it['cliente_ruc'] ??
                    it['ruc_cliente'] ??
                    g.resumen['RUC'] ??
                    g.resumen['ruc'])
                ?.toString();

        wsList.add({
          'RUC': rucIt,
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

          // 🔹 NUEVO: categoría y color de categoría (si vienen del WS)
          'Categoria': it['Categoria'] ?? it['categoria'],
          'ColorCategoria': it['ColorCategoria'] ?? it['colorCategoria'],

          // ← mantenemos EXACTAMENTE la clave del acordeón (EN_ATENCION, etc.)
          'parameterUsed': paramUpper,

          'details': it,
        });
      }
    });

    _rebuildTicketIndex(services: wsList, tickets: collectedTickets);

    setState(() {
      allServices = wsList;
      _tickets = collectedTickets;
      isLoadingServices = false; // ya tenemos data
      errorMessage = null; // limpia cualquier mensaje previo
    });
  }

  Widget _buildIncidentsMapCard() {
    if (!showMap) return const SizedBox.shrink();

    final markers = _buildMarkersFromFiltered();
    LatLng? initialCenter;
    double initialZoom = 13;

    if (markers.isNotEmpty) {
      initialCenter = markers.first.point;
      if (markers.length == 1) initialZoom = 16.5;
    } else {
      initialCenter = const LatLng(-12.0464, -77.0428); // Lima fallback
    }
    int _tileErrorCount = 0;

    final bounds = (markers.length >= 2)
        ? LatLngBounds.fromPoints(markers.map((m) => m.point).toList())
        : null;
    // Usa onMapReady para el fit, no `initialCameraFit`.

    return Container(
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
        child: Container(
          key: _mapBoxKey, // ← nos deja medir el tamaño real
          height: 220,
          child: FlutterMap(
            key: const ValueKey('persistent-flutter-map'),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              minZoom: 3,
              maxZoom: 19,
              initialCameraFit: bounds == null
                  ? null
                  : CameraFit.bounds(
                      bounds: bounds,
                      padding: _safeMapPadding(),
                    ),
              onMapReady: () {
                // Si no pusiste initialCameraFit, ajusta aquí:
                if (bounds == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _fitToMarkers(markers);
                  });
                }
              },
            ),

            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fiberlux.app',
                tileProvider: NetworkTileProvider(),
                maxZoom: 19,
                maxNativeZoom: 19,
                errorTileCallback: (tile, error, stack) {
                  _tileErrorCount++;
                  debugPrint('OSM tile error: $error');
                  if (_tileErrorCount > 20 && mounted) {
                    // Degrada con gracia si no hay red/DNS
                    setState(() => showMap = false);
                    // (Opcional) muestra un snackbar informando que no hay mapas offline
                  }
                },
              ),

              MarkerLayer(markers: _buildMarkersFromFiltered()),
            ],
          ),
        ),
      ),
    );
  }

  // NUEVO: Lista filtrada que considera tanto el estado seleccionado como la búsqueda
  // Reemplaza la función get filteredServices (líneas aproximadamente 110-150)
  List<Map<String, dynamic>> get filteredServices {
    List<Map<String, dynamic>> services = allServices;
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();

    // Si estamos en modo GRUPO, filtra por el RUC seleccionado
    if (sp.grupoEconomicoOrRuc && ws.usingGroup) {
      // Sin “defaults”: solo filtra si el usuario seleccionó explícitamente un RUC
      final targetRuc = _selectedRuc;
      if (targetRuc != null && targetRuc.isNotEmpty) {
        services = services.where((svc) => _svcRuc(svc) == targetRuc).toList();
      }
    }

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

    // Filtro por estado seleccionado (robusto y con grupos visuales)
    if (selectedStatus != null && !isSearching) {
      final sel = _normStatus(
        selectedStatus!,
      ); // 'pefibra', 'peenergia', 'endiagnostico', 'noprecisa', 'up'

      bool matchesGroup(String raw) {
        final c = canonStatus(raw); // canon
        switch (sel) {
          case 'up':
            return c == 'up';
          case 'peenergia':
            return c == 'pe_energia';
          case 'enatencion':
            return c == 'en_atencion';
          case 'pefibra':
            return c == 'pe_fibra';
          case 'endiagnostico':
            return c == 'en_diagnostico' || c == 'down';
          case 'down':
            // cuando tocas la tarjeta/gráfico "DOWN"
            return c == 'down';

          case 'noprecisa':
            return c == 'no_precisa' || c == 'router' || c == 'enlacesnogpon';
          default:
            return false;
        }
      }

      services = services.where((svc) {
        final raw = (svc['parameterUsed'] ?? '').toString();
        return matchesGroup(raw);
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

    // 🔎 Enfoque de un único servicio (solo vista AGRUPADA)
    // Requiere: String? _focusedServiceId; y el toggle en el onTap de cada fila.
    if (_view == EntidadViewMode.grouped && _focusedServiceId != null) {
      services = services.where((s) {
        final id = (s['IdServicio'] ?? s['idservicio'] ?? '').toString();
        return id == _focusedServiceId;
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
      // ⬅️ Si filtro por estado, no tiene sentido dejar un servicio enfocado
      _focusedServiceId = null;

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

  Color _getColorForStatusRPA(String rawParameterUsed) {
    final g = context.read<GraphSocketProvider>();

    // 1) Color específico si el WS lo definió en colorMap
    final byName = g.colorOf(rawParameterUsed);
    if (byName != null) return byName;

    // 2) Si no, usa el color del GRUPO (consistente)
    final canon = canonStatus(rawParameterUsed);
    final groupKey = _groupKeyFromCanon(canon);
    return _groupColorFromSocketOrDefault(groupKey);
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);

    if (session.ruc == null) {
      return SafeArea(
        child: Scaffold(
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
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        endDrawer: FiberluxDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildEntityTitle(),

              if (_view == EntidadViewMode.classic) ...[
                if (!isSearching)
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 200),
                    crossFadeState: showMap
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Column(
                      children: [
                        _buildStatusCards(),
                        _buildProgressBar(),
                        _buildEconomicGroupsBar(),
                      ],
                    ),
                    secondChild: Column(
                      children: [
                        _buildStatusChipsHorizontal(),
                        _buildProgressBar(),
                        _buildEconomicGroupsBar(),
                      ],
                    ),
                  ),

                if (showMap && !isSearching) const SizedBox(height: 6),
                _buildIncidentsMapCard(),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    child: _buildServicesList(), // lista plana clásica
                  ),
                ),
                _buildSearchBar(),
              ] else ...[
                // ====== VISTA AGRUPADA (TODO en la lista con expansibles) ======
                _buildProgressBar(),
                _buildEconomicGroupsBar(),
                _buildIncidentsMapCard(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    child: _buildGroupedListScreen(),
                  ),
                ),
                _buildSearchBar(),
              ],
            ],
          ),
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
            ],
          ),
          Row(
            children: [
              // 👇 Campana reutilizable
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      NotificationOverlay.isShowing
                          ? Icons.notifications
                          : Icons.notifications_outlined,
                      color: Colors.purple, // o tu color
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

  Map<String, List<Map<String, dynamic>>> _servicesByGroup(
    List<Map<String, dynamic>> services,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final svc in services) {
      // Usamos parameterUsed (WS) o StatusRPA (fallback)
      final raw = (svc['parameterUsed'] ?? svc['StatusRPA'] ?? '').toString();
      final canon = canonStatus(
        raw,
      ); // up / pe_energia / pe_fibra / en_diagnostico / no_precisa / ...
      final key = _groupKeyFromCanon(
        canon,
      ); // 'UP' | 'PE_Energia' | 'PE_Fibra' | 'En_Diagnostico' | 'No_Precisa'
      (grouped[key] ??= <Map<String, dynamic>>[]).add(svc);
    }

    // (Opcional) ordenar cada grupo por IdServicio para una lectura consistente
    for (final k in grouped.keys) {
      grouped[k]!.sort(
        (a, b) => (a['IdServicio'] ?? '').toString().compareTo(
          (b['IdServicio'] ?? '').toString(),
        ),
      );
    }
    return grouped;
  }

  Widget _buildGroupedListScreen() {
    // Si hay búsqueda, resultados planos ya filtrados
    if (isSearching) {
      final results = filteredServices;
      return _buildFlatResults(results);
    }

    // ✅ Aplica filtros también en la vista agrupada:
    // - RUC seleccionado (en modo grupo)
    // - Estado seleccionado (chips)
    // - Servicio enfocado (chip “Viendo solo servicio…”)
    final ws = context.read<GraphSocketProvider>();
    final bool hasRucFilter =
        ws.usingGroup && (_selectedRuc != null && _selectedRuc!.isNotEmpty);
    final bool hasStatusFilter = (selectedStatus != null);
    final bool focusingOne =
        (_view == EntidadViewMode.grouped && _focusedServiceId != null);

    // Si hay CUALQUIER filtro activo, usa filteredServices
    final List<Map<String, dynamic>> source =
        (hasRucFilter || hasStatusFilter || focusingOne)
        ? filteredServices
        : allServices;

    // Agrupa lo que toque mostrar
    final groups = _servicesByGroup(source);

    // Orden visual de grupos
    const order = [
      'UP',
      'En_Diagnostico',
      'En_Atencion',
      'PE_Fibra',
      'PE_Energia',
      'No_Precisa',
    ];
    final keys = [
      ...order.where(groups.containsKey),
      ...groups.keys.where((k) => !order.contains(k)),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        final color = _groupColorFromSocketOrDefault(key);
        final icon = _groupIconByKey(key);
        final label = _groupPretty(key);
        final items = groups[key] ?? const <Map<String, dynamic>>[];
        final count = items.length;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
                      '$count',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Sin servicios en esta categoría',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: (items.length > 3)
                        ? SizedBox(
                            key: const ValueKey('scrollable-group'),
                            height: _visiblePanelHeightFor(items.length),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              itemCount: items.length,
                              shrinkWrap: true,
                              primary: false,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              itemBuilder: (_, j) => _miniServiceRow(items[j]),
                            ),
                          )
                        : Column(
                            key: const ValueKey('simple-group'),
                            children: items
                                .map<Widget>((svc) => _miniServiceRow(svc))
                                .toList(),
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color? _parseCategoriaColor(dynamic raw) {
    if (raw == null) return null;
    if (raw is Color) return raw;

    String s = raw.toString().trim();
    if (s.isEmpty) return null;

    // 1) NOMBRES: "greenAccent", "green_accent", "green-accent", etc.
    final key = s.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

    switch (key) {
      case 'greenaccent':
        return Colors.greenAccent;
      case 'green':
        return Colors.green;

      case 'redaccent':
        return Colors.redAccent;
      case 'red':
        return Colors.red;

      case 'blueaccent':
        return Colors.blueAccent;
      case 'blue':
        return Colors.blue;

      case 'amberaccent':
        return Colors.amberAccent;
      case 'amber':
        return Colors.amber;

      case 'orangeaccent':
        return Colors.orangeAccent;
      case 'orange':
        return Colors.orange;

      case 'deeppurpleaccent':
        return Colors.deepPurpleAccent;
      case 'deeppurple':
        return Colors.deepPurple;

      case 'tealaccent':
        return Colors.tealAccent;
      case 'teal':
        return Colors.teal;

      case 'pinkaccent':
        return Colors.pinkAccent;
      case 'pink':
        return Colors.pink;

      case 'cyanaccent':
        return Colors.cyanAccent;
      case 'cyan':
        return Colors.cyan;

      case 'lightgreenaccent':
        return Colors.lightGreenAccent;
      case 'lightgreen':
        return Colors.lightGreen;

      case 'limeaccent':
        return Colors.limeAccent;
      case 'lime':
        return Colors.lime;

      case 'deeporangeaccent':
        return Colors.deepOrangeAccent;
      case 'deeporange':
        return Colors.deepOrange;

      case 'grey':
      case 'gray':
        return Colors.grey;
      case 'bluegrey':
        return Colors.blueGrey;
    }

    // 2) ENTERO ARGB
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final v = int.tryParse(s);
      if (v != null) return Color(v);
    }

    // 3) HEX: "#RRGGBB", "RRGGBB", "#AARRGGBB"
    if (s.startsWith('#')) s = s.substring(1);

    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    } else if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      if (v != null) return Color(v);
    }

    return null;
  }

  /// Etiqueta de categoría para servicios UP / DOWN
  /// Etiqueta de categoría para servicios UP / DOWN
  Widget? _buildCategoriaChip(Map<String, dynamic> service) {
    final rawParam = (service['parameterUsed'] ?? service['StatusRPA'] ?? '')
        .toString();
    final canon = canonStatus(rawParam);

    // Solo pintar categoría para UP y DOWN
    if (canon != 'up' && canon != 'down') return null;

    final categoriaRaw = (service['Categoria'] ?? service['categoria'] ?? '')
        .toString()
        .trim();
    if (categoriaRaw.isEmpty) return null;

    final label = _prettyCategory(
      categoriaRaw,
    ); // ← aquí limpiamos "_" y title case

    // Intentamos parsear el color; si falla, usamos el morado base
    final rawColor = service['ColorCategoria'] ?? service['colorCategoria'];
    final parsedColor = _parseCategoriaColor(rawColor);
    final color = parsedColor ?? const Color(0xFF8B4A9C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      child: Text(
        label, // ← ya sin underscores
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _miniServiceRow(Map<String, dynamic> service) {
    final categoriaChip = _buildCategoriaChip(service);
    final parameterUsed = (service['parameterUsed'] ?? '').toString();
    final color = _getColorForStatusRPA(parameterUsed);
    final id = (service['IdServicio'] ?? '').toString();
    final dir =
        (service['DireccionFull'] ??
                service['DireccionOdoo'] ??
                'Sin dirección')
            .toString();
    final date = _formatDate(service['DESDE']);
    final related = _ticketsForService(id);
    final tCount = related.length;
    final bool isGrouped = (_view == EntidadViewMode.grouped);
    final bool isFocused = (_focusedServiceId == id);

    return InkWell(
      // 👇 Tap SIEMPRE abre detalles (ya no filtra)
      onTap: () => navigateToServiceDetail(service),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(id, overflow: TextOverflow.ellipsis)),

                // 👉 Botón "Filtrar" (solo en vista agrupada)
                if (isGrouped) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () => _toggleFocusServiceByMap(service),
                    icon: Icon(
                      isFocused ? Icons.filter_alt_off : Icons.filter_alt,
                      size: 16,
                    ),
                    label: Text(isFocused ? 'Quitar' : 'Filtrar'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 6),

                // 👉 Botón "Detalles"
                ElevatedButton.icon(
                  onPressed: () => navigateToServiceDetail(service),
                  icon: const Icon(Icons.chevron_right, size: 16),
                  label: const Text('Detalles'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Dirección
            Text(
              dir,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 🔹 Etiqueta de categoría (solo UP/DOWN si hay data)
                if (categoriaChip != null) ...[
                  categoriaChip,
                  const SizedBox(width: 8),
                ],

                // Fecha
                if (date.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Tickets
                if (tCount > 0) ...[
                  InkWell(
                    onTap: () =>
                        _showTicketsSheet(related, title: 'Tickets de $id'),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$tCount',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatResults(List<Map<String, dynamic>> services) {
    if (services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sin resultados para "$searchQuery"',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: services.length,
      itemBuilder: (_, i) => _miniServiceRow(services[i]),
    );
  }

  Widget _buildEntityTitle() {
    final purple = const Color(0xFF8B4A9C);
    final sp = context.watch<SessionProvider>();
    final ws = context.watch<GraphSocketProvider>();

    // Nombre de grupo con espacios (GRUPO / GRUPO_ECONOMICO / Grupo_Empresarial)
    final String? grupoNombre = (() {
      final r = ws.resumen;
      final raw = (r['GRUPO'] ?? r['GRUPO_ECONOMICO'] ?? r['Grupo_Empresarial'])
          ?.toString()
          .trim();
      if (raw != null && raw.isNotEmpty) return raw;
      final cur = ws.currentGroupName?.toString();
      return (cur == null || cur.isEmpty)
          ? null
          : cur.replaceAll('_', ' ').trim();
    })();

    final bool isGroupedView = _view == EntidadViewMode.grouped;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Título a la izquierda
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Diagnosticos',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                if (sp.grupoEconomicoOrRuc &&
                    (grupoNombre?.isNotEmpty ?? false))
                  Text(
                    'Grupo: $grupoNombre',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),

          // Botones a la derecha
          Row(
            children: [
              // Toggle Mapa
              TextButton.icon(
                onPressed: () {
                  if (showMap) {
                    setState(() => showMap = false);
                  } else {
                    setState(() => showMap = true);
                    _scheduleFitToMarkers(); // ← centrado seguro
                  }
                },

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),

              const SizedBox(width: 6),

              // Cambiar vista (Agrupada ↔ Clásica)
            ],
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

    // Reusa la lista ya filtrada (> 0)
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
              final key =
                  item['key'] as String; // <-- clave de grupo para filtrar
              final label = item['label'] as String; // <-- texto mostrado
              final value = item['value'] as int;
              final color = item['color'] as Color;
              final icon = item['icon'] as IconData;

              final isSel = selectedStatus == key; // <-- comparar contra key

              // Si la última fila tiene solo 1 ítem, que ocupe todo el ancho
              final isLonelyLast = (rem == 1) && (i == lastIndex);
              final width = isLonelyLast ? constraints.maxWidth : tileW;

              return SizedBox(
                width: width,
                height: tileH,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => toggleStatusFilter(key), // <-- togglear con key
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
    if (!g.isConnected) return const SizedBox.shrink();

    final data = _statusData(g);
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold<int>(0, (s, it) => s + (it['value'] as int));
    if (total <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(data.length, (index) {
          final int value = data[index]['value'] as int;
          final String key = data[index]['key'] as String;
          final Color color = data[index]['color'] as Color;

          final double percent = value / total;
          final bool isSel = (selectedStatus == key);

          // ancho mínimo para que no “desaparezca”
          final int flex = (percent * 100 + 10).toInt();

          return Expanded(
            flex: flex,
            child: Column(
              children: [
                Container(
                  height: isSel ? 12 : 10,
                  decoration: BoxDecoration(
                    color: color, // nunca gris
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : const [],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(percent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.normal,
                    color: isSel ? color : Colors.grey[700],
                  ),
                ),
              ],
            ),
          );
        }),
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
    final g = Provider.of<GraphSocketProvider>(context);

    // Helper local: obtiene el nombre de grupo tal cual (con ESPACIOS),
    // ya sea desde Resumen o desde currentGroupName "denormalizando" _ -> ' '.
    String? grupoRaw(GraphSocketProvider ws) {
      final r = ws.resumen;
      final raw = (r['GRUPO'] ?? r['GRUPO_ECONOMICO'] ?? r['Grupo_Empresarial'])
          ?.toString()
          .trim();
      if (raw != null && raw.isNotEmpty) return raw;

      final cur = ws.currentGroupName?.toString();
      if (cur != null && cur.isNotEmpty) return cur.replaceAll('_', ' ').trim();

      return null;
    }

    // 1) Mientras el WS está conectado pero aún no llega el acordeón, mostramos "esperando"
    if (g.isConnected && isLoadingServices && allServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF8B4A9C)),
            const SizedBox(height: 16),
            Text(
              'Esperando datos del WebSocket...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Solicitar de nuevo'),
              onPressed: () {
                final sp = context.read<SessionProvider>();
                final ws = context.read<GraphSocketProvider>();

                if (sp.grupoEconomicoOrRuc) {
                  // Re-solicitar respetando modo GRUPO (con espacios)
                  final String? grupo = grupoRaw(ws);

                  if (grupo != null && grupo.isNotEmpty) {
                    ws.requestGraphDataForSelection(grupo: grupo);
                  } else {
                    // Aún no hay nombre de grupo en resumen → fallback por RUC
                    final ruc = sp.ruc;
                    if (ruc != null && ruc.isNotEmpty) {
                      ws.requestGraphData(ruc);
                    }
                  }
                } else {
                  // Modo RUC clásico
                  final ruc = sp.ruc;
                  if (ruc != null && ruc.isNotEmpty) {
                    ws.requestGraphData(ruc);
                  }
                }
              },
            ),
          ],
        ),
      );
    }

    // 2) Si no hay conexión WS, mostramos controles para reconectar
    if (!g.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text('Desconectado del WebSocket'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final sp = context.read<SessionProvider>();
                final ws = context.read<GraphSocketProvider>();

                if (sp.grupoEconomicoOrRuc) {
                  final String? grupo = grupoRaw(ws); // ← con espacios

                  if (grupo != null && grupo.isNotEmpty) {
                    if (!ws.isConnected && !ws.isConnecting) {
                      ws.connectByGroup(grupo, ws.rawColors); // ← con espacios
                    }
                    ws.requestGraphDataForSelection(grupo: grupo); // ← sin RUC
                  } else {
                    // Sin grupo definido aún → reconectar por RUC
                    final ruc = sp.ruc;
                    if (ruc != null && ruc.isNotEmpty) {
                      if (!ws.isConnected && !ws.isConnecting) {
                        ws.connect(ruc);
                      }
                      ws.requestGraphData(ruc);
                    }
                  }
                } else {
                  // Modo RUC clásico
                  final ruc = sp.ruc;
                  if (ruc != null && ruc.isNotEmpty) {
                    if (!ws.isConnected && !ws.isConnecting) {
                      ws.connect(ruc);
                    }
                    ws.requestGraphData(ruc);
                  }
                }
              },
              child: const Text('Reconectar'),
            ),
          ],
        ),
      );
    }

    // 3) Errores reales (excepciones) — sólo si no estamos esperando acordeón
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
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    // 4) Lista normal (ya hay acordeón en memoria)
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
                  backgroundColor: const Color(0xFF8B4A9C),
                ),
                child: const Text(
                  'Limpiar búsqueda',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else if (selectedStatus != null)
              ElevatedButton(
                onPressed: () => setState(() => selectedStatus = null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4A9C),
                ),
                child: const Text(
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
        // Header con resultados de búsqueda
        if (isSearching)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B4A9C).withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF8B4A9C), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${services.length} resultado${services.length != 1 ? 's' : ''} para "$searchQuery"',
                    style: const TextStyle(
                      color: Color(0xFF8B4A9C),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: clearSearch,
                  child: const Text(
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
              final categoriaChip = _buildCategoriaChip(service);

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
                            offset: const Offset(0, 4),
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
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                              if (formattedDate.isNotEmpty ||
                                  categoriaChip != null) ...[
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (formattedDate.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: serviceColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                  ],
                                ),
                              ],

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
                          const SizedBox(height: 12),
                          if (categoriaChip != null) ...[
                            categoriaChip,
                            const SizedBox(width: 6),
                          ],
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

  // === BW: helpers para DETALLE ===
  String _resolveIdServicio() {
    final d = widget.servicioData;
    return (d['IdServicio'] ??
            d['idservicio'] ??
            d['idServicio'] ??
            d['id'] ??
            '')
        .toString();
  }

  double _asDouble(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v') ?? double.nan;

  VoidCallback _showBwLoading(String title, [String? subtitle]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return () {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }

  Future<Map<String, dynamic>> _fetchDiagnosticoCompleto({
    required String idServicio,
    bool? save,
    int connectTimeoutMs = 10000,
    int commandTimeoutMs = 20000,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = Duration(milliseconds: connectTimeoutMs);

    final uri = Uri.parse('http://200.1.179.157:3000/BW');

    try {
      final req = await client.postUrl(uri);
      req.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );

      final payload = <String, dynamic>{'IdServicio': idServicio};
      if (save != null) payload['save'] = save;

      req.add(utf8.encode(jsonEncode(payload)));

      final res = await req.close().timeout(
        Duration(milliseconds: commandTimeoutMs),
      );
      final body = await utf8.decoder.bind(res).join();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw 'HTTP ${res.statusCode}';
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['ok'] != true) throw 'Respuesta inesperada del servidor';

      return Map<String, dynamic>.from(data);
    } on TimeoutException {
      throw 'Tiempo de espera agotado';
    } on SocketException {
      throw 'No se pudo conectar al host';
    } finally {
      client.close(force: true);
    }
  }

  String _formatMs(dynamic raw) {
    if (raw == null) return '—';

    final s = raw.toString().trim();
    if (s.isEmpty || s == '—') return '—';

    // Si ya viene con "ms", no lo duplicamos
    if (s.toLowerCase().contains('ms')) return s;

    return '$s ms';
  }

  void _showDiagnosticoSheet(Map<String, dynamic> data) {
    final ping = Map<String, dynamic>.from(data['ping'] ?? {});
    final used = Map<String, dynamic>.from(data['used'] ?? {});

    final routerIp = used['routerIP']?.toString() ?? '—';
    final loss = ping['lossPercent']?.toString() ?? '—';

    // 👇 Ahora la latencia siempre va con "ms" si hay dato numérico
    final lat = _formatMs(ping['Latencia_Promedio']);
    // Si quieres lo mismo para RTT:
    // final rtt = _formatMs(ping['RTT_Promedio']);

    final up = (data['uploadMbps'] ?? '—').toString();
    final down = (data['downloadMbps'] ?? '—').toString();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.build),
                  SizedBox(width: 8),
                  Text(
                    'Autodiagnóstico',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Ping',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PingMetric(label: 'Pérdida', value: loss),
                  _PingMetric(label: 'Latencia Promedio', value: lat),
                ],
              ),

              const SizedBox(height: 20),

              const Text(
                'Ancho de Banda',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _BigRateCard(
                      label: 'Upload',
                      value: up,
                      icon: Icons.upload,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BigRateCard(
                      label: 'Download',
                      value: down,
                      icon: Icons.download,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onDiagnosticoCompleto() async {
    final id = _resolveIdServicio();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el IdServicio')),
      );
      return;
    }

    final close = _showBwLoading('Ejecutando diagnóstico…', 'Servicio: $id');

    try {
      final res = await _fetchDiagnosticoCompleto(idServicio: id);

      close();
      if (!mounted) return;

      _showDiagnosticoSheet(res);
    } catch (e) {
      close();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showBwMiniSheet({
    required String idServicio,
    required double uploadMbps,
    required double downloadMbps,
  }) {
    String _fmt(double v) => v.isFinite ? v.toStringAsFixed(1) : '—';
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.speed),
                  SizedBox(width: 8),
                  Text(
                    'Análisis BW',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BigRateCard(
                      label: 'Upload',
                      value: _fmt(uploadMbps),
                      icon: Icons.upload,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BigRateCard(
                      label: 'Download',
                      value: _fmt(downloadMbps),
                      icon: Icons.download,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Servicio: $idServicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPingSheet({
    required String routerIp,
    required String lossPercent,
    required String minRtt,
    required String avgRtt,
    required String maxRtt,
    required String avgLatency,
  }) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.network_ping),
                  SizedBox(width: 8),
                  Text(
                    'Ping',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Router/IP usado
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.router, size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                      'Router/IP: $routerIp',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Grid de métricas
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PingMetric(label: 'Pérdida', value: lossPercent),
                  _PingMetric(label: 'RTT mín', value: minRtt),
                  _PingMetric(label: 'RTT prom', value: avgRtt),
                  _PingMetric(
                    label: 'RTT máx',
                    value: (maxRtt.isEmpty || maxRtt == 'null') ? '—' : maxRtt,
                  ),
                  _PingMetric(label: 'Lat prom (ms)', value: avgLatency),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _ticketEstadoColor(String? estado) {
    final e = (estado ?? '').toLowerCase();
    if (e.contains('pend') || e.contains('nuevo')) return Colors.orange;
    if (e.contains('en at') || e.contains('proceso')) return Colors.blue;
    if (e.contains('resu') || e.contains('cerr') || e.contains('ok'))
      return Colors.green;
    return Colors.grey;
  }

  String _lastDiagCombined(String? status, String? desde) {
    final s = (status ?? '').trim();
    final d = _formatTicketDate(desde); // ya formatea dd/MM/yyyy HH:mm
    if (s.isNotEmpty && d.isNotEmpty) return '$s • $d';
    if (s.isNotEmpty) return s;
    if (d.isNotEmpty) return d;
    return '—';
  }

  // Extrae el RUC desde el mapa del servicio (o su details)
  String? _extractRucFrom(Map<String, dynamic> data) {
    final direct =
        data['RUC'] ??
        data['ruc'] ??
        data['cliente_ruc'] ??
        data['ruc_cliente'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final det = data['details'];
    if (det is Map) {
      final d = Map<String, dynamic>.from(det);
      final v = d['RUC'] ?? d['ruc'] ?? d['cliente_ruc'] ?? d['ruc_cliente'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  // Resuelve la Razón Social desde el propio item o usando los mapas del provider
  String? _resolveRazonSocialForService() {
    final data = widget.servicioData;

    // a) Intentar campos directos
    final direct = data['Razon_Social'] ?? data['razon'] ?? data['razonsocial'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    // b) Intentar en details
    final det = data['details'];
    if (det is Map) {
      final m = Map<String, dynamic>.from(det);
      final v =
          m['Razon_Social'] ??
          m['Razon Social'] ??
          m['RazonSocial'] ??
          m['razon'] ??
          m['cliente_nombre'];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }

    // c) Buscar por RUC en el GraphSocketProvider
    final ruc = _extractRucFrom(data);
    final ws = context.read<GraphSocketProvider>();

    if (ruc != null && ruc.isNotEmpty) {
      // i) Mapa RUC -> Razón Social
      final mapRaz = Map<String, dynamic>.from(
        (ws.resumen['RUCs_Razones_Map'] as Map?) ?? const {},
      );
      final mapped = mapRaz[ruc];
      if (mapped != null && mapped.toString().trim().isNotEmpty) {
        return mapped.toString().trim();
      }

      // ii) Lista "bonita" del provider
      for (final e in ws.rucsRazonesList) {
        final eruc = (e['ruc'] ?? e['RUC'] ?? '').toString();
        if (eruc == ruc) {
          final name =
              (e['nombre'] ??
                      e['razon'] ??
                      e['Razon_Social'] ??
                      e['Razon Social'])
                  ?.toString();
          if (name != null && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      }

      // iii) Fallback: resumen si coincide el RUC actual
      final single =
          ws.resumen['Razon_Social'] ??
          ws.resumen['Razon Social'] ??
          ws.resumen['razon_social'];
      if (single != null &&
          single.toString().trim().isNotEmpty &&
          (ws.ruc == ruc)) {
        return single.toString().trim();
      }
    }

    return null;
  }

  String _formatTicketDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';

    String s = raw.trim();

    // --- 1) Timestamps (10 = segundos / 13 = milisegundos) ---
    final digits = RegExp(r'^\d+$');
    if (digits.hasMatch(s)) {
      final n = int.tryParse(s);
      if (n != null) {
        DateTime dt;
        if (s.length == 13) {
          dt = DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toLocal();
        } else if (s.length == 10) {
          dt = DateTime.fromMillisecondsSinceEpoch(n * 1000).toLocal();
        } else {
          return '';
        }
      }
    }

    return s;
  }

  Map<String, dynamic> _mergeTicketMaps(Map a, Map b) {
    final out = Map<String, dynamic>.from(a);
    for (final k in [
      'Estado',
      'Fecha',
      'Tipo',
      'ServiciosAfectados',
      'nroServicios',
      'Area',
    ]) {
      final av = (out[k]?.toString() ?? '').trim();
      final bv = (b[k]?.toString() ?? '').trim();
      if (av.isEmpty && bv.isNotEmpty) out[k] = b[k];
    }
    // conserva el TicketId más “rico” (con prefijo) si es que uno de los dos lo tiene
    final aid = (a['TicketId'] ?? '').toString();
    final bid = (b['TicketId'] ?? '').toString();
    final aHasPref = RegExp(r'^[A-Z]+').hasMatch(aid);
    final bHasPref = RegExp(r'^[A-Z]+').hasMatch(bid);
    if (!aHasPref && bHasPref) out['TicketId'] = bid;
    return out;
  }

  String _canonTicketKey(dynamic raw) {
    final s = (raw ?? '').toString().toUpperCase().trim();
    if (s.isEmpty) return '';
    final cleaned = s.replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    ); // quita espacios, guiones, etc.
    final m = RegExp(
      r'(\d{4,})$',
    ).firstMatch(cleaned); // parte numérica final (>=4 dígitos)
    return m?.group(1) ?? cleaned; // fallback: todo el cleaned si no hay match
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
          // Texto de servicios afectados (IDs)
          String serviciosTxt = '';
          int count = 0;

          if (t['ServiciosAfectados'] is List) {
            final list = (t['ServiciosAfectados'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
            serviciosTxt = list.join(', ');
            count = list.length;
          } else if (t['nroServicios'] is num) {
            count = (t['nroServicios'] as num).toInt();
          }

          final area = (t['area'] ?? t['Area'] ?? t['equipo'] ?? '').toString();

          return {
            'TicketId': (t['NroTicket'] ?? '').toString(),
            'Estado': t['EstadoTicket']?.toString(),
            'Fecha': t['FechaCreacion']?.toString(),
            'Tipo': t['Tipo']?.toString(),
            'ServiciosAfectados': serviciosTxt,
            'nroServicios': count,
            'Area': area,
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
          'ServiciosAfectados': '',
          'nroServicios': r['nroServicios'] ?? 0,
          'Area': (r['area'] ?? '').toString(),
          'source': 'Item',
        });
      }
    }

    // unir sin duplicar por TicketId CANÓNICO y mergear campos
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final t in [...fromAfectados, ...fromDetails]) {
      final key = _canonTicketKey(t['TicketId']);
      if (key.isEmpty) continue;

      final i = out.indexWhere((x) => _canonTicketKey(x['TicketId']) == key);
      if (i == -1) {
        out.add(t);
        seen.add(key);
      } else {
        out[i] = _mergeTicketMaps(out[i], t);
      }
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

  // Usa el mismo resolvedor global que usas en la lista
  Color _resolveServiceColor(String rawLabel) => statusColor(context, rawLabel);

  // y tu getter:

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
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin coordenadas válidas para este servicio',
                style: TextStyle(color: Colors.red[700]),
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

        // Mapa
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 160,

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
        Row(children: [
            
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String? value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), // antes 14
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
            padding: const EdgeInsets.all(14), // antes 18
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: lightPurple.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: primaryPurple.withOpacity(0.06),
                  blurRadius: 8, // antes 10
                  offset: const Offset(0, 3), // antes (0,4)
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10), // antes 12
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
                        color: primaryPurple.withOpacity(0.18), // antes 0.2
                        blurRadius: 3, // antes 4
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: primaryPurple, size: 20), // antes 22
                ),
                const SizedBox(width: 14), // antes 18
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5, // antes 13
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2, // antes 0.3
                        ),
                      ),
                      const SizedBox(height: 3), // antes 4
                      Text(
                        value ?? 'N/A',
                        style: TextStyle(
                          fontSize: 15.5, // antes 16
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                          letterSpacing: 0.15, // antes 0.2
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
      margin: const EdgeInsets.symmetric(vertical: 15), // antes 20
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7), // antes 8
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryPurple, secondaryPurple],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primaryPurple.withOpacity(0.25), // antes 0.3
                  blurRadius: 6, // antes 8
                  offset: const Offset(0, 3), // antes (0,4)
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18), // antes 20
          ),
          const SizedBox(width: 12), // antes 16
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18, // antes 19
                fontWeight: FontWeight.bold,
                color: primaryPurple,
                letterSpacing: 0.4, // antes 0.5
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

    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-acciones-pruebas',
          onPressed: _onDiagnosticoCompleto,
          icon: const Icon(Icons.build),
          label: const Text('Autodiagnóstico'),
          tooltip: 'Gestiona tu Servicio',
        ),

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
                padding: EdgeInsets.fromLTRB(24, 6, 24, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMapaSection(),
                    const SizedBox(height: 10),

                    _buildInfoTile(
                      'Razón social',
                      _resolveRazonSocialForService() ?? '—',
                      Icons.badge, // o Icons.business
                    ),

                    _buildInfoTile(
                      'Dirección',
                      widget.servicioData['DireccionOdoo'],
                      Icons.location_on,
                    ),
                    _buildInfoTile(
                      'Distrito',
                      widget.servicioData['DistritoOdoo']?.toString(),
                      Icons.apartment, // o Icons.location_city
                    ),
                    _buildInfoTile(
                      'Provincia',
                      widget.servicioData['ProvinciaOdoo']?.toString(),
                      Icons.location_city,
                    ),
                    _buildInfoTile(
                      'Departamento',
                      widget.servicioData['DptoOdoo']?.toString(),
                      Icons.public, // o Icons.map
                    ),

                    if (ticketsHere.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Tickets relacionados',
                        Icons.receipt_long,
                      ),
                      ...ticketsHere.map((t) {
                        final estado = (t['Estado'] ?? '').toString();
                        final fecha = _formatTicketDate(t['Fecha']?.toString());
                        final tipo = (t['Tipo'] ?? '').toString();
                        final color = _ticketEstadoColor(estado);

                        final serviciosTxt = (t['ServiciosAfectados'] ?? '')
                            .toString();
                        final nroServ = (t['nroServicios'] is num)
                            ? (t['nroServicios'] as num).toInt()
                            : null;
                        final area = (t['Area'] ?? '').toString();

                        // Línea de afectados igual que en TicketCard
                        String? afectadosLine;
                        if (serviciosTxt.isNotEmpty) {
                          afectadosLine = 'ID Afectados: $serviciosTxt';
                        } else if (nroServ != null && nroServ > 0) {
                          afectadosLine = '$nroServ servicios afectados';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: color.withOpacity(0.35)),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fila superior: código + tipo (INCIDENCIA)
                              Row(
                                children: [
                                  // Pastilla con el código tal cual
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      (t['TicketId'] ?? '')
                                          .toString(), // 👈 sin concatenar "INC"
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (tipo.isNotEmpty)
                                    Text(
                                      tipo.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                      ),
                                    ),
                                ],
                              ),

                              if (afectadosLine != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  afectadosLine,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 6),

                              // Fecha · Área  +  Estado a la derecha
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      [
                                        if (fecha.isNotEmpty) fecha,
                                        if (area.isNotEmpty) area,
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),

                                  Text(
                                    estado.isEmpty ? '—' : estado,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 8),
                    ],

                    // ⬆️ FIN DE LA SECCIÓN DE TICKETS
                    _buildSectionHeader('Detalles', Icons.build),

                    _buildInfoTile(
                      'Estado Administrativo',
                      widget.servicioData['StatusOdoo'],
                      Icons
                          .verified_user, // o Icons.approval / Icons.assignment_turned_in
                    ),
                    _buildInfoTile(
                      'Último diagnóstico',
                      _lastDiagCombined(
                        widget.servicioData['StatusRPA']?.toString(),
                        widget.servicioData['DESDE']?.toString(),
                      ),
                      Icons.settings_backup_restore,
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
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

class _BigRateCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _BigRateCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.black.withOpacity(0.06);

    // Gradiente suave de superficie
    final surface = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF12161D), Color(0xFF0E1319)]
            : const [Color(0xFFFFFFFF), Color(0xFFF7F8FA)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );

    final accent = _accentFor(label);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge con gradiente
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: accent),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.last.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Valor con animación sutil y unidad diferenciada
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.02, 0.15),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _ValueRichText(
              key: ValueKey(value),
              value: value,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  // Paleta por tipo (Upload/Download/Ping/Default)
  List<Color> _accentFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('upload') || l.contains('subida')) {
      return const [Color(0xFF60A5FA), Color(0xFF2563EB)]; // azules
    }
    if (l.contains('download') || l.contains('bajada')) {
      return const [Color(0xFF34D399), Color(0xFF059669)]; // verdes
    }
    if (l.contains('ping')) {
      return const [Color(0xFFF59E0B), Color(0xFFD97706)]; // ámbar
    }
    // default: toma un morado elegante
    return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
  }
}

class _ValueRichText extends StatelessWidget {
  final String value;
  final bool isDark;

  const _ValueRichText({super.key, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final big = theme.textTheme.displaySmall?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      height: 1.1,
      color: isDark ? Colors.white : const Color(0xFF0F172A),
    );

    final unit = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white70 : Colors.black54,
      height: 1.1,
    );

    final m = RegExp(
      r'^\s*([-+]?\d+(?:\.\d+)?)\s*([a-zA-Z%/]+.*)?$',
    ).firstMatch(value.trim());
    if (m != null) {
      final num = m.group(1)!;
      final u = m.group(2) ?? '';
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: num, style: big),
            if (u.isNotEmpty) TextSpan(text: ' $u', style: unit),
          ],
        ),
      );
    }
    return Text(value, style: big);
  }
}

class _PingMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PingMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.28)
        : Colors.black.withOpacity(0.05);

    // Ancho responsive: 2 columnas en móvil, 3 en tablet
    final width = _tileWidth(context);

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        // Borde con “stroke” sutil y fondo con gradiente muy suave
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF141A22), Color(0xFF0F141B)]
              : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiqueta pequeña con tracking
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          // Valor con animación
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Text(
              value,
              key: ValueKey(value),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _tileWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = w >= 820 ? 3 : 2; // 3 columnas en pantallas anchas
    const gap = 10.0;
    const hPad = 16.0; // padding horizontal del contenedor padre
    return (w - hPad * 2 - gap * (cols - 1)) / cols;
  }
}
