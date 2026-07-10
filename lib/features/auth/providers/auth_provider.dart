import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/models/models.dart';
import '../../../core/localization/translations.dart';

// Auth holati
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isIdentifierChecked;
  final bool identifierExists;
  final String? identifier;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isIdentifierChecked = false,
    this.identifierExists = false,
    this.identifier,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    bool? isIdentifierChecked,
    bool? identifierExists,
    String? identifier,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      isIdentifierChecked: isIdentifierChecked ?? this.isIdentifierChecked,
      identifierExists: identifierExists ?? this.identifierExists,
      identifier: identifier ?? this.identifier,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final Ref _ref;

  AuthNotifier(this._api, this._ref) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await SecureTokenStorage.getToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final res = await _api.getMe();
      if (res.data['success'] == true) {
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        // Role asosida driver modeni avtomatik o'rnatish
        _syncDriverMode(user);
      } else {
        await SecureTokenStorage.deleteToken();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      // Network xatosi bo'lsa token O'CHIRMAYMIZ — cached holatda qolsin
      debugPrint('_checkAuth network error: $e');
      // Token bor lekin server javob bermadi — unauthenticated sifatida ko'rsatamiz
      // lekin tokenni saqlab qolamiz (keyingi urinishda qayta tekshiradi)
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  void _syncDriverMode(UserModel user) {
    try {
      final isCurrentlyDriver = _ref.read(driverModeProvider);
      
      // Agar foydalanuvchi haydovchi bo'lmasa, driver rejimidan chiqaramiz.
      // Agar u haydovchi bo'lsa, faqatgina ilova allaqachon driver rejimida boshlangan bo'lsa (Driver App) driver rejimida qoladi.
      // Mijoz ilovasida esa (driverModeProvider = false bo'lgani uchun) u avtomatik ravishda driver rejimiga o'tib ketmaydi.
      if (!user.isDriver) {
        _ref.read(driverModeProvider.notifier).state = false;
      }
      
      final activeMode = _ref.read(driverModeProvider);
      _ref.read(socketServiceProvider).connect(user.id, isDriver: activeMode);
    } catch (_) {}
  }

  Future<bool> checkIdentifier(String identifier) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final res = await _api.checkIdentifier(identifier);
      if (res.data['success'] == true) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isIdentifierChecked: true,
          identifierExists: res.data['exists'] == true,
          identifier: identifier,
        );
        return true;
      }
      state = state.copyWith(status: AuthStatus.error, error: 'Xatolik yuz berdi');
      return false;
    } catch (e) {
      debugPrint('CheckIdentifier API error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Serverga ulanishda xatolik. Internet aloqasini tekshiring.',
      );
      return false;
    }
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final res = await _api.login(identifier, password);
      if (res.data['success'] == true) {
        final token = res.data['token'];
        await SecureTokenStorage.setToken(token);
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isIdentifierChecked: false,
        );
        _syncDriverMode(user);
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Xatolik',
      );
      return false;
    } catch (e) {
      debugPrint('Login API error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Serverga ulanishda xatolik. Internet aloqasini tekshiring.',
      );
      return false;
    }
  }

  Future<bool> register(String identifier, String password, String fullName, {String? referredByCode}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final res = await _api.register(identifier, password, fullName, referredByCode: referredByCode);
      if (res.data['success'] == true) {
        final token = res.data['token'];
        await SecureTokenStorage.setToken(token);
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isIdentifierChecked: false,
        );
        _syncDriverMode(user);
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Xatolik',
      );
      return false;
    } catch (e) {
      debugPrint('Register API error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Serverga ulanishda xatolik. Internet aloqasini tekshiring.',
      );
      return false;
    }
  }

  void reset() {
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      isIdentifierChecked: false,
      identifierExists: false,
      identifier: null,
      clearError: true,
    );
  }

  Future<void> logout() async {
    await SecureTokenStorage.deleteToken();
    _ref.read(driverModeProvider.notifier).state = false;
    _ref.read(socketServiceProvider).disconnect();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<bool> updateProfile(String fullName, String username) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final res = await _api.updateProfile(fullName, username);
      if (res.data['success'] == true) {
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Xatolik',
      );
      return false;
    } catch (e) {
      debugPrint('UpdateProfile API error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Serverga ulanishda xatolik. Internetni tekshiring.',
      );
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      final res = await _api.getMe();
      if (res.data['success'] == true) {
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(user: user);
        _syncDriverMode(user);
      }
    } catch (_) {}
  }

  Future<bool> verifyDriver() async {
    try {
      final res = await _api.verifyDriver();
      if (res.data['success'] == true) {
        await refreshUser();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> topUpDriverWallet(double amount) async {
    try {
      final res = await _api.topUpDriverWallet(amount);
      if (res.data['success'] == true) {
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(user: user);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final res = await _api.changePassword(oldPassword, newPassword);
      return res.data['success'] == true;
    } catch (_) {}
    return false;
  }

  /// OTP yuborish — Haqiqiy API chaqiruvi
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final normalized = _normalizePhone(phone);
      final res = await _api.sendOtp(normalized);
      if (res.data['success'] == true) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isIdentifierChecked: true,
          identifier: normalized,
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'OTP yuborishda xatolik',
      );
      return false;
    } catch (e) {
      debugPrint('sendOtp error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Tasdiqlash kodini yuborishda xatolik yuz berdi. Internetni tekshiring.',
      );
      return false;
    }
  }

  /// OTP tekshirish va kirish/ro'yxatdan o'tish
  Future<bool> verifyOtp(String phone, String code, {String? fullName, String? referredByCode}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final normalized = _normalizePhone(phone);
      final res = await _api.verifyOtp(
        normalized,
        code,
        fullName: fullName,
        referredByCode: referredByCode,
      );
      if (res.data['success'] == true) {
        final token = res.data['token'];
        await SecureTokenStorage.setToken(token);
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isIdentifierChecked: false,
        );
        _syncDriverMode(user);
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Tasdiqlash kodi xato',
      );
      return false;
    } catch (e) {
      debugPrint('verifyOtp error: $e');
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Kodni tasdiqlashda xatolik yuz berdi. Internetni tekshiring.',
      );
      return false;
    }
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('998') && digits.length == 12) return '+$digits';
    if (digits.length == 9) return '+998$digits';
    return phone;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final api = ref.read(apiServiceProvider);
  return AuthNotifier(api, ref);
});
