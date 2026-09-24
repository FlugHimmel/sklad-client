import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/data_watcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkladApp());
}

class SkladApp extends StatefulWidget {
  const SkladApp({super.key});

  @override
  State<SkladApp> createState() => _SkladAppState();
}

class _SkladAppState extends State<SkladApp> {
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final DataWatcher _dataWatcher;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _authService = AuthService(_apiClient);
    _dataWatcher = DataWatcher(_apiClient);
    _authService.addListener(_onAuthChanged);
    // Если сессия уже жива на момент старта — запускаем polling сразу.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAuthChanged());
  }

  void _onAuthChanged() {
    if (_authService.isAuthenticated && !_dataWatcher.isRunning) {
      _dataWatcher.start();
    } else if (!_authService.isAuthenticated && _dataWatcher.isRunning) {
      _dataWatcher.stop();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _dataWatcher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        ChangeNotifierProvider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<DataWatcher>.value(value: _dataWatcher),
      ],
      child: MaterialApp(
        title: 'Складской учёт',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
