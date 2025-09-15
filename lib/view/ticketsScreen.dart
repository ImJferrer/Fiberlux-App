import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';

import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart'; // ⬅️ IMPORTANTE
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ========================= Transformación a vista =========================
class _TicketView {
  final String code;
  final String date; // formateada dd/MM/yy
  final int affectedStores;
  final String issueType; // 2 líneas mayúsculas
  final String status;
  final bool isActive;
  final DateTime? createdAt;

  const _TicketView({
    required this.code,
    required this.date,
    required this.affectedStores,
    required this.issueType,
    required this.status,
    required this.isActive,
    required this.createdAt,
  });
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({Key? key}) : super(key: key);

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  bool _showHistory = false;
  bool hasNotifications = true;

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

  List<_TicketView> _mapAfectadosToViews(dynamic afectadosDyn) {
    final list = (afectadosDyn is List) ? afectadosDyn : const [];
    final tmp = <_TicketView>[];
    final seen = <String>{};

    for (final t in list) {
      if (t is! Map) continue;

      final code = (t['NroTicket'] ?? t['ticket_id'] ?? t['id'] ?? '')
          .toString();
      if (code.isEmpty || seen.contains(code)) continue; // evitar duplicados
      seen.add(code);

      final estado = (t['EstadoTicket'] ?? t['estado'] ?? '').toString();
      final tipo = (t['Tipo'] ?? t['tipo_ticket_nombre'] ?? 'Ticket')
          .toString();

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

      tmp.add(
        _TicketView(
          code: code,
          date: date,
          affectedStores: affected,
          issueType: _twoLineUpper(tipo),
          status: estado.isEmpty ? '—' : estado,
          isActive: _isActiveStatus(estado),
          createdAt: created,
        ),
      );
    }

    // ordenar por fecha (recientes primero)
    tmp.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return tmp;
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
                ],
              ),
            ],
          ),
        ),
        automaticallyImplyLeading: false,
      ),
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
                            ),
                          ),
                        ),

                      // ---------- Separador / Historial -----------
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showHistory = !_showHistory),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Color.fromARGB(255, 185, 31, 167),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  const Text(
                                    'Historial de tickets',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 185, 31, 167),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(
                                    _showHistory
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: const Color.fromARGB(
                                      255,
                                      185,
                                      31,
                                      167,
                                    ),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Color.fromARGB(255, 185, 31, 167),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_showHistory) ...[
                        const SizedBox(height: 16),

                        if (history.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'Sin historial',
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

  const TicketCard({
    Key? key,
    required this.code,
    required this.date,
    required this.affectedStores,
    required this.issueType,
    required this.status,
    required this.isActive,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
                      'Cód. $code',
                      style: const TextStyle(color: Colors.white, fontSize: 17),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$affectedStores tiendas afectadas',
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    date,
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
                    issueType,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    status,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
