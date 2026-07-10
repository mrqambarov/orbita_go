import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final xpProvider = StateNotifierProvider<XpNotifier, XpState>((ref) {
  return XpNotifier();
});

class XpState {
  final int totalXp;
  final int level;
  final int currentLevelXp;
  final int nextLevelXp;

  XpState({
    required this.totalXp,
    required this.level,
    required this.currentLevelXp,
    required this.nextLevelXp,
  });

  XpState copyWith({int? totalXp, int? level, int? currentLevelXp, int? nextLevelXp}) {
    return XpState(
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      currentLevelXp: currentLevelXp ?? this.currentLevelXp,
      nextLevelXp: nextLevelXp ?? this.nextLevelXp,
    );
  }
}

class XpNotifier extends StateNotifier<XpState> {
  XpNotifier() : super(XpState(totalXp: 0, level: 1, currentLevelXp: 0, nextLevelXp: 1000)) {
    loadXp();
  }

  Future<void> loadXp() async {
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt('user_xp') ?? 0;
    _updateState(xp);
  }

  Future<void> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final newXp = (prefs.getInt('user_xp') ?? 0) + amount;
    await prefs.setInt('user_xp', newXp);
    _updateState(newXp);
  }

  void _updateState(int totalXp) {
    // Basic leveling formula: Each level is 1000 XP
    int level = (totalXp ~/ 1000) + 1;
    int currentLevelXp = totalXp % 1000;
    state = XpState(
      totalXp: totalXp,
      level: level,
      currentLevelXp: currentLevelXp,
      nextLevelXp: 1000,
    );
  }
}
