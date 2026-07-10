import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.orbitago.uz',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<Response> checkIdentifier(String identifier) async {
    return _dio.post('/api/auth/check-identifier', data: {
      'identifier': identifier,
    });
  }

  Future<Response> login(String identifier, String password) async {
    return _dio.post('/api/auth/login', data: {
      'identifier': identifier,
      'password': password,
    });
  }

  Future<Response> register(String identifier, String password, String fullName, {String? referredByCode}) async {
    return _dio.post('/api/auth/register', data: {
      'identifier': identifier,
      'password': password,
      'fullName': fullName,
      if (referredByCode != null && referredByCode.isNotEmpty) 'referredByCode': referredByCode,
    });
  }

  Future<Response> getMe() async {
    return _dio.get('/api/auth/me');
  }

  Future<Response> convertCoins(int coins) async {
    return _dio.post('/api/games/runner/convert', data: {
      'coins': coins,
    });
  }

  // --- NEW GAME APIs ---

  Future<Response> updateStats({required String gameType, int? score, int? level}) async {
    return _dio.post('/api/games/stats', data: {
      'gameType': gameType,
      if (score != null) 'score': score,
      if (level != null) 'level': level,
    });
  }

  Future<Response> getLeaderboard(String gameType) async {
    return _dio.get('/api/games/leaderboard', queryParameters: {'gameType': gameType});
  }

  Future<Response> getMissions() async {
    return _dio.get('/api/games/missions');
  }

  Future<Response> claimMission(String missionId) async {
    return _dio.post('/api/games/missions/claim', data: {'missionId': missionId});
  }

  Future<Response> getGarden() async {
    return _dio.get('/api/games/garden');
  }

  Future<Response> waterGarden({int amount = 1}) async {
    return _dio.post('/api/games/garden/water', data: {'amount': amount});
  }

  Future<Response> waterFriendGarden(String friendOrbitaId) async {
    return _dio.post('/api/games/garden/water-friend', data: {'friendOrbitaId': friendOrbitaId});
  }

  Future<Response> getShopItems() async {
    return _dio.get('/api/games/shop');
  }

  Future<Response> buyItem(String itemId) async {
    return _dio.post('/api/games/shop/buy', data: {'itemId': itemId});
  }

  Future<Response> seedData() async {
    return _dio.post('/api/games/dev/seed');
  }

  Future<Response> getCheckInStatus() async {
    return _dio.get('/api/games/check-in');
  }

  Future<Response> claimCheckIn() async {
    return _dio.post('/api/games/check-in/claim');
  }
}
