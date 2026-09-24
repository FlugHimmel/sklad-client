import 'package:flutter/foundation.dart';

import 'api_client.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _api;
  AuthService(this._api);

  Map<String, dynamic>? _user;
  bool _initializing = true;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get initializing => _initializing;
  String? get error => _error;

  Future<void> bootstrap() async {
    _initializing = true;
    notifyListeners();

    await _api.init();

    if (_api.isAuthenticated && _api.baseUrl != null) {
      try {
        final me = await _api.get('/api/auth/me/');
        _user = me as Map<String, dynamic>;
      } catch (_) {
        _user = null;
      }
    }

    _initializing = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    notifyListeners();
    try {
      final resp = await _api.post(
        '/api/auth/login/',
        body: {'username': username, 'password': password},
      );
      final data = resp as Map<String, dynamic>;
      await _api.saveTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
      _user = data['user'] as Map<String, dynamic>?;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Неизвестная ошибка: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearTokens();
    _user = null;
    notifyListeners();
  }
}
