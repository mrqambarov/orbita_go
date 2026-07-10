class AppConfig {
  // ─── Backend URL ───────────────────────────────────────────────────
  // Haqiqiy qurilmada har doim api.orbitago.uz tunnel orqali ishlaydi.
  // Bu orqali Wi-Fi IP ni sozlash shart emas, har qanday telefonda ishlaydi!
  static const String _prodUrl = 'https://api.orbitago.uz';

  static String get baseUrl => _prodUrl;
  static String get socketUrl => _prodUrl;

  // Yandex Maps
  static const String yandexApiKey = 'YOUR_YANDEX_MAPKIT_API_KEY';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  // App info
  static const String appName = 'Orbita Go';
  static const String appVersion = '1.0.0';
}
