import 'package:flutter/material.dart';
import 'package:fiberlux_new_app/view/entidadDashboard.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final entidadKey = GlobalKey<EntidadDashboardState>();
  int _tabIndex = 0;

  CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  // Colores para el ítem activo/inactivo
  static const _activeColor = Color(0xFF8B4A9C);
  static const _inactiveColor = Color(0xFFBDBDBD);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItemIcon(context, Icons.call, 3),
          _buildNavItem(context, 'assets/icons/Status_navbar', 1),
          _buildNavItem(context, 'assets/icons/Home_navbar', 0),
          _buildNavItem(context, 'assets/icons/Ticket_navbar', 2),
          //_buildNavItem(context, 'assets/icons/Fact_navbar', 3),
          _buildNavItem(context, 'assets/icons/Ayuda_navbar', 4),
        ],
      ),
    );
  }

  // Builder para ítems con imagen (lo que ya tenías)
  Widget _buildNavItem(BuildContext context, String iconPath, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            '${iconPath}_${isActive ? "activo" : "inactivo"}.png',
            height: 45,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // NUEVO: builder para ítems con Icon nativo
  Widget _buildNavItemIcon(BuildContext context, IconData icon, int index) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: isActive ? _activeColor : _inactiveColor),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
