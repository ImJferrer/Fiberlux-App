import 'package:fiberlux_new_app/widgets/fiberlux_base_layout.dart';
import 'package:flutter/material.dart';

// Pantalla para ingresar correo corporativo
class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({Key? key}) : super(key: key);

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final TextEditingController _correoController = TextEditingController();

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FiberluxBaseLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            Text(
              'Recupera tu contraseña',
              style: TextStyle(
                fontFamily: "Poppins",
                color: const Color(0xFF772D8B),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Para recuperar tu contraseña ingresa tu correo corporativo. Se te enviará un correo con las credenciales para iniciar sesión.',
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.black,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Email field
            const Text(
              'Correo corporativo',
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _correoController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'usuario@empresa.pe',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(0xFF772D8B)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Recover button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla de confirmación
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const ConfirmacionRecuperacionScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            // Usar una transición sin animación
                            return child;
                          },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF772D8B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Recuperar contraseña',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de confirmación después de solicitar recuperación
class ConfirmacionRecuperacionScreen extends StatefulWidget {
  const ConfirmacionRecuperacionScreen({Key? key}) : super(key: key);

  @override
  State<ConfirmacionRecuperacionScreen> createState() =>
      _ConfirmacionRecuperacionScreenState();
}

class _ConfirmacionRecuperacionScreenState
    extends State<ConfirmacionRecuperacionScreen> {
  @override
  Widget build(BuildContext context) {
    return FiberluxBaseLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 50.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            Text(
              'Recupera tu contraseña',
              style: TextStyle(
                fontFamily: "Poppins",
                color: const Color(0xFF772D8B),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text(
              'Se te envió un correo. Inicia sesión con las credenciales enviadas.',
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.black,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 90),
            // Login button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  // Volver a la pantalla de inicio de sesión
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF772D8B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Iniciar sesión',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
