import 'dart:convert';

import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';

import '../providers/SessionProvider.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class QAPantalla extends StatefulWidget {
  const QAPantalla({super.key});

  @override
  State<QAPantalla> createState() => _QAPantallaState();
}

class _QAPantallaState extends State<QAPantalla> {
  // 🔔 YA NO usamos hasNotifications local, todo viene de SessionProvider

  final List<Map<String, dynamic>> faqItems = [
    {
      'question': '¿Dónde puedo ver el estado de mis tickets de soporte?',
      'answer':
          'Puedes verificar el estado de tus tickets en la sección "Tickets" de la aplicación. Allí encontrarás todos tus tickets activos y el historial completo.',
      'isExpanded': false,
    },
    {
      'question': '¿Cuáles son los métodos de pago disponibles?',
      'answer':
          'Aceptamos múltiples métodos de pago incluyendo tarjetas de crédito, débito, transferencias bancarias y pagos en efectivo en puntos autorizados.',
      'isExpanded': false,
    },
    {
      'question': '¿Cómo puedo solicitar mi factura electrónica?',
      'answer':
          'Las facturas electrónicas se generan automáticamente y se envían a tu correo registrado. También puedes descargarlas desde tu portal de cliente.',
      'isExpanded': false,
    },
    {
      'question': '¿Cómo puedo cancelar o suspender mi servicio con Fiberlux?',
      'answer':
          'Para cancelar o suspender tu servicio, contacta a nuestro centro de atención al cliente o visita una de nuestras oficinas con tu documento de identidad.',
      'isExpanded': false,
    },
    {
      'question':
          '¿Cómo puedo conocer las características técnicas de mi servicio de Internet Dedicado?',
      'answer':
          'Las especificaciones técnicas de tu servicio se encuentran en tu contrato y también puedes consultarlas en tu portal de cliente o contactando a soporte técnico.',
      'isExpanded': false,
    },
    {
      'question': '¿Cómo realizo un upgrade o downgrade de mi servicio?',
      'answer':
          'Para cambiar tu plan de servicio, contacta a nuestro equipo comercial. Te ayudaremos a encontrar el plan que mejor se adapte a tus necesidades.',
      'isExpanded': false,
    },
    {
      'question': '¿Cómo solicito un traslado de servicio?',
      'answer':
          'Para solicitar un traslado de servicio, comunícate con nuestro centro de atención al cliente con al menos 15 días de anticipación.',
      'isExpanded': false,
    },
  ];

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FractionallySizedBox(heightFactor: 0.9, child: _QAChatSheet());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);

    if (session.ruc == null) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
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
                  // CAMPANITA CON FUNCIONALIDAD
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

                  // MENÚ HAMBURGUESA (si quieres agregar el botón del drawer aquí)
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Título principal
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                'Centro de ayuda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            // Lista de preguntas frecuentes
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: faqItems.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildFAQItem(faqItems[index], index),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // FAB del chat conversacional
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFA4238E),
        onPressed: _openChatSheet,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildFAQItem(Map<String, dynamic> item, int index) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            item['question'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        trailing: Icon(
          item['isExpanded']
              ? Icons.keyboard_arrow_up
              : Icons.keyboard_arrow_down,
          color: Colors.grey.shade600,
          size: 24,
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 20,
          top: 0,
        ),
        onExpansionChanged: (bool expanded) {
          setState(() {
            item['isExpanded'] = expanded;
          });
        },
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['answer'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= CHAT SHEET =======================

class _ChatMessage {
  final String text;
  final bool fromUser;

  _ChatMessage({required this.text, required this.fromUser});
}

class _QAChatSheet extends StatefulWidget {
  @override
  State<_QAChatSheet> createState() => _QAChatSheetState();
}

class _QAChatSheetState extends State<_QAChatSheet> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  String? _sessionId; // para mantener el contexto de la conversación en backend

  /// Convierte **texto** en negrita ocultando los ** en el mensaje
  Widget parseMessageText(String text, {bool isUser = false}) {
    final regex = RegExp(r'\*\*(.*?)\*\*');
    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in regex.allMatches(text)) {
      // Texto antes del bloque en negrita
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isUser ? Colors.white : Colors.black87,
            ),
          ),
        );
      }

      // Texto en negrita (sin los **)
      final boldText = match.group(1);

      spans.add(
        TextSpan(
          text: boldText,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.bold,
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      );

      start = match.end;
    }

    // Resto del texto (si lo hay)
    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  static const String _endpoint = 'http://209.61.72.70:9000/ask';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendQuestion() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final session = context.read<SessionProvider>();
    final ruc = session.ruc?.trim();
    if (ruc == null || ruc.isEmpty) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'No pude enviar la pregunta porque falta el RUC.',
            fromUser: false,
          ),
        );
      });
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _sending = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          if (_sessionId != null) 'session': _sessionId!, // mantiene la memoria
        },
        body: jsonEncode({
          'question': text,
          'ruc': ruc,
          if (_sessionId != null)
            'session_id': _sessionId!, // backend espera session_id en payload
        }),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final answer = (data['answer'] ?? '').toString().trim();
        final sessionId = (data['session_id'] ?? '').toString().trim();
        if (sessionId.isNotEmpty) _sessionId = sessionId;

        setState(() {
          _messages.add(
            _ChatMessage(
              text: answer.isEmpty
                  ? 'No recibí una respuesta del asistente.'
                  : answer,
              fromUser: false,
            ),
          );
        });
      } else {
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  'Ocurrió un error al consultar el asistente (HTTP ${resp.statusCode}).',
              fromUser: false,
            ),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'No se pudo conectar con el asistente. Inténtalo nuevamente.',
            fromUser: false,
          ),
        );
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Color(0xFFA4238E)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Asistente Fiberlux',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Lista de mensajes
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.fromUser;
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 4.0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 14.0,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? const Color(0xFFA4238E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16.0).copyWith(
                            bottomLeft: isUser
                                ? const Radius.circular(16)
                                : Radius.zero,
                            bottomRight: isUser
                                ? Radius.zero
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: parseMessageText(msg.text, isUser: isUser),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Barra de entrada
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendQuestion(),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu pregunta...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFFA4238E),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          color: const Color(0xFFA4238E),
                          onPressed: _sendQuestion,
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
