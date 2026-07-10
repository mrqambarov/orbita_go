import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'achievement_provider.dart';
import 'quest_provider.dart';

class WalkSession {
  final String id;
  final int steps;
  final double distanceKm;
  final int calories;
  final int durationSecs;
  final DateTime date;

  WalkSession({
    required this.id,
    required this.steps,
    required this.distanceKm,
    required this.calories,
    required this.durationSecs,
    required this.date,
  });

  factory WalkSession.fromJson(Map<String, dynamic> json) {
    return WalkSession(
      id: json['id'] ?? '',
      steps: json['steps'] ?? 0,
      distanceKm: (json['distanceKm'] ?? 0.0).toDouble(),
      calories: json['calories'] ?? 0,
      durationSecs: json['durationSecs'] ?? 0,
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'steps': steps,
        'distanceKm': distanceKm,
        'calories': calories,
        'durationSecs': durationSecs,
        'date': date.toIso8601String(),
      };
}

class WalkState {
  final int dailySteps;
  final int stepGoal;
  final int unredeemedSteps;
  final bool isActiveWalk;
  final int sessionSteps;
  final int sessionDuration;
  final List<WalkSession> walkHistory;
  final bool isRedeeming;
  final String? permissionError;

  WalkState({
    this.dailySteps = 0,
    this.stepGoal = 10000,
    this.unredeemedSteps = 0,
    this.isActiveWalk = false,
    this.sessionSteps = 0,
    this.sessionDuration = 0,
    this.walkHistory = const [],
    this.isRedeeming = false,
    this.permissionError,
  });

  WalkState copyWith({
    int? dailySteps,
    int? stepGoal,
    int? unredeemedSteps,
    bool? isActiveWalk,
    int? sessionSteps,
    int? sessionDuration,
    List<WalkSession>? walkHistory,
    bool? isRedeeming,
    String? permissionError,
    bool clearPermissionError = false,
  }) {
    return WalkState(
      dailySteps: dailySteps ?? this.dailySteps,
      stepGoal: stepGoal ?? this.stepGoal,
      unredeemedSteps: unredeemedSteps ?? this.unredeemedSteps,
      isActiveWalk: isActiveWalk ?? this.isActiveWalk,
      sessionSteps: sessionSteps ?? this.sessionSteps,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      walkHistory: walkHistory ?? this.walkHistory,
      isRedeeming: isRedeeming ?? this.isRedeeming,
      permissionError: clearPermissionError ? null : (permissionError ?? this.permissionError),
    );
  }
}

class WalkNotifier extends StateNotifier<WalkState> {
  final ApiService _api;
  final Ref _ref;
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  SharedPreferences? _prefs;

  // Local accumulation values for high-precision calculations
  Position? _lastPosition;
  double _accumulatedDistance = 0.0;

  WalkNotifier(this._api, this._ref) : super(WalkState()) {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    
    // First, verify and perform the midnight check & reset
    await _checkMidnightReset();

    final steps = _prefs?.getInt('daily_steps') ?? 0;
    final unredeemed = _prefs?.getInt('unredeemed_steps') ?? 0;
    final historyJson = _prefs?.getStringList('walk_history') ?? [];

    final history = historyJson
        .map((item) => WalkSession.fromJson(json.decode(item)))
        .toList();

    state = state.copyWith(
      dailySteps: steps,
      unredeemedSteps: unredeemed,
      walkHistory: history,
    );
  }

  // Smart Midnight Check and Archive reset
  Future<void> _checkMidnightReset() async {
    if (_prefs == null) _prefs = await SharedPreferences.getInstance();

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastDateStr = _prefs!.getString('last_steps_date');

    if (lastDateStr == null) {
      // First run: save today's date
      await _prefs!.setString('last_steps_date', todayStr);
      return;
    }

    if (lastDateStr != todayStr) {
      // Midnight crossed: Archive previous day's steps count
      final lastDaySteps = _prefs!.getInt('daily_steps') ?? 0;

      final dailyHistoryJsonList = _prefs!.getStringList('daily_steps_history') ?? [];
      final newHistoryEntry = json.encode({
        'date': lastDateStr,
        'steps': lastDaySteps,
      });
      dailyHistoryJsonList.add(newHistoryEntry);
      
      await _prefs!.setStringList('daily_steps_history', dailyHistoryJsonList);

      // Reset daily counter (unredeemed steps remain safe for withdrawal!)
      state = state.copyWith(dailySteps: 0);
      await _prefs!.setInt('daily_steps', 0);
      await _prefs!.setString('last_steps_date', todayStr);
    }
  }

