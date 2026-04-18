/// App configuration — centralizes base URL and environment settings.
///
/// Change [environment] to switch between dev / staging / production.
class AppConfig {
  AppConfig._();

  /// Current environment. Change this to switch API targets.
  static const AppEnvironment environment = AppEnvironment.production;

  /// Base URL resolved from the current environment.
  static String get baseUrl => environment.baseUrl;

  /// Request timeout in seconds.
  static const int requestTimeoutSeconds = 30;

  /// Cache TTL for offline data.
  static const Duration cacheTtl = Duration(hours: 24);

  /// Items per page for paginated endpoints.
  static const int pageSize = 20;
}

enum AppEnvironment {
  development(baseUrl: 'http://192.168.1.100/api/mobile'),
  staging(baseUrl: 'https://staging.svss.in/api/mobile'),
  production(baseUrl: 'https://svss.in/api/mobile');

  const AppEnvironment({required this.baseUrl});
  final String baseUrl;
}
