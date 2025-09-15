// lib/models/grafica_payload.dart
import 'package:flutter/material.dart';

class GraficaPayload {
  final String? ruc;
  final String? alias;
  final List<double> valores;
  final List<String> leyenda;
  final List<String> coloresRaw;
  final List<Color> colores; // derivado
  final String msg;
  final String fecha;

  // Campos opcionales del tablero
  final Map<String, dynamic> resumen;
  final List<dynamic> detalle;
  final Map<String, dynamic> acordeon;
  final dynamic afectados; // puede ser lista/map/num/bool

  // Campos desconocidos (para no perder nada si el backend agrega claves)
  final Map<String, dynamic> extra;

  const GraficaPayload({
    required this.ruc,
    required this.alias,
    required this.valores,
    required this.leyenda,
    required this.coloresRaw,
    required this.colores,
    required this.msg,
    required this.fecha,
    required this.resumen,
    required this.detalle,
    required this.acordeon,
    required this.afectados,
    required this.extra,
  });

  static String _cleanHex(String input) =>
      input.toLowerCase().replaceAll('#', '').replaceAll(RegExp(r'^0x'), '');

  static Color _parseColorString(String raw) {
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
        return Colors.grey;
    }
  }

  static List<double> _asDoubleList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => (e is num) ? e.toDouble() : double.tryParse('$e') ?? 0.0)
          .toList();
    }
    return const [];
  }

  static List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e?.toString() ?? '').toList();
    }
    return const [];
  }

  factory GraficaPayload.fromSocket(dynamic data) {
    if (data is! Map) {
      return GraficaPayload(
        ruc: null,
        alias: null,
        valores: const [],
        leyenda: const [],
        coloresRaw: const [],
        colores: const [],
        msg: '',
        fecha: '',
        resumen: const {},
        detalle: const [],
        acordeon: const {},
        afectados: null,
        extra: const {},
      );
    }

    // Soporte plano y anidado (por si vuelve el formato nuevo)
    final Map<String, dynamic> raw = Map<String, dynamic>.from(data as Map);
    final bool hasNested = raw['grafica'] is Map;
    final Map<String, dynamic> src = hasNested
        ? Map<String, dynamic>.from(raw['grafica'])
        : raw;

    // Campos conocidos
    final ruc = src['ruc']?.toString();
    final alias = src['alias']?.toString();
    final msg = (src['msg']?.toString() ?? '').trim();
    final fecha = (src['fecha']?.toString() ?? '').trim();

    // Gráfica (plano o anidado)
    final valores = hasNested
        ? _asDoubleList((src['values'] ?? src['valores']))
        : _asDoubleList(src['valores']);

    final leyenda = hasNested
        ? _asStringList((src['labels'] ?? src['leyenda']))
        : _asStringList(src['leyenda']);

    final coloresRaw = hasNested
        ? _asStringList((src['colors'] ?? src['colores']))
        : _asStringList(src['colores']);

    final coloresParsed = coloresRaw.map(_parseColorString).toList();

    // Opcionales
    final resumen = (src['resumen'] is Map)
        ? Map<String, dynamic>.from(src['resumen'])
        : <String, dynamic>{};
    final acordeon = (src['acordeon'] is Map)
        ? Map<String, dynamic>.from(src['acordeon'])
        : <String, dynamic>{};
    final detalle = (src['detalle'] is List)
        ? List<dynamic>.from(src['detalle'])
        : <dynamic>[];
    final afectados = src['afectados']; // no tipamos fuerte a propósito

    // Capturar claves desconocidas
    final known = <String>{
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
      'resumen',
      'detalle',
      'acordeon',
      'afectados',
      'grafica',
    };
    final extra = <String, dynamic>{
      for (final entry in src.entries)
        if (!known.contains(entry.key)) entry.key: entry.value,
    };

    return GraficaPayload(
      ruc: ruc,
      alias: alias,
      valores: valores,
      leyenda: leyenda,
      coloresRaw: coloresRaw,
      colores: coloresParsed,
      msg: msg,
      fecha: fecha,
      resumen: resumen,
      detalle: detalle,
      acordeon: acordeon,
      afectados: afectados,
      extra: extra,
    );
  }
}