  Future<void> _saveToPrefs() async {
    if (_prefs == null) return;
    await _prefs!.setInt('daily_steps', state.dailySteps);
    await _prefs!.setInt('unredeemed_steps', state.unredeemedSteps);

    final historyJson = state.walkHistory
        .map((session) => json.encode(session.toJson()))
        .toList();
    await _prefs!.setStringList('walk_history', historyJson);
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(permissionError: "GPS datchigi o'chirilgan. Iltimos yoqing.");
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        state = state.copyWith(permissionError: "Joylashuvni aniqlashga ruxsat berilmadi.");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
          permissionError: "Joylashuv ruxsati butunlay rad etilgan. Sozlamalardan yoqing.");
      return false;
    }

    state = state.copyWith(clearPermissionError: true);
    return true;
  }

  Future<void> startWalk() async {
    if (state.isActiveWalk) return;

    // Verify day hasn't changed before starting
    await _checkMidnightReset();

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    _lastPosition = null;
    _accumulatedDistance = 0.0;

    state = state.copyWith(
      isActiveWalk: true,
      sessionSteps: 0,
      sessionDuration: 0,
      clearPermissionError: true,
    );

    // 1. Timer for duration tracking
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(
        sessionDuration: state.sessionDuration + 1,
      );
    });

    // 2. Location Stream with Foreground Service
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // notify every 2 meters
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Orbita Walk xizmati faol",
        notificationText: "Orqa fonda qadamlaringiz hisoblanmoqda",
      ),
    );

    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          // --- ANTI-CHEAT RULE 1: Mock Location (Fake GPS) Detection ---
          if (position.isMocked) {
            _timer?.cancel();
            _positionSubscription?.cancel();
            await NotificationService.cancelWalkNotification();
            state = state.copyWith(
              isActiveWalk: false,
              sessionSteps: 0,
              sessionDuration: 0,
              permissionError: "Soxta GPS (Fake location) aniqlandi! Mashg'ulot rad etildi.",
            );
            return;
          }

          // Trigger day check just in case midnight is crossed during active walk!
          await _checkMidnightReset();

          // Notify Quest Provider of coordinate changes
          _ref.read(questProvider.notifier).updateUserLocation(position.latitude, position.longitude);

          if (_lastPosition != null) {
            final distance = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            // --- ANTI-CHEAT RULE 2: Speed Threshold Filter (with fallback calculation) ---
            final double currentSpeed = position.speed > 0 ? position.speed : (distance / 2.0);
            
            if (position.accuracy < 25.0 && currentSpeed >= 0.35 && currentSpeed <= 6.0) {
              _accumulatedDistance += distance;
              final calculatedSteps = (_accumulatedDistance / 0.76).round();

              state = state.copyWith(
                sessionSteps: calculatedSteps,
              );
            }
          }
          _lastPosition = position;

          // Update dynamic lock screen / notification widget metrics in real-time!
          final sessionDistance = state.sessionSteps * 0.00076;
          final questState = _ref.read(questProvider);
          final activeId = questState.activeQuestId;
          
          if (activeId != null) {
            try {
              final activeQuest = questState.quests.firstWhere((q) => q.id == activeId);
              await NotificationService.showWalkNotification(
                steps: state.sessionSteps,
                distanceKm: sessionDistance,
                activeQuestTitle: activeQuest.title,
                distanceToQuestKm: activeQuest.distanceToTarget != null ? activeQuest.distanceToTarget! / 1000 : null,
              );
            } catch (e) {
              await NotificationService.showWalkNotification(
                steps: state.sessionSteps,
                distanceKm: sessionDistance,
              );
            }
          } else {
            await NotificationService.showWalkNotification(
              steps: state.sessionSteps,
              distanceKm: sessionDistance,
            );
          }
        },
        onError: (error) {
          debugPrint('Geolocator stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error starting position stream: $e');
    }
  }

  Future<void> saveSession() async {
    if (!state.isActiveWalk) return;
    _timer?.cancel();
    _positionSubscription?.cancel();
    
    // Clear lock screen notification
    await NotificationService.cancelWalkNotification();

    // Verify day hasn't changed before saving
    await _checkMidnightReset();

    final sessionSteps = state.sessionSteps;
    final duration = state.sessionDuration;

    // --- ANTI-CHEAT RULE 3: Cadence check (Steps per minute) ---
    if (sessionSteps > 0 && duration > 0) {
      final stepsPerMinute = sessionSteps / (duration / 60.0);
      if (stepsPerMinute > 220) {
        state = state.copyWith(
          isActiveWalk: false,
          sessionSteps: 0,
          sessionDuration: 0,
          permissionError: "Shubhali yuqori tezlik aniqlandi! Mashg'ulot saqlanmadi.",
        );
        return;
      }
    }

    if (sessionSteps > 0) {
      final newSession = WalkSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        steps: sessionSteps,
        distanceKm: double.parse((sessionSteps * 0.00076).toStringAsFixed(2)),
        calories: (sessionSteps * 0.04).round(),
        durationSecs: duration,
        date: DateTime.now(),
      );

      final updatedHistory = [newSession, ...state.walkHistory];
      state = state.copyWith(
        isActiveWalk: false,
        dailySteps: state.dailySteps + sessionSteps,
        unredeemedSteps: state.unredeemedSteps + sessionSteps,
        walkHistory: updatedHistory,
        sessionSteps: 0,
        sessionDuration: 0,
      );

      await _saveToPrefs();

      // Check step-based quests (e.g. Daily 12k step challenge) upon saving
      _ref.read(questProvider.notifier).updateUserSteps(state.dailySteps);

      // Check achievements for daily totals
      _ref.read(achievementProvider.notifier).checkMorningWalk(state.dailySteps);
      _ref.read(achievementProvider.notifier).checkMarathon(state.dailySteps);
    } else {
      state = state.copyWith(
        isActiveWalk: false,
        sessionSteps: 0,
        sessionDuration: 0,
      );
    }
  }

  Future<void> cancelSession() async {
    _timer?.cancel();
    _positionSubscription?.cancel();
    
    // Dismiss lock screen widget
    await NotificationService.cancelWalkNotification();

    state = state.copyWith(
      isActiveWalk: false,
      sessionSteps: 0,
      sessionDuration: 0,
    );
  }

  Future<bool> redeemSteps(WidgetRef ref) async {
    if (state.unredeemedSteps <= 0 || state.isRedeeming) return false;

    state = state.copyWith(isRedeeming: true);
    
    // --- ANTI-CHEAT RULE 4: Daily conversion limit check ---
    int stepsToRedeem = state.unredeemedSteps;
    int remainingSteps = 0;
    if (stepsToRedeem > 15000) {
      remainingSteps = stepsToRedeem - 15000;
      stepsToRedeem = 15000;
    }

    final rewardAmount = stepsToRedeem.toDouble();

    try {
      final res = await _api.redeemWalkSteps(stepsToRedeem, rewardAmount);
      if (res.data['success'] == true) {
        state = state.copyWith(
          unredeemedSteps: remainingSteps,
          isRedeeming: false,
        );
        await _saveToPrefs();
        await ref.read(authProvider.notifier).refreshUser();
        return true;
      }
    } catch (e) {
      debugPrint('Redeem steps network error: $e');
    }

    state = state.copyWith(isRedeeming: false);
    return false;
  }

  Future<void> resetDailySteps() async {
    state = state.copyWith(
      dailySteps: 0,
      unredeemedSteps: 0,
    );
    await _saveToPrefs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSubscription?.cancel();
    NotificationService.cancelWalkNotification();
    super.dispose();
  }
}

final walkProvider = StateNotifierProvider<WalkNotifier, WalkState>((ref) {
  return WalkNotifier(ref.read(apiServiceProvider), ref);
});
