import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';

class GraphSocketProvider extends ChangeNotifier {
  IO.Socket? _socket;
  String? _currentRuc;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;

  // === Estado de conexión ===
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get ruc => _currentRuc;

  // === Datos principales para UI ===
  List<double> valores = [];
  List<String> leyenda = [];
  List<String> _rawColors = [];
  List<Color> colors = [];

  // === Otros campos del payload ===
  Map<String, dynamic> grafica = {};
  Map<String, dynamic> resumen = {};
  Map<String, dynamic> detalle = {}; // soporta el bloque "Detalle" (mapa)
  Map<String, dynamic> acordeon = {};
  dynamic afectados; // puede ser lista/map/número/etc.
  String msg = '';
  String fecha = '';
  String alias = 'APPFiberlux';

  // Eventos auxiliares
  List<String> miembrosSala = const [];
  Map<String, dynamic> extra = const {};

  // Exponer colors crudos si la UI los quiere enviar al backend
  List<String> get rawColors => _rawColors;

  // Helpers
  int get totalServicios => valores.fold<int>(0, (a, b) => a + b.toInt());
  T? resumenField<T>(String k) => (resumen[k] is T) ? resumen[k] as T : null;

  // ========= Helpers de color =========
  String _cleanHex(String input) {
    return input
        .toLowerCase()
        .replaceAll('#', '')
        .replaceAll(RegExp(r'^0x'), '');
  }

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
        return Colors.pink.shade100;
      default:
        return Colors.grey;
    }
  }

  Color _colorForStatusName(String name) {
    final u = name.toUpperCase();
    switch (u) {
      case 'UP':
        return Colors.green;
      case 'DOWN':
        return Colors.red;
      case 'POWER':
        return Colors.orange;
      case 'ROUTER':
        return const Color(0xFF8B4A9C);
      case 'LOST':
        return Colors.purple;
      case 'SUSPENCIONBAJA':
        return Colors.yellow;
      case 'ENLACESNOGPON':
        return Colors.blue;
      case 'ONULOS':
        return Colors.pink;
      case 'OLTLOS':
        return Colors.teal;
      case 'ALARMASACEPTADAS':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // ========= Limpiar Data =========
  void clearData() {
    valores = [];
    leyenda = [];
    colors = [];
    _rawColors = [];
    msg = '';
    fecha = '';
    alias = 'APPFiberlux';
    resumen = {};
    detalle = {};
    acordeon = {};
    afectados = null;
    miembrosSala = const [];
    extra = const {};
    _currentRuc = null;
    notifyListeners();
    debugPrint('🧹 Limpieza completa del GraphSocketProvider');
  }

  // ========= Conexión =========

  void applyPayload(Map<String, dynamic> data) {
    grafica = (data['Grafica'] is Map)
        ? Map<String, dynamic>.from(data['Grafica'])
        : {};
    detalle = (data['Detalle'] is Map)
        ? Map<String, dynamic>.from(data['Detalle'])
        : {};
    acordeon = (data['Acordeon'] is Map)
        ? Map<String, dynamic>.from(data['Acordeon'])
        : {};

    notifyListeners();
  }

  Future<void> connect(String ruc, [List<String> colores = const []]) async {
    _rawColors = List<String>.from(colores);

    if (_isConnected && _currentRuc == ruc) {
      debugPrint('⏭️ Ya conectado al RUC $ruc');
      return;
    }

    _isConnecting = true;
    _currentRuc = ruc;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_socket != null) {
      debugPrint('🔌 Cerrando socket previo');
      _socket!
        ..disconnect()
        ..dispose();
      _socket = null;
    }

    debugPrint('🔄 Conectando WS para RUC: $ruc');

    try {
      _socket = IO.io('http://200.1.179.157:3000', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'reconnection': false,
      });

      _setupSocketListeners(ruc);
      _socket!.connect();
    } catch (e) {
      _isConnecting = false;
      debugPrint('❌ Error al crear socket: $e');
      rethrow;
    }
  }

  void _setupSocketListeners(String ruc) {
    _socket!
      ..on('connect', (_) async {
        debugPrint('✅ WS connected');
        _isConnected = true;
        _isConnecting = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;

        _socket!.emit('joinRoom', {
          'ruc': ruc,
          'alias': 'PRTG',
          'colores': _rawColors,
        });

        notifyListeners();

        await Future.delayed(const Duration(milliseconds: 400));
        if (_isConnected && _socket != null) {
          debugPrint('📊 Solicitando payload inicial para RUC: $ruc');
          _socket!.emit('PedirGrafica', {'ruc': ruc, 'alias': 'PRTG'});
        }
      })
      ..on('miembrosSala', (data) {
        if (data is List) {
          miembrosSala = data.map((e) => e.toString()).toList();
          notifyListeners();
        }
      })
      ..on('grafica', (data) {
        debugPrint('📥 grafica raw: $data');
        _ingestarPayload(data);
      })
      ..on('payload', (data) {
        debugPrint('📥 payload raw: $data');
        _ingestarPayload(data);
      })
      ..on('disconnect', (_) {
        debugPrint('❌ WS disconnected');
        _isConnected = false;
        _isConnecting = false;
        notifyListeners();
      })
      ..on('error', (e) {
        debugPrint('❌ WS error: $e');
        _isConnecting = false;
        notifyListeners();
      });
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
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
      // Si pasaron _rawColors se usan, sino se toma el map por nombre, si no hay ninguno será gris
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

    // si no hubo nada, limpia
    leyenda = [];
    valores = [];
    colors = [];
  }

  // ========= Ingesta del payload =========
  void _ingestarPayload(dynamic data) {
    try {
      // 1) Base: el payload puede venir plano o dentro de "grafica"
      final isMap = data is Map;
      final hasNested = isMap && data['grafica'] is Map;

      final Map<String, dynamic> src = hasNested
          ? Map<String, dynamic>.from(data['grafica'] as Map)
          : isMap
          ? Map<String, dynamic>.from(data as Map)
          : <String, dynamic>{};

      Map<String, dynamic> _pickMap(dynamic v) =>
          v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
      int _toIntSafe(dynamic v) =>
          v is num ? v.toInt() : int.tryParse('${v ?? 0}'.trim()) ?? 0;

      // Secciones crudas
      Map<String, dynamic> graficaSection = _pickMap(
        src['Grafica'] ?? src['grafica'],
      );
      final Map<String, dynamic> detalleSection = _pickMap(
        src['Detalle'] ?? src['detalle'],
      );
      final Map<String, dynamic> acordeonSection = _pickMap(
        src['Acordeon'] ?? src['acordeon'],
      );

      // 2) Normalizar/calc. UP/DOWN
      int? upVal = graficaSection.isNotEmpty
          ? _toIntSafe(
              graficaSection['UP'] ??
                  graficaSection['Up'] ??
                  graficaSection['up'],
            )
          : null;
      int? downVal = graficaSection.isNotEmpty
          ? _toIntSafe(
              graficaSection['DOWN'] ??
                  graficaSection['Down'] ??
                  graficaSection['down'],
            )
          : null;

      // Fallback: UP/DOWN sueltos a nivel raíz
      if (upVal == null || downVal == null) {
        final upAny = src['UP'] ?? src['Up'] ?? src['up'];
        final downAny = src['DOWN'] ?? src['Down'] ?? src['down'];
        if (upAny != null && upVal == null) upVal = _toIntSafe(upAny);
        if (downAny != null && downVal == null) downVal = _toIntSafe(downAny);
      }

      // Fallback: desde Detalle (DOWN + ONULOS + OLTLOS)
      if ((upVal == null && downVal == null) ||
          (upVal == 0 && downVal == 0 && detalleSection.isNotEmpty)) {
        if (detalleSection.isNotEmpty) {
          final up = _toIntSafe(
            detalleSection['UP'] ??
                detalleSection['Up'] ??
                detalleSection['up'],
          );
          final down =
              _toIntSafe(
                detalleSection['DOWN'] ??
                    detalleSection['Down'] ??
                    detalleSection['down'],
              ) +
              _toIntSafe(
                detalleSection['ONULOS'] ??
                    detalleSection['OnuLos'] ??
                    detalleSection['onulos'],
              ) +
              _toIntSafe(
                detalleSection['OLTLOS'] ??
                    detalleSection['OltLos'] ??
                    detalleSection['oltlos'],
              );
          upVal = up;
          downVal = down;
        }
      }

      // Fallback: desde Acordeon (conteo de listas)
      if ((upVal == null && downVal == null) ||
          (upVal == 0 && downVal == 0 && acordeonSection.isNotEmpty)) {
        if (acordeonSection.isNotEmpty) {
          final up = (acordeonSection['UP'] as List?)?.length ?? 0;
          final down =
              ((acordeonSection['DOWN'] as List?)?.length ?? 0) +
              ((acordeonSection['ONULOS'] as List?)?.length ?? 0) +
              ((acordeonSection['OLTLOS'] as List?)?.length ?? 0);
          upVal = up;
          downVal = down;
        }
      }

      // Asignar secciones normalizadas
      graficaSection = {'UP': _toIntSafe(upVal), 'DOWN': _toIntSafe(downVal)};
      grafica = graficaSection;
      detalle = detalleSection;
      acordeon = acordeonSection;

      // Log robusto
      debugPrint(
        '🔥 GRAFICA parsed => UP=${grafica['UP']}, DOWN=${grafica['DOWN']}',
      );

      // 3) Construcción para la UI (agregados/legacy)
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

      // 4) Otros campos
      resumen = _pickMap(src['Resumen'] ?? src['resumen']);
      afectados = src['Afectados'] ?? src['afectados'];
      msg = (src['msg'] ?? src['Msg'] ?? msg).toString();
      fecha = (src['fecha'] ?? src['Fecha'] ?? fecha).toString();
      alias = (src['alias'] ?? src['Alias'] ?? alias).toString();

      const known = {
        'ruc',
        'alias',
        'valores',
        'leyenda',
        'colores',
        'msg',
        'fecha',
        'labels',
        'values',
        'colors',
        'detalle',
        'Detalle',
        'resumen',
        'Resumen',
        'acordeon',
        'Acordeon',
        'afectados',
        'Afectados',
        'grafica',
        'Grafica',
      };
      extra = {
        for (final e in src.entries)
          if (!known.contains(e.key)) e.key: e.value,
      };

      debugPrint(
        '✅ Payload ok: '
        'leyenda=${leyenda.length}, valores=${valores.length}, '
        'Detalle(keys)=${detalle.keys.length}, '
        'Acordeon(keys)=${acordeon.keys.length}, '
        'Afectados=${afectados != null}',
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('💥 Error parseando payload: $e\n$st');
    }
  }

  // ========= Refresh manual =========
  void requestGraphData(String ruc) {
    if (_socket != null && _isConnected) {
      debugPrint('🔄 Solicitar refresh para RUC: $ruc');
      _socket!.emit('PedirGrafica', {'ruc': ruc, 'alias': 'PRTG'});
    } else {
      debugPrint(
        '⚠️ No se puede pedir gráfica: socket=${_socket != null}, connected=$_isConnected',
      );
    }
  }

  // ========= Desconexión =========
  void disconnect() {
    debugPrint('🔌 Desconectando socket manualmente');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;

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
