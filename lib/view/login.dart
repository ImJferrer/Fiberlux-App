import 'dart:convert';
import 'package:fiberlux_new_app/widgets/fiberlux_base_layout.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import '../providers/loader_provider.dart';
import '../providers/nox_data_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'main_screen.dart';
import 'olvido_contra.dart';

/// Convierte una contraseña en texto plano a su hash SHA-256 en hexadecimal.
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool rememberPassword = true;
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _obscurePassword = true;

  final colores = <String>[
    '#f8f9fa',
    '#333333',
    '#ffffff',
    '#0056b3',
    '#007bff',
    '#17a2b8',
    '#138496',
    '#28a745',
    '#218838',
    '#f1f1f1',
    '#fefefe',
    '#cccccc',
    '#dddddd',
    '#f5f5f5',
    'green',
    'red',
  ];

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Auto-login: recuerda solo el username; obtiene el RUC desde Firestore.
  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldRemember = prefs.getBool('remember_login') ?? false;

    if (!shouldRemember) return;

    final savedUsername = prefs.getString('saved_username');
    if (savedUsername == null) return;

    try {
      final sessionProv = Provider.of<SessionProvider>(context, listen: false);
      final socketProv = Provider.of<GraphSocketProvider>(
        context,
        listen: false,
      );

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(savedUsername.toLowerCase())
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      final ruc = (data['ruc'] ?? '').toString().trim();
      if (ruc.isEmpty) return; // sin RUC, no seguimos

      sessionProv.setLogin(
        isSocial: false,
        nombre: (data['nombre'] ?? savedUsername).toString(),
        apellido: (data['apellido'] ?? '').toString().isEmpty
            ? null
            : data['apellido'],
        ruc: ruc,
        usuario: savedUsername,
        rol: (data['rol'] ?? 'USUARIO').toString(),
        email: (data['email'] ?? '').toString().isEmpty ? null : data['email'],
        photoUrl: (data['photoUrl'] ?? '').toString().isEmpty
            ? null
            : data['photoUrl'],
      );

      await socketProv.connect(ruc, colores);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (_) {
      // silencio: si falla auto login, que siga el flujo normal
    }
  }

  /// Login: valida Firestore (users/{username}), compara contraseña y toma RUC del doc.
  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _errorMessage = null);

    final username = _userController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if ([username, password].any((e) => e.isEmpty)) {
      setState(() => _errorMessage = 'Usuario y contraseña son obligatorios');
      return;
    }

    final loaderProv = Provider.of<LoaderProvider>(context, listen: false);
    final sessionProv = Provider.of<SessionProvider>(context, listen: false);
    final socketProv = Provider.of<GraphSocketProvider>(context, listen: false);
    final noxProv = Provider.of<NoxDataProvider>(context, listen: false);

    // Limpia data previa del socket
    socketProv.clearData();

    loaderProv.showLoader();
    try {
      // 1) Buscar al usuario en Firestore por su username (doc id = username en minúsculas)
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(username);
      final snap = await docRef.get();
      if (!snap.exists) {
        throw Exception('Usuario o contraseña incorrectos');
      }
      final data = snap.data()!;

      // 2) Cuenta activa?
      if (data['activo'] == false) {
        throw Exception('Esta cuenta ha sido deshabilitada');
      }

      // 3) Validar y migrar credenciales:
      //    - Si existe "Pass" (texto plano), comparamos y migramos a "passwordHash"
      //    - Si existe "passwordHash", comparamos hash
      //    - (Opcional) si existe "password", también migramos (soporte legado)
      bool credOk = false;

      if (data.containsKey('Pass')) {
        if (password == (data['Pass'] ?? '')) {
          credOk = true;
          await docRef.update({
            'passwordHash': hashPassword(password),
            'updatedAt': FieldValue.serverTimestamp(),
            'Pass': FieldValue.delete(),
          });
        }
      } else if (data.containsKey('passwordHash')) {
        final inputHash = hashPassword(password);
        credOk = (inputHash == data['passwordHash']);
      } else if (data.containsKey('password')) {
        if (password == (data['password'] ?? '')) {
          credOk = true;
          await docRef.update({
            'passwordHash': hashPassword(password),
            'updatedAt': FieldValue.serverTimestamp(),
            'password': FieldValue.delete(),
          });
        }
      }

      if (!credOk) {
        throw Exception('Usuario o contraseña incorrectos');
      }

      // 4) Obtener RUC desde Firestore (acepta "ruc" o "Ruc")
      final ruc = (data['ruc'] ?? data['Ruc'] ?? '').toString().trim();
      if (ruc.isEmpty) {
        throw Exception('Este usuario no tiene RUC configurado');
      }

      // 5) Guardar sesión local
      sessionProv.setLogin(
        isSocial: false,
        nombre: (data['nombre'] ?? username).toString(),
        apellido: (data['apellido']?.toString().trim().isEmpty ?? true)
            ? null
            : data['apellido'],
        ruc: ruc,
        usuario: username,
        rol: (data['rol'] ?? 'USUARIO').toString(),
        email: (data['email']?.toString().trim().isEmpty ?? true)
            ? null
            : data['email'],
        photoUrl: (data['photoUrl']?.toString().trim().isEmpty ?? true)
            ? null
            : data['photoUrl'],
      );

      // 6) Preferencias para autologin (guardamos username y ruc)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', username);
      await prefs.setString('saved_ruc', ruc);
      await prefs.setBool('remember_login', rememberPassword);

      // 7) (Opcional) Cargar Nox con el RUC
      try {
        final nox = await ApiService.fetchNoxData(ruc);
        noxProv.setNoxData(nox);
      } catch (_) {
        // silencioso si falla
      }

      // 8) Conectar socket con el RUC
      await socketProv.connect(ruc, colores);

      // 9) Navegar
      loaderProv.hideLoader();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (e) {
      if (mounted) loaderProv.hideLoader();
      if (mounted) setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    return FiberluxBaseLayout(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 70.0, vertical: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Iniciar sesión',
              style: TextStyle(
                fontFamily: "Poppins",
                color: const Color.fromARGB(255, 128, 42, 118),
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Username
            const Text(
              'Usuario',
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.black,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _userController,
              decoration: InputDecoration(
                hintText: 'Escribe Aquí...',
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
            const SizedBox(height: 20),

            // Password
            const Text(
              'Contraseña',
              style: TextStyle(
                fontFamily: "Poppins",
                color: Colors.black,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: '•••••••',
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
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Remember
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: rememberPassword,
                    onChanged: (bool? value) {
                      setState(() {
                        rememberPassword = value ?? false;
                      });
                    },
                    activeColor: const Color.fromARGB(255, 128, 42, 118),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recordar contraseña',
                  style: TextStyle(
                    fontFamily: "Poppins",
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontFamily: "Poppins",
                  fontStyle: FontStyle.italic,
                  color: Colors.red,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Login button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 128, 42, 118),
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

            // Forgot password
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const RecuperarContrasenaScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return child;
                          },
                    ),
                  );
                },
                child: const Text(
                  'Olvidé mi contraseña',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.grey,
                  ),
                ),
              ),
            ),

            if (!session.isValidated) ...[
              Text(
                'O Inicia sesión con',
                style: TextStyle(
                  fontFamily: "Poppins",
                  color: Colors.black,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final user = await AuthService().signInWithGoogle();
                        if (user == null) return;

                        final emailLower = (user.email ?? '').toLowerCase();
                        if (emailLower.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se obtuvo email de Google'),
                            ),
                          );
                          return;
                        }

                        final doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(emailLower)
                            .get();

                        if (!doc.exists ||
                            ((doc.data()?['ruc'] ?? '')
                                .toString()
                                .trim()
                                .isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tu cuenta no tiene RUC configurado. Contacta a soporte.',
                              ),
                            ),
                          );
                          return;
                        }

                        final data = doc.data()!;
                        final ruc = (data['ruc'] ?? '').toString().trim();

                        final parts = (user.displayName ?? '').trim().split(
                          ' ',
                        );
                        final nombre = parts.isNotEmpty
                            ? parts.first
                            : (data['nombre'] ?? '');
                        final apellido = parts.length > 1
                            ? parts.sublist(1).join(' ')
                            : (data['apellido'] ?? '');

                        final sessionProv = Provider.of<SessionProvider>(
                          context,
                          listen: false,
                        );
                        final socketProv = Provider.of<GraphSocketProvider>(
                          context,
                          listen: false,
                        );

                        sessionProv.setLogin(
                          isSocial: true,
                          nombre: nombre,
                          apellido: apellido.isEmpty ? null : apellido,
                          ruc: ruc,
                          usuario: null,
                          rol: (data['rol'] ?? 'USUARIO').toString(),
                          email: emailLower,
                          photoUrl: user.photoURL,
                        );

                        await socketProv.connect(ruc, colores);

                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainScreen(),
                            ),
                          );
                        }
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 2,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: Image.network(
                        'https://developers.google.com/identity/images/g-logo.png',
                        height: 24.0,
                        width: 24.0,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.g_mobiledata,
                              size: 24.0,
                              color: Colors.blue,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Microsoft (placeholder)
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Esta función se encuentra en desarrollo...',
                            ),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F2F2F),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: Image.network(
                        'https://cdn-icons-png.flaticon.com/512/732/732221.png',
                        height: 20.0,
                        width: 20.0,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.window,
                              size: 20.0,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
