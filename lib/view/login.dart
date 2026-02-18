import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fiberlux_new_app/providers/notifications_provider.dart';
import 'package:fiberlux_new_app/services/api_services.dart';
import 'package:fiberlux_new_app/services/fcm_service.dart';
import 'package:fiberlux_new_app/widgets/fiberlux_base_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../providers/SessionProvider.dart';
import '../providers/graph_socket_provider.dart';
import '../providers/loader_provider.dart';
import 'main_screen.dart';
import 'olvido_contra.dart';

const String _kSavedLoginPassword = 'saved_login_password';
const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Convierte una contraseña en texto plano a su hash SHA-256 en hexadecimal.
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  final digest = sha256.convert(bytes);
  return digest.toString();
}

// === Helpers para validación de contraseñas (retro-compatibles) ===
String _hexNormalize(String s) =>
    s.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();

bool _looksHexLen(String s, int len) =>
    RegExp(r'^[0-9a-fA-F]+$').hasMatch(s) && s.length == len;

String _sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();
String _sha1Hex(String s) => sha1.convert(utf8.encode(s)).toString();
String _md5Hex(String s) => md5.convert(utf8.encode(s)).toString();

bool _timingSafeEquals(String a, String b) {
  // Comparación constante para evitar filtrado por timing.
  var res = 0;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    res |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return res == 0;
}

