import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/quest_model.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'achievement_provider.dart';

class QuestState {
  final List<QuestModel> quests;
  final String? activeQuestId;

  QuestState({
    required this.quests,
    this.activeQuestId,
  });

  QuestState copyWith({
    List<QuestModel>? quests,
    String? activeQuestId,
    bool clearActiveQuest = false,
  }) {
    return QuestState(
      quests: quests ?? this.quests,
      activeQuestId: clearActiveQuest ? null : (activeQuestId ?? this.activeQuestId),
    );
  }
}

class QuestNotifier extends StateNotifier<QuestState> {
  final ApiService _api;
  final Ref _ref;
  SharedPreferences? _prefs;
  
  Function(QuestModel)? onQuestCompleted;

  QuestNotifier(this._api, this._ref) : super(QuestState(quests: [])) {
    _initQuests();
  }

  // Predefined Partner Quests (English terms translated to clean, beautiful Uzbek)
  final List<QuestModel> _defaultQuests = [
    const QuestModel(
      id: 'quest_evos',
      title: 'Evos Cafesiga sayr',
      description: 'Kosonsoy markazidagi Evos filialiga boring va 15% chegirmali kuponni qo\'lga kiriting.',
      targetType: 'LOCATION',
      targetLat: 41.2561,
      targetLng: 71.5508,
      targetName: 'Evos Cafe (Kosonsoy)',
      rewardCoins: 3000.0,
      rewardCoupon: 'Evosdan 15% chegirma',
      rewardPromoCode: 'ORBITAEVOS15',
    ),
    const QuestModel(
      id: 'quest_macro',
      title: 'Macro Supermarket sayri',
      description: 'Kosonsoy Macro supermarketiga boring va 20,000 so\'mlik chegirmali kupon yuting.',
      targetType: 'LOCATION',
      targetLat: 41.2600,
      targetLng: 71.5550,
      targetName: 'Macro Supermarket',
      rewardCoins: 5000.0,
      rewardCoupon: 'Macroda 20,000 so\'m chegirma',
      rewardPromoCode: 'MACROWALK20',
    ),
    const QuestModel(
      id: 'quest_12k_steps',
      title: 'Kunlik 12,000 qadam',
      description: 'Bugun jami 12,000 qadam bosing va qo\'shimcha 10,000 UZS chempionlik bonusini oling.',
      targetType: 'STEPS',
      targetSteps: 12000,
      targetName: 'Faollik marra',
      rewardCoins: 10000.0,
      rewardCoupon: 'Chempionlik maxsus bonusi',
      rewardPromoCode: 'CHAMPWALK12K',
    ),
  ];

  Future<void> _initQuests() async {
    _prefs = await SharedPreferences.getInstance();
    final completedIds = _prefs?.getStringList('completed_quests') ?? [];
    final activeId = _prefs?.getString('active_quest_id');

    final questsList = _defaultQuests.map((quest) {
      if (completedIds.contains(quest.id)) {
        return quest.copyWith(isCompleted: true);
      }
      return quest;
    }).toList();

    state = QuestState(
      quests: questsList,
      activeQuestId: activeId,
    );
  }

  Future<void> activateQuest(String id) async {
    // Cannot activate a quest that is already completed
    final quest = state.quests.firstWhere((q) => q.id == id);
    if (quest.isCompleted) return;

    state = state.copyWith(activeQuestId: id);
    
    if (_prefs != null) {
      await _prefs!.setString('active_quest_id', id);
    }
  }

  Future<void> deactivateQuest() async {
    state = state.copyWith(clearActiveQuest: true);
    
    if (_prefs != null) {
      await _prefs!.remove('active_quest_id');
    }
  }

  Future<void> _markQuestCompleted(QuestModel quest) async {
    if (quest.isCompleted) return;

    // 1. Update local state list and clear active status
    final updatedQuests = state.quests.map((q) {
      if (q.id == quest.id) {
        return q.copyWith(isCompleted: true);
      }
      return q;
    }).toList();

    state = state.copyWith(
      quests: updatedQuests,
      clearActiveQuest: true,
    );

    // 2. Save to SharedPreferences
    if (_prefs != null) {
      final completedIds = _prefs!.getStringList('completed_quests') ?? [];
      if (!completedIds.contains(quest.id)) {
        completedIds.add(quest.id);
        await _prefs!.setStringList('completed_quests', completedIds);
      }
      await _prefs!.remove('active_quest_id');
    }

    // 3. Payout UZS rewards directly to the wallet database
    try {
      final res = await _api.redeemWalkSteps(0, quest.rewardCoins);
      if (res.data['success'] == true) {
        // Sync user wallet balance
        await _ref.read(authProvider.notifier).refreshUser();
      }
    } catch (e) {
      debugPrint('Error payout quest reward: $e');
    }

    // 4. Check partner quest achievements
    _ref.read(achievementProvider.notifier).checkPartnerQuest(quest.id);

    // 5. Trigger callback for congratulatory dialog
    if (onQuestCompleted != null) {
      onQuestCompleted!(quest.copyWith(isCompleted: true));
    }
  }

  // Proximity validation checks (ONLY run for the selected/active quest!)
  void updateUserLocation(double lat, double lng) {
    if (state.activeQuestId == null) return;

    final activeId = state.activeQuestId;
    final updatedQuests = state.quests.map((quest) {
      if (quest.id == activeId && quest.targetType == 'LOCATION' && !quest.isCompleted) {
        final distance = Geolocator.distanceBetween(
          lat,
          lng,
          quest.targetLat!,
          quest.targetLng!,
        );

        if (distance <= 50.0) {
          Future.microtask(() => _markQuestCompleted(quest));
          return quest.copyWith(isCompleted: true, distanceToTarget: 0);
        }

        return quest.copyWith(distanceToTarget: distance);
      }
      return quest;
    }).toList();

    state = state.copyWith(quests: updatedQuests);
  }

  // Steps validation check (ONLY run for the selected/active quest!)
  void updateUserSteps(int steps) {
    if (state.activeQuestId == null) return;

    final activeId = state.activeQuestId;
    for (var quest in state.quests) {
      if (quest.id == activeId && quest.targetType == 'STEPS' && !quest.isCompleted) {
        if (steps >= quest.targetSteps) {
          _markQuestCompleted(quest);
        }
      }
    }
  }

  Future<void> resetQuests() async {
    if (_prefs != null) {
      await _prefs!.setStringList('completed_quests', []);
      await _prefs!.remove('active_quest_id');
    }
    state = QuestState(
      quests: _defaultQuests,
      activeQuestId: null,
    );
  }
}

final questProvider = StateNotifierProvider<QuestNotifier, QuestState>((ref) {
  return QuestNotifier(ref.read(apiServiceProvider), ref);
});
