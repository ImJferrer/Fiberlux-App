import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:fiberlux_new_app/view/preticket_chat_screen.dart';
import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';
import 'dart:math' as math;
import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart'; // ⬅️ IMPORTANTE
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ========================= Direcciones detectadas (modelo) =========================
class _DetectedAddress {
  final String direccion;
  final String distrito;
  final String provincia;
  final String dpto;
  final String? ruc;
  final String? razon;
  final String? idServicio;
  final Map<String, dynamic> raw;

  const _DetectedAddress({
    required this.direccion,
    required this.distrito,
    required this.provincia,
    required this.dpto,
    this.ruc,
    this.razon,
    this.idServicio,
    required this.raw,
  });
}

// ========================= Catálogo de clientes (RUC/Razón) =========================
class _RucPair {
  final String ruc;
  final String razon;
  const _RucPair(this.ruc, this.razon);
}

// ========================= Transformación a vista =========================
// ========================= Transformación a vista =========================
class _TicketView {
  final String code;
  final String date; // formateada dd/MM/yy
  final int affectedStores;
  final String issueType; // 2 líneas mayúsculas
  final String status;
  final bool isActive;
  final DateTime? createdAt;
  final String serviciosAfectados;
  final String area;

  // 👇 NUEVO
  final int? preticketId; // ID del PreTicket (solo si origen = PRE)
  final bool isPreTicket; // true si origen == "PRE"

  const _TicketView({
    required this.code,
    required this.date,
    required this.affectedStores,
    required this.issueType,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.serviciosAfectados,
    required this.area,

    this.preticketId,
    this.isPreTicket = false,
  });
}

class TicketsScreen extends StatefulWidget {
  final bool groupMode;
  const TicketsScreen({
    Key? key,
    this.groupMode = false, // por defecto apagado
  }) : super(key: key);

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  // ========================= Helpers de formato =========================
  String _twoLineUpper(String? s) {
    final t = (s ?? '').trim();
    if (t.isEmpty) return 'TICKET';
    final up = t.toUpperCase();
    final idx = up.indexOf(' ');
    if (idx > 0) {
      // dos líneas: primera palabra \n resto
      return '${up.substring(0, idx)}\n${up.substring(idx + 1)}';
    }
    return up;
  }

  bool _isActiveStatus(String? estado) {
    final e = (estado ?? '').toLowerCase();
    if (e.isEmpty) return true;
    final closed = ['solucion', 'resuelt', 'cerr', 'ok', 'cancel'];
    return !closed.any(e.contains);
  }

