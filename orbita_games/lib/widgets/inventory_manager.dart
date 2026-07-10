import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final inventoryProvider = StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier();
});

class InventoryState {
  final String equippedRocket;
  final bool hasTimeFreeze;
  final int shieldsCount;

  InventoryState({
    this.equippedRocket = 'DEFAULT',
    this.hasTimeFreeze = false,
    this.shieldsCount = 1,
  });

  InventoryState copyWith({String? equippedRocket, bool? hasTimeFreeze, int? shieldsCount}) {
    return InventoryState(
      equippedRocket: equippedRocket ?? this.equippedRocket,
      hasTimeFreeze: hasTimeFreeze ?? this.hasTimeFreeze,
      shieldsCount: shieldsCount ?? this.shieldsCount,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier() : super(InventoryState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      equippedRocket: prefs.getString('equipped_rocket') ?? 'DEFAULT',
      shieldsCount: prefs.getInt('inventory_shields') ?? 1,
    );
  }

  Future<void> equipRocket(String rocket) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('equipped_rocket', rocket);
    state = state.copyWith(equippedRocket: rocket);
  }
}
