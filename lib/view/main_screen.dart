import 'package:fiberlux_new_app/view/contactos_screen.dart';
import 'package:fiberlux_new_app/widgets/custom_bottomNavBar.dart';

import 'preguntas_respuestas.dart';
import 'ticketsScreen.dart';
import 'entidadDashboard.dart';
import 'facturacionScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home.dart';

// ESTO ES EL BUTTONNAVBAR DE ABAJO QUE CAMBIA DE PANTALLA //

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _entidadFilter;
  final _entidadKey = GlobalKey<EntidadDashboardState>();

  List<Widget> get _screens => [
    DashboardWidget(onStatusTap: _handleEntidadStatusTap), // 0(Home)
    EntidadDashboard(
      // 3 (Entidad)
      key: _entidadKey,
      initialStatus: _entidadFilter,
      onStatusTap: _handleEntidadStatusTap,
    ),
    const TicketsScreen(), // 2
    // const FacturacionScreen(), // 4
    const ContactosScreen(), // 5 👈 NUEVO (Contactos)
    const QAPantalla(), // 1
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            final shouldExit = await _showExitDialog();
            if (shouldExit && context.mounted) {
              SystemNavigator.pop();
            }
          }
        },
        child: Scaffold(
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 3) {
                setState(() {
                  _entidadFilter = null;
                  _currentIndex = 3;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _entidadKey.currentState?.refresh();
                });
                return;
              }
              // Contactos (5) y demás tabs
              setState(() => _currentIndex = index);
            },
          ),
        ),
      ),
    );
  }

  void _handleEntidadStatusTap(String status) {
    setState(() {
      _entidadFilter = status;
      _currentIndex = 1;
    });
  }

  Future<bool> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Cerrar aplicación',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '¿Estás seguro de que quieres salir?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFA4238E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Salir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }
}