  DateTime? _parseAfectadoDate(String? raw) {
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

    // Intento genérico
    try {
      // normalizar -0500 -> -05:00
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

  String _fmtDDMMYY(DateTime? dt, {String fallback = ''}) {
    if (dt == null) return fallback;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = (dt.year % 100).toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  String _monthNameEs(int m) {
    const meses = [
      '', // 0
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    if (m < 1 || m > 12) return '';
    return meses[m];
  }

  List<_RucPair> _collectRucCatalog(
    GraphSocketProvider g,
    SessionProvider session,
    List<_DetectedAddress> addrs,
  ) {
    final seen = <String>{};
    final out = <_RucPair>[];

    void add(String ruc, String razon) {
      final r = ruc.trim();
      if (r.isEmpty) return;
      if (seen.add(r)) {
        out.add(_RucPair(r, razon.trim().isEmpty ? '—' : razon.trim()));
      }
    }

    // 1) Desde direcciones detectadas
    for (final a in addrs) {
      if ((a.ruc ?? '').trim().isNotEmpty) {
        add(a.ruc!, a.razon ?? '');
      }
    }

    // 2) Desde lista bonita del socket
    final list = g.rucsRazonesList;
    if (list is List) {
      for (final e in list) {
        if (e is Map) {
          final r = (e['ruc'] ?? e['RUC'] ?? '').toString();
          final n =
              (e['nombre'] ??
                      e['razon'] ??
                      e['Razon_Social'] ??
                      e['Razon Social'] ??
                      '')
                  .toString();
          add(r, n);
        }
      }
    }

    // 3) Desde resumen del socket
    final rResumen = (g.resumen['RUC'] ?? g.resumen['ruc'] ?? '').toString();
    final nResumen =
        (g.resumen['Razon_Social'] ??
                g.resumen['Razon Social'] ??
                g.resumen['razon_social'] ??
                '')
            .toString();
    if (rResumen.trim().isNotEmpty) add(rResumen, nResumen);

    // 4) Desde la sesión
    final rSes = (session.ruc ?? '').toString();
    if (rSes.trim().isNotEmpty && !seen.contains(rSes)) {
      add(rSes, '');
    }

    out.sort((a, b) => a.razon.compareTo(b.razon));
    return out;
  }

  // Extrae y normaliza direcciones desde g.acordeon (y mapea RUC/Razón Social)
  List<_DetectedAddress> _harvestDetectedAddresses(GraphSocketProvider g) {
    final out = <_DetectedAddress>[];
    final seen = <String>{};

    void addFromItem(Map it) {
      final mm = Map<String, dynamic>.from(it);

      // —— Dirección
      final dirMap = (mm['direccion'] is Map)
          ? Map<String, dynamic>.from(mm['direccion'])
          : const {};

      String dir =
          (dirMap['direccion'] ?? mm['direccionodoo'] ?? mm['direccion'] ?? '')
              .toString()
              .trim();
      String dist =
          (dirMap['distrito'] ?? mm['distritoodoo'] ?? mm['distrito'] ?? '')
              .toString()
              .trim();
      String prov =
          (dirMap['provincia'] ?? mm['provinciaodoo'] ?? mm['provincia'] ?? '')
              .toString()
              .trim();
      String dpto =
          (dirMap['departamento'] ?? mm['dptoodoo'] ?? mm['departamento'] ?? '')
              .toString()
              .trim();

      if (dir.isEmpty && dist.isEmpty && prov.isEmpty && dpto.isEmpty) return;

      // —— ID de servicio (acepta variantes de nombre)
      String idServ =
          (mm['ID_Servicio'] ??
                  mm['idservicio'] ??
                  mm['IdServicio'] ??
                  mm['idServicio'] ??
                  mm['ID_SERVICIO'] ??
                  mm['id_servicio'] ??
                  mm['servicio_id'] ??
                  mm['ServicioId'] ??
                  '')
              .toString()
              .trim();

      // —— RUC y Razón (como ya lo tenías)
      final String? ruc =
          (mm['RUC'] ??
                  mm['ruc'] ??
                  mm['cliente_ruc'] ??
                  mm['ruc_cliente'] ??
                  g.resumen['RUC'] ??
                  g.resumen['ruc'])
              ?.toString();

      String? razon;
      final direct =
          (mm['Razon_Social'] ??
          mm['Razon Social'] ??
          mm['razon_social'] ??
          mm['razon'] ??
          mm['razonsocial'] ??
          mm['cliente_nombre']);
      if (direct != null && direct.toString().trim().isNotEmpty) {
        razon = direct.toString().trim();
      } else if (ruc != null && ruc.isNotEmpty) {
        final mapRaz = Map<String, dynamic>.from(
          (g.resumen['RUCs_Razones_Map'] as Map?) ?? const {},
        );
        final byMap = mapRaz[ruc];
        if (byMap != null && byMap.toString().trim().isNotEmpty) {
          razon = byMap.toString().trim();
        }
        if (razon == null) {
          for (final e in g.rucsRazonesList) {
            final eruc = (e['ruc'] ?? e['RUC'] ?? '').toString();
            if (eruc == ruc) {
              final name =
                  (e['nombre'] ??
                          e['razon'] ??
                          e['Razon_Social'] ??
                          e['Razon Social'])
                      ?.toString();
              if (name != null && name.trim().isNotEmpty) {
                razon = name.trim();
                break;
              }
            }
          }
        }
        if (razon == null && (g.ruc == ruc)) {
          final single =
              (g.resumen['Razon_Social'] ??
                      g.resumen['Razon Social'] ??
                      g.resumen['razon_social'])
                  ?.toString();
          if (single != null && single.trim().isNotEmpty) razon = single.trim();
        }
      }

      // —— CLAVE de deduplicación: incluye el id de servicio.
      //     Si no existiera, usa el RUC como parte de la clave para no colapsar clientes distintos.
      final key = [
        dir.toLowerCase(),
        dist.toLowerCase(),
        prov.toLowerCase(),
        dpto.toLowerCase(),
        (idServ.isNotEmpty ? idServ : (ruc ?? '')).toLowerCase(),
      ].join('|');

      if (seen.contains(key)) return;
      seen.add(key);

      out.add(
        _DetectedAddress(
          direccion: dir.isEmpty ? 'Sin dirección' : dir,
          distrito: dist,
          provincia: prov,
          dpto: dpto,
          ruc: (ruc ?? '').isEmpty ? null : ruc,
          razon: razon,
          idServicio: idServ,
          raw: mm,
        ),
      );
    }

    // Recorre acordeón del socket
    if (g.acordeon is Map) {
      g.acordeon.forEach((_, value) {
        final items = (value is List)
            ? value
            : (value is Map ? [value] : const []);
        for (final it in items) {
          if (it is Map) addFromItem(it);
        }
      });
    }

    // Orden pedido: distrito → provincia → departamento → dirección
    out.sort((a, b) {
      final c1 = a.distrito.compareTo(b.distrito);
      if (c1 != 0) return c1;
      final c2 = a.provincia.compareTo(b.provincia);
      if (c2 != 0) return c2;
      final c3 = a.dpto.compareTo(b.dpto);
      if (c3 != 0) return c3;
      return a.direccion.compareTo(b.direccion);
    });

    return out;
  }

  List<_TicketView> _mapAfectadosToViews(dynamic afectadosDyn) {
    final list = (afectadosDyn is List) ? afectadosDyn : const [];
    final tmp = <_TicketView>[];
    final seen = <String>{};

    for (final t in list) {
      if (t is! Map) continue;

      final code = (t['NroTicket'] ?? t['ticket_id'] ?? t['id'] ?? '')
          .toString();
      // evita duplicados por código
      if (code.isEmpty || !seen.add(code)) continue;

      final estado = (t['EstadoTicket'] ?? t['estado'] ?? '').toString();
      final tipo = (t['Tipo'] ?? t['tipo_ticket_nombre'] ?? 'Ticket')
          .toString();

      final area = (t['area'] ?? t['Area'] ?? t['equipo'] ?? '')
          .toString()
          .trim();

      final created = _parseAfectadoDate(t['FechaCreacion']?.toString());
      final date = _fmtDDMMYY(
        created,
        fallback: (t['FechaCreacion'] ?? '').toString(),
      );

      int affected = 0;
      if (t['nroServicios'] is num) {
        affected = (t['nroServicios'] as num).toInt();
      } else if (t['ServiciosAfectados'] is List) {
        affected = (t['ServiciosAfectados'] as List).length;
      }

      String serviciosAfectadosText = '';
      if (t['ServiciosAfectados'] is List) {
        serviciosAfectadosText = (t['ServiciosAfectados'] as List)
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .join(', ');
      }

      final origin = (t['origen'] ?? t['Origen'] ?? '')
          .toString()
          .toUpperCase();

      // Id de preticket (string → int?)
      final preTicketStr =
          (t['PreTicket'] ??
                  t['preticket'] ??
                  t['preticket_id'] ??
                  t['id_preticket'] ??
                  '')
              .toString()
              .trim();

      final int? preticketId = int.tryParse(preTicketStr);

      // ✅ Puede abrir chat si ORIGIN es PRE o TICKET y hay id de preticket
      final bool canOpenChat =
          (origin == 'PRE' || origin == 'TICKET') && preticketId != null;

      tmp.add(
        _TicketView(
          code: code,
          date: date,
          affectedStores: affected,
          issueType: _twoLineUpper(tipo),
          status: estado.isEmpty ? '—' : estado,
          isActive: _isActiveStatus(estado),
          createdAt: created,
          serviciosAfectados: serviciosAfectadosText,
          area: area,
          preticketId: preticketId,
          isPreTicket: canOpenChat, // ← ahora significa "tiene chat"
        ),
      );
    }

    return tmp;
  }

  // ⬇️ NUEVO: POST al backend (ajusta base/endpoint si lo necesitas)
  Future<Map<String, dynamic>> _sendTicket({
    required SessionProvider sp,
    required _DetectedAddress addr,
    required String ruc,
    required String razon,
    required String motivo,
    required String telefono,
    required String nombre,
    required bool isRequerimientos,
  }) async {
    final uri = Uri.parse("http://200.1.179.157:3000/CrearPRE");

    // 1 = incidencia, 2 = requerimiento
    final int typeTicket = isRequerimientos ? 2 : 1;

    // ID usuario (úsalo desde sesión si lo tienes)
    final int userId = sp.userId ?? 147;

    // Cliente (razón social)
    final String clientName = razon.trim().isEmpty ? 'SIN RAZON SOCIAL' : razon;

    // Dirección formateada
    final String address =
        '${addr.direccion}/ ${addr.dpto}/ ${addr.provincia}/ ${addr.distrito}';

    // Contacto
    final String contact = '${nombre.trim()} - ${telefono.trim()}';

    // Username y password (según PRE)
    final String password = '${ruc.trim()}\$';

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    };

    final body = jsonEncode({
      "type_ticket": typeTicket,
      "user": userId,
      "client": clientName,
      "address": address,
      "id_service": addr.idServicio ?? "",
      "message": motivo.trim(),
      "contact": contact,
      "ruc": ruc.trim(),
      "district": addr.distrito.trim(),
      "executive": "CHIRINOS RAMIREZ ROCIO VIRGINIA",
      "username": "dmagisterial",
      "password": "20136424867\$",
    });

    final resp = await http.post(uri, headers: headers, body: body);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final txt = resp.body.trim();
      return txt.isEmpty ? {} : jsonDecode(txt);
    }

    throw Exception("Error ${resp.statusCode}: ${resp.body}");
  }

  // ⬇️ NUEVO: hoja modal con formulario
  void _openSendTicketSheet() {
    final session = context.read<SessionProvider>();
    final g = context.read<GraphSocketProvider>();
    final addrListController = ScrollController();
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    bool? isRequerimientos; // null = nada seleccionado
    String? selectedIncidencia; // opción del dropdown de incidencia
    String? tipoReq; // lo que ya usabas si te hace falta
    bool suggForceHidden = false;

    const brand = Color(0xFF8B4A9C);
    const radius = 12.0;

    final isGroup = session.grupoEconomicoOrRuc || (widget.groupMode);

    final addrsAll = _harvestDetectedAddresses(g);
    final catalog = _collectRucCatalog(g, session, addrsAll);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        // Controllers
        final nombreCtrl = TextEditingController();
        final telefonoCtrl = TextEditingController();
        final motivoCtrl = TextEditingController();
        final searchCtrl = TextEditingController();

        // Estado selector
        String? selDpto;
        String? selProv;
        String? selDist;
        _DetectedAddress? selAddr;

        String? selRucKey = isGroup
            ? ''
            : (session.ruc ??
                  (addrsAll.isNotEmpty ? (addrsAll.first.ruc ?? '') : ''));

        String ruc = '';
        String razon = '';

        if ((selRucKey ?? '').isNotEmpty) {
          final found = catalog.where((e) => e.ruc == selRucKey).toList();
          if (found.isNotEmpty) {
            ruc = found.first.ruc;
            razon = found.first.razon;
          } else {
            ruc = selRucKey!;
            razon = '';
          }
        } else if (!isGroup) {
          ruc = addrsAll.isNotEmpty ? (addrsAll.first.ruc ?? '') : '';
          razon = addrsAll.isNotEmpty ? (addrsAll.first.razon ?? '') : '';
        }

        List<String> _uniq(Iterable<String> it) =>
            it.toSet().where((s) => s.trim().isNotEmpty).toList()..sort();

        Future<void> _submit() async {
          if (selAddr == null) return;

          final addr = selAddr!;
          final sp = session;
          final nombre = nombreCtrl.text.trim();
          final tel = telefonoCtrl.text.trim();
          final motOriginal = motivoCtrl.text.trim();

          if (isRequerimientos == null) {
            // Por seguridad extra, aunque con canSend no debería pasar
            return;
          }

          final bool req = isRequerimientos!;
          final bool isIncidenciaLocal = !req;

          String mot = motOriginal;
          if (isIncidenciaLocal &&
              selectedIncidencia != null &&
              selectedIncidencia!.isNotEmpty) {
            // Ejemplo: "[Caída de servicio] Se ve intermitente desde la mañana"
            mot = '[${selectedIncidencia!}] $motOriginal';
          }

          try {
            final resp = await _sendTicket(
              sp: sp,
              addr: addr,
              ruc: ruc,
              razon: razon,
              motivo: mot, // 👈 mensaje ya concatenado
              telefono: tel,
              nombre: nombre,
              isRequerimientos: req, // 👈 bool seguro, no-null
            );

            Navigator.pop(ctx);

            if (mounted) {
              final msg =
                  (resp['message'] ??
                          resp['detail'] ??
                          'Ticket enviado correctamente')
                      .toString();

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
            }
          } catch (e) {
            Navigator.pop(ctx);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al enviar ticket: $e')),
              );
            }
          }
        }

        return StatefulBuilder(
          builder: (ctx, setState) {
            final bool isIncidencia = isRequerimientos == false;
            final bool isRequerimiento = isRequerimientos == true;

            // Texto dinámico para el campo de motivo
            final String motivoLabel = isRequerimientos == null
                ? 'Describa el motivo de su problema'
                : 'Describa su ${isIncidencia ? 'Incidencia' : 'Requerimiento'}';

            final String motivoHint = isRequerimientos == null
                ? 'Describe brevemente el problema'
                : 'Describe brevemente la ${isIncidencia ? 'incidencia' : 'requerimiento'}';

            // Opciones del dropdown de Incidencias
            const List<String> incidenciaOptions = [
              'Caída de servicio',
              'Lentitud',
              'Intermitencia',
              'Latencia elevada',
              'Pérdida de paquetes',
              'Problemas Streaming',
              'Problema con correo',
              'Problemas con Teams/Zoom/Meet',
              'Problemas acceso a App/Web/Juegos',
            ];

            // Base filtrada
            final base = (isGroup && (selRucKey ?? '').isNotEmpty)
                ? addrsAll.where((e) => (e.ruc ?? '') == selRucKey).toList()
                : addrsAll.toList();

            final dptos = _uniq(base.map((e) => e.dpto));
            final provs = _uniq(
              base
                  .where(
                    (e) =>
                        selDpto == null ||
                        selDpto!.isEmpty ||
                        e.dpto == selDpto,
                  )
                  .map((e) => e.provincia),
            );
            final dists = _uniq(
              base
                  .where(
                    (e) =>
                        (selDpto == null ||
                            selDpto!.isEmpty ||
                            e.dpto == selDpto) &&
                        (selProv == null ||
                            selProv!.isEmpty ||
                            e.provincia == selProv),
                  )
                  .map((e) => e.distrito),
            );

            var visible = base.where((e) {
              final okD =
                  (selDpto == null || selDpto!.isEmpty || e.dpto == selDpto);
              final okP =
                  (selProv == null ||
                  selProv!.isEmpty ||
                  e.provincia == selProv);
              final okT =
                  (selDist == null ||
                  selDist!.isEmpty ||
                  e.distrito == selDist);
              return okD && okP && okT;
            }).toList();

            final q = searchCtrl.text.trim().toLowerCase();
            final addrSuggest = (q.isEmpty || suggForceHidden)
                ? const <_DetectedAddress>[]
                : base
                      .where((e) => e.direccion.toLowerCase().contains(q))
                      .take(3)
                      .toList();
            if (q.isNotEmpty) {
              bool matches(_DetectedAddress a) =>
                  a.direccion.toLowerCase().contains(q) ||
                  a.distrito.toLowerCase().contains(q) ||
                  a.provincia.toLowerCase().contains(q) ||
                  a.dpto.toLowerCase().contains(q) ||
                  (a.idServicio ?? '').toLowerCase().contains(q);
              visible = visible.where(matches).toList();
            }

            final bottom = MediaQuery.of(ctx).viewInsets.bottom;
            final canSend =
                selAddr != null &&
                motivoCtrl.text.trim().isNotEmpty &&
                telefonoCtrl.text.trim().isNotEmpty &&
                nombreCtrl.text.trim().isNotEmpty &&
                isRequerimientos !=
                    null && // debe elegir Incidencia o Requerimiento
                (!isIncidencia ||
                    (selectedIncidencia != null &&
                        selectedIncidencia!.isNotEmpty));

            // Tema minimal local
            final localTheme = Theme.of(ctx).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: const BorderSide(color: brand, width: 1.6),
                ),
                labelStyle: TextStyle(color: Colors.grey[800]),
              ),
            );

