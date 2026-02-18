import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

class GraphSocketProvider extends ChangeNotifier {
  IO.Socket? _socket;
  String? _currentRuc;
  String? _currentGrupo;
  bool _usingGroup = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  DateTime? _lastPayloadAt;
  int _connectAttemptSerial = 0;
  void Function(String)?
  onGroupResolved; // callback opcional para persistir grupo
  String? _lastGroupPersisted; // evita notificar repetido

  Completer<void>? _connCompleter;
  Map<String, dynamic>? _queuedPedir;

  // Último payload enviado a PedirGrafica (para reloadTickets)
  Map<String, dynamic>? _lastPedirPayload;

  Map<String, dynamic>? _noFibraFromApi;
  String? _lastNoFibraRuc;
  DateTime? _lastNoFibraFetch;
  bool _noFibraFetchInFlight = false;

  // === Estado de conexión ===
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get ruc => _currentRuc;
  String? get grupo => _currentGrupo;
  bool get usingGroup => _usingGroup;
  String? selectedGroupRuc;

  // === Datos de gráfica ===
  List<double> valores = [];
  List<String> leyenda = [];
  List<String> _rawColors = [];
  List<Color> colors = [];
  List<String> get rawColors => _rawColors;

  // === Datos del payload ===
  Map<String, dynamic> grafica = {};
  Map<String, dynamic> resumen = {};
  Map<String, dynamic> detalle = {};
  Map<String, dynamic> acordeon = {};
  dynamic afectados;
  Map<String, dynamic> extra = const {};
  String msg = '';
  String fecha = '';
  String alias = 'APPFiberlux';

  // === Colores por nombre ===
  Map<String, Color> _colorsByName = {};
  Map<String, String> _rawColorMap = {};
  Map<String, String> get rawColorMap => Map.unmodifiable(_rawColorMap);
  String _normKey(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '');
  Color? colorOf(String label) => _colorsByName[_normKey(label)];

  // === Soporte de grupo: lista de RUCs y razones sociales ===
  List<String> _groupRucs = [];
  Map<String, String> _groupRucNombre = {}; // ruc -> razón social

  List<String> get groupRucs => List.unmodifiable(_groupRucs);

  List<Map<String, String>> get rucsRazonesList {
    final out = <Map<String, String>>[];
    if (_groupRucs.isNotEmpty) {
      for (final r in _groupRucs) {
        final nombre = _groupRucNombre[r]?.trim();
        out.add({
          'ruc': r,
          'nombre': (nombre == null || nombre.isEmpty) ? r : nombre,
        });
      }
    } else if (_groupRucNombre.isNotEmpty) {
      _groupRucNombre.forEach((r, n) {
        out.add({'ruc': r, 'nombre': (n.isEmpty) ? r : n});
      });
    }
    out.sort(
      (a, b) =>
          a['nombre']!.toLowerCase().compareTo(b['nombre']!.toLowerCase()),
    );
    return out;
  }

  void clearSelectedGroupRuc() {
    selectedGroupRuc = null;
    notifyListeners();
  }

