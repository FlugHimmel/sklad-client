import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const _kAccessToken = 'sklad_access_token';
  static const _kRefreshToken = 'sklad_refresh_token';
  static const _kActiveBaseUrl = 'sklad_active_base_url';

  final http.Client _http = http.Client();

  String? _baseUrl;
  String? _accessToken;
  String? _refreshToken;

  String? get baseUrl => _baseUrl;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessToken);
    _refreshToken = prefs.getString(_kRefreshToken);

    final saved = prefs.getString(_kActiveBaseUrl);
    if (saved != null && await _ping(saved)) {
      _baseUrl = saved;
      return;
    }

    final resolved = await _resolveServer();
    _baseUrl = resolved;
    if (resolved != null) {
      await prefs.setString(_kActiveBaseUrl, resolved);
    }
  }

  Future<String?> _resolveServer() async {
    if (AppConfig.serverUrls.isEmpty) return null;

    final futures = AppConfig.serverUrls
        .map((url) async => (await _ping(url)) ? url : null)
        .toList();

    final completer = Completer<String?>();
    int completed = 0;
    for (final f in futures) {
      f.then((url) {
        if (url != null && !completer.isCompleted) {
          completer.complete(url);
        }
        completed++;
        if (completed == futures.length && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }
    return completer.future;
  }

  Future<bool> _ping(String baseUrl) async {
    try {
      final resp = await _http
          .get(Uri.parse('$baseUrl/api/health/'))
          .timeout(AppConfig.healthCheckTimeout);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _accessToken = access;
    _refreshToken = refresh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, access);
    await prefs.setString(_kRefreshToken, refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
  }

  Future<bool> _tryRefresh() async {
    if (_refreshToken == null || _baseUrl == null) return false;
    try {
      final resp = await _http
          .post(
            Uri.parse('$_baseUrl/api/auth/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': _refreshToken}),
          )
          .timeout(AppConfig.requestTimeout);
      if (resp.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final newAccess = data['access'] as String?;
      if (newAccess == null) return false;
      _accessToken = newAccess;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAccessToken, newAccess);
      final newRefresh = data['refresh'] as String?;
      if (newRefresh != null) {
        _refreshToken = newRefresh;
        await prefs.setString(_kRefreshToken, newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) =>
      _request('POST', path, body: body, query: query);

  Future<dynamic> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool retry = true,
  }) async {
    if (_baseUrl == null) {
      throw ApiException(0, 'Нет доступного сервера');
    }

    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    final http.Response resp;
    try {
      switch (method) {
        case 'GET':
          resp = await _http
              .get(uri, headers: headers)
              .timeout(AppConfig.requestTimeout);
          break;
        case 'POST':
          resp = await _http
              .post(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(AppConfig.requestTimeout);
          break;
        case 'PUT':
          resp = await _http
              .put(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(AppConfig.requestTimeout);
          break;
        case 'PATCH':
          resp = await _http
              .patch(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(AppConfig.requestTimeout);
          break;
        case 'DELETE':
          resp = await _http
              .delete(uri, headers: headers)
              .timeout(AppConfig.requestTimeout);
          break;
        default:
          throw ApiException(0, 'Unsupported method: $method');
      }
    } on TimeoutException {
      throw ApiException(0, 'Таймаут запроса');
    } catch (e) {
      throw ApiException(0, 'Ошибка сети: $e');
    }

    if (resp.statusCode == 401 && retry && _refreshToken != null) {
      final ok = await _tryRefresh();
      if (ok) {
        return _request(method, path, body: body, query: query, retry: false);
      }
      await clearTokens();
      throw ApiException(401, 'Сессия истекла, войдите заново');
    }

    if (resp.body.isEmpty) {
      if (resp.statusCode >= 200 && resp.statusCode < 300) return null;
      throw ApiException(resp.statusCode, 'Пустой ответ (${resp.statusCode})');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    } catch (_) {
      decoded = resp.body;
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return decoded;
    }

    String message = 'HTTP ${resp.statusCode}';
    if (decoded is Map) {
      if (decoded['detail'] != null) {
        message = decoded['detail'].toString();
      } else if (decoded['error'] != null) {
        message = decoded['error'].toString();
      } else if (decoded.isNotEmpty) {
        message = decoded.values.first.toString();
      }
    }
    throw ApiException(resp.statusCode, message);
  }

  /// Скачивание бинарных данных (PDF и т.п.) с тем же JWT-циклом.
  Future<List<int>> getBytes(String path) async {
    if (_baseUrl == null) {
      throw ApiException(0, 'Нет доступного сервера');
    }
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{};
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    final resp = await _http
        .get(uri, headers: headers)
        .timeout(AppConfig.requestTimeout);
    if (resp.statusCode == 401 && _refreshToken != null) {
      if (await _tryRefresh()) return getBytes(path);
      await clearTokens();
      throw ApiException(401, 'Сессия истекла');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.bodyBytes;
    }
    throw ApiException(resp.statusCode, 'HTTP ${resp.statusCode}');
  }

  /// POST, возвращающий бинарные данные (PDF пачки этикеток).
  Future<List<int>> postBytes(String path, {Object? body}) async {
    if (_baseUrl == null) {
      throw ApiException(0, 'Нет доступного сервера');
    }
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    final resp = await _http
        .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(AppConfig.requestTimeout);
    if (resp.statusCode == 401 && _refreshToken != null) {
      if (await _tryRefresh()) return postBytes(path, body: body);
      await clearTokens();
      throw ApiException(401, 'Сессия истекла');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return resp.bodyBytes;
    }
    String msg = 'HTTP ${resp.statusCode}';
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map && decoded['error'] != null) {
        msg = decoded['error'].toString();
      }
    } catch (_) {}
    throw ApiException(resp.statusCode, msg);
  }
}
