class AppConfig {
  // Standalone App Configuration pointing to unified Cloudflare Tunnel
  static const String baseUrl = 'https://api.orbitago.uz';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static const String appName = 'Orbita Walk';
  static const String appVersion = '1.0.0';
}
