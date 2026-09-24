class AppConfig {
  /// Список кандидатов для подключения.
  /// Опрашиваются параллельно, используется первый ответивший.
  /// Когда появится второй сервер — добавь его URL в этот список.
  static const List<String> serverUrls = [
    'https://example.com',
    // 'https://<второй-сервер>',  // раскомментировать при появлении
  ];

  static const Duration healthCheckTimeout = Duration(seconds: 3);
  static const Duration requestTimeout = Duration(seconds: 30);
}
