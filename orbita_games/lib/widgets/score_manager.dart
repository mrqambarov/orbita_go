import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import 'xp_provider.dart';

class ScoreManager {
  static final ScoreManager _instance = ScoreManager._internal();
  factory ScoreManager() => _instance;
  ScoreManager._internal();

  Future<void> saveResult({
    required String gameType,
    required int score,
    int? level,
    int? coins,
    required ApiService api,
    required WidgetRef ref,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Calculate and update XP globally
    int addedXp = (score ~/ 5) + (level != null ? level * 20 : 0);
    await ref.read(xpProvider.notifier).addXp(addedXp);

    // 2. Local Persistence (Normalized keys)
    final keyPrefix = gameType.toLowerCase();
    String levelKey = '${gameType}_level';
    String scoreKey = '${keyPrefix}_high_score';

    if (keyPrefix == 'word_quest') {
      levelKey = 'word_level';
      scoreKey = 'word_high_score';
    } else if (keyPrefix == 'math_dash') {
      levelKey = 'math_level';
      scoreKey = 'math_high_score';
    } else if (keyPrefix == 'gravity_run' || keyPrefix == 'rocket_rush') {
      levelKey = 'gravity_run_level';
      scoreKey = 'rocket_rush_high_score';
    } else if (keyPrefix == 'star_connect') {
      levelKey = 'star_connect_level';
      scoreKey = 'star_connect_high_score';
    } else if (keyPrefix == 'memory') {
      levelKey = 'memory_level';
      scoreKey = 'memory_high_score';
    }

    if (level != null) {
      int currentMaxLvl = prefs.getInt(levelKey) ?? 0;
      if (level > currentMaxLvl) await prefs.setInt(levelKey, level);
    }
    
    int currentBest = prefs.getInt(scoreKey) ?? 0;
    if (score > currentBest) await prefs.setInt(scoreKey, score);
    
    if (coins != null && coins > 0) {
      int currentBank = prefs.getInt('coin_bank') ?? 0;
      await prefs.setInt('coin_bank', currentBank + coins);
    }

    // 3. Server Sync
    try {
      await api.updateStats(
        gameType: gameType.toUpperCase(),
        score: score,
        level: level,
      );
    } catch (e) {
      print('Sync Error: $e');
    }
  }
}
