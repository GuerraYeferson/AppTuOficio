import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ApiResponse {
  final int statusCode;
  final Map<String, dynamic> data;

  ApiResponse(this.statusCode, this.data);

  bool get ok => statusCode >= 200 && statusCode < 300;

  /// Mensaje listo para mostrar al usuario (incluye errores de validación)
  String get message {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return (data['message'] ?? 'Ocurrió un error inesperado').toString();
  }
}

class ApiService {
  static const _tokenKey = 'auth_token';

  // ---------- Token ----------
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ---------- Métodos HTTP ----------
  static Future<ApiResponse> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  static Future<ApiResponse> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  static Future<ApiResponse> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  static Future<ApiResponse> delete(String path, {Map<String, dynamic>? body}) =>
      _send('DELETE', path, body: body);

  // ---------- Núcleo ----------
  static Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: query);
    final token = await getToken();

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      late http.Response res;
      final encoded = body != null ? jsonEncode(body) : null;

      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          res = await http.put(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers, body: encoded);
          break;
        default:
          res = await http.get(uri, headers: headers);
      }

      final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      return ApiResponse(
        res.statusCode,
        decoded is Map<String, dynamic> ? decoded : {'data': decoded},
      );
    } catch (e) {
      return ApiResponse(0, {
        'message': 'No se pudo conectar con el servidor. Revisa tu conexión.',
      });
    }
  }
}