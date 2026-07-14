import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

enum AuthStatus { initial, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;
  final bool isIdentifierChecked;
  final bool identifierExists;
  final String? identifier;
  final bool otpSent; // telefon uchun OTP yuborildimi

  AuthState({
    required this.status,
    this.user,
    this.error,
    this.isIdentifierChecked = false,
    this.identifierExists = false,
    this.identifier,
    this.otpSent = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? error,
    bool? isIdentifierChecked,
    bool? identifierExists,
    String? identifier,
    bool? otpSent,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      isIdentifierChecked: isIdentifierChecked ?? this.isIdentifierChecked,
      identifierExists: identifierExists ?? this.identifierExists,
      identifier: identifier ?? this.identifier,
      otpSent: otpSent ?? this.otpSent,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this._api) : super(AuthState(status: AuthStatus.initial)) {
    checkSession();
  }

  Future<void> checkSession() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      state = AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final res = await _api.getMe();
      if (res.data['success'] == true) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: res.data['user'],
        );
      } else {
        await logout();
      }
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated);
    }
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
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Xatolik yuz berdi',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Aloqa o\'rnatishda xatolik. Internetni tekshiring.',
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
        await _storage.write(key: 'auth_token', value: token);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: res.data['user'],
        );
        return true;
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          error: res.data['message'] ?? 'Parol noto\'g\'ri',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Tizimga ulanib bo\'lmadi. Internetni tekshiring.',
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
        await _storage.write(key: 'auth_token', value: token);
        state = AuthState(
          status: AuthStatus.authenticated,
          user: res.data['user'],
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Ro\'yxatdan o\'tishda xatolik',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Tizimga ulanib bo\'lmadi. Internetni tekshiring.',
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

  /// Telefon uchun SMS-kod (OTP) yuborish
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final normalized = _normalizePhone(phone);
      final res = await _api.sendOtp(normalized);
      if (res.data['success'] == true) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          otpSent: true,
          isIdentifierChecked: true,
          identifier: normalized,
        );
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Kod yuborishda xatolik',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Serverga ulanib bo\'lmadi. Internetni tekshiring.',
      );
      return false;
    }
  }

  /// OTP kodni tekshirib kirish/ro'yxatdan o'tish
  Future<bool> verifyOtp(String phone, String code, {String? fullName, String? referredByCode}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final normalized = _normalizePhone(phone);
      final res = await _api.verifyOtp(normalized, code, fullName: fullName, referredByCode: referredByCode);
      if (res.data['success'] == true) {
        await _storage.write(key: 'auth_token', value: res.data['token']);
        state = AuthState(status: AuthStatus.authenticated, user: res.data['user']);
        return true;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        error: res.data['message'] ?? 'Kod noto\'g\'ri',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Kodni tekshirishda xatolik. Internetni tekshiring.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void reset() {
    state = AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(Map<String, dynamic> user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider));
});
