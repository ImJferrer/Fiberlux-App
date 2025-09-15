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
  int _currentIndex = 2;
  String? _entidadFilter;

  // ⬇️ clave para acceder a EntidadDashboardState.refresh()
  final _entidadKey = GlobalKey<EntidadDashboardState>();

  // Define aquí las pantallas que quieres mostrar.
  List<Widget> get _screens => [
    const QAPantalla(),
    const TicketsScreen(),
    DashboardWidget(onStatusTap: _handleEntidadStatusTap),
    EntidadDashboard(
      key: _entidadKey, // ⬅️ usa la key aquí
      initialStatus: _entidadFilter,
      onStatusTap: _handleEntidadStatusTap,
    ),
    const FacturacionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
              // Entrar por navbar => SIN filtro
              setState(() {
                _entidadFilter = null;
                _currentIndex = 3;
              });

              // Espera al frame y aplica el estado dentro de Entidad
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _entidadKey.currentState
                    ?.refresh(); // usa widget.initialStatus (null)
              });
              return;
            }

            // Otras pestañas
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }

  void _handleEntidadStatusTap(String status) {
    setState(() {
      _entidadFilter = status; // actualiza el filtro
      _currentIndex = 3; // salta a la pestaña de Entidades
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
