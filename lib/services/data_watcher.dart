import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Опрашивает /api/version/ раз в 10 секунд.
/// Если метка изменилась — выставляет isStale=true, экраны показывают плашку.
class DataWatcher extends ChangeNotifier {
  final ApiClient _api;
  DataWatcher(this._api);

  static const _interval = Duration(seconds: 10);

  Timer? _timer;
  String? _lastMarker;
  bool _isStale = false;
  bool _autoRefresh = true;  // по умолчанию авто включено
  bool _running = false;
  bool _suppressNextMismatch = false;
  DateTime? _lastCheck;
  bool _online = true;

  bool get isStale => _isStale;
  bool get autoRefresh => _autoRefresh;
  bool get isRunning => _running;
  DateTime? get lastCheck => _lastCheck;
  bool get online => _online;

  void setAutoRefresh(bool v) {
    if (_autoRefresh == v) return;
    _autoRefresh = v;
    notifyListeners();
  }

  /// Вызывается экраном после собственной перезагрузки данных.
  void markFresh() {
    _isStale = false;
    notifyListeners();
  }

  /// Вызывается экраном после собственного действия (создание тары и т.п.),
  /// чтобы следующий опрос не показал пользователю «устарело» из-за его же
  /// изменения.
  void suppressNextMismatch() {
    _suppressNextMismatch = true;
  }

  void start() {
    if (_running) return;
    _running = true;
    // сразу зафиксировать текущий маркер, чтобы не сработать на первом тике
    _tick();
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (!_api.isAuthenticated || _api.baseUrl == null) return;
    try {
      final resp = await _api.get('/api/version/');
      final marker = (resp as Map<String, dynamic>)['marker'] as String?;
      if (marker == null) return;
      _online = true;
      _lastCheck = DateTime.now();
      if (_lastMarker == null) {
        _lastMarker = marker;
      } else if (marker != _lastMarker) {
        _lastMarker = marker;
        if (_suppressNextMismatch) {
          _suppressNextMismatch = false;
          _isStale = false;
        } else {
          _isStale = true;
        }
      } else {
        _suppressNextMismatch = false;
      }
      notifyListeners();
    } catch (_) {
      _online = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
