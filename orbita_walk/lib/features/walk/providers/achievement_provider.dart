import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String iconName; // 'morning', 'marathon', 'evos', 'macro'
  final bool isUnlocked;
  final DateTime? unlockDate;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    this.isUnlocked = false,
    this.unlockDate,
  });

  AchievementModel copyWith({
    bool? isUnlocked,
    DateTime? unlockDate,
  }) {
    return AchievementModel(
      id: id,
      title: title,
      description: description,
      iconName: iconName,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockDate: unlockDate ?? this.unlockDate,
    );
  }
}

class AchievementNotifier extends StateNotifier<List<AchievementModel>> {
  SharedPreferences? _prefs;
  Function(AchievementModel)? onAchievementUnlocked;

  AchievementNotifier() : super([]) {
    _init();
  }

  final List<AchievementModel> _defaultAchievements = [
    const AchievementModel(
      id: 'ach_morning_walk',
      title: 'Tonggi Sayr',
      description: 'Ertalab soat 08:00 gacha 3,000 qadam bosib sog\'lom tongni kutib oling.',
      iconName: 'morning',
    ),
    const AchievementModel(
      id: 'ach_marathon',
      title: 'Super Marafonchi',
      description: 'Bir kunda jami 15,000 qadam bosib chidamlilik rekordini o\'rnating.',
      iconName: 'marathon',
    ),
    const AchievementModel(
      id: 'ach_evos_quest',
      title: 'Evos Do\'sti',
      description: 'Evos kafe topshirig\'ini muvaffaqiyatli yakunlab chegirma yuting.',
      iconName: 'evos',
    ),
    const AchievementModel(
      id: 'ach_macro_quest',
      title: 'Macro Xaridor',
      description: 'Macro supermarket topshirig\'ini muvaffaqiyatli bajarib chegirma yuting.',
      iconName: 'macro',
    ),
  ];

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final unlockedIds = _prefs?.getStringList('unlocked_achievements') ?? [];

    state = _defaultAchievements.map((ach) {
      if (unlockedIds.contains(ach.id)) {
        final dateStr = _prefs?.getString('ach_date_${ach.id}');
        return ach.copyWith(
          isUnlocked: true,
          unlockDate: dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
        );
      }
      return ach;
    }).toList();
  }

  Future<void> _unlock(String id) async {
    // Check if already unlocked
    final index = state.indexWhere((a) => a.id == id);
    if (index == -1 || state[index].isUnlocked) return;

    final now = DateTime.now();
    final unlockedModel = state[index].copyWith(
      isUnlocked: true,
      unlockDate: now,
    );

    state = [
      for (var a in state)
        if (a.id == id) unlockedModel else a
    ];

    if (_prefs != null) {
      final unlockedIds = _prefs!.getStringList('unlocked_achievements') ?? [];
      if (!unlockedIds.contains(id)) {
        unlockedIds.add(id);
        await _prefs!.setStringList('unlocked_achievements', unlockedIds);
        await _prefs!.setString('ach_date_$id', now.toIso8601String());
      }
    }

    if (onAchievementUnlocked != null) {
      onAchievementUnlocked!(unlockedModel);
    }
  }

  void checkMorningWalk(int steps) {
    if (steps >= 3000 && DateTime.now().hour < 8) {
      _unlock('ach_morning_walk');
    }
  }

  void checkMarathon(int steps) {
    if (steps >= 15000) {
      _unlock('ach_marathon');
    }
  }

  void checkPartnerQuest(String questId) {
    if (questId == 'quest_evos') {
      _unlock('ach_evos_quest');
    } else if (questId == 'quest_macro') {
      _unlock('ach_macro_quest');
    }
  }

  Future<void> resetAchievements() async {
    if (_prefs != null) {
      await _prefs!.setStringList('unlocked_achievements', []);
      for (var ach in _defaultAchievements) {
        await _prefs!.remove('ach_date_${ach.id}');
      }
    }
    state = _defaultAchievements;
  }
}

final achievementProvider =
    StateNotifierProvider<AchievementNotifier, List<AchievementModel>>((ref) {
  return AchievementNotifier();
});
