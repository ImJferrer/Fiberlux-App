// lib/view/contactos_screen.dart
import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login.dart';
import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';
import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';

class ContactosScreen extends StatefulWidget {
  const ContactosScreen({Key? key}) : super(key: key);

  @override
  State<ContactosScreen> createState() => _ContactosScreenState();
}

class _ContactosScreenState extends State<ContactosScreen> {
  // 🔔 YA NO USAMOS hasNotifications local, todo viene del SessionProvider

  // Colores de marca
  static const Color kPurple = Color(0xFF8B4A9C); // Comercial
  static const Color kPurpleSoft = Color(0xFFB565A7); // Cobranzas
  static const Color kIndigo = Color(0xFF3F51B5); // NOC
  static const Color kTeal = Color(0xFF009688); // SOC

  // ===== Helpers =====
  String? _pick(Map res, List<String> keys) {
    for (final k in keys) {
      final v = res[k] ?? res[k.toLowerCase()] ?? res[k.toUpperCase()];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty && s != 'null') return s;
      }
    }
    return null;
  }

  String _initials(String? name) {
    final s = (name ?? '').trim();
    if (s.isEmpty) return '';
    final parts = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String _digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  String _toDialable(String raw, {String defaultCC = '+51'}) {
    final onlyDigits = _digitsOnly(raw);
    if (onlyDigits.isEmpty) return raw.trim();
    if (raw.trim().startsWith('+')) return '+' + onlyDigits;

    // Si es fijo con 01 (Lima), marcamos sin el "+" para que el SO resuelva
    if (onlyDigits.startsWith('01') && onlyDigits.length >= 8) {
      return onlyDigits; // "017480606"
    }

    if (onlyDigits.length == 9) return '$defaultCC$onlyDigits';
    if (onlyDigits.length == 10 && onlyDigits.startsWith('0')) {
      return '$defaultCC${onlyDigits.substring(1)}';
    }
    return '+$onlyDigits';
  }

  Future<void> _launchPhone(String phone) async {
    // Usamos solo dígitos cuando es posible para el esquema tel:
    final digits = _digitsOnly(phone);
    final path = digits.isNotEmpty ? digits : phone.trim();
    final uri = Uri(scheme: 'tel', path: path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone, {String? prefilled}) async {
    final e164 = _toDialable(phone);
    final digits = e164.replaceAll('+', '');
    final text = Uri.encodeComponent(prefilled ?? '');
    final uri = Uri.parse(
      'https://wa.me/$digits${text.isEmpty ? '' : '?text=$text'}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(
    String email, {
    String? subject,
    String? body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject != null && subject.trim().isNotEmpty) 'subject': subject,
        if (body != null && body.trim().isNotEmpty) 'body': body,
      },
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _copy(String what, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$what copiado'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (session.ruc == null) {
      // ===== Acceso restringido =====
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
                                  // 🔔 marcar como leídas en el provider
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

    // ===== Pantalla normal =====
    final g = context.watch<GraphSocketProvider>();
    final resumen = (g.resumenConContactos is Map)
        ? Map<String, dynamic>.from(g.resumenConContactos)
        : const {};

    // Comercial
    final comercialName =
        _pick(resumen, ['Comercial', 'comercial']) ?? 'Ejecutivo Comercial';
    final comercialMail = _pick(resumen, [
      'CorreoComercial',
      'correo_comercial',
      'Comercial_Correo',
      'correo',
    ]);
    final comercialPhone = _pick(resumen, [
      'Comercial_Movil',
      'ComercialMovil',
      'Comercial_Telefono',
      'ComercialTelefono',
      'Comercial_Tel',
      'ComercialCelular',
    ]);

    // Cobranzas
    final cobranzaName =
        _pick(resumen, ['Cobranza', 'cobranza']) ?? 'Agente de cobranzas';

    // NOC
    final nocName = _pick(resumen, [
      'NOC',
      'noc',
      'Soporte',
      'soporte',
      'Contacto_NOC',
    ]);

    final cobranzaMail = _pick(resumen, [
      'CorreoCobranza',
      'cobranza_correo',
      'Cobranza_Correo',
    ]);
    final cobranzaPhone = _pick(resumen, [
      'Cobranza_Movil',
      'CobranzaTelefono',
      'Cobranza_Telefono',
      'CobranzaCelular',
    ]);

    final nocMail = _pick(resumen, [
      'CorreoNOC',
      'NOC_Correo',
      'noc_correo',
      'Soporte_Correo',
      'soporte_correo',
    ]);
    final nocPhone = _pick(resumen, [
      'NOC_Movil',
      'NOC_Telefono',
      'noc_telef',
      'Soporte_Movil',
      'Soporte_Telefono',
    ]);

    // SOC (seguridad)
    final socName = _pick(resumen, [
      'SOC',
      'soc',
      'Seguridad',
      'seguridad',
      'Contacto_SOC',
    ]);
    final socMail = _pick(resumen, [
      'CorreoSOC',
      'SOC_Correo',
      'soc_correo',
      'Seguridad_Correo',
      'seguridad_correo',
    ]);
    final socPhone = _pick(resumen, [
      'SOC_Movil',
      'SOC_Telefono',
      'Seguridad_Movil',
      'Seguridad_Telefono',
    ]);

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

                      // 👇 ESTE ES EL PUNTO ROJO GLOBAL
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ===== Título =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Contactos',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comercial, Cobranzas, NOC',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== Contactos =====
          SliverToBoxAdapter(
            child: _contactExpandableCard(
              role: 'Comercial',
              name: comercialName,
              initials: _initials(cobranzaName),
              accent: kPurpleSoft,
              phone: comercialPhone,
              email: comercialMail,
              enableWhatsapp: false,
            ),
          ),

          SliverToBoxAdapter(
            child: _contactExpandableCard(
              role: 'Cobranzas',
              name: "Agente de cobranzas",
              initials: _initials(cobranzaName),
              accent: kPurpleSoft,
              phone: "(01) 748 0606",
              email: "cobranzas.clientes@fiberlux.com",
              emailSubject: 'Cobranza - $cobranzaName',
              annex: 'Opción 4',
              enableWhatsapp: false,
            ),
          ),

          SliverToBoxAdapter(
            child: _contactExpandableCard(
              role: 'NOC',
              name: nocName ?? 'Soporte Técnico',
              initials: _initials(nocName),
              accent: kIndigo,
              phone: "(01) 748 0606",
              email: "noc@fiberlux.pe",
              emailSubject: 'Soporte - ${nocName ?? 'NOC'}',
              annex: 'Opción 1 - 1',
              enableWhatsapp: true,
              whatsappNumber: '913795489',
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );
  }

  // ====== UI pieces ======

  Widget _contactExpandableCard({
    required String role,
    required String name,
    required String initials,
    required Color accent,
    String? phone,
    String? email,
    String? emailSubject,
    String? annex,
    bool enableWhatsapp = false,
    String? whatsappNumber,
  }) {
    final hasPhone = (phone != null && phone.trim().isNotEmpty);
    final hasEmail = (email != null && email.trim().isNotEmpty);
    final hasAnnex = (annex != null && annex!.trim().isNotEmpty);
    final hasWhatsapp =
        enableWhatsapp &&
        ((whatsappNumber != null && whatsappNumber!.trim().isNotEmpty) ||
            hasPhone);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: accent.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          iconColor: accent,
          collapsedIconColor: Colors.black45,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (initials.isEmpty ? role.characters.first : initials),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Nombre + rol
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rol chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          letterSpacing: .2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Chips info
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (hasPhone)
                          _miniInfoChip(
                            icon: Icons.phone_outlined,
                            label: phone!,
                            onTap: () => _launchPhone(phone),
                            onLongPress: () =>
                                _copy('Teléfono', _toDialable(phone)),
                          ),
                        if (hasAnnex)
                          _miniInfoChip(icon: Icons.dialpad, label: annex!),
                        if (hasEmail)
                          _miniInfoChip(
                            icon: Icons.email_outlined,
                            label: email!,
                            onTap: () =>
                                _launchEmail(email!, subject: emailSubject),
                            onLongPress: () => _copy('Correo', email!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Contenido expandido
          children: [
            if (hasWhatsapp)
              _actionRow(
                icon: Icons.chat_bubble_outline,
                label: 'WhatsApp',
                onTap: () => _launchWhatsApp(
                  (whatsappNumber?.trim().isNotEmpty ?? false)
                      ? whatsappNumber!.trim()
                      : phone!,
                  prefilled: 'Hola, ¿qué tal?',
                ),
                trailing: IconButton(
                  tooltip: 'Copiar para WhatsApp',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(
                    'WhatsApp',
                    _toDialable(
                      (whatsappNumber?.trim().isNotEmpty ?? false)
                          ? whatsappNumber!.trim()
                          : phone!,
                    ),
                  ),
                ),
              ),
            if (hasEmail)
              _actionRow(
                icon: Icons.alternate_email,
                label: 'Enviar correo',
                onTap: () => _launchEmail(email!, subject: emailSubject),
                trailing: IconButton(
                  tooltip: 'Copiar correo',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy('Correo', email!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfoChip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.black87),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      leading: Icon(icon, size: 20, color: Colors.black87),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
      trailing: trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