/// Valida la contraseña de usuario contra el documento de Firestore.
/// Soporta:
/// - passwordAlgo: 'SHA256' | 'SHA1' | 'MD5' | 'PLAINTEXT'
/// - passwordHash | password_sha256 | password (auto-detecta forma)
/// - passwordSalt (opcional). Se prueban salt+pass y pass+salt.
bool _validatePassword(Map<String, dynamic> data, String inputPassword) {
  final algo = (data['password'] ?? data['clave'] ?? data['pass'] ?? '')
      .toString()
      .trim()
      .toUpperCase();

  final salt = (data['passwordSalt'] ?? data['salt'] ?? '').toString().trim();

  final storedRaw =
      (data['passwordHash'] ??
              data['password_hash'] ??
              data['password_sha256'] ??
              data['password'] ??
              data['pass'] ??
              '')
          .toString()
          .trim();

  if (storedRaw.isEmpty) return false;

  // Construye posibles candidatos segun el algoritmo o forma detectada.
  final candidates = <String>[];
  final addSha256 = () {
    if (salt.isNotEmpty) {
      candidates.add(_sha256Hex(salt + inputPassword));
      candidates.add(_sha256Hex(inputPassword + salt));
    } else {
      candidates.add(_sha256Hex(inputPassword));
    }
  };

  switch (algo) {
    case 'SHA256':
      addSha256();
      break;
    case 'SHA1':
      candidates.add(_sha1Hex(inputPassword));
      break;
    case 'MD5':
      candidates.add(_md5Hex(inputPassword));
      break;
    case 'PLAINTEXT':
      candidates.add(inputPassword);
      break;
    default:
      // Autodetección por forma del valor almacenado
      final sr = storedRaw.trim();
      if (_looksHexLen(sr, 64)) {
        addSha256();
      } else if (_looksHexLen(sr, 40)) {
        candidates.add(_sha1Hex(inputPassword));
      } else if (_looksHexLen(sr, 32)) {
        candidates.add(_md5Hex(inputPassword));
      } else {
        // Parece texto plano
        candidates.add(inputPassword);
      }
  }

  // Comparación: si el almacenado "parece" hash hex, normalizamos a hex
  // para comparar; si no, comparamos como texto plano.
  final storedLooksHash =
      _looksHexLen(storedRaw, 64) ||
      _looksHexLen(storedRaw, 40) ||
      _looksHexLen(storedRaw, 32);

  if (storedLooksHash) {
    final stored = _hexNormalize(storedRaw);
    for (final c in candidates) {
      if (_timingSafeEquals(_hexNormalize(c), stored)) return true;
    }
    return false;
  } else {
    for (final c in candidates) {
      if (_timingSafeEquals(c, storedRaw)) return true;
    }
    return false;
  }
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

  // Extrae el nombre de grupo económico de la respuesta de Arcus.
  // Prioridad: GRUPO_ECONOMICO (MAYÚS) y fallbacks comunes.
  String _extractGrupoEconomico(Map<String, dynamic> resp) {
    const keys = [
      'GRUPO_ECONOMICO', // ← WebSocket/Arcus (MAYÚS)
      'grupo_economico',
      'grupoEconomico',
      'grupo',
      'economic_group',
    ];
    for (final k in keys) {
      final v = resp[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase() ?? '';
    return s == '1' || s == 'true';
  }

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

    // 🔌 Enlaza socket -> session para persistir grupo SIN tocar el main
    final sessionProv = Provider.of<SessionProvider>(context, listen: false);
    final socketProv = Provider.of<GraphSocketProvider>(context, listen: false);
    socketProv.onGroupResolved ??= sessionProv.setGrupoNombre;

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

    try {
      final sessionProv = Provider.of<SessionProvider>(context, listen: false);
      final socketProv = Provider.of<GraphSocketProvider>(
        context,
        listen: false,
      );
      final notifProv = Provider.of<NotificationsProvider>(
        context,
        listen: false,
      );

      final savedUsername =
          prefs.getString('saved_username') ?? sessionProv.usuario ?? '';
      var savedPassword =
          (await _secureStorage.read(key: _kSavedLoginPassword)) ?? '';
      if (savedPassword.isEmpty) {
        final legacy = prefs.getString(_kSavedLoginPassword) ?? '';
        if (legacy.isNotEmpty) {
          savedPassword = legacy;
          await _secureStorage.write(key: _kSavedLoginPassword, value: legacy);
          await prefs.remove(_kSavedLoginPassword);
        }
      }
      if (savedUsername.trim().isNotEmpty && savedPassword.isNotEmpty) {
        sessionProv.setRuntimeLoginCredentials(
          username: savedUsername,
          password: savedPassword,
        );
      }

      final savedRuc = prefs.getString('saved_ruc') ?? sessionProv.ruc;
      final access = sessionProv.accessToken ?? prefs.getString('access_token');

      if (savedRuc == null ||
          savedRuc.isEmpty ||
          access == null ||
          access.isEmpty) {
        return;
      }

      // 👉 IMPORTANTE: sincronizar userId con NotificationsProvider
      if (sessionProv.userId != null) {
        notifProv.setCurrentUserId(sessionProv.userId);
      }

      // Reinicia WS limpio y conecta con el RUC
      socketProv.disconnect();
      socketProv.clearData();
      await socketProv.connect(savedRuc, colores);

      try {
        final fcmToken = await FcmService.instance.ensureRegistered(
          ruc: savedRuc,
          grupo: sessionProv.grupoNombre,
          vistaRuc: false,
        );
        notifProv.setCurrentDeviceToken(fcmToken);
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } catch (_) {
      // silencio: si falla autologin, que siga el flujo normal
    }
  }

  /// Login: valida Firestore (users/{username}), compara contraseña y toma RUC del doc.
  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _errorMessage = null);

    final username = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Usuario y contraseña son obligatorios');
      return;
    }

    final loaderProv = Provider.of<LoaderProvider>(context, listen: false);
    final sessionProv = Provider.of<SessionProvider>(context, listen: false);
    final socketProv = Provider.of<GraphSocketProvider>(context, listen: false);

    socketProv.disconnect();
    socketProv.clearData();

    loaderProv.showLoader();
    try {
      // 1) Login contra Arcus
      final resp = await ApiService.arcusLogin(
        username: username,
        password: password,
      );

      final access = (resp['access_token'] ?? '').toString();
      final refresh = (resp['refresh_token'] ?? '').toString();
      final userId = int.tryParse('${resp['user_id']}') ?? 0;
      final uname = (resp['username'] ?? username).toString();
      final email = (resp['email'] ?? '').toString();
      final firstName = (resp['first_name'] ?? '').toString();
      final lastName = (resp['last_name'] ?? '').toString();
      final isStaff = _asBool(resp['is_staff']);
      final isActive = _asBool(resp['is_active']);
      final ruc = (resp['ruc'] ?? '').toString().trim();

      if (!isActive) {
        throw ApiException('Esta cuenta ha sido deshabilitada', status: 403);
      }
      if (ruc.isEmpty) {
        throw ApiException(
          'Este usuario no tiene RUC configurado',
          status: 422,
        );
      }

      // 2) Cargar sesión
      sessionProv.setLogin(
        isSocial: false,
        nombre: firstName.isNotEmpty ? firstName : uname,
        apellido: lastName.trim().isEmpty ? null : lastName,
        ruc: ruc,
        usuario: uname,
        rol: isStaff ? 'STAFF' : 'USUARIO',
        email: email.trim().isEmpty ? null : email,
        photoUrl: null,
      );

      // 3) Persistir tokens/flags de Arcus
      sessionProv.setArcusAuth(
        access: access,
        refresh: refresh,
        userId: userId,
        isStaff: isStaff,
        isActive: isActive,
      );
      sessionProv.setRuntimeLoginCredentials(
        username: uname,
        password: password,
      );

      // 👉 Avisar al NotificationsProvider quién soy
      final notifProv = Provider.of<NotificationsProvider>(
        context,
        listen: false,
      );
      notifProv.setCurrentUserId(userId);

      // 4) Guardar preferencias de autologin
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_username', uname);
      await prefs.setString('saved_ruc', ruc);
      await prefs.setBool('remember_login', rememberPassword);
      await prefs.setInt('user_id', userId);
      await prefs.setString('access_token', access);
      await prefs.setString('refresh_token', refresh);
      if (rememberPassword) {
        await _secureStorage.write(key: _kSavedLoginPassword, value: password);
        await prefs.remove(_kSavedLoginPassword);
      } else {
        await _secureStorage.delete(key: _kSavedLoginPassword);
        await prefs.remove(_kSavedLoginPassword);
      }

      // 5) Conectar WebSocket con el RUC de Arcus
      await socketProv.connect(ruc, colores);

      // 6) Registrar FCM por RUC
      final grupoEconomico = (resp['GRUPO_ECONOMICO'] ?? '').toString().trim();
      if (grupoEconomico.isNotEmpty) {
        sessionProv.setGrupoNombre(grupoEconomico);
      }

      String fcmTokenReal = 'N/A';
      try {
        final fcmToken = await FcmService.instance.ensureRegistered(
          ruc: ruc,
          grupo: grupoEconomico.isNotEmpty
              ? grupoEconomico
              : sessionProv.grupoNombre,
          vistaRuc: false,
        );
        notifProv.setCurrentDeviceToken(fcmToken);
        fcmTokenReal = fcmToken ?? 'N/A';
      } catch (_) {
        // no rompas el flujo si /FCM falla
      }

      // 7) Registrar sesión en el servidor de pánico (con FCM real)
      try {
        final deviceInfo = DeviceInfoPlugin();
        String deviceOS = 'Desconocido';
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceOS = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceOS = 'iOS ${iosInfo.systemVersion}';
        }

        await http
            .post(
              Uri.parse('https://zeus.fiberlux.pe/api/register-session'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'RUC': ruc,
                'Username': uname,
                'grupoEconomico': grupoEconomico.isNotEmpty
                    ? grupoEconomico
                    : 'N/A',
                'fcmToken': fcmTokenReal,
                'appName': 'Fiberlux App',
                'deviceOS': deviceOS,
                'email': email.trim().isEmpty ? 'N/A' : email,
                'isStaff': isStaff,
              }),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // no rompas el flujo si el servidor de pánico falla
      }

      loaderProv.hideLoader();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } on ApiException catch (e) {
      if (mounted) loaderProv.hideLoader();
      setState(
        () => _errorMessage = (e.status == 400)
            ? 'Usuario o contraseña incorrectos'
            : e.toString(),
      );
    } catch (e) {
      if (mounted) loaderProv.hideLoader();
      setState(() => _errorMessage = 'No se pudo iniciar sesión. $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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

            const SizedBox(height: 12),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // texto alineado al tope del logo
              children: [
                SizedBox(
                  height: 100,
                  width: 100,
                  child: Image.asset(
                    'assets/logos/ISO-logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FIBERLUX TECH cuenta con la certificación ISO 27001:2013 en los procesos de Ventas, Operaciones y Postventa, respaldando nuestra excelencia en la prestación de los servicios de Internet dedicado, Trasmisión de datos, Seguridad gestionada, Wifi Gestionado, Telefonía IP, Cloud Server, Data Center.',
                    softWrap: true, // muestra TODO el texto en múltiples líneas
                    overflow:
                        TextOverflow.clip, // nunca sobrepone/“rebasa” la imagen
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9, // legible; ajusta si deseas
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),

            // if (!session.isValidated) ...[
            //   Text(
            //     'O Inicia sesión con',
            //     style: TextStyle(
            //       fontFamily: "Poppins",
            //       color: Colors.black,
            //       fontSize: 14,
            //     ),
            //     textAlign: TextAlign.center,
            //   ),
            //   const SizedBox(height: 16),
            //   Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       // Google
            //       SizedBox(
            //         width: 50,
            //         height: 50,
            //         child: ElevatedButton(
            //           onPressed: () async {
            //             final user = await AuthService().signInWithGoogle();
            //             if (user == null) return;

            //             final emailLower = (user.email ?? '').toLowerCase();
            //             if (emailLower.isEmpty) {
            //               ScaffoldMessenger.of(context).showSnackBar(
            //                 const SnackBar(
            //                   content: Text('No se obtuvo email de Google'),
            //                 ),
            //               );
            //               return;
            //             }

            //             final doc = await FirebaseFirestore.instance
            //                 .collection('users')
            //                 .doc(emailLower)
            //                 .get(const GetOptions(source: Source.server))
            //                 .catchError(
            //                   (_) => FirebaseFirestore.instance
            //                       .collection('users')
            //                       .doc(emailLower)
            //                       .get(const GetOptions(source: Source.cache)),
            //                 );

            //             if (!doc.exists ||
            //                 ((doc.data()?['ruc'] ?? '')
            //                     .toString()
            //                     .trim()
            //                     .isEmpty)) {
            //               ScaffoldMessenger.of(context).showSnackBar(
            //                 const SnackBar(
            //                   content: Text(
            //                     'Tu cuenta no tiene RUC configurado. Contacta a soporte.',
            //                   ),
            //                 ),
            //               );
            //               return;
            //             }

            //             final data = doc.data()!;
            //             final ruc = (data['ruc'] ?? '').toString().trim();

            //             final parts = (user.displayName ?? '').trim().split(
            //               ' ',
            //             );
            //             final nombre = parts.isNotEmpty
            //                 ? parts.first
            //                 : (data['nombre'] ?? '');
            //             final apellido = parts.length > 1
            //                 ? parts.sublist(1).join(' ')
            //                 : (data['apellido'] ?? '');

            //             final sessionProv = Provider.of<SessionProvider>(
            //               context,
            //               listen: false,
            //             );
            //             final socketProv = Provider.of<GraphSocketProvider>(
            //               context,
            //               listen: false,
            //             );

            //             sessionProv.setLogin(
            //               isSocial: true,
            //               nombre: nombre,
            //               apellido: apellido.isEmpty ? null : apellido,
            //               ruc: ruc,
            //               usuario: null,
            //               rol: (data['rol'] ?? 'USUARIO').toString(),
            //               email: emailLower,
            //               photoUrl: user.photoURL,
            //             );

            //             await socketProv.connect(ruc, colores);

            //             if (mounted) {
            //               Navigator.pushReplacement(
            //                 context,
            //                 MaterialPageRoute(
            //                   builder: (_) => const MainScreen(),
            //                 ),
            //               );
            //             }
            //           },

            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: Colors.white,
            //             foregroundColor: Colors.black,
            //             elevation: 2,
            //             shape: const CircleBorder(),
            //             padding: const EdgeInsets.all(12),
            //           ),
            //           child: Image.network(
            //             'https://developers.google.com/identity/images/g-logo.png',
            //             height: 24.0,
            //             width: 24.0,
            //             errorBuilder: (context, error, stackTrace) =>
            //                 const Icon(
            //                   Icons.g_mobiledata,
            //                   size: 24.0,
            //                   color: Colors.blue,
            //                 ),
            //           ),
            //         ),
            //       ),

            //       const SizedBox(width: 20),

            //       // Microsoft (placeholder)
            //       SizedBox(
            //         width: 50,
            //         height: 50,
            //         child: ElevatedButton(
            //           onPressed: () {
            //             ScaffoldMessenger.of(context).showSnackBar(
            //               const SnackBar(
            //                 content: Text(
            //                   'Esta función se encuentra en desarrollo...',
            //                 ),
            //                 duration: Duration(seconds: 2),
            //                 behavior: SnackBarBehavior.floating,
            //               ),
            //             );
            //           },
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: const Color(0xFF2F2F2F),
            //             foregroundColor: Colors.white,
            //             elevation: 2,
            //             shape: const CircleBorder(),
            //             padding: const EdgeInsets.all(12),
            //           ),
            //           child: Image.network(
            //             'https://cdn-icons-png.flaticon.com/512/732/732221.png',
            //             height: 20.0,
            //             width: 20.0,
            //             errorBuilder: (context, error, stackTrace) =>
            //                 const Icon(
            //                   Icons.window,
            //                   size: 20.0,
            //                   color: Colors.white,
            //                 ),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ],
          ],
        ),
      ),
    );
  }
}
