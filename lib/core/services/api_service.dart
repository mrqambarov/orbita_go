import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

// Xavfsiz token storage
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _tokenKey = 'auth_token';

  static Future<String?> getToken() => _storage.read(key: _tokenKey);
  static Future<void> setToken(String token) => _storage.write(key: _tokenKey, value: token);
  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureTokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Token muddati tugagan (401) — tokenni o'chiramiz
          if (error.response?.statusCode == 401) {
            final data = error.response?.data;
            if (data is Map && data['code'] == 'TOKEN_EXPIRED') {
              await SecureTokenStorage.deleteToken();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;

  // AUTH
  Future<Response> checkIdentifier(String identifier) =>
      _dio.post('/api/auth/check-identifier', data: {'identifier': identifier});

  Future<Response> login(String identifier, String password) =>
      _dio.post('/api/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });

  Future<Response> register(
          String identifier, String password, String fullName, {String? referredByCode}) =>
      _dio.post('/api/auth/register', data: {
        'identifier': identifier,
        'password': password,
        'fullName': fullName,
        if (referredByCode != null && referredByCode.isNotEmpty) 'referredByCode': referredByCode,
      });

  Future<Response> sendOtp(String phoneNumber) =>
      _dio.post('/api/auth/otp/send', data: {'phoneNumber': phoneNumber});

  Future<Response> verifyOtp(String phoneNumber, String code, {String? fullName, String? referredByCode}) =>
      _dio.post('/api/auth/otp/verify', data: {
        'phoneNumber': phoneNumber,
        'code': code,
        if (fullName != null) 'fullName': fullName,
        if (referredByCode != null) 'referredByCode': referredByCode,
      });

  Future<Response> getMe() => _dio.get(
        '/api/auth/me',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

  Future<Response> updateProfile(String fullName, String username) =>
      _dio.patch('/api/auth/profile', data: {
        'fullName': fullName,
        'username': username,
      });

  Future<Response> changePassword(String oldPassword, String newPassword) =>
      _dio.patch('/api/auth/change-password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      });

  // ORDERS
  Future<Response> createOrder(Map<String, dynamic> data) =>
      _dio.post('/api/order', data: data);

  Future<Response> searchAddress(String query) =>
      _dio.get('/api/order/geocode', queryParameters: {'query': query});

  Future<Response> reverseGeocode(double lat, double lng) =>
      _dio.get('/api/order/reverse-geocode', queryParameters: {'lat': lat, 'lng': lng});

  /// Foydalanuvchining faol buyurtmasini olish (SEARCHING → IN_TRIP)
  Future<Response> getActiveOrder(String userId) =>
      _dio.get('/api/order/active/$userId');

  Future<Response> getOrderHistory(String userId) =>
      _dio.get('/api/order/user/$userId');

  Future<Response> cancelOrder(String orderId) =>
      _dio.patch('/api/order/$orderId/cancel');

  Future<Response> rateOrder(String orderId, int rating) =>
      _dio.patch('/api/order/$orderId/rate', data: {'rating': rating});

  Future<Response> getOrderMessages(String orderId) =>
      _dio.get('/api/order/$orderId/messages');

  Future<Response> verifyDriver() => _dio.post('/api/auth/driver/verify');
  Future<Response> topUpDriverWallet(double amount) =>
      _dio.post('/api/auth/driver/topup', data: {'amount': amount});
  Future<Response> getWalletTransactions() =>
      _dio.get('/api/driver/wallet/transactions');

  Future<Response> updateDriverProfile({
    String? carModel,
    String? carColor,
    String? carNumber,
  }) =>
      _dio.patch('/api/auth/driver/profile', data: {
        if (carModel != null) 'carModel': carModel,
        if (carColor != null) 'carColor': carColor,
        if (carNumber != null) 'carNumber': carNumber,
      });

  Future<Response> toggleDriverOnline() =>
      _dio.patch('/api/driver/toggle-online');

  Future<Response> updateDriverLocation({
    required double lat,
    required double lng,
    String? orderId,
  }) =>
      _dio.patch('/api/driver/location', data: {
        'lat': lat,
        'lng': lng,
        if (orderId != null) 'orderId': orderId,
      });

  Future<Response> driverArrived(String orderId) =>
      _dio.post('/api/driver/arrived/$orderId');

  Future<Response> startTrip(String orderId) =>
      _dio.post('/api/driver/start/$orderId');

  Future<Response> completeTrip(String orderId) =>
      _dio.post('/api/driver/complete/$orderId');

  Future<Response> getDriverStats() => _dio.get('/api/driver/stats');

  Future<Response> getAvailableOrders() => _dio.get('/api/order/available');

  Future<Response> acceptOrder(String orderId) =>
      _dio.post('/api/driver/accept/$orderId');

  // HEALTH
  Future<Response> checkHealth() => _dio.get('/api/health');

  // REFERRALS
  Future<Response> getReferrals() => _dio.get('/api/auth/referrals');

  // FAVORITES
  Future<Response> getFavoriteAddresses() => _dio.get('/api/order/favorites');

  Future<Response> addFavoriteAddress({
    required String label,
    required String address,
    required double lat,
    required double lng,
    String? iconType,
  }) =>
      _dio.post('/api/order/favorites', data: {
        'label': label,
        'address': address,
        'lat': lat,
        'lng': lng,
        if (iconType != null) 'iconType': iconType,
      });

  Future<Response> deleteFavoriteAddress(String id) =>
      _dio.delete('/api/order/favorites/$id');

  // QUESTS
  Future<Response> getQuests() => _dio.get('/api/order/quests');
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