  String? get currentGroupName {
    final r = resumen;
    final v =
        r['GRUPO_ECONOMICO'] ??
        r['Grupo_Empresarial'] ??
        r['GRUPO'] ??
        r['Grupo'] ??
        r['grupo'] ??
        r['grupo_empresarial'];
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  int get totalServicios => valores.fold<int>(0, (a, b) => a + b.toInt());
  T? resumenField<T>(String k) => (resumen[k] is T) ? resumen[k] as T : null;

  Map<String, dynamic> _asMapDeep(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is List) {
      for (final it in v) {
        final asMap = _asMapDeep(it);
        if (asMap.isNotEmpty) return asMap;
      }
      return <String, dynamic>{};
    }
    if (v is String) {
      final s = v.trim();
      if (s.isNotEmpty && (s.startsWith('{') || s.startsWith('['))) {
        try {
          final dec = jsonDecode(s);
          if (dec is Map) return Map<String, dynamic>.from(dec);
          if (dec is List) {
            for (final it in dec) {
              final asMap = _asMapDeep(it);
              if (asMap.isNotEmpty) return asMap;
            }
          }
        } catch (_) {}
      }
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _asMapIf(dynamic v) {
    final m = _asMapDeep(v);
    return m.isEmpty ? null : m;
  }

  String _short(dynamic data, {int max = 220}) {
    String s;
    try {
      s = data is String ? data : jsonEncode(data);
    } catch (_) {
      s = data.toString();
    }
    s = s.replaceAll('\n', ' ');
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  String? _aliasFallbackFrom(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['RUC'],
      payload['ruc'],
      payload['GRUPO'],
      payload['grupo'],
    ];
    for (final c in candidates) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  void _scheduleCompatRetry({
    required int attemptSerial,
    required Map<String, dynamic> joinParams,
    Map<String, dynamic>? pedirPayload,
  }) {
    Future.delayed(const Duration(seconds: 2), () {
      if (_socket == null || !_isConnected) return;
      if (_connectAttemptSerial != attemptSerial) return;

      final gotPayloadRecently =
          _lastPayloadAt != null &&
          DateTime.now().difference(_lastPayloadAt!) <
              const Duration(seconds: 8);
      if (gotPayloadRecently) return;

      final joinAlias = _aliasFallbackFrom(joinParams);
      if (joinAlias != null &&
          joinAlias != (joinParams['alias']?.toString().trim() ?? '')) {
        final compatJoin = Map<String, dynamic>.from(joinParams)
          ..['alias'] = joinAlias;
        debugPrint(
          '🧪 Sin payload tras conectar. Reintento joinRoom compat: $compatJoin',
        );
        _socket!.emit('joinRoom', compatJoin);
      }

      final p = Map<String, dynamic>.from(
        pedirPayload ?? _lastPedirPayload ?? {},
      );
      if (p.isEmpty) return;
      final pedirAlias = _aliasFallbackFrom(p);
      if (pedirAlias != null &&
          pedirAlias != (p['alias']?.toString().trim() ?? '')) {
        final compatPedir = Map<String, dynamic>.from(p)
          ..['alias'] = pedirAlias;
        debugPrint(
          '🧪 Sin payload tras conectar. Reintento PedirGrafica compat: $compatPedir',
        );
        _socket!.emit('PedirGrafica', compatPedir);
      }
    });
  }

  Map<String, dynamic>? _extractNoFibraFrom(
    List<Map<String, dynamic>> sources,
  ) {
    const keys = [
      'NoFibra',
      'NOFIBRA',
      'noFibra',
      'no_fibra',
      'No_Fibra',
      'NO_FIBRA',
    ];
    for (final m in sources) {
      for (final k in keys) {
        final asMap = _asMapIf(m[k]);
        if (asMap != null && asMap.isNotEmpty) return asMap;
      }
    }
    return null;
  }

  String _roomFromGroup(String g) =>
      g.trim().replaceAll(RegExp(r'\s+'), '_').toUpperCase();

  // ===== Cambiar modo y reconectar automáticamente =====
  Future<void> switchMode({
    required bool useGroup,
    String? groupName, // si no lo pasas, intenta inferirlo del resumen
    String? ruc, // si no lo pasas, usa el actual / sesión
  }) async {
    if (useGroup) {
      final g = (groupName ?? currentGroupName ?? _currentGrupo)
          ?.toString()
          .trim();
      if (g == null || g.isEmpty) {
        debugPrint('⚠️ switchMode → grupo vacío; no reconecto');
        _usingGroup = true;
        notifyListeners();
        return;
      }
      await _connectInternal(ruc: null, grupo: g, colores: _rawColors);
      try {
        await waitUntilConnected();
        // Pedimos el índice/summary del grupo apenas conecte
        await fetchGroupSummary(g);
      } catch (_) {}
    } else {
      final r = (ruc ?? _currentRuc)?.toString().trim();
      if (r == null || r.isEmpty) {
        debugPrint('⚠️ switchMode → RUC vacío; no reconecto');
        _usingGroup = false;
        notifyListeners();
        return;
      }
      await _connectInternal(ruc: r, grupo: null, colores: _rawColors);
      try {
        await waitUntilConnected();
        requestGraphData(r);
      } catch (_) {}
    }
  }

  // ===== fetchGroupSummary ahora infiere grupo si _currentGrupo está vacío =====
  Future<void> fetchGroupSummary([String? forceGrupo]) async {
    String? g = (forceGrupo ?? _currentGrupo)?.toString();
    // 👇 nuevo: si estás en modo grupo pero no hay _currentGrupo, usa el nombre del resumen
    if ((g == null || g.isEmpty) && _usingGroup) {
      final cg = currentGroupName;
      if (cg != null && cg.isNotEmpty) g = cg;
    }
    if (g == null || g.isEmpty) return;

    final payload = {'alias': 'PRTG', 'GRUPO': g, 'ruc': _roomFromGroup(g)};
    if (_socket == null || !_isConnected) {
      _queuedPedir = payload;
      _lastPedirPayload = Map<String, dynamic>.from(payload);
      debugPrint('⏳ No conectado. Encolando índice de grupo: $payload');
      return;
    }
    debugPrint('📬 PedirGrafica (índice grupo): $payload');
    _lastPedirPayload = Map<String, dynamic>.from(payload);
    _socket!.emit('PedirGrafica', payload);
  }

  // ========= Color parsing =========
  String _cleanHex(String input) =>
      input.toLowerCase().replaceAll('#', '').replaceAll(RegExp(r'^0x'), '');

  Color _parseColorString(String raw) {
    final s = raw.trim().toLowerCase();
    final clean = _cleanHex(s);
    if (RegExp(r'^[0-9a-f]{6,8}$').hasMatch(clean)) {
      final hexValue = clean.length == 6 ? 'ff$clean' : clean;
      return Color(int.parse(hexValue, radix: 16));
    }
    switch (s) {
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'purple':
        return Colors.purple;
      case 'yellow':
        return Colors.yellow;
      case 'pink':
        return Colors.pink;
      default:
        final hue = raw.hashCode % 360;
        return HSLColor.fromAHSL(1, hue.toDouble(), .65, .45).toColor();
    }
  }

  // === Contactos fijos (persisten aunque cambies a modo grupo) ===
  final Map<String, dynamic> _contactosFijos = {};
  Map<String, dynamic> get contactosFijos => Map.unmodifiable(_contactosFijos);

  Map<String, dynamic> get resumenConContactos {
    final m = <String, dynamic>{};
    m.addAll(resumen); // lo último recibido del WS
    // Sobrescribe con lo fijo (si hay valor no vacío)
    _contactosFijos.forEach((k, v) {
      if (v != null && v.toString().trim().isNotEmpty) m[k] = v;
    });
    return m;
  }

  void _cachearContactosDesdeResumen(Map<String, dynamic> res) {
    const keys = [
      // Comercial
      'Comercial',
      'comercial',
      'CorreoComercial',
      'correo_comercial',
      'Comercial_Correo',
      'Comercial_Movil',
      'ComercialTelefono',
      'Comercial_Telefono',
      'ComercialCelular',
      // Cobranzas
      'Cobranza',
      'cobranza',
      'CorreoCobranza',
      'cobranza_correo',
      'Cobranza_Correo',
      'Cobranza_Movil',
      'CobranzaTelefono',
      'Cobranza_Telefono',
      'CobranzaCelular',
      // NOC
      'NOC',
      'noc',
      'CorreoNOC',
      'NOC_Correo',
      'noc_correo',
      'NOC_Movil',
      'NOC_Telefono',
      // SOC
      'SOC',
      'soc',
      'CorreoSOC',
      'SOC_Correo',
      'soc_correo',
      'SOC_Movil',
      'SOC_Telefono',
    ];
    for (final k in keys) {
      final v = res[k] ?? res[k.toLowerCase()] ?? res[k.toUpperCase()];
      if (v != null && v.toString().trim().isNotEmpty) {
        _contactosFijos[k] = v;
      }
    }
  }

  // (opcional, por si alguna vez quieres limpiarlos manualmente)
  void clearContactosFijos() => _contactosFijos.clear();

  // ======== COLORES DENTRO DE LOS DETALLES DE SERVICIOS ========

  Color _colorForStatusName(String name) {
    final u = _normKey(name);
    switch (u) {
      case 'UP':
        return Colors.green;
      case 'POWER':
      case 'ENERGIA':
      case 'PE_ENERGIA':
      case 'PEENERGIA':
        return Colors.orange;
      case 'PE_FIBRA':
      case 'PEFIBRA':
      case 'ONULOS':
      case 'ONU_LOS':
      case 'ONULOSALARM':
      case 'OLTLOS':
      case 'OLT_LOS':
      case 'LOST':
        return Colors.indigo;
      case 'EN_ATENCION':
      case 'ENATENCION':
        return Colors.orangeAccent;
      case 'EN_DIAGNOSTICO':
      case 'ENDIAGNOSTICO':
        return Colors.deepPurple;
      case 'DOWN':
      case 'down':
        return Colors.red;
      case 'ROUTER':
        return const Color(0xFF8B4A9C);
      case 'ENLACESNOGPON':
      case 'NOGPON':
        return Colors.blueGrey;
      case 'ALARMASACEPTADAS':
        return Colors.indigo;
      case 'OBS':
        return Colors.cyan;
      default:
        final hue = name.hashCode % 360;
        return HSLColor.fromAHSL(1, hue.toDouble(), .65, .45).toColor();
    }
  }

  // ========= Conectar =========
  Future<void> connect(String ruc, [List<String> colores = const []]) async {
    // ⛔️ No mutar estado aquí. Delega todo a _connectInternal.
    await _connectInternal(ruc: ruc, grupo: null, colores: colores);
    try {
      await waitUntilConnected();
    } catch (_) {}
  }

  Future<void> connectByGroup(
    String grupo, [
    List<String> colores = const [],
  ]) async {
    // ⛔️ No mutar estado aquí. Delega todo a _connectInternal.
    await _connectInternal(ruc: null, grupo: grupo, colores: colores);
    try {
      await waitUntilConnected();
    } catch (_) {}
  }

  Future<void> waitUntilConnected({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_isConnected) return;
    final c = _connCompleter;
    if (c != null) {
      await c.future.timeout(timeout);
    }
  }

  Future<void> _connectInternal({
    String? ruc,
    String? grupo,
    List<String> colores = const [],
  }) async {
    _rawColors = List<String>.from(colores);

    // ---- Snapshot del estado ACTUAL (antes de mutar) ----
    final currentUsingGroup = _usingGroup;
    final currentRuc = _currentRuc;
    final currentGrupo = _currentGrupo;

    // ---- Destino deseado ----
    final wantUsingGroup = (grupo != null && grupo.isNotEmpty);

    // ¿Estoy ya exactamente en ese destino?
    final isSameTarget =
        _isConnected &&
        currentUsingGroup == wantUsingGroup &&
        ((wantUsingGroup && currentGrupo == grupo) ||
            (!wantUsingGroup && currentRuc == ruc));

    if (isSameTarget) {
      debugPrint(
        '⏭️ Ya conectado al mismo destino: '
        '${wantUsingGroup ? "GRUPO=$grupo" : "RUC=$ruc"}',
      );
      // Si había algo encolado, envíalo de todos modos
      if (_queuedPedir != null) {
        _socket?.emit('PedirGrafica', _queuedPedir);
        _queuedPedir = null;
      }
      return;
    }

    // ---- Cambia objetivo y limpia caches de grupo ----
    _usingGroup = wantUsingGroup;
    _currentRuc = ruc;
    _currentGrupo = grupo;
    _groupRucs = [];
    _groupRucNombre = {};
    _queuedPedir = null;
    _lastPedirPayload = null;
    _lastPayloadAt = null;

    // ---- Tumba socket previo (si existe) ----
    if (_socket != null) {
      try {
        _socket!.disconnect();
      } catch (_) {}
      try {
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }

    _isConnected = false;
    _isConnecting = true;
    _connCompleter = Completer<void>();

    debugPrint(
      '🔄 Conectando WS: ${_usingGroup ? "GRUPO=$grupo" : "RUC=$ruc"}',
    );

    try {
      _socket = IO.io('https://zeus.fiberlux.pe', {
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 3,
        'forceNew': true,
        'query': {'alias': 'PRTG'},
      });

      _setupSocketListeners(ruc: ruc, grupo: grupo);
      _socket!.connect();
    } catch (e) {
      _isConnecting = false;
      _connCompleter?.completeError(e);
      debugPrint('❌ Error al crear socket: $e');
      rethrow;
    }
  }

  void _setupSocketListeners({String? ruc, String? grupo}) {
    _socket!
      ..on('connect', (_) async {
        final attemptSerial = ++_connectAttemptSerial;
        debugPrint('✅ WS connected');
        _isConnected = true;
        _isConnecting = false;
        _connCompleter?.complete();

        // 👇 Unirse a la sala correcta (compat: siempre envío 'ruc')
        final joinParams = <String, dynamic>{
          'alias': 'PRTG',
          'colores': _rawColors,
        };
        if (_usingGroup && (grupo != null && grupo.isNotEmpty)) {
          joinParams['GRUPO'] = grupo;
          joinParams['ruc'] = _roomFromGroup(grupo); // <- clave para room
        } else if (!_usingGroup && (ruc != null && ruc.isNotEmpty)) {
          joinParams['RUC'] = ruc;
          joinParams['ruc'] = ruc; // compat
        }
        debugPrint('📤 joinRoom: $joinParams');
        _socket!.emit('joinRoom', joinParams);

        // 🔸 PRIMERA CARGA
        Map<String, dynamic>? firstPedirPayload;
        await Future.delayed(const Duration(milliseconds: 250));
        if (_usingGroup && (grupo != null && grupo.isNotEmpty)) {
          final pedir = {
            'alias': 'PRTG',
            'GRUPO': grupo,
            'ruc': _roomFromGroup(grupo),
          };
          debugPrint('📊 PedirGrafica init (grupo): $pedir');
          firstPedirPayload = Map<String, dynamic>.from(pedir);
          _lastPedirPayload = Map<String, dynamic>.from(pedir);
          _socket!.emit('PedirGrafica', pedir);
        } else if (ruc != null && ruc.isNotEmpty) {
          final pedir = {'alias': 'PRTG', 'RUC': ruc, 'ruc': ruc};
          debugPrint('📊 PedirGrafica init (ruc): $pedir');
          firstPedirPayload = Map<String, dynamic>.from(pedir);
          _lastPedirPayload = Map<String, dynamic>.from(pedir);
          _socket!.emit('PedirGrafica', pedir);
        }

        // Enviar lo encolado (si hubiera)
        if (_queuedPedir != null) {
          await Future.delayed(const Duration(milliseconds: 150));
          debugPrint('⏩ Enviando PedirGrafica encolado: $_queuedPedir');
          _socket!.emit('PedirGrafica', _queuedPedir);
          _lastPedirPayload = Map<String, dynamic>.from(_queuedPedir!);
          _queuedPedir = null;
        }

        _scheduleCompatRetry(
          attemptSerial: attemptSerial,
          joinParams: joinParams,
          pedirPayload: firstPedirPayload,
        );
        notifyListeners();
      })
      ..on('payload', (data) {
        debugPrint('📥 WS event payload: ${_short(data)}');
        _ingestarPayload(data);
      })
      ..on('grafica', (data) {
        debugPrint('📥 WS event grafica: ${_short(data)}');
        _ingestarPayload(data);
      })
      ..on('message', (data) {
        debugPrint('📥 WS event message: ${_short(data)}');
        _ingestarPayload(data);
      })
      ..on('data', (data) {
        debugPrint('📥 WS event data: ${_short(data)}');
        _ingestarPayload(data);
      })
      ..on('response', (data) {
        debugPrint('📥 WS event response: ${_short(data)}');
        _ingestarPayload(data);
      })
      ..on('joinedRoom', (data) {
        debugPrint('📨 joinedRoom: ${_short(data)}');
      })
      ..on('join_error', (e) => debugPrint('⚠️ join_error: ${_short(e)}'))
      ..on('disconnect', (_) {
        _isConnected = false;
        _isConnecting = false;
        _connCompleter = null;
        debugPrint('🔌 WS disconnect');
        notifyListeners();
      })
      ..on('connect_error', (e) {
        _isConnected = false;
        _isConnecting = false;
        _connCompleter?.completeError(e);
        _connCompleter = null;
        debugPrint('⚠️ connect_error: $e');
        notifyListeners();
      })
      ..on('error', (e) => debugPrint('⚠️ socket error: $e'))
      ..on('reconnect_attempt', (n) => debugPrint('… reconnect_attempt $n'))
      ..on('reconnect_error', (e) => debugPrint('⚠️ reconnect_error: $e'))
      ..on('reconnect_failed', (_) => debugPrint('❌ reconnect_failed'));
  }

  // ======= Forzar índice de grupo (si lo necesitas manual) =======

  // Pedir gráfica dentro del grupo actual seleccionando un RUC
  Future<void> requestGraphDataForSelection({
    String? ruc,
    String? grupo,
  }) async {
    final String? g = (grupo ?? _currentGrupo)?.toString();
    final bool inGroup = (g != null && g.isNotEmpty);

    // Payload consistente con el init de grupo:
    // - 'GRUPO': nombre con espacios
    // - 'ruc': room del grupo (compat backend)
    // - 'RUC': filtro opcional dentro del grupo
    final Map<String, dynamic> payload = {
      'alias': 'PRTG',
      if (inGroup) 'GRUPO': g,
      if (!inGroup && ruc != null && ruc.isNotEmpty) ...{
        'RUC': ruc,
        'ruc': ruc, // compat clásica por RUC
      },
      if (inGroup && ruc != null && ruc.isNotEmpty) ...{
        'RUC': ruc, // filtro por RUC dentro del grupo
        'ruc': _roomFromGroup(g), // room del GRUPO, no del RUC
      },
      if (inGroup && (ruc == null || ruc.isEmpty)) ...{
        'ruc': _roomFromGroup(g), // pedir TODOS los RUCs del grupo
      },
    };

    // Estado local para UI/flujo:
    if (inGroup) {
      // selección efímera en sesión (no persistir _currentRuc)
      selectedGroupRuc = (ruc != null && ruc.isNotEmpty) ? ruc : null;
    } else if (ruc != null && ruc.isNotEmpty) {
      // modo RUC clásico
      _currentRuc = ruc;
    }

    if (_socket == null || !_isConnected) {
      _queuedPedir = payload;
      _lastPedirPayload = Map<String, dynamic>.from(payload);
      debugPrint('⏳ No conectado. Encolando PedirGrafica: $payload');
      notifyListeners(); // refleja selectedGroupRuc en la UI
      return;
    }

    debugPrint('🔄 PedirGrafica ${inGroup ? "(grupo)" : "(ruc)"}: $payload');
    _lastPedirPayload = Map<String, dynamic>.from(payload);
    _socket!.emit('PedirGrafica', payload);
    notifyListeners();
  }

  // ========= Limpieza =========
  void clearData() {
    valores = [];
    leyenda = [];
    colors = [];
    _rawColors = [];
    grafica = {};
    detalle = {};
    acordeon = {};
    resumen = {};
    afectados = null;
    extra = const {};
    msg = '';
    fecha = '';
    alias = 'APPFiberlux';
    _groupRucs = [];
    _groupRucNombre = {};
    _currentRuc = null;
    _queuedPedir = null;
    _lastPedirPayload = null;
    _lastPayloadAt = null;
    notifyListeners();
    debugPrint('🧹 Limpieza completa del GraphSocketProvider');
  }

  // ========= Construcción de gráfica =========
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  void _buildChartDataFromSections({
    required Map<String, dynamic> detalleSection,
    required Map<String, dynamic> graficaSection,
    required List<dynamic> labelsLegacy,
    required List<dynamic> valuesLegacy,
  }) {
    if (detalleSection.isNotEmpty) {
      final entries = detalleSection.entries.toList();
      leyenda = entries.map((e) => e.key.toString()).toList();
      valores = entries.map((e) => _toDouble(e.value)).toList();
      colors = leyenda.map(_colorForStatusName).toList();
      return;
    }
    if (graficaSection.isNotEmpty) {
      final entries = graficaSection.entries.toList();
      leyenda = entries.map((e) => e.key.toString()).toList();
      valores = entries.map((e) => _toDouble(e.value)).toList();
      colors = leyenda.map(_colorForStatusName).toList();
      return;
    }
    if (labelsLegacy.isNotEmpty && valuesLegacy.isNotEmpty) {
      leyenda = labelsLegacy.map((e) => e.toString()).toList();
      valores = valuesLegacy.map(_toDouble).toList();
      if (_rawColors.isNotEmpty && _rawColors.length >= leyenda.length) {
        colors = _rawColors
            .take(leyenda.length)
            .map(_parseColorString)
            .toList();
      } else {
        colors = leyenda.map(_colorForStatusName).toList();
      }
      return;
    }
    leyenda = [];
    valores = [];
    colors = [];
  }

  // ========= Ingesta del payload (robusta) =========
  void _ingestarPayload(dynamic data) {
    try {
      int _toIntSafe(dynamic v) =>
          v is num ? v.toInt() : int.tryParse('${v ?? 0}'.trim()) ?? 0;

      final root = _asMapDeep(data);
      if (root.isEmpty) {
        debugPrint(
          'ℹ️ Evento WS ignorado (sin mapa parseable): ${data.runtimeType} ${_short(data)}',
        );
        return;
      }
      _lastPayloadAt = DateTime.now();

      bool looksLikeContainer(Map m) =>
          m.containsKey('Resumen') ||
          m.containsKey('resumen') ||
          m.containsKey('Grafica') ||
          m.containsKey('grafica') ||
          m.containsKey('Detalle') ||
          m.containsKey('detalle') ||
          m.containsKey('Acordeon') ||
          m.containsKey('acordeon');

      Map<String, dynamic> src = root;
      if (!looksLikeContainer(src)) {
        final cg = _asMapDeep(root['grafica']);
        final cG = _asMapDeep(root['Grafica']);
        if (looksLikeContainer(cg)) {
          src = cg;
        } else if (looksLikeContainer(cG)) {
          src = cG;
        }
      }

      final seemsGraphPayload =
          looksLikeContainer(src) ||
          root.containsKey('leyenda') ||
          root.containsKey('valores') ||
          root.containsKey('labels') ||
          root.containsKey('values') ||
          root.containsKey('UP') ||
          root.containsKey('DOWN') ||
          root.containsKey('up') ||
          root.containsKey('down') ||
          src.containsKey('leyenda') ||
          src.containsKey('valores') ||
          src.containsKey('labels') ||
          src.containsKey('values') ||
          src.containsKey('UP') ||
          src.containsKey('DOWN') ||
          src.containsKey('up') ||
          src.containsKey('down');
      if (!seemsGraphPayload) {
        debugPrint('ℹ️ Evento WS sin datos de gráfica, se omite.');
        return;
      }

      // Secciones "clásicas"
      Map<String, dynamic> graficaSection = _asMapDeep(
        src['Grafica'] ?? src['grafica'] ?? root['Grafica'] ?? root['grafica'],
      );
      final Map<String, dynamic> detalleSection = _asMapDeep(
        src['Detalle'] ?? src['detalle'] ?? root['Detalle'] ?? root['detalle'],
      );
      final Map<String, dynamic> acordeonSection = _asMapDeep(
        src['Acordeon'] ??
            src['acordeon'] ??
            root['Acordeon'] ??
            root['acordeon'],
      );

      // Agregados (como en el demo web del grupo)
      final List<dynamic> leyendaAgg =
          (src['leyenda'] as List?) ?? (root['leyenda'] as List?) ?? const [];
      final List<dynamic> valoresAgg =
          (src['valores'] as List?) ?? (root['valores'] as List?) ?? const [];
      final List<dynamic> coloresAgg =
          (src['colores'] as List?) ?? (root['colores'] as List?) ?? const [];

      bool appliedAgg = false;

      // 🟣 PRIORIDAD en modo GRUPO: usar leyenda/valores/colores
      if (_usingGroup && leyendaAgg.isNotEmpty && valoresAgg.isNotEmpty) {
        leyenda = leyendaAgg.map((e) => e.toString()).toList();
        valores = valoresAgg.map(_toDouble).toList();
        if (coloresAgg.isNotEmpty) {
          colors = coloresAgg
              .map((e) => _parseColorString(e.toString()))
              .toList();
        } else {
          colors = leyenda.map(_colorForStatusName).toList();
        }
        // Calcula grafica simple UP/DOWN si no vino
        final upI = leyenda.indexWhere((l) => l.toUpperCase() == 'UP');
        final dnI = leyenda.indexWhere((l) => l.toUpperCase() == 'DOWN');
        final upV = (upI >= 0 && upI < valores.length)
            ? valores[upI].toInt()
            : 0;
        final dnV = (dnI >= 0 && dnI < valores.length)
            ? valores[dnI].toInt()
            : 0;
        graficaSection = {'UP': upV, 'DOWN': dnV};

        appliedAgg = true;
      }

      // Si no aplicamos agregados, usar la lógica tradicional
      if (!appliedAgg) {
        int? upVal, downVal;
        if (graficaSection.isNotEmpty) {
          upVal = _toIntSafe(
            graficaSection['UP'] ??
                graficaSection['Up'] ??
                graficaSection['up'],
          );
          downVal = _toIntSafe(
            graficaSection['DOWN'] ??
                graficaSection['Down'] ??
                graficaSection['down'],
          );
        }
        if (upVal == null && downVal == null) {
          final upAny =
              src['UP'] ??
              src['Up'] ??
              src['up'] ??
              root['UP'] ??
              root['Up'] ??
              root['up'];
          final dnAny =
              src['DOWN'] ??
              src['Down'] ??
              src['down'] ??
              root['DOWN'] ??
              root['Down'] ??
              root['down'];
          if (upAny != null) upVal = _toIntSafe(upAny);
          if (dnAny != null) downVal = _toIntSafe(dnAny);
        }
        if (upVal == null && downVal == null && detalleSection.isNotEmpty) {
          upVal = _toIntSafe(
            detalleSection['UP'] ??
                detalleSection['Up'] ??
                detalleSection['up'],
          );
          downVal = _toIntSafe(
            detalleSection['DOWN'] ??
                detalleSection['Down'] ??
                detalleSection['down'],
          );
        }
        if (upVal == null && downVal == null && acordeonSection.isNotEmpty) {
          upVal = (acordeonSection['UP'] as List?)?.length ?? 0;
          downVal = (acordeonSection['DOWN'] as List?)?.length ?? 0;
        }

        graficaSection = {'UP': _toIntSafe(upVal), 'DOWN': _toIntSafe(downVal)};
        // Construcción de series
        final labelsLegacy =
            (src['labels'] as List?) ?? (src['leyenda'] as List?) ?? const [];
        final valuesLegacy =
            (src['values'] as List?) ?? (src['valores'] as List?) ?? const [];
        _buildChartDataFromSections(
          detalleSection: detalleSection,
          graficaSection: graficaSection,
          labelsLegacy: labelsLegacy,
          valuesLegacy: valuesLegacy,
        );

        // colores desde el payload (ahora también acepta 'colores')
        final Map<String, dynamic> colorMapAny = _asMapDeep(
          src['colorMap'] ??
              src['colormap'] ??
              src['colores_map'] ??
              _asMapDeep(
                src['Grafica']?['colorMap'] ?? src['Grafica']?['colormap'],
              ),
        );
        final List<dynamic> colorsListAny =
            (src['colors'] as List?) ??
            (src['colores'] as List?) ?? // ← nuevo
            (src['colores_list'] as List?) ??
            (src['Grafica']?['colors'] as List?) ??
            const [];

        if (colorMapAny.isNotEmpty) {
          _rawColorMap = {
            for (final e in colorMapAny.entries)
              e.key.toString(): e.value.toString(),
          };
          _colorsByName = {
            for (final e in _rawColorMap.entries)
              _normKey(e.key): _parseColorString(e.value),
          };
          if (leyenda.isNotEmpty) {
            colors = leyenda
                .map(
                  (name) =>
                      _colorsByName[_normKey(name)] ??
                      _colorForStatusName(name),
                )
                .toList();
          }
        } else if (colorsListAny.isNotEmpty && leyenda.isNotEmpty) {
          final n = math.min(leyenda.length, colorsListAny.length);
          colors = List<Color>.generate(
            n,
            (i) => _parseColorString(colorsListAny[i].toString()),
          );
          if (n < leyenda.length) {
            colors.addAll(leyenda.skip(n).map(_colorForStatusName));
          }
        }
      }

      // Guardar secciones y metadatos comunes
      grafica = graficaSection;
      detalle = detalleSection;
      acordeon = acordeonSection;

      final nuevoResumen = _asMapDeep(
        src['Resumen'] ?? src['resumen'] ?? root['Resumen'] ?? root['resumen'],
      );
      resumen = nuevoResumen;

      final gName = currentGroupName;
      if (gName != null && gName.isNotEmpty && gName != _lastGroupPersisted) {
        _lastGroupPersisted = gName;
        try {
          onGroupResolved?.call(gName);
        } catch (_) {}
      }

      _cachearContactosDesdeResumen(nuevoResumen);

      afectados =
          src['Afectados'] ??
          src['afectados'] ??
          root['Afectados'] ??
          root['afectados'];
      msg = (src['msg'] ?? root['msg'] ?? msg).toString();
      fecha =
          (src['fecha'] ??
                  src['Fecha'] ??
                  root['fecha'] ??
                  root['Fecha'] ??
                  fecha)
              .toString();
      alias =
          (src['alias'] ??
                  src['Alias'] ??
                  root['alias'] ??
                  root['Alias'] ??
                  alias)
              .toString();

      // Índice de grupo (RUCs y razones)
      final dynamic maybeRucs = nuevoResumen['RUCs'];
      if (maybeRucs is List) {
        _groupRucs = maybeRucs
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
      final dynamic maybeRazList = nuevoResumen['RUCs_Razones'];
      if (maybeRazList is List) {
        final nuevoMapa = <String, String>{};
        for (final it in maybeRazList) {
          if (it is Map) {
            final r = it['RUC']?.toString();
            final n = (it['Razon_Social'] ?? it['Razon'])?.toString() ?? '';
            if (r != null && r.isNotEmpty) nuevoMapa[r] = n.trim();
          }
        }
        if (nuevoMapa.isNotEmpty) _groupRucNombre = nuevoMapa;
      }
      final dynamic maybeRazMap = nuevoResumen['RUCs_Razones_Map'];
      if (maybeRazMap is Map) {
        final m = Map<String, dynamic>.from(maybeRazMap);
        m.forEach((k, v) {
          final r = k.toString();
          final n = (v?.toString() ?? '').trim();
          if (r.isNotEmpty) _groupRucNombre[r] = n;
        });
      }

      final knownKeys = <String>{
        'Grafica',
        'grafica',
        'Detalle',
        'detalle',
        'Acordeon',
        'acordeon',
        'Resumen',
        'resumen',
        'Afectados',
        'afectados',
        'msg',
        'Msg',
        'fecha',
        'Fecha',
        'alias',
        'Alias',
        'leyenda',
        'valores',
        'colores',
        'colors',
        'labels',
        'values',
        'colorMap',
        'colormap',
        'colores_map',
        'colores_list',
        'colors_list',
        'UP',
        'DOWN',
        'Up',
        'Down',
        'up',
        'down',
        'RUC',
        'ruc',
        'RUCs',
        'RUCs_Razones',
        'RUCs_Razones_Map',
        'GRUPO',
        'Grupo',
        'grupo',
      };
      final extraMap = <String, dynamic>{};
      void addExtraFrom(Map<String, dynamic> m) {
        for (final entry in m.entries) {
          final k = entry.key.toString();
          if (knownKeys.contains(k)) continue;
          extraMap[k] = entry.value;
        }
      }

      addExtraFrom(root);
      addExtraFrom(src);
      addExtraFrom(graficaSection);
      addExtraFrom(detalleSection);
      addExtraFrom(acordeonSection);

      final noFibraFromWs = _extractNoFibraFrom([
        root,
        src,
        graficaSection,
        detalleSection,
        acordeonSection,
        nuevoResumen,
      ]);
      if (noFibraFromWs != null && noFibraFromWs.isNotEmpty) {
        extraMap['NoFibra'] = noFibraFromWs;
      } else if (_noFibraFromApi != null && _noFibraFromApi!.isNotEmpty) {
        extraMap['NoFibra'] = _noFibraFromApi;
      }
      extra = extraMap;

      debugPrint(
        '🧩 Grupo: ${currentGroupName ?? "-"}  RUCs=${_groupRucs.length}  Razones=${_groupRucNombre.length}',
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('💥 Error parseando payload: $e\n$st');
    }
  }

  // ========= Recargar tickets (para PRE recién creado) =========
  Future<void> reloadTickets() async {
    try {
      if (_lastPedirPayload == null) {
        debugPrint(
          '🔁 reloadTickets: no hay _lastPedirPayload, nada que refrescar.',
        );
        return;
      }

      final payload = Map<String, dynamic>.from(_lastPedirPayload!);

      if (_socket == null || !_isConnected) {
        _queuedPedir = payload;
        debugPrint(
          '🔁 reloadTickets: socket no conectado, encolando PedirGrafica: $payload',
        );
        return;
      }

      debugPrint('🔁 reloadTickets → emit PedirGrafica: $payload');
      _socket!.emit('PedirGrafica', payload);
    } catch (e) {
      debugPrint('⚠️ reloadTickets error: $e');
    }
  }

  Future<void> fetchNoFibraForRuc(
    String ruc, {
    Duration minInterval = const Duration(seconds: 30),
  }) async {
    final trimmed = ruc.trim();
    if (trimmed.isEmpty) return;

    final isNewRuc = _lastNoFibraRuc != trimmed;
    if (isNewRuc) {
      _noFibraFromApi = null;
      if (extra.containsKey('NoFibra')) {
        final updated = Map<String, dynamic>.from(extra);
        updated.remove('NoFibra');
        extra = updated;
        notifyListeners();
      }
    }

    final now = DateTime.now();
    if (!isNewRuc &&
        _lastNoFibraFetch != null &&
        now.difference(_lastNoFibraFetch!) < minInterval) {
      return;
    }

    if (_noFibraFetchInFlight) return;
    _noFibraFetchInFlight = true;
    _lastNoFibraRuc = trimmed;
    _lastNoFibraFetch = now;

    try {
      final uri = Uri.parse('https://zeus.fiberlux.pe/App/');
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'RUC': trimmed}),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint('⚠️ /App/ NoFibra HTTP ${resp.statusCode}: ${resp.body}');
        return;
      }

      final raw = utf8.decode(resp.bodyBytes);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      final root = _asMapDeep(decoded);
      final noFibra = _extractNoFibraFrom([
        root,
        _asMapDeep(root['Resumen']),
        _asMapDeep(root['resumen']),
        _asMapDeep(root['Grafica']),
        _asMapDeep(root['grafica']),
      ]);
      if (noFibra == null || noFibra.isEmpty) return;

      _noFibraFromApi = noFibra;
      final updated = Map<String, dynamic>.from(extra);
      updated['NoFibra'] = noFibra;
      extra = updated;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error /App/ NoFibra: $e');
    } finally {
      _noFibraFetchInFlight = false;
    }
  }

  // ========= Refresh manual (por RUC directo) =========
  void requestGraphData(String ruc) {
    final payload = {'RUC': ruc, 'ruc': ruc, 'alias': 'PRTG'};
    if (_socket != null && _isConnected) {
      debugPrint('🔄 Solicitar refresh para RUC: $payload');
      _lastPedirPayload = Map<String, dynamic>.from(payload);
      _socket!.emit('PedirGrafica', payload);
    } else {
      _queuedPedir = payload;
      _lastPedirPayload = Map<String, dynamic>.from(payload);
      debugPrint('⏳ No conectado. Encolando refresh: $payload');
    }
  }

  // ========= Desconexión =========
  void disconnect() {
    debugPrint('🔌 Desconectando socket manualmente');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _connCompleter = null;
    _queuedPedir = null;
    _lastPedirPayload = null;
    _lastPayloadAt = null;
    msg = '';
    _currentRuc = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
