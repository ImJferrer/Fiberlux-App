import 'package:fiberlux_new_app/view/entidadDashboard.dart';
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final entidadKey = GlobalKey<EntidadDashboardState>();
  int _tabIndex = 2; // ej. 2=Home, 3=Entidad

  CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

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
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(context, 'assets/icons/Ayuda_navbar', 0),
          _buildNavItem(context, 'assets/icons/Ticket_navbar', 1),
          _buildNavItem(context, 'assets/icons/Home_navbar', 2),
          _buildNavItem(context, 'assets/icons/Status_navbar', 3),
          _buildNavItem(context, 'assets/icons/Fact_navbar', 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String iconPath, int index) {
    bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            '${iconPath}_${isActive ? "activo" : "inactivo"}.png',
            height: isActive ? 45 : 45,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
