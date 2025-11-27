// providers/SessionProvider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  // ===== Auth Arcus =====
  String? _accessToken;
  String? _refreshToken;
  int? _userId;
  bool? _isStaffFlag;
  bool? _isActiveFlag;

  // 🔔 Estado global de notificaciones sin leer
  bool _hasUnreadNotifications = false;

  bool get hasUnreadNotifications => _hasUnreadNotifications;

  void setHasUnreadNotifications(bool value) {
    if (_hasUnreadNotifications == value) return;
    _hasUnreadNotifications = value;
    notifyListeners();
  }

  // Getters Arcus
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get userId => _userId;
  bool? get isStaffFlag => _isStaffFlag;
  bool? get isActiveFlag => _isActiveFlag;

  // Útil para requests
  Map<String, String> get authHeader =>
      _accessToken == null ? {} : {'Authorization': 'Bearer $_accessToken'};

  // ===== Campos base =====
  bool _isValidated = false;
  String? _nombre;
  String? _apellido; // <-- legado (para backward compatibility)
  String? _ruc;
  String? _usuario; // uid Firebase
  String? _rol;
  String? _email; // no se modifica desde profile
  String? _photoUrl;
  String? _telefono;

  // ===== Nuevos campos de perfil =====
  String? _apellidoPaterno;
  String? _apellidoMaterno;
  String? _displayName;
  DateTime? _fechaNacimiento;

  // ===== Preferencias =====
  bool _preferModernView = true;
  bool _grupoEconomicoOrRuc = false;

  // ===== Grupo empresarial (último detectado) =====
  String? _grupoNombre;

  // ===== Notificaciones =====
  bool? _notiEmail;
  bool? _notiApp;
  bool? _notiWsp;
  bool? _notiVoz;

  // ===== Getters =====
  bool get isValidated => _isValidated;
  String? get nombre => _nombre;
  String? get apellido => _apellido; // legado
  String? get apellidoPaterno => _apellidoPaterno;
  String? get apellidoMaterno => _apellidoMaterno;
  String? get displayName => _displayName;
  DateTime? get fechaNacimiento => _fechaNacimiento;

  String? get ruc => _ruc;
  String? get usuario => _usuario;
  String? get rol => _rol;
  String? get email => _email;
  String? get photoUrl => _photoUrl;
  String? get telefono => _telefono;

  bool get preferModernView => _preferModernView;
  bool get grupoEconomicoOrRuc => _grupoEconomicoOrRuc;

  String? get grupoNombre => _grupoNombre;

  bool? get notiEmail => _notiEmail;
  bool? get notiApp => _notiApp;
  bool? get notiWsp => _notiWsp;
  bool? get notiVoz => _notiVoz;

  SessionProvider(this._prefs) {
    _isValidated = _prefs.getBool('isValidated') ?? false;

    // 🔥 Hidratar auth de Arcus desde SharedPreferences
    _accessToken = _prefs.getString('access_token');
    _refreshToken = _prefs.getString('refresh_token');
    _userId = _prefs.getInt('user_id');
    _isStaffFlag = _prefs.containsKey('is_staff')
        ? _prefs.getBool('is_staff')
        : null;
    _isActiveFlag = _prefs.containsKey('is_active')
        ? _prefs.getBool('is_active')
        : null;

    _nombre = _prefs.getString('nombre');
    _apellido = _prefs.getString('apellido'); // legado
    _apellidoPaterno = _prefs.getString('apellidoPaterno');
    _apellidoMaterno = _prefs.getString('apellidoMaterno');
    _displayName = _prefs.getString('displayName');

    final fechaIso = _prefs.getString('fechaNacimiento');
    if (fechaIso != null && fechaIso.isNotEmpty) {
      try {
        _fechaNacimiento = DateTime.parse(fechaIso);
      } catch (_) {}
    }

    _ruc = _prefs.getString('ruc');
    _usuario = _prefs.getString('usuario');
    _rol = _prefs.getString('rol');
    _email = _prefs.getString('email');
    _photoUrl = _prefs.getString('photoUrl');
    _telefono = _prefs.getString('telefono');

    _preferModernView = _prefs.getBool('preferModernView') ?? true;
    _grupoEconomicoOrRuc = _prefs.getBool('grupoEconomicoOrRuc') ?? false;

    // <- NUEVO: hidratar nombre de grupo
    _grupoNombre = _prefs.getString('grupoNombre');

    _notiEmail = _prefs.containsKey('notiEmail')
        ? _prefs.getBool('notiEmail')
        : null;
    _notiApp = _prefs.containsKey('notiApp') ? _prefs.getBool('notiApp') : null;
    _notiWsp = _prefs.containsKey('notiWsp') ? _prefs.getBool('notiWsp') : null;
    _notiVoz = _prefs.containsKey('notiVoz') ? _prefs.getBool('notiVoz') : null;

    // Migración simple: si existe 'apellido' y no hay 'apellidoPaterno', úsalo.
    if (_apellidoPaterno == null &&
        _apellido != null &&
        _apellido!.isNotEmpty) {
      _apellidoPaterno = _apellido;
      _prefs.setString('apellidoPaterno', _apellidoPaterno!);
    }

    // Si no hay displayName, sugerir uno.
    if ((_displayName == null || _displayName!.isEmpty) && _nombre != null) {
      final apPat = _apellidoPaterno ?? '';
      final dn = [
        _nombre,
        apPat,
      ].where((e) => e != null && e!.trim().isNotEmpty).join(' ').trim();
      if (dn.isNotEmpty) {
        _displayName = dn;
        _prefs.setString('displayName', dn);
      }
    }

    print(
      '🏷️ SessionProvider loaded: '
      'validated=$_isValidated, nombre=$_nombre, email=$_email, photoUrl=$_photoUrl, grupo=$_grupoNombre',
    );
  }

  // 👇 añade este helper dentro de SessionProvider
  String? get _userDocId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final byEmail = _email?.toLowerCase();
    final byUsuario = _usuario?.toLowerCase();
    final candidate = uid ?? byEmail ?? byUsuario;
    if (candidate == null) return null;
    final t = candidate.trim();
    return t.isEmpty ? null : t;
  }

  void setArcusAuth({
    required String access,
    required String refresh,
    required int userId,
    required bool isStaff,
    required bool isActive,
  }) {
    _accessToken = access;
    _refreshToken = refresh;
    _userId = userId;
    _isStaffFlag = isStaff;
    _isActiveFlag = isActive;

    _prefs.setString('access_token', access);
    _prefs.setString('refresh_token', refresh);
    _prefs.setInt('user_id', userId);
    _prefs.setBool('is_staff', isStaff);
    _prefs.setBool('is_active', isActive);

    notifyListeners();
  }

  void updateAccessToken(String access, {String? refresh}) {
    _accessToken = access;
    _prefs.setString('access_token', access);
    if (refresh != null) {
      _refreshToken = refresh;
      _prefs.setString('refresh_token', refresh);
    }
    notifyListeners();
  }

  void clearArcusAuth() {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _isStaffFlag = null;
    _isActiveFlag = null;

    for (final k in [
      'access_token',
      'refresh_token',
      'user_id',
      'is_staff',
      'is_active',
    ]) {
      _prefs.remove(k);
    }
    notifyListeners();
  }

  // ====== Login / Logout ======
  void setLogin({
    required bool isSocial,
    required String nombre,
    String? apellido, // legado
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? displayName,
    DateTime? fechaNacimiento,
    String? ruc,
    String? usuario,
    String? rol,
    String? email,
    String? photoUrl,
    String? telefono,
    bool? notiEmail,
    bool? notiApp,
    bool? notiWsp,
    bool? notiVoz,
  }) {
    _nombre = nombre;
    _apellido = apellido;
    _apellidoPaterno = apellidoPaterno ?? _apellidoPaterno;
    _apellidoMaterno = apellidoMaterno ?? _apellidoMaterno;
    _displayName = displayName ?? _displayName;
    _fechaNacimiento = fechaNacimiento ?? _fechaNacimiento;

    _ruc = ruc;
    _usuario = usuario;
    _rol = rol;
    _email = email;
    _photoUrl = photoUrl;
    _telefono = telefono;

    _notiEmail = notiEmail ?? _notiEmail;
    _notiApp = notiApp ?? _notiApp;
    _notiWsp = notiWsp ?? _notiWsp;
    _notiVoz = notiVoz ?? _notiVoz;

    _isValidated = true;

    _prefs.setBool('isValidated', true);
    _prefs.setString('nombre', nombre);
    if (apellido != null) _prefs.setString('apellido', apellido); // legado
    if (_apellidoPaterno != null)
      _prefs.setString('apellidoPaterno', _apellidoPaterno!);
    if (_apellidoMaterno != null)
      _prefs.setString('apellidoMaterno', _apellidoMaterno!);
    if (_displayName != null) _prefs.setString('displayName', _displayName!);
    if (_fechaNacimiento != null)
      _prefs.setString('fechaNacimiento', _fechaNacimiento!.toIso8601String());

    if (ruc != null) _prefs.setString('ruc', ruc);
    if (usuario != null) _prefs.setString('usuario', usuario);
    if (rol != null) _prefs.setString('rol', rol);
    if (email != null) _prefs.setString('email', email);
    if (photoUrl != null) _prefs.setString('photoUrl', photoUrl);
    if (telefono != null) _prefs.setString('telefono', telefono);

    if (_notiEmail != null) _prefs.setBool('notiEmail', _notiEmail!);
    if (_notiApp != null) _prefs.setBool('notiApp', _notiApp!);
    if (_notiWsp != null) _prefs.setBool('notiWsp', _notiWsp!);
    if (_notiVoz != null) _prefs.setBool('notiVoz', _notiVoz!);

    notifyListeners();
  }

  void setRuc(String? ruc, {bool touchSavedRuc = true}) {
    final v = (ruc ?? '').trim();
    if (v.isEmpty) {
      _ruc = null;
      _prefs.remove('ruc');
      if (touchSavedRuc) _prefs.remove('saved_ruc'); // opcional (auto-login)
    } else {
      _ruc = v;
      _prefs.setString('ruc', v);
      if (touchSavedRuc) _prefs.setString('saved_ruc', v); // opcional
    }
    notifyListeners();
  }

  // ===== NUEVO: setear/limpiar nombre de grupo =====
  void setGrupoNombre(String? nombre) {
    final v = (nombre ?? '').trim();
    if (v.isEmpty) {
      _grupoNombre = null;
      _prefs.remove('grupoNombre');
    } else {
      _grupoNombre = v;
      _prefs.setString('grupoNombre', v);
    }
    notifyListeners();
  }

  void logout() {
    for (final k in [
      'access_token',
      'refresh_token',
      'user_id',
      'is_staff',
      'is_active',
      'isValidated',
      'nombre',
      'apellido', // legado
      'apellidoPaterno',
      'apellidoMaterno',
      'displayName',
      'fechaNacimiento',
      'ruc',
      'usuario',
      'rol',
      'email',
      'photoUrl',
      'telefono',
      'preferModernView',
      'grupoEconomicoOrRuc',
      'grupoNombre', // <- NUEVO
      'notiEmail',
      'notiApp',
      'notiWsp',
      'notiVoz',
    ]) {
      _prefs.remove(k);
    }

    _isValidated = false;
    _nombre = null;
    _apellido = null;
    _apellidoPaterno = null;
    _apellidoMaterno = null;
    _displayName = null;
    _fechaNacimiento = null;

    _ruc = null;
    _usuario = null;
    _rol = null;
    _email = null;
    _photoUrl = null;
    _telefono = null;

    _preferModernView = true;
    _grupoEconomicoOrRuc = false;
    _grupoNombre = null; // <- NUEVO

    _notiEmail = null;
    _notiApp = null;
    _notiWsp = null;
    _notiVoz = null;

    notifyListeners();
  }

  // ====== Hidratar desde Firebase ======
  Future<bool> loadFromFirebaseUser(User fbUser) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fbUser.uid)
          .get();

      final data = snap.data() ?? {};
      String _s(dynamic v) => (v ?? '').toString().trim();
      String? _sN(dynamic v) => (v == null)
          ? null
          : _s(v).isEmpty
          ? null
          : _s(v);

      String? _stringOrNull(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      DateTime? _dtOrNull(dynamic v) {
        if (v == null) return null;
        try {
          if (v is Timestamp) return v.toDate();
          if (v is DateTime) return v;
          if (v is String && v.isNotEmpty) return DateTime.parse(v);
        } catch (_) {}
        return null;
      }

      final ruc = _sN(data['ruc']);
      final nombre =
          _sN(data['nombre']) ?? _sN(fbUser.displayName) ?? 'Usuario';
      final apPat =
          _sN(data['apellidoPaterno']) ??
          _sN(data['apellido']); // fallback al campo legado
      final apMat = _sN(data['apellidoMaterno']);
      final dispName = _sN(data['displayName']);
      final fechaNac = _dtOrNull(data['fechaNacimiento']);
      final rol = _sN(data['rol']);
      final email = _sN(data['email']) ?? _sN(fbUser.email);
      final photo = _sN(data['photoUrl']) ?? _sN(fbUser.photoURL);
      final tel = _sN(data['telefono']);

      final nEmail = data['notiEmail'];
      final nApp = data['notiApp'];
      final nWsp = data['notiWsp'];
      final nVoz = data['notiVoz'];

      setLogin(
        isSocial: false,
        nombre: nombre!,
        apellido: _sN(data['apellido']), // legado
        apellidoPaterno: apPat,
        apellidoMaterno: apMat,
        displayName:
            dispName ?? [nombre, apPat].whereType<String>().join(' ').trim(),
        fechaNacimiento: fechaNac,
        ruc: ruc,
        usuario: fbUser.uid,
        rol: rol,
        email: email,
        photoUrl: photo,
        telefono: tel,
        notiEmail: (nEmail is bool) ? nEmail : null,
        notiApp: (nApp is bool) ? nApp : null,
        notiWsp: (nWsp is bool) ? nWsp : null,
        notiVoz: (nVoz is bool) ? nVoz : null,
      );

      return (ruc != null && ruc.isNotEmpty);
    } catch (e) {
      print('❌ loadFromFirebaseUser error: $e');
      return false;
    }
  }

  // ====== Update Profile (NO cambia email) ======
  Future<void> updateProfile({
    String? nombre,
    String? apellido, // legado
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? displayName,
    DateTime? fechaNacimiento,
    String? telefono,
    String? photoUrl,
    String? rol, // opcional
  }) async {
    // 1) Construir patch
    final patch = <String, dynamic>{};
    if (nombre != null) patch['nombre'] = nombre;
    if (apellido != null) patch['apellido'] = apellido; // legado
    if (apellidoPaterno != null) patch['apellidoPaterno'] = apellidoPaterno;
    if (apellidoMaterno != null) patch['apellidoMaterno'] = apellidoMaterno;
    if (displayName != null) patch['displayName'] = displayName;
    if (fechaNacimiento != null) patch['fechaNacimiento'] = fechaNacimiento;
    if (telefono != null) patch['telefono'] = telefono;
    if (photoUrl != null) patch['photoUrl'] = photoUrl;
    if (rol != null) patch['rol'] = rol;

    if (patch.isEmpty) return;

    // 2) Actualización local (optimista) + persistencia en prefs
    if (nombre != null) {
      _nombre = nombre;
      _prefs.setString('nombre', nombre);
    }
    if (apellido != null) {
      _apellido = apellido;
      _prefs.setString('apellido', apellido);
    }
    if (apellidoPaterno != null) {
      _apellidoPaterno = apellidoPaterno;
      _prefs.setString('apellidoPaterno', apellidoPaterno);
    }
    if (apellidoMaterno != null) {
      _apellidoMaterno = apellidoMaterno;
      _prefs.setString('apellidoMaterno', apellidoMaterno);
    }
    if (displayName != null) {
      _displayName = displayName;
      _prefs.setString('displayName', displayName);
    }
    if (fechaNacimiento != null) {
      _fechaNacimiento = fechaNacimiento;
      _prefs.setString('fechaNacimiento', fechaNacimiento.toIso8601String());
    }
    if (telefono != null) {
      _telefono = telefono;
      _prefs.setString('telefono', telefono);
    }
    if (photoUrl != null) {
      _photoUrl = photoUrl;
      _prefs.setString('photoUrl', photoUrl);
    }
    if (rol != null) {
      _rol = rol;
      _prefs.setString('rol', rol);
    }

    // Notificar para que la UI se refresque de inmediato
    notifyListeners();

    // 3) Parchear Firestore si sabemos en qué doc escribir
    final docId = _userDocId; // ← uid || email || usuario
    if (docId == null) {
      debugPrint('updateProfile: sin docId; se guardó solo localmente.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .set(patch, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateProfile Firestore error: $e');
      // opcional: podrías revertir cambios locales o mostrar un banner
    }
  }

  // ====== Preferencias ======
  void setPreferModernView(bool v) {
    _preferModernView = v;
    _prefs.setBool('preferModernView', v);
    notifyListeners();
  }

  void setGrupoEconomicoOrRuc(bool v) {
    _grupoEconomicoOrRuc = v;
    _prefs.setBool('grupoEconomicoOrRuc', v);
    notifyListeners();
  }

  // ====== Notificaciones (persisten local + Firestore) ======
  Future<void> _patchFirestore(Map<String, dynamic> patch) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || patch.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(patch, SetOptions(merge: true));
  }

  Future<void> setNotiEmail(bool v) async {
    _notiEmail = v;
    _prefs.setBool('notiEmail', v);
    notifyListeners();
    await _patchFirestore({'notiEmail': v});
  }

  Future<void> setNotiApp(bool v) async {
    _notiApp = v;
    _prefs.setBool('notiApp', v);
    notifyListeners();
    await _patchFirestore({'notiApp': v});
  }

  Future<void> setNotiWsp(bool v) async {
    _notiWsp = v;
    _prefs.setBool('notiWsp', v);
    notifyListeners();
    await _patchFirestore({'notiWsp': v});
  }

  Future<void> setNotiVoz(bool v) async {
    _notiVoz = v;
    _prefs.setBool('notiVoz', v);
    notifyListeners();
    await _patchFirestore({'notiVoz': v});
  }
}
