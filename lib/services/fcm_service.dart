import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_services.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _kLastTokenKeyPrefix = 'fcm_last_token_';

  StreamSubscription<String>? _refreshSub;

  // Estado actual (último login)
  String? _currentRuc;
  String? _currentGrupo;
  bool _currentVistaRuc = false;

  Future<String?> _getTokenRespectingPermissions() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();

    if ((Platform.isIOS || Platform.isMacOS) &&
        settings.authorizationStatus == AuthorizationStatus.notDetermined) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return FirebaseMessaging.instance.getToken();
  }

  /// Registra token FCM para el RUC y se suscribe a onTokenRefresh.
  Future<void> ensureRegistered({
    required String ruc,
    String? grupo,
    bool vistaRuc = false,
  }) async {
    final token = await _getTokenRespectingPermissions();
    if (token == null || token.isEmpty) return;

    // Actualizamos el "contexto" actual de FCM
    _currentRuc = ruc;
    _currentGrupo = grupo;
    _currentVistaRuc = vistaRuc;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_kLastTokenKeyPrefix$ruc';
    final last = prefs.getString(key);

    // 🔁 Solo evitamos repetir si YA registramos EXACTAMENTE (ruc, token)
    if (last != token) {
      try {
        await ApiService.sendFcmRegistration(
          ruc: ruc,
          tokenFcm: token,
          grupo: grupo,
          vistaRuc: vistaRuc,
        );
        await prefs.setString(key, token);
      } catch (_) {
        // No rompemos el login si /FCM falla
      }
    }

    // 🔄 Refrescamos siempre el listener con el RUC actual
    await _refreshSub?.cancel();
    _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      final currentRuc = _currentRuc;
      if (currentRuc == null || newToken.isEmpty) return;

      try {
        await ApiService.sendFcmRegistration(
          ruc: currentRuc,
          tokenFcm: newToken,
          grupo: _currentGrupo,
          vistaRuc: _currentVistaRuc,
        );

        final p = await SharedPreferences.getInstance();
        final k = '$_kLastTokenKeyPrefix$currentRuc';
        await p.setString(k, newToken);
      } catch (_) {}
    });
  }

  void dispose() {
    _refreshSub?.cancel();
    _refreshSub = null;
  }
}
