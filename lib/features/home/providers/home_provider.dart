import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

class HomeState {
  final LocationPoint? pickupPoint;
  final LocationPoint? destinationPoint;
  final LocationPoint? stopPoint;
  final String fromAddress;
  final String toAddress;
  final String stopAddress;
  final TariffModel? selectedTariff;
  final bool selectingDestination;
  final bool isLoading;
  final double? estimatedPrice;
  final double? distanceKm;
  final String paymentMethod; // 'CASH' or 'WALLET'

  const HomeState({
    this.pickupPoint,
    this.destinationPoint,
    this.stopPoint,
    this.fromAddress = '',
    this.toAddress = '',
    this.stopAddress = '',
    this.selectedTariff,
    this.selectingDestination = false,
    this.isLoading = false,
    this.estimatedPrice,
    this.distanceKm,
    this.paymentMethod = 'CASH',
  });

  bool get canOrder =>
      pickupPoint != null && destinationPoint != null && selectedTariff != null;

  HomeState copyWith({
    LocationPoint? pickupPoint,
    LocationPoint? destinationPoint,
    LocationPoint? stopPoint,
    String? fromAddress,
    String? toAddress,
    String? stopAddress,
    TariffModel? selectedTariff,
    bool? selectingDestination,
    bool? isLoading,
    double? estimatedPrice,
    double? distanceKm,
    String? paymentMethod,
    bool clearStopPoint = false,
  }) {
    return HomeState(
      pickupPoint: pickupPoint ?? this.pickupPoint,
      destinationPoint: destinationPoint ?? this.destinationPoint,
      stopPoint: clearStopPoint ? null : (stopPoint ?? this.stopPoint),
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      stopAddress: clearStopPoint ? '' : (stopAddress ?? this.stopAddress),
      selectedTariff: selectedTariff ?? this.selectedTariff,
      selectingDestination: selectingDestination ?? this.selectingDestination,
      isLoading: isLoading ?? this.isLoading,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      distanceKm: distanceKm ?? this.distanceKm,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final ApiService _api;

  HomeNotifier(this._api) : super(const HomeState());

  Future<void> setPickupFromPosition(Position position) async {
    state = state.copyWith(
      pickupPoint: LocationPoint(
        lat: position.latitude,
        lng: position.longitude,
      ),
      fromAddress: 'Joylashuv aniqlanmoqda...',
    );
    try {
      final res = await _api.reverseGeocode(position.latitude, position.longitude);
      if (res.data['success'] == true) {
        state = state.copyWith(
          fromAddress: res.data['address'] as String,
        );
      } else {
        state = state.copyWith(fromAddress: 'Joriy joylashuv');
      }
    } catch (_) {
      state = state.copyWith(fromAddress: 'Joriy joylashuv');
    }
  }

  void setPickup(Point point, String address) {
    state = state.copyWith(
      pickupPoint: LocationPoint(lat: point.latitude, lng: point.longitude),
      fromAddress: address,
    );
    _calculatePrice();
  }

  void setStopPoint(Point point, {String? address}) {
    state = state.copyWith(
      stopPoint: LocationPoint(lat: point.latitude, lng: point.longitude),
      stopAddress: address ?? 'Yo\'l-yo\'lakay to\'xtash',
    );
    _calculatePrice();
  }

  void clearStopPoint() {
    state = state.copyWith(clearStopPoint: true);
    _calculatePrice();
  }

  void setDestination(Point point, {String? address}) {
    state = state.copyWith(
      destinationPoint: LocationPoint(lat: point.latitude, lng: point.longitude),
      toAddress: address ?? 'Belgilangan joy',
      selectingDestination: false,
    );
    _calculatePrice();
    // Auto-select first tariff
    if (state.selectedTariff == null) {
      state = state.copyWith(selectedTariff: TariffModel.defaults.first);
    }
  }

  void selectTariff(TariffModel tariff) {
    state = state.copyWith(selectedTariff: tariff);
    _calculatePrice();
  }

  void _calculatePrice() {
    if (state.pickupPoint == null || state.destinationPoint == null) return;

    double distKm;
    if (state.stopPoint != null) {
      distKm = _haversine(
        state.pickupPoint!.lat,
        state.pickupPoint!.lng,
        state.stopPoint!.lat,
        state.stopPoint!.lng,
      ) + _haversine(
        state.stopPoint!.lat,
        state.stopPoint!.lng,
        state.destinationPoint!.lat,
        state.destinationPoint!.lng,
      );
    } else {
      distKm = _haversine(
        state.pickupPoint!.lat,
        state.pickupPoint!.lng,
        state.destinationPoint!.lat,
        state.destinationPoint!.lng,
      );
    }

    final tariff = state.selectedTariff ?? TariffModel.defaults.first;
    final price = tariff.calculatePrice(distKm);

    state = state.copyWith(
      distanceKm: distKm,
      estimatedPrice: price,
    );
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final a = sinDLat * sinDLat +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * sinDLon * sinDLon;
    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return r * c;
  }

  double _toRad(double deg) => deg * math.pi / 180;

  void selectPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  Future<String?> createOrder(String userId) async {
    if (!state.canOrder) return null;
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.createOrder({
        'userId': userId,
        'fromLocation': state.pickupPoint!.toJson(),
        'toLocation': state.destinationPoint!.toJson(),
        if (state.stopPoint != null) 'stopLocation': state.stopPoint!.toJson(),
        if (state.stopPoint != null) 'stopAddress': state.stopAddress,
        'fromAddress': state.fromAddress,
        'toAddress': state.toAddress,
        'tariff': state.selectedTariff!.id,
        'price': state.estimatedPrice,
        'type': 'TAXI',
        'paymentMethod': state.paymentMethod,
      });
      state = state.copyWith(isLoading: false);
      if (res.data['success'] == true) {
        return res.data['order']['id'] as String;
      }
    } catch (e) {
      print('CreateOrder API error: $e');
    }
    state = state.copyWith(isLoading: false);
    return null;
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref.read(apiServiceProvider));
});
