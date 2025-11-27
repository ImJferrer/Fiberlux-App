import 'package:shared_preferences/shared_preferences.dart';
import '../providers/SessionProvider.dart';
import '../providers/googleUser_provider.dart';
import '../providers/graph_socket_provider.dart';
import '../services/auth_service.dart';
import '../widgets/remote_config_service.dart'; // ← NUEVO
import '../view/login.dart';
import '../view/perfil.dart';
import '../view/encuesta.dart'; // ← NUEVO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiberluxDrawer extends StatelessWidget {
  const FiberluxDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rc = RemoteConfigService.i;
    final aiIcon = (rc.aiMenuIconUrl != null)
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              rc.aiMenuIconUrl!,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.psychology_alt_rounded, color: Colors.white),
            ),
          )
        : const Icon(Icons.psychology_alt_rounded, color: Colors.white);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Container(
        color: const Color(0xFFA4238E),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 20),

              _buildMenuItem(context, 'Perfil de usuario', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileWidget(),
                  ),
                );
              }, icon: Icons.person_outline),

              // === REEMPLAZO: si está habilitado por RC, mostramos "Encuesta" (icono IA),
              // y no mostramos "Post Venta"/"Consultar beneficios".
              if (rc.showAiMenu)
                _buildMenuItem(
                  context,
                  rc.aiMenuTitle, // p.ej. "Encuesta"
                  () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EncuestaScreen()),
                    );
                  },
                  leading: aiIcon,
                )
              else
                _buildMenuItem(
                  context,
                  'Consultar beneficios', // tu ítem antiguo (Post Venta)
                  () {
                    Navigator.pop(context);
                    _showDevelopmentSnackBar(context, 'Consultar beneficios');
                  },
                  icon: Icons.local_offer_outlined,
                ),

              _buildMenuItem(
                context,
                '''Términos y
              condiciones''',
                () {
                  Navigator.pop(context);
                  _showDevelopmentSnackBar(context, 'Términos y condiciones');
                },
                icon: Icons.description_outlined,
              ),

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

              _buildMenuItem(
                context,
                'Cerrar sesión',
                () async {
                  try {
                    await AuthService().signOut();
                  } catch (e) {
                    debugPrint('Error al cerrar sesión con AuthService: $e');
                  }
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

                  graphProv.disconnect();
                  graphProv.clearData();
                  sessionProv.logout();
                  googleProv.clearUser();

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('remember_login');
                  await prefs.remove('saved_username');
                  await prefs.remove('saved_ruc');

                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                textColor: Colors.white.withOpacity(0.5),
                icon: Icons.logout,
              ),

              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 30),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'Version 1.1',
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
    IconData? icon,
    Widget? leading, // ⬅️ NUEVO
  }) {
    final effectiveLeading =
        leading ??
        Icon(icon ?? Icons.chevron_right, color: (textColor ?? Colors.white));

    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
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
            const SizedBox(width: 12),
            effectiveLeading,
          ],
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
