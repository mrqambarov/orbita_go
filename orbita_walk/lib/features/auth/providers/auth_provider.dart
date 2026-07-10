import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/user_model.dart';
import '../../walk/providers/walk_provider.dart';
import '../../walk/providers/quest_provider.dart';
import '../../walk/providers/achievement_provider.dart';

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
    checkAuth();
  }

  Future<void> checkAuth() async {
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
      } else {
        await SecureTokenStorage.deleteToken();
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      debugPrint('Walk auth check error: $e');
      state = state.copyWith(status: AuthStatus.unauthenticated);
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
        error: 'Tizimga kirishda xatolik. Tarmoqni tekshiring.',
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
        error: 'Ro\'yxatdan o\'tishda xatolik. Tarmoqni tekshiring.',
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

  Future<void> refreshUser() async {
    try {
      final res = await _api.getMe();
      if (res.data['success'] == true) {
        final user = UserModel.fromJson(res.data['user']);
        state = state.copyWith(user: user);
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
    }
  }

  Future<void> logout() async {
    await SecureTokenStorage.deleteToken();
    
    // Clear all user-specific data from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('Error clearing SharedPreferences on logout: $e');
    }

    // Reset providers in memory
    _ref.read(walkProvider.notifier).resetDailySteps();
    _ref.read(questProvider.notifier).resetQuests();
    _ref.read(achievementProvider.notifier).resetAchievements();
    
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(apiServiceProvider), ref);
});
