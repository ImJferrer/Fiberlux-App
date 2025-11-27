import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/SessionProvider.dart';
import '../providers/googleUser_provider.dart';
import '../providers/graph_socket_provider.dart';
import '../services/auth_service.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:provider/provider.dart';

/// ====== Estilos y Helpers ======
const _brandColor = Color(0xFFA4238E);

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({
    Key? key,
    required this.title,
    required this.child,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _brandColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _brandColor,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      value: value,
      onChanged: onChanged,
      activeColor: _brandColor,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _brandColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _brandColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      subtitle: (subtitle == null) ? null : Text(subtitle!),
    );
  }
}

/// ====== Plexus animation (igual que la tuya) ======
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
      if (point.x < 0 || point.x > 400) point.vx *= -1;
      if (point.y < 0 || point.y > 300) point.vy *= -1;
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
        1.5,
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
            ..color = Colors.white.withOpacity(opacity * 0.7)
            ..strokeWidth = 0.8;
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// ====== Pantalla de Perfil ======
class UserProfileWidget extends StatefulWidget {
  const UserProfileWidget({Key? key}) : super(key: key);

  @override
  State<UserProfileWidget> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final plexusState = PlexusState();
  bool hasNotifications = true;

  // Espera utilitaria: aguarda a que el WS conecte (sin usar el valor de ningún void)
  Future<void> _waitConnected(
    GraphSocketProvider ws, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final limit = DateTime.now().add(timeout);
    while (!ws.isConnected && DateTime.now().isBefore(limit)) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  /// Activa el modo GRUPO:
  /// - Detecta el nombre del grupo desde el WS.resumen/currentGroupName
  /// - Lo guarda en SessionProvider
  /// - Conecta por grupo y pide la data adecuada
  Future<void> _activarModoGrupo() async {
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();

    sp.setGrupoEconomicoOrRuc(true);

    // 1) Detectar nombre de grupo del resumen
    String? grupo =
        ws.currentGroupName ??
        (ws.resumen['GRUPO'] ?? ws.resumen['Grupo_Empresarial'])?.toString();

    // 2) Si no hay grupo, hidrata desde RUC para obtenerlo
    if (grupo == null || grupo.isEmpty) {
      final r = sp.ruc ?? ws.ruc;
      if (r != null && r.isNotEmpty) {
        await ws.connect(r, ws.rawColors); // ← fuerza conexión por RUC
        ws.requestGraphData(r); // ← hidrata resumen
        await Future.delayed(const Duration(milliseconds: 400));
        grupo =
            ws.currentGroupName ??
            (ws.resumen['GRUPO'] ?? ws.resumen['Grupo_Empresarial'])
                ?.toString();
      }
    }

    if (grupo == null || grupo.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo determinar el Grupo Económico. Abre Pre-Diagnósticos y refresca.',
          ),
        ),
      );
      return;
    }

    // 3) Guardar en sesión (útil para siguientes pantallas)
    sp.setGrupoNombre(grupo);

    // 4) **SIEMPRE** reconectar por grupo (aunque ya esté conectado a RUC)
    await ws.connectByGroup(grupo, ws.rawColors);
    ws.fetchGroupSummary();

    // 5) Si tienes un RUC preferido, pide el detalle para ese RUC dentro del grupo
    final rPrefer = sp.ruc ?? ws.ruc;
    if (rPrefer != null && rPrefer.isNotEmpty) {
      ws.requestGraphDataForSelection(ruc: rPrefer, grupo: grupo);
    } else {
      ws.requestGraphDataForSelection(grupo: grupo);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Modo Grupo activado: $grupo')));
  }

  /// Vuelve al modo RUC clásico:
  /// - Conecta por RUC y pide la gráfica
  Future<void> _volverAModoRuc() async {
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();

    sp.setGrupoEconomicoOrRuc(false);

    final ruc = sp.ruc ?? ws.ruc;
    if (ruc == null || ruc.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay RUC configurado para reconectar.'),
        ),
      );
      return;
    }

    // **SIEMPRE** reconectar por RUC (aunque ya esté conectado a grupo)
    await ws.connect(ruc, ws.rawColors);
    ws.requestGraphData(ruc);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Modo RUC activado: $ruc')));
  }

  /// Controllers para la hoja de edición
  final _nombreCtrl = TextEditingController();
  final _apPatCtrl = TextEditingController();
  final _apMatCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController(); // Solo lectura
  DateTime? _fechaNac;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _animationController.addListener(_updatePoints);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nombreCtrl.dispose();
    _apPatCtrl.dispose();
    _apMatCtrl.dispose();
    _displayNameCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Widget _profileHeader({
    required String fotoUrl,
    required String displayName,
    required String rol,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _brandColor.withOpacity(0.25),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: fotoUrl.isNotEmpty
                  ? Image.network(fotoUrl, fit: BoxFit.cover)
                  : Container(
                      color: _brandColor.withOpacity(0.10),
                      child: const Icon(
                        Icons.person_outline,
                        size: 40,
                        color: _brandColor,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Nombre a mostrar + Rol
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display name
                Text(
                  displayName.isEmpty ? 'Usuario' : displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
                const SizedBox(height: 6),
                // Rol pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _brandColor.withOpacity(0.10),
                    border: Border.all(color: _brandColor.withOpacity(0.30)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (rol.isEmpty ? '—' : rol),
                    style: const TextStyle(
                      color: _brandColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _updatePoints() {
    plexusState.updatePoints();
    setState(() {});
  }

  // void _verificarUsuario() {
  //   Navigator.pushAndRemoveUntil(
  //     context,
  //     MaterialPageRoute(builder: (_) => const LoginScreen()),
  //     (route) => false,
  //   );
  // }

  Future<void> _pickFechaNacimiento(DateTime? initial) async {
    final now = DateTime.now();
    final first = DateTime(1900, 1, 1);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(2000, 1, 1),
      firstDate: first,
      lastDate: last,
      helpText: 'Selecciona tu fecha de cumpleaños',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(
              ctx,
            ).colorScheme.copyWith(primary: _brandColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaNac = picked);
    }
  }

  void _openEditProfileSheet() {
    final s = context.read<SessionProvider>();
    _nombreCtrl.text = s.nombre ?? '';
    _apPatCtrl.text = s.apellidoPaterno ?? '';
    _apMatCtrl.text = s.apellidoMaterno ?? '';
    _displayNameCtrl.text = s.displayName ?? s.nombre ?? s.usuario ?? '';
    _telefonoCtrl.text = s.telefono ?? '';
    _correoCtrl.text = s.email ?? s.usuario ?? '';
    _fechaNac = s.fechaNacimiento; // DateTime? esperado en el provider

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Editar perfil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),

                /// Nombre
                TextField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// Apellido paterno
                TextField(
                  controller: _apPatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellido paterno',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// Apellido materno
                TextField(
                  controller: _apMatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Apellido materno',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// Nombre a mostrar
                TextField(
                  controller: _displayNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre a mostrar',
                    hintText: 'Cómo se mostrará en la app',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                /// Fecha de nacimiento
                InkWell(
                  onTap: () => _pickFechaNacimiento(_fechaNac),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha de cumpleaños',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _fechaNac == null
                          ? 'Seleccionar...'
                          : '${_fechaNac!.year.toString().padLeft(4, '0')}-'
                                '${_fechaNac!.month.toString().padLeft(2, '0')}-'
                                '${_fechaNac!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: _fechaNac == null
                            ? Colors.black54
                            : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                /// Correo (solo lectura)
                TextField(
                  controller: _correoCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Correo (no modificable)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),

                /// Teléfono
                TextField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    hintText: '+51 9xx xxx xxx',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar cambios'),
                    onPressed: () async {
                      final nombre = _nombreCtrl.text.trim();
                      final apPat = _apPatCtrl.text.trim();
                      final apMat = _apMatCtrl.text.trim();
                      final displayName = _displayNameCtrl.text.trim();
                      final telefono = _telefonoCtrl.text.trim();

                      // 🔧 Ajusta esta llamada a tu SessionProvider:
                      await context.read<SessionProvider>().updateProfile(
                        nombre: nombre.isEmpty ? null : nombre,
                        apellidoPaterno: apPat.isEmpty ? null : apPat,
                        apellidoMaterno: apMat.isEmpty ? null : apMat,
                        displayName: displayName.isEmpty ? null : displayName,
                        fechaNacimiento: _fechaNac, // DateTime?
                        telefono: telefono.isEmpty ? null : telefono,
                        // correo: no se actualiza (solo lectura)
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perfil actualizado')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onToggleGrupoEconomico(bool v) async {
    final sp = context.read<SessionProvider>();
    final ws = context.read<GraphSocketProvider>();

    sp.setGrupoEconomicoOrRuc(v);

    if (v) {
      // → Activado: GRUPO
      final grupo =
          ws.currentGroupName ??
          (ws.resumen['GRUPO'] ?? ws.resumen['Grupo_Empresarial'])?.toString();

      if (grupo == null || grupo.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontró GRUPO_ECONOMICO en el Resumen. Abre Pre-Diagnósticos y refresca.',
            ),
          ),
        );
        return;
      }

      await ws.connectByGroup(grupo, ws.rawColors); // ← SIEMPRE
      ws.fetchGroupSummary();

      final rucActual = sp.ruc ?? ws.ruc;
      if (rucActual != null && rucActual.isNotEmpty) {
        ws.requestGraphDataForSelection(ruc: rucActual, grupo: grupo);
      } else {
        ws.requestGraphDataForSelection(grupo: grupo);
      }
    } else {
      // → Desactivado: RUC
      final ruc = sp.ruc ?? ws.ruc;
      if (ruc == null || ruc.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay RUC configurado para reconectar.'),
          ),
        );
        return;
      }

      await ws.connect(ruc, ws.rawColors); // ← SIEMPRE
      ws.requestGraphData(ruc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final google = context.watch<GoogleUserProvider>();

    final ruc = session.ruc ?? "N/A";
    final usuario = session.usuario ?? "Desconocido";
    final nombre = session.nombre ?? google.user?.displayName ?? "Desconocido";
    final apPat = session.apellidoPaterno ?? '';
    final apMat = session.apellidoMaterno ?? '';
    final displayName =
        session.displayName ??
        (nombre.isNotEmpty ? '$nombre $apPat'.trim() : 'Desconocido');
    final fechaNac = session.fechaNacimiento; // DateTime?
    final rol =
        session.rol ??
        (session.isValidated ? "DESCONOCIDO" : "Verifique su Cuenta");
    final correo = session.email ?? 'No definido';
    final fotoUrl = session.photoUrl ?? '';
    final telefono = session.telefono ?? 'No definido';

    final isGrupo = session.grupoEconomicoOrRuc;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        endDrawer: FiberluxDrawer(),
        body: Stack(
          children: [
            /// Fondo morado con Plexus
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 250,
              child: Container(
                decoration: const BoxDecoration(
                  color: _brandColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(80),
                    bottomRight: Radius.circular(80),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: CustomPaint(
                    painter: SimplePlexusPainter(
                      plexusState.points,
                      plexusState.connectionDistance,
                    ),
                  ),
                ),
              ),
            ),

            /// Contenido
            SafeArea(
              child: Column(
                children: [
                  /// Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Row(
                          children: [
                            /// Campanita
                            // Stack(
                            //   alignment: Alignment.center,
                            //   children: [
                            //     IconButton(
                            //       icon: Icon(
                            //         NotificationOverlay.isShowing
                            //             ? Icons.notifications
                            //             : Icons.notifications_outlined,
                            //         color: Colors.white,
                            //         size: 28,
                            //       ),
                            //       onPressed: () {
                            //         if (NotificationOverlay.isShowing) {
                            //           NotificationOverlay.hide();
                            //         } else {
                            //           NotificationOverlay.show(
                            //             context,
                            //             onClose: () {
                            //               setState(() {
                            //                 hasNotifications = false;
                            //               });
                            //             },
                            //           );
                            //         }
                            //       },
                            //     ),
                            //     if (hasNotifications)
                            //       Positioned(
                            //         top: 10,
                            //         right: 10,
                            //         child: Container(
                            //           width: 10,
                            //           height: 10,
                            //           decoration: const BoxDecoration(
                            //             color: Colors.red,
                            //             shape: BoxShape.circle,
                            //           ),
                            //         ),
                            //       ),
                            //   ],
                            // ),

                            /// Menú
                            // Builder(
                            //   builder: (context) => IconButton(
                            //     icon: const Icon(
                            //       Icons.menu,
                            //       color: Colors.white,
                            //       size: 28,
                            //     ),
                            //     onPressed: () =>
                            //         Scaffold.of(context).openEndDrawer(),
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  /// Título
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Perfil de usuario',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  /// Contenido principal
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            /// Tarjeta de perfil
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24.0),
                                border: Border.all(
                                  color: _brandColor.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _brandColor.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),

                                  _profileHeader(
                                    fotoUrl: fotoUrl,
                                    displayName: displayName,
                                    rol: rol,
                                  ),

                                  const SizedBox(height: 8),

                                  _buildInfoRow('RUC:', ruc),

                                  const SizedBox(height: 8),
                                  _buildInfoRow('Usuario:', usuario),
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Nombre:', nombre),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Paterno:',
                                    apPat.isEmpty ? 'No definido' : apPat,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Materno:',
                                    apMat.isEmpty ? 'No definido' : apMat,
                                  ),

                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    'Cumpleaños:',
                                    (fechaNac == null)
                                        ? 'No definido'
                                        : '${fechaNac.year.toString().padLeft(4, '0')}-'
                                              '${fechaNac.month.toString().padLeft(2, '0')}-'
                                              '${fechaNac.day.toString().padLeft(2, '0')}',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Correo:', correo),
                                  const SizedBox(height: 8),
                                  _buildInfoRow('Teléfono:', telefono),
                                  const SizedBox(height: 26),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            /// Botón Editar
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _openEditProfileSheet,
                                icon: const Icon(Icons.edit),
                                label: const Text('Editar perfil'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            /// Preferencias (Switches con mejor apariencia)
                            _SectionCard(
                              title: 'Preferencias',
                              child: Column(
                                children: [
                                  _SwitchTile(
                                    icon: Icons.badge_outlined,
                                    title: 'Grupo empresarial o RUC',
                                    subtitle:
                                        'Actívalo para trabajar por Grupo Económico',
                                    value: context
                                        .watch<SessionProvider>()
                                        .grupoEconomicoOrRuc,
                                    onChanged: (v) async {
                                      final sp = context
                                          .read<SessionProvider>();
                                      sp.setGrupoEconomicoOrRuc(v);

                                      if (v) {
                                        await _activarModoGrupo();
                                      } else {
                                        await _volverAModoRuc();
                                      }
                                    },
                                  ),

                                  const Divider(height: 1),
                                  _SwitchTile(
                                    icon: Icons.dashboard_customize_outlined,
                                    title: 'Vista moderna (agrupada)',
                                    subtitle:
                                        'Afecta la pantalla de Pre-Diagnósticos',
                                    value: context
                                        .watch<SessionProvider>()
                                        .preferModernView,
                                    onChanged: (v) => context
                                        .read<SessionProvider>()
                                        .setPreferModernView(v),
                                  ),
                                ],
                              ),
                            ),

                            /// Notificaciones (nuevo apartado)
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Notificaciones',
                              child: Column(
                                children: [
                                  // Notificaciones (solo el primer switch cambia)
                                  _SwitchTile(
                                    icon: Icons.email_outlined,
                                    title: 'Correo',
                                    value: true,
                                    onChanged: (v) {
                                      // Si intentan apagarlo, lo volvemos a encender y avisamos.
                                      final sp = context
                                          .read<SessionProvider>();
                                      sp.setNotiEmail(true);
                                    },
                                  ),

                                  const Divider(height: 1),
                                  _SwitchTile(
                                    icon: Icons.phone_iphone_outlined,
                                    title: 'App',
                                    value: session.notiApp ?? true,
                                    onChanged: (v) => context
                                        .read<SessionProvider>()
                                        .setNotiApp(v),
                                  ),

                                  const Divider(height: 1),
                                  _SwitchTile(
                                    icon: Icons.call_outlined,
                                    title: 'Llamada VOZ',
                                    value: session.notiVoz ?? false,
                                    onChanged: (v) => context
                                        .read<SessionProvider>()
                                        .setNotiVoz(v),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            /// Acciones
                            // SizedBox(
                            //   width: double.infinity,
                            //   child: ElevatedButton(
                            //     onPressed: () {},
                            //     style: ElevatedButton.styleFrom(
                            //       backgroundColor: Colors.white,
                            //       foregroundColor: _brandColor,
                            //       shape: RoundedRectangleBorder(
                            //         borderRadius: BorderRadius.circular(30),
                            //         side: const BorderSide(color: _brandColor),
                            //       ),
                            //       padding: const EdgeInsets.symmetric(
                            //         vertical: 14,
                            //       ),
                            //       elevation: 0,
                            //     ),
                            //     child: const Text(
                            //       'Modificar contraseña',
                            //       style: TextStyle(fontSize: 16),
                            //     ),
                            //   ),
                            // ),
                            // const SizedBox(height: 12),

                            // ElevatedButton.icon(
                            //   onPressed: _verificarUsuario,
                            //   icon: const Icon(Icons.verified_user),
                            //   label: const Text('Verificar cuenta'),
                            //   style: ElevatedButton.styleFrom(
                            //     backgroundColor: _brandColor,
                            //     foregroundColor: Colors.white,
                            //     shape: RoundedRectangleBorder(
                            //       borderRadius: BorderRadius.circular(30),
                            //     ),
                            //     padding: const EdgeInsets.symmetric(
                            //       vertical: 14,
                            //       horizontal: 24,
                            //     ),
                            //   ),
                            // ),
                            // const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Cerrar sesión'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFFE53935,
                                  ), // rojo "salir"
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  try {
                                    await AuthService().signOut();
                                  } catch (_) {}

                                  final sessionProv =
                                      Provider.of<SessionProvider>(
                                        context,
                                        listen: false,
                                      );
                                  final googleProv =
                                      Provider.of<GoogleUserProvider>(
                                        context,
                                        listen: false,
                                      );
                                  final graphProv =
                                      Provider.of<GraphSocketProvider>(
                                        context,
                                        listen: false,
                                      );

                                  graphProv.disconnect();
                                  graphProv.clearData();
                                  sessionProv.logout();
                                  googleProv.clearUser();

                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.remove('remember_login');
                                  await prefs.remove('saved_username');
                                  await prefs.remove('saved_ruc');

                                  if (!context.mounted) return;
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: _brandColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