            return Theme(
              data: localTheme,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: FractionallySizedBox(
                  heightFactor: 0.9,
                  child: Column(
                    children: [
                      // Header simple
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            const Text(
                              'Crear ticket',
                              style: TextStyle(
                                fontSize: 18,
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
                      ),
                      const Divider(height: 1),

                      // CONTENIDO
                      // ⬇️ NUEVO: Toggle superior
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TopTabButton(
                                label: 'Incidencias',
                                selected: isIncidencia,
                                onTap: () => setState(() {
                                  isRequerimientos = false; // Incidencia
                                  selectedIncidencia = null; // resetea dropdown
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TopTabButton(
                                label: 'Req. Soporte',
                                selected: isRequerimiento,
                                onTap: () => setState(() {
                                  isRequerimientos = true; // Requerimiento
                                  selectedIncidencia =
                                      null; // no aplica, pero lo limpiamos igual
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Buscar
                              TextField(
                                controller: searchCtrl,
                                decoration: InputDecoration(
                                  labelText:
                                      'Buscar dirección / distrito / provincia / ID',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: (searchCtrl.text.isEmpty)
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            searchCtrl.clear();
                                            setState(() {});
                                          },
                                        ),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    suggForceHidden =
                                        false; // al escribir, se vuelven a mostrar
                                  });
                                },
                              ), // ⬇️ Panel de sugerencias (hasta 3 resultados)
                              if (addrSuggest.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.black12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: addrSuggest.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, i) {
                                      final a = addrSuggest[i];
                                      final subtitleMain = [
                                        if (a.distrito.isNotEmpty) a.distrito,
                                        if (a.provincia.isNotEmpty) a.provincia,
                                        if (a.dpto.isNotEmpty) a.dpto,
                                      ].join(' • ');
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          a.direccion,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: subtitleMain.isNotEmpty
                                            ? Text(subtitleMain)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            // 1) Selecciona la dirección como si hubieras tocado el RadioListTile
                                            selAddr = a;

                                            // 2) Autorrellena los selects
                                            selDpto = a.dpto.isEmpty
                                                ? null
                                                : a.dpto;
                                            selProv = a.provincia.isEmpty
                                                ? null
                                                : a.provincia;
                                            selDist = a.distrito.isEmpty
                                                ? null
                                                : a.distrito;

                                            // 3) Mantén tu lógica de RUC/Razón (si aplica)
                                            if ((selRucKey ?? '').isEmpty ||
                                                (a.ruc ?? '') !=
                                                    (selRucKey ?? '')) {
                                              ruc = (a.ruc ?? ruc);
                                              razon = (a.razon ?? razon);
                                            }

                                            // 4) Opcional: deja el texto de búsqueda con la dirección elegida
                                            searchCtrl.text = a.direccion;
                                            searchCtrl.selection =
                                                TextSelection.fromPosition(
                                                  TextPosition(
                                                    offset:
                                                        searchCtrl.text.length,
                                                  ),
                                                );

                                            // 5) Cierra el panel de sugerencias sin cerrar la hoja
                                            suggForceHidden = true;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              Divider(
                                color: Color.fromARGB(255, 185, 31, 167),
                                thickness: 1,
                              ),

                              const SizedBox(height: 12),

                              // Cliente
                              if (isGroup) ...[
                                DropdownButtonFormField<String>(
                                  value: selRucKey,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('Todas las Razones Sociales'),
                                    ),
                                    ...catalog.map(
                                      (p) => DropdownMenuItem(
                                        value: p.ruc,
                                        child: Text('${p.ruc} — ${p.razon}'),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    setState(() {
                                      selRucKey = v ?? '';
                                      if ((selRucKey ?? '').isEmpty) {
                                        ruc = '';
                                        razon = '';
                                        selAddr = null;
                                      } else {
                                        final found = catalog
                                            .where((e) => e.ruc == selRucKey)
                                            .toList();
                                        ruc = found.isNotEmpty
                                            ? found.first.ruc
                                            : (selRucKey ?? '');
                                        razon = found.isNotEmpty
                                            ? found.first.razon
                                            : '';
                                        if (selAddr != null &&
                                            ((selAddr!.ruc ?? '') != ruc)) {
                                          selAddr = null;
                                        }
                                      }
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Cliente',
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Filtros

                              // Contacto
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: nombreCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Ingrese su Nombre',
                                        hintText: 'Nombre de contacto',
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: TextFormField(
                                      controller: telefonoCtrl,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Contacto en Sede',
                                        hintText: '9XXXXXXXX',
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (isIncidencia) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: selectedIncidencia,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de incidencia',
                                  ),
                                  items: incidenciaOptions
                                      .map(
                                        (op) => DropdownMenuItem<String>(
                                          value: op,
                                          child: Text(op),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedIncidencia = value;
                                    });
                                  },
                                ),
                              ],

                              const SizedBox(height: 10),

                              TextFormField(
                                controller: motivoCtrl,
                                maxLines: 2,
                                minLines: 1,
                                decoration: InputDecoration(
                                  labelText: motivoLabel, // 👈 dinámico
                                  hintText: motivoHint, // 👈 dinámico
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 10),

                              // Lista de direcciones (compacta con scroll interno: máx. 5 filas)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(radius),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Direcciones (${visible.length})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    if (visible.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          'No hay resultados con los filtros/búsqueda.',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      )
                                    else
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 72.0 * 5,
                                        ), // ~5 filas
                                        child: Scrollbar(
                                          controller:
                                              addrListController, // <-- AQUÍ
                                          thumbVisibility: true,
                                          child: ListView.separated(
                                            controller:
                                                addrListController, // <-- Y AQUÍ
                                            primary: false,
                                            shrinkWrap: true,
                                            physics:
                                                const ClampingScrollPhysics(),
                                            itemCount: visible.length,
                                            separatorBuilder: (_, __) =>
                                                Divider(
                                                  height: 1,
                                                  color: Colors.grey.shade200,
                                                ),
                                            itemBuilder: (ctx, index) {
                                              final a = visible[index];
                                              final subtitleMain = [
                                                if (a.distrito.isNotEmpty)
                                                  a.distrito,
                                                if (a.provincia.isNotEmpty)
                                                  a.provincia,
                                                if (a.dpto.isNotEmpty) a.dpto,
                                              ].join(' • ');
                                              final idLine =
                                                  (a.idServicio ?? '')
                                                      .isNotEmpty
                                                  ? 'ID servicio: ${a.idServicio}'
                                                  : null;

                                              return RadioListTile<
                                                _DetectedAddress
                                              >(
                                                value: a,
                                                groupValue: selAddr,
                                                dense: true,
                                                visualDensity:
                                                    const VisualDensity(
                                                      horizontal: -1,
                                                      vertical: -2,
                                                    ),
                                                contentPadding: EdgeInsets.zero,
                                                activeColor: brand,
                                                title: Text(
                                                  a.direccion,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (subtitleMain.isNotEmpty)
                                                      Text(
                                                        subtitleMain,
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    if (idLine != null)
                                                      Text(
                                                        idLine,
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                onChanged: (v) {
                                                  if (v == null) return;
                                                  setState(() {
                                                    selAddr = v;
                                                    selDpto = v.dpto.isEmpty
                                                        ? null
                                                        : v.dpto;
                                                    selProv =
                                                        v.provincia.isEmpty
                                                        ? null
                                                        : v.provincia;
                                                    selDist = v.distrito.isEmpty
                                                        ? null
                                                        : v.distrito;

                                                    if ((selRucKey ?? '')
                                                            .isEmpty ||
                                                        (v.ruc ?? '') !=
                                                            (selRucKey ?? '')) {
                                                      ruc = (v.ruc ?? ruc);
                                                      razon =
                                                          (v.razon ?? razon);
                                                    }
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Resumen (líneas simples)
                              if (selAddr != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x0F8B4A9C), // 6% aprox
                                    borderRadius: BorderRadius.circular(radius),
                                    border: Border.all(
                                      color: const Color(0x1A8B4A9C),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Resumen de selección',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Dirección: ${selAddr!.direccion}'),
                                      Text(
                                        'Ubicación: ${selAddr!.distrito} • ${selAddr!.provincia} • ${selAddr!.dpto}',
                                      ),
                                      if ((selAddr!.idServicio ?? '')
                                          .isNotEmpty)
                                        Text(
                                          'ID servicio: ${selAddr!.idServicio}',
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // CTA
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: canSend ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(radius),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Enviar'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      addrListController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    if (session.ruc == null) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        endDrawer: FiberluxDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.white,
          scrolledUnderElevation: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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
                                  // 🔔 Marcar como leídas en el provider
                                  session.setHasUnreadNotifications(false);
                                },
                              );
                            }
                          },
                        ),
                        if (session.hasUnreadNotifications)
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
                  ],
                ),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
        ),
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

    // =================== Tickets desde el socket: g.afectados ===================
    final g = context.watch<GraphSocketProvider>();
    final views = _mapAfectadosToViews(g.afectados);
    final active = views.where((v) => v.isActive).toList();
    final history = views.where((v) => !v.isActive).toList();

    // Agrupar historial por mes/año
    Map<String, List<_TicketView>> historyByMonth = {};
    for (final v in history) {
      final dt = v.createdAt;
      final key = (dt == null)
          ? 'Sin fecha'
          : '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      (historyByMonth[key] ??= []).add(v);
    }

    // Ordenar claves de historial descendente por fecha
    final sortedHistKeys = historyByMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: FiberluxDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                          final notifProv = context
                              .read<NotificationsProvider>();

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

                      // ESTE ES EL PUNTO ROJO GLOBAL
                      Consumer<NotificationsProvider>(
                        builder: (_, notifProv, __) {
                          if (!notifProv.hasUnread)
                            return const SizedBox.shrink();
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
                ],
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-enviar-ticket',
        onPressed: _openSendTicketSheet,
        icon: const Icon(Icons.add),
        label: const Text('Crear ticket'),
        backgroundColor: const Color(0xFF8B4A9C),
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Tickets',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              Center(
                child: Text(
                  g.isConnected
                      ? 'En caso no mostrarse su ticket, comunicarse con soporte.'
                      : 'Mostrando tickets (sin conexión en vivo)',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),

              // =================== Listado dinámico ===================
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // --------- Activos ----------
                      if (active.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'No hay tickets activos',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      else
                        ...active.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TicketCard(
                              code: t.code,
                              date: t.date,
                              affectedStores: t.affectedStores,
                              issueType: t.issueType,
                              status: t.status,
                              isActive: true,
                              serviciosAfectados: t.serviciosAfectados,
                              area: t.area,
                              onTap: () {
                                if (t.isPreTicket && t.preticketId != null) {
                                  // Solo PRE entra al chat
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PreticketChatScreen(
                                        preticketId: t.preticketId!,
                                        ticketCode: t.code,
                                        serviciosAfectados:
                                            t.serviciosAfectados,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Los TICKET normales no tienen chat
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Este ticket no tiene chat disponible',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),

                      // ---------- Separador / Historial -----------
                      const SizedBox(height: 8),

                      if (_showHistory) ...[
                        const SizedBox(height: 16),

                        if (history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'Sin Informes de tickets previos',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        else
                          ...sortedHistKeys.expand((key) {
                            final group = historyByMonth[key]!;
                            // Header del mes
                            DateTime? dt = group.first.createdAt;
                            final header = (dt == null)
                                ? 'Sin fecha'
                                : '${_monthNameEs(dt.month)} ${dt.year}';
                            return [
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      header,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.grey[300],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...group.map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: TicketCard(
                                    code: t.code,
                                    date: t.date,
                                    affectedStores: t.affectedStores,
                                    issueType: t.issueType,
                                    status: t.status,
                                    isActive: false,
                                    serviciosAfectados: t.serviciosAfectados,
                                    area: t.area,
                                    onTap: () {
                                      if (t.isPreTicket &&
                                          t.preticketId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PreticketChatScreen(
                                              preticketId: t.preticketId!,
                                              ticketCode: t.code,
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Este ticket no tiene chat disponible',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),
                            ];
                          }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  final String code;
  final String date;
  final int affectedStores;
  final String issueType;
  final String status;
  final bool isActive;
  final String serviciosAfectados;
  final String area;
  final VoidCallback? onTap; // 👈 NUEVO

  const TicketCard({
    Key? key,
    required this.code,
    required this.date,
    required this.affectedStores,
    required this.issueType,
    required this.status,
    required this.isActive,
    required this.serviciosAfectados,
    required this.area,
    this.onTap, // 👈 NUEVO
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color.fromARGB(255, 185, 31, 167)
              : Colors.grey,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Left side - code and details
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 1,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color.fromARGB(255, 185, 31, 167)
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$code',
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    serviciosAfectados.isNotEmpty
                        ? 'ID Afectados: $serviciosAfectados'
                        : '$affectedStores servicios afectados',
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    area.isNotEmpty ? '$date · $area' : date,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
            // Right side - issue type and status
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Si no hay onTap, se comporta igual que siempre
    if (onTap == null) return content;

    // Si hay onTap, la tarjeta es clickeable
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? helper;
  const _SectionTitle({required this.icon, required this.title, this.helper});

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF8B4A9C);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: brand.withOpacity(.10),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: brand),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              if (helper != null)
                Text(
                  helper!,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF8B4A9C);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? brand : Colors.grey.shade300),
          color: selected ? brand.withOpacity(0.10) : Colors.white,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: brand.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? brand : Colors.grey[800],
          ),
        ),
      ),
    );
  }
}
