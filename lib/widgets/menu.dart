import 'package:shared_preferences/shared_preferences.dart';

import '../providers/SessionProvider.dart';
import '../providers/googleUser_provider.dart';
import '../providers/graph_socket_provider.dart';
import '../services/auth_service.dart';
import '../view/login.dart';
import '../view/perfil.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiberluxDrawer extends StatelessWidget {
  const FiberluxDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Container(
        color: const Color(0xFFA4238E), // Color morado de la aplicación
        child: SafeArea(
          child: Column(
            children: [
              // X button to close drawer
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              const SizedBox(height: 20),

              // Menu items
              _buildMenuItem(context, 'Perfil de usuario', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileWidget(),
                  ),
                );
              }),

              _buildMenuItem(context, 'Consultar beneficios', () {
                Navigator.pop(context);
                _showDevelopmentSnackBar(context, 'Consultar beneficios');
              }),

              _buildMenuItem(
                context,
                '''Términos y
              condiciones''',
                () {
                  Navigator.pop(context);
                  _showDevelopmentSnackBar(context, 'Términos y condiciones');
                },
              ),

              _buildMenuItem(context, 'Asesor postventa', () {
                Navigator.pop(context);
                _showDevelopmentSnackBar(context, 'Asesor postventa');
              }),

              // Divider line
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 10,
                ),
                child: Divider(
                  color: Colors.white.withOpacity(0.5),
                  thickness: 1,
                ),
              ),

              // Logout option
              _buildMenuItem(context, 'Cerrar sesión', () async {
                try {
                  await AuthService().signOut();
                } catch (e) {
                  debugPrint('Error al cerrar sesión con AuthService: $e');
                }

                // Providers
                final sessionProv = Provider.of<SessionProvider>(
                  context,
                  listen: false,
                );
                final googleProv = Provider.of<GoogleUserProvider>(
                  context,
                  listen: false,
                );
                final graphProv = Provider.of<GraphSocketProvider>(
                  context,
                  listen: false,
                );

                // 1) Desconectar socket y limpiar
                graphProv.disconnect();
                graphProv.clearData();

                // 2) Limpiar sesión/providers
                sessionProv.logout();
                googleProv.clearUser();

                // 3) Limpiar AUTOINICIO (remember me) para que Login no te reenvíe al Home
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('remember_login');
                await prefs.remove('saved_username');
                await prefs.remove('saved_ruc');

                if (!context.mounted) return;

                // 4) Navegar al login limpiando la pila
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }, textColor: Colors.white.withOpacity(0.5)),

              // Push to bottom - App version
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 30),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'App Mi Fiberlux 1.0v',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    Function() onTap, {
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
        child: Text(
          title,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showDevelopmentSnackBar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature está en desarrollo'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
