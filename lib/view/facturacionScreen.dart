import 'package:fiberlux_new_app/widgets/buildAppBarNotifications/buildappbarnotifications.dart';
import 'package:fiberlux_new_app/widgets/menu.dart';

import '../providers/SessionProvider.dart';
import 'login.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/graph_socket_provider.dart';

class FacturacionScreen extends StatefulWidget {
  const FacturacionScreen({Key? key}) : super(key: key);

  @override
  State<FacturacionScreen> createState() => _FacturacionScreenState();
}

class _FacturacionScreenState extends State<FacturacionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _mostrarPendientes = true;
  bool hasNotifications = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                    // CAMPANITA CON FUNCIONALIDAD
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
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 15.0,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48.0, color: Colors.purple),
                SizedBox(height: 16.0),
                Text(
                  'Acceso restringido',
                  style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Verifica tu cuenta para continuar.',
                  style: TextStyle(fontSize: 16.0, color: Colors.grey[600]),
                ),
                SizedBox(height: 24.0),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
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
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Facturación',
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
              'Actualmente esta pantalla está en desarrollo.',
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
          // Reemplaza el Container anterior con este código para tener botones separados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mostrarPendientes = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mostrarPendientes
                          ? Color(0xFF8E2D87)
                          : Color(0xFFEACCE8),
                      foregroundColor: _mostrarPendientes
                          ? Colors.white
                          : Color(0xFF8E2D87),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Pendientes',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16), // Espacio entre los botones
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mostrarPendientes = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_mostrarPendientes
                          ? Color(0xFF8E2D87)
                          : Color(0xFFEACCE8),
                      foregroundColor: !_mostrarPendientes
                          ? Colors.white
                          : Color(0xFF8E2D87),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Pagados',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: _mostrarPendientes
                ? _buildPendientesView()
                : _buildPagadosView(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendientesView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Octubre 2024',
                  style: TextStyle(color: Color(0xFFBF2FB2), fontSize: 16),
                ),
                Expanded(
                  child: Divider(
                    color: Color(0xFFBF2FB2),
                    thickness: 1,
                    indent: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildFacturaPendienteItem('Factura #142', '54'),
          _buildFacturaPendienteItem('Factura #142', '868'),
          _buildFacturaPendienteItem('Factura #142', '9477'),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Agosto 2024',
                  style: TextStyle(color: Color(0xFFBF2FB2), fontSize: 16),
                ),
                Expanded(
                  child: Divider(
                    color: Color(0xFFBF2FB2),
                    thickness: 1,
                    indent: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildFacturaPendienteItem('Factura #142', '125'),
          _buildFacturaPendienteItem('Factura #142', '9477'),
        ],
      ),
    );
  }

  Widget _buildPagadosView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Marzo 2025',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
                ),
                Expanded(
                  child: Divider(
                    color: Color(0xFFE0E0E0),
                    thickness: 1,
                    indent: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildFacturaPagadaItem('Factura #143', '489'),
          _buildFacturaPagadaItem('Factura #142', '1529'),
          _buildFacturaPagadaItem('Factura #141', '89'),
          _buildFacturaPagadaItem('Factura #143', '489'),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Febrero 2025',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
                ),
                Expanded(
                  child: Divider(
                    color: Color(0xFFE0E0E0),
                    thickness: 1,
                    indent: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _buildFacturaPagadaItem('Factura #143', '489'),
        ],
      ),
    );
  }

  Widget _buildFacturaPendienteItem(String titulo, String monto) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFBF2FB2)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFBF2FB2),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Tienda ###',
                style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 5),
              Text(
                'F. Venc.: 28/02/25',
                style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          Text(
            's/ $monto',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacturaPagadaItem(String titulo, String monto) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Tienda ###',
                style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(height: 5),
              Text(
                'F. Venc.: 28/02/25',
                style: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                's/ $monto',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.download, color: Color(0xFF9E9E9E)),
            ],
          ),
        ],
      ),
    );
  }
}
