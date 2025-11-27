// lib/services/grupo_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ResumenGrupo {
  final String? ruc;
  final String? razonSocial;
  final String? comercial;
  final String? correoComercial;
  final String? comercialMovil;
  final String? grupoEconomico;
  final String? categoria;
  final String? cobranza;

  ResumenGrupo({
    this.ruc,
    this.razonSocial,
    this.comercial,
    this.correoComercial,
    this.comercialMovil,
    this.grupoEconomico,
    this.categoria,
    this.cobranza,
  });

  factory ResumenGrupo.fromJson(Map<String, dynamic> j) => ResumenGrupo(
    ruc: j['RUC']?.toString(),
    razonSocial: j['Razon_Social']?.toString(),
    comercial: j['Comercial']?.toString(),
    correoComercial: j['CorreoComercial']?.toString(),
    comercialMovil: j['Comercial_Movil']?.toString(),
    grupoEconomico: j['GRUPO_ECONOMICO']?.toString(),
    categoria: j['categoria']?.toString(),
    cobranza: j['Cobranza']?.toString(),
  );
}

class GrupoApi {
  static final Uri _url = Uri.parse('http://200.1.179.157:3000/App/');

  /// Llama a /App/ con {"GRUPO": "<nombre exacto>"}
  static Future<ResumenGrupo> fetchResumen(String grupo) async {
    final body = jsonEncode({'GRUPO': grupo.trim()});
    final resp = await http
        .post(
          _url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    // Asegura UTF-8 (acentos como “COMPAÑÍA” bien decodificados)
    final raw = utf8.decode(resp.bodyBytes);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final resumen = (json['Resumen'] ?? {}) as Map<String, dynamic>;
    if (resumen.isEmpty) {
      throw Exception('La respuesta no trae "Resumen".');
    }
    return ResumenGrupo.fromJson(resumen);
  }
}
