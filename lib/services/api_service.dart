import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nox_data_model.dart';

class ApiService {
  static const String baseUrl = 'http://200.1.179.157:3000';

  static Future<NoxDataModel> fetchNoxData(String ruc) async {
    final response = await http.post(
      Uri.parse('$baseUrl/NOX'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'RUC': ruc}),
    );

    if (response.statusCode == 200) {
      return NoxDataModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  //  Método para validación de cuenta
  static Future<http.Response> verificarCuenta(
    String correo,
    String ruc,
  ) async {
    final url = Uri.parse('http://200.1.179.157:3000/MyFLX');
    return await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"Correo": correo, "RUC": ruc}),
    );
  }
}
