import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

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
          if (error.response?.statusCode == 401) {
            await SecureTokenStorage.deleteToken();
          }
          handler.next(error);
        },
      ),
    );
  }

  Dio get client => _dio;

  // Authentication
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

  Future<Response> getMe() => _dio.get('/api/auth/me');

  // Walk redemption (Cashout)
  Future<Response> redeemWalkSteps(int steps, double amount) =>
      _dio.post('/api/auth/walk/redeem', data: {
        'steps': steps,
        'amount': amount,
      });

  // Wallet and transactions
  Future<Response> getWalletTransactions() =>
      _dio.get('/api/driver/wallet/transactions');

  // Walking leaderboard
  Future<Response> getWalkLeaderboard() =>
      _dio.get('/api/auth/walk/leaderboard');
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
