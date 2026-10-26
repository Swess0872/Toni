import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Server base URL. Web builds talk to the origin they were served from;
/// mobile builds default to production. Override with --dart-define=API_URL=…
String apiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kIsWeb) return Uri.base.origin;
  return 'https://toni.techstein.ch';
}

class ApiException implements Exception {
  ApiException(this.message, [this.status = 0]);
  final String message;
  final int status;

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Thin JSON client. All reads and writes of the app go through here,
/// so the backend can be swapped without touching the UI.
class ApiClient {
  ApiClient(this.baseUrl, {http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? token;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl/api$path'));
    req.headers['Accept'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req));
    } catch (_) {
      throw ApiException('Keine Verbindung zum Server.');
    }

    final text = utf8.decode(res.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (res.statusCode >= 400) {
      final msg = json is Map && json['error'] is String
          ? json['error'] as String
          : switch (res.statusCode) {
              401 => 'Bitte melde dich an.',
              403 => 'Dafür fehlen dir die Rechte.',
              429 => 'Zu viele Versuche — bitte kurz warten.',
              _ => 'Unerwarteter Fehler (${res.statusCode}).',
            };
      throw ApiException(msg, res.statusCode);
    }
    return json;
  }
}
