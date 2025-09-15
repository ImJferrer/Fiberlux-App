import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';

import '../providers/SessionProvider.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QAPantalla extends StatefulWidget {
  const QAPantalla({super.key});

  @override
  State<QAPantalla> createState() => _QAPantallaState();
}

class _QAPantallaState extends State<QAPantalla> {
  bool hasNotifications = true;

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
                          color: const Color(0xFFA4238E),
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
                  // MENÚ HAMBURGUESA
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

      // Botón flotante de chat/IA
      floatingActionButton: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFA4238E),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA4238E).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 28,
        ),
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
