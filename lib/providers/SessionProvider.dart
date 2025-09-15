// providers/SessionProvider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  bool _isValidated = false;
  String? _nombre;
  String? _apellido;
  String? _ruc;
  String? _usuario; // aquí guardaremos el uid de Firebase
  String? _rol;
  String? _email;
  String? _photoUrl;

  bool get isValidated => _isValidated;
  String? get nombre => _nombre;
  String? get apellido => _apellido;
  String? get ruc => _ruc;
  String? get usuario => _usuario;
  String? get rol => _rol;
  String? get email => _email;
  String? get photoUrl => _photoUrl;

  SessionProvider(this._prefs) {
    _isValidated = _prefs.getBool('isValidated') ?? false;
    _nombre = _prefs.getString('nombre');
    _apellido = _prefs.getString('apellido');
    _ruc = _prefs.getString('ruc');
    _usuario = _prefs.getString('usuario');
    _rol = _prefs.getString('rol');
    _email = _prefs.getString('email');
    _photoUrl = _prefs.getString('photoUrl');

    print(
      '🏷️ SessionProvider loaded: validated=$_isValidated, nombre=$_nombre, email=$_email, photoUrl=$_photoUrl',
    );
  }

  void setLogin({
    required bool isSocial,
    required String nombre,
    String? apellido,
    String? ruc,
    String? usuario,
    String? rol,
    String? email,
    String? photoUrl,
  }) {
    _nombre = nombre;
    _apellido = apellido;
    _ruc = ruc;
    _usuario = usuario;
    _rol = rol;
    _email = email;
    _photoUrl = photoUrl;
    _isValidated = true;

    _prefs.setBool('isValidated', true);
    _prefs.setString('nombre', nombre);
    if (apellido != null) _prefs.setString('apellido', apellido);
    if (ruc != null) _prefs.setString('ruc', ruc);
    if (usuario != null) _prefs.setString('usuario', usuario);
    if (rol != null) _prefs.setString('rol', rol);
    if (email != null) _prefs.setString('email', email);
    if (photoUrl != null) _prefs.setString('photoUrl', photoUrl);

    notifyListeners();
  }

  void logout() {
    _prefs.remove('isValidated');
    _prefs.remove('nombre');
    _prefs.remove('apellido');
    _prefs.remove('ruc');
    _prefs.remove('usuario');
    _prefs.remove('rol');
    _prefs.remove('email');
    _prefs.remove('photoUrl');

    _isValidated = false;
    _nombre = null;
    _apellido = null;
    _ruc = null;
    _usuario = null;
    _rol = null;
    _email = null;
    _photoUrl = null;

    notifyListeners();
  }

  // 👇 NUEVO: hidratar sesión (incluye RUC) desde Firestore /users/{uid}
  Future<bool> loadFromFirebaseUser(User fbUser) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fbUser.uid)
          .get();

      final data = snap.data() ?? {};
      String _s(dynamic v) => (v ?? '').toString().trim();
      final ruc = _s(data['ruc']);

      setLogin(
        isSocial: false,
        nombre: _s(data['nombre']).isNotEmpty
            ? _s(data['nombre'])
            : (_s(fbUser.displayName).isNotEmpty
                  ? _s(fbUser.displayName)
                  : 'Usuario'),
        apellido: _s(data['apellido']).isNotEmpty ? _s(data['apellido']) : null,
        ruc: ruc.isNotEmpty ? ruc : null,
        usuario: fbUser.uid, // guardamos uid en "usuario"
        rol: _s(data['rol']).isNotEmpty ? _s(data['rol']) : null,
        email: _s(data['email']).isNotEmpty
            ? _s(data['email'])
            : _s(fbUser.email),
        photoUrl: _s(data['photoUrl']).isNotEmpty
            ? _s(data['photoUrl'])
            : _s(fbUser.photoURL),
      );

      return ruc.isNotEmpty; // true si el usuario tiene RUC en Firestore
    } catch (e) {
      print('❌ loadFromFirebaseUser error: $e');
      return false;
    }
  }
}
