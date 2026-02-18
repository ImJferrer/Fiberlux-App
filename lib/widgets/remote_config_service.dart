import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService i = RemoteConfigService._();

  late final FirebaseRemoteConfig _rc;

  // Defaults seguros
  static const _defaults = <String, dynamic>{
    'show_ai_menu': true,
    'ai_menu_title': 'Encuesta',
    'ai_convai_enabled': true,
    'ai_convai_agent_id': 'agent_3301k6ky6wanfk1apqf5508hnjjh',
    'ai_menu_icon_url': '', // ⬅️ NUEVO
  };

  // Getter cómodo
  String? get aiMenuIconUrl {
    final v = _rc.getString('ai_menu_icon_url').trim();
    return v.isEmpty ? null : v;
  }

  Future<void> init() async {
    _rc = FirebaseRemoteConfig.instance;
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(minutes: 5),
      ),
    );

    await _rc.setDefaults(_defaults);
    await _rc.fetchAndActivate();
  }

  // Getters
  bool get showAiMenu => _rc.getBool('show_ai_menu');
  String get aiMenuTitle => _rc.getString('ai_menu_title').trim().isEmpty
      ? _defaults['ai_menu_title'] as String
      : _rc.getString('ai_menu_title');

  bool get convaiEnabled => _rc.getBool('ai_convai_enabled');
  String get convaiAgentId => _rc.getString('ai_convai_agent_id').trim().isEmpty
      ? _defaults['ai_convai_agent_id'] as String
      : _rc.getString('ai_convai_agent_id');

  Future<void> refresh() async {
    await _rc.fetchAndActivate();
  }
}
