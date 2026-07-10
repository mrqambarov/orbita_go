import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../shared/theme/app_theme.dart';

// Order tracking state
class OrderTrackingState {
  final OrderModel? order;
  final bool isLoading;
  final String? error;
  final List<Point> routePoints;
  final bool ratingSubmitted;

  const OrderTrackingState({
    this.order,
    this.isLoading = true,
    this.error,
    this.routePoints = const [],
    this.ratingSubmitted = false,
  });

  OrderTrackingState copyWith({
    OrderModel? order,
    bool? isLoading,
    String? error,
    List<Point>? routePoints,
    bool? ratingSubmitted,
  }) {
    return OrderTrackingState(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      routePoints: routePoints ?? this.routePoints,
      ratingSubmitted: ratingSubmitted ?? this.ratingSubmitted,
    );
  }
}

class OrderTrackingNotifier extends StateNotifier<OrderTrackingState> {
  final ApiService _api;
  final SocketService _socket;
  final String orderId;
  Timer? _pollTimer;

  OrderTrackingNotifier(this._api, this._socket, this.orderId)
      : super(const OrderTrackingState()) {
    _loadOrder();
    _setupSocketListeners();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (state.order?.status == OrderStatus.completed ||
          state.order?.status == OrderStatus.cancelled) {
        timer.cancel();
        return;
      }
      _loadOrder();
    });
  }

  Future<void> _loadOrder() async {
    try {
      final res = await _api.client.get('/api/order/$orderId');
      if (res.data['success'] == true) {
        final order = OrderModel.fromJson(res.data['order']);
        List<Point> routePts = [];
        if (res.data['routeGeometry'] != null) {
          final list = res.data['routeGeometry'] as List;
          routePts = list.map((item) {
            final ptList = item as List;
            return Point(
              latitude: (ptList[0] as num).toDouble(),
              longitude: (ptList[1] as num).toDouble(),
            );
          }).toList();
        }
        state = state.copyWith(order: order, routePoints: routePts, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: res.data['message'] ?? 'Buyurtma yuklashda xatolik',
        );
      }
    } catch (e, stack) {
      print('LoadOrder API error: $e');
      print(stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Serverga ulanishda xatolik. Internet aloqasini tekshiring.',
      );
    }
  }

  // Named handler refs — only remove OUR handlers in dispose
  late final Function(dynamic) _statusHandler;
  late final Function(dynamic) _locationHandler;

  void _setupSocketListeners() {
    _statusHandler = (data) {
      try {
        final dataMap = Map<String, dynamic>.from(data as Map);
        debugPrint('🔌 [Client] Socket status: $dataMap');
        if (dataMap['orderId'] != orderId) return;

        // Wait until order is loaded. If not loaded yet, try to load it
        if (state.order == null) {
          debugPrint('⚠️ order is null when status update came — reloading order');
          _loadOrder();
          return;
        }

        final newStatus = _parseStatus(dataMap['status']);
        final newPrice = dataMap['price'] != null ? (dataMap['price'] as num).toDouble() : null;

        DriverInfo? updatedDriver = state.order!.driver;
        if (dataMap['driver'] != null) {
          updatedDriver = DriverInfo.fromJson(Map<String, dynamic>.from(dataMap['driver']));
          debugPrint('🔌 Driver info from socket: ${updatedDriver.fullName}');
        }

        state = state.copyWith(
          order: state.order!.copyWith(
            status: newStatus,
            price: newPrice,
            driver: updatedDriver,
          ),
        );
        debugPrint('✅ Client status → $newStatus, driver: ${state.order?.driver?.fullName}');
      } catch (e, stack) {
        debugPrint('❌ status update error: $e\n$stack');
      }
    };

    _locationHandler = (data) {
      try {
        final dataMap = Map<String, dynamic>.from(data as Map);
        if (state.order == null) return;
        final lat = (dataMap['lat'] as num).toDouble();
        final lng = (dataMap['lng'] as num).toDouble();
        final newLocation = LocationPoint(lat: lat, lng: lng);

        // If driver info not yet available, just update location in a safe way
        if (state.order!.driver != null) {
          state = state.copyWith(
            order: state.order!.copyWith(
              driver: state.order!.driver!.copyWith(
                currentLocation: newLocation,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ location update error: $e');
      }
    };

    _socket.socket.on('order_status_update', _statusHandler);
    _socket.socket.on('driver_location_update', _locationHandler);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    // Only remove OUR handlers — not all listeners on the shared socket
    _socket.socket.off('order_status_update', _statusHandler);
    _socket.socket.off('driver_location_update', _locationHandler);
    super.dispose();
  }

  Future<void> cancelOrder() async {
    try {
      await _api.cancelOrder(orderId);
      final order = state.order;
      if (order != null) {
        state = state.copyWith(
          order: order.copyWith(status: OrderStatus.cancelled),
        );
      }
    } catch (_) {}
  }

  Future<bool> submitRating(int rating) async {
    try {
      final res = await _api.rateOrder(orderId, rating);
      if (res.data['success'] == true) {
        state = state.copyWith(ratingSubmitted: true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static OrderStatus _parseStatus(String? s) {
    switch (s) {
      case 'SEARCHING': return OrderStatus.searching;
      case 'FOUND': return OrderStatus.found;
      case 'DRIVER_ARRIVING': return OrderStatus.driverArriving;
      case 'DRIVER_ARRIVED': return OrderStatus.driverArrived;
      case 'IN_TRIP': return OrderStatus.inTrip;
      case 'COMPLETED': return OrderStatus.completed;
      case 'CANCELLED': return OrderStatus.cancelled;
      default: return OrderStatus.searching;
    }
  }

}

final orderTrackingProvider = StateNotifierProvider.family<
    OrderTrackingNotifier, OrderTrackingState, String>((ref, orderId) {
  return OrderTrackingNotifier(
    ref.read(apiServiceProvider),
    ref.read(socketServiceProvider),
    orderId,
  );
});

// ── ORDER TRACKING SCREEN ──
class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _waitingTimer;
  int _waitingSeconds = 0;
  double? _lastKnownPrice;
  bool _shownPriceAlert = false;
  YandexMapController? _mapController;
  Point? _lastCameraTarget;

  @override
  void dispose() {
    _waitingTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingSeconds = 0;
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _waitingSeconds++);
    });
  }

  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
  }

  void _callDriver(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Haydovchi harakatlanayotganda xarita kamerasini kuzatish
  void _trackDriverCamera(Point driverPoint) {
    if (_mapController == null) return;
    // Faqat kamera ancha uzoqlashsa animatsiya qilamiz (isrofni oldini olish)
    if (_lastCameraTarget != null) {
      final dLat = (driverPoint.latitude - _lastCameraTarget!.latitude).abs();
      final dLng = (driverPoint.longitude - _lastCameraTarget!.longitude).abs();
      if (dLat < 0.0001 && dLng < 0.0001) return;
    }
    _lastCameraTarget = driverPoint;
    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: driverPoint, zoom: 15),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.5,
      ),
    );
  }

  void _centerCameraOnRoute() async {
    if (_mapController == null) return;
    final state = ref.read(orderTrackingProvider(widget.orderId));
    final order = state.order;
    if (order == null) return;

    final fromLat = order.fromLocation.lat;
    final fromLng = order.fromLocation.lng;
    final toLat = order.toLocation.lat;
    final toLng = order.toLocation.lng;

    final centerLat = (fromLat + toLat) / 2;
    final centerLng = (fromLng + toLng) / 2;

    final latDiff = (fromLat - toLat).abs();
    final lngDiff = (fromLng - toLng).abs();
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 14.0;
    if (maxDiff > 0.08) {
      zoom = 11.0;
    } else if (maxDiff > 0.04) {
      zoom = 12.0;
    } else if (maxDiff > 0.015) {
      zoom = 13.0;
    } else if (maxDiff > 0.005) {
      zoom = 14.0;
    } else {
      zoom = 15.0;
    }

    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(latitude: centerLat, longitude: centerLng),
          zoom: zoom,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 1.0,
      ),
    );
  }

  /// Baholash dialogi
  void _showRatingDialog(BuildContext context) {
    int selectedRating = 5;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF13131F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.star_rounded, color: OrbitaColors.accent, size: 48),
              SizedBox(height: 12),
              Text(
                'Sayohatni baholang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Haydovchi xizmatini baholang',
                textAlign: TextAlign.center,
                style: TextStyle(color: OrbitaColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedRating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: OrbitaColors.accent,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) context.go('/home');
              },
              child: const Text('O\'tkazib yuborish',
                style: TextStyle(color: OrbitaColors.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OrbitaColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final router = GoRouter.of(context);
                navigator.pop();
                await ref
                    .read(orderTrackingProvider(widget.orderId).notifier)
                    .submitRating(selectedRating);
                router.go('/home');
              },
              child: const Text('Yuborish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderTrackingProvider(widget.orderId));
    final order = state.order;

    // Listen to changes in order loading state to center camera on completion
    ref.listen<OrderTrackingState>(orderTrackingProvider(widget.orderId), (previous, next) {
      if (previous?.isLoading == true && next.isLoading == false) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _centerCameraOnRoute();
        });
      }
    });

    // Manage waiting timer based on status
    if (order?.status == OrderStatus.driverArrived && _waitingTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startWaitingTimer());
    } else if (order?.status != OrderStatus.driverArrived && _waitingTimer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopWaitingTimer());
    }

    // Price change notification
    if (order != null && _lastKnownPrice != null && order.price > _lastKnownPrice! && !_shownPriceAlert) {
      _shownPriceAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final diff = (order.price - _lastKnownPrice!).toStringAsFixed(0);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.timer_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Kutish to\'lovi qo\'shildi: +$diff so\'m'),
            ]),
            backgroundColor: OrbitaColors.warning,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
      });
    }
    if (order != null) _lastKnownPrice = order.price;

    // Haydovchi harakatlanayotganda kamerani kuzatish
    final driverLocation = order?.driver?.currentLocation;
    if (driverLocation != null &&
        (order?.status == OrderStatus.driverArriving ||
         order?.status == OrderStatus.driverArrived ||
         order?.status == OrderStatus.inTrip)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackDriverCamera(
          Point(latitude: driverLocation.lat, longitude: driverLocation.lng),
        );
      });
    }

    // Sayohat yakunlanganda baholash dialogi
    if (order?.status == OrderStatus.completed && !state.ratingSubmitted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          // state local o'zgaruvchidan foydalaniladi (protected member muammosini hal qiladi)
          if (!state.ratingSubmitted) {
            _showRatingDialog(context);
          }
        }
      });
    }

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF13131F),
        body: Center(child: CircularProgressIndicator(color: OrbitaColors.primary)),
      );
    }

    if (order == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: OrbitaColors.error, size: 48),
              const SizedBox(height: 16),
              Text(state.error ?? 'Buyurtma topilmadi',
                  style: const TextStyle(color: OrbitaColors.textSecondary)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Bosh sahifaga qaytish'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          // Map
          YandexMap(
            onMapCreated: (controller) {
              _mapController = controller;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _centerCameraOnRoute();
              });
            },
            mapObjects: _buildMapObjects(order, state.routePoints),
            nightModeEnabled: true,
          ),

          // Status panel

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _OrderStatusPanel(
              order: order,
              waitingSeconds: order.status == OrderStatus.driverArrived ? _waitingSeconds : 0,
              onCancel: order.status == OrderStatus.searching ||
                      order.status == OrderStatus.found
                  ? () async {
                      await ref
                          .read(orderTrackingProvider(widget.orderId).notifier)
                          .cancelOrder();
                      if (context.mounted) context.go('/home');
                    }
                  : null,
              onCallDriver: order.driver != null
                  ? () => _callDriver(order.driver!.phoneNumber)
                  : null,
              onCompleted: order.status == OrderStatus.completed && !state.ratingSubmitted
                  ? () => _showRatingDialog(context)
                  : (order.status == OrderStatus.completed && state.ratingSubmitted
                      ? () => context.go('/home')
                      : null),
            ),
          ),

          // Back button
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: OrbitaColors.card.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: OrbitaColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MapObject> _buildMapObjects(OrderModel order, List<Point> routePoints) {
    final objects = <MapObject>[];

    // Add road routing polyline
    if (routePoints.isNotEmpty) {
      objects.add(PolylineMapObject(
        mapId: const MapObjectId('route'),
        polyline: Polyline(points: routePoints),
        strokeColor: OrbitaColors.primary,
        strokeWidth: 4.5,
        outlineColor: Colors.black.withOpacity(0.4),
        outlineWidth: 1.5,
      ));
    }

    objects.add(PlacemarkMapObject(
      mapId: const MapObjectId('pickup'),
      point: Point(
          latitude: order.fromLocation.lat,
          longitude: order.fromLocation.lng),
      icon: PlacemarkIcon.single(PlacemarkIconStyle(
        image: BitmapDescriptor.fromAssetImage('assets/icons/pickup_pin.png'),
        scale: 0.45,
      )),
    ));

    objects.add(PlacemarkMapObject(
      mapId: const MapObjectId('destination'),
      point: Point(
          latitude: order.toLocation.lat, longitude: order.toLocation.lng),
      icon: PlacemarkIcon.single(PlacemarkIconStyle(
        image:
            BitmapDescriptor.fromAssetImage('assets/icons/destination_pin.png'),
        scale: 0.45,
      )),
    ));

    if (order.driver?.currentLocation != null) {
      objects.add(PlacemarkMapObject(
        mapId: const MapObjectId('driver'),
        point: Point(
          latitude: order.driver!.currentLocation!.lat,
          longitude: order.driver!.currentLocation!.lng,
        ),
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/icons/car_pin.png'),
          scale: 0.45,
        )),
      ));
    }

    return objects;
  }
}

class _OrderStatusPanel extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onCancel;
  final VoidCallback? onCallDriver;
  final VoidCallback? onCompleted;
  final int waitingSeconds;

  const _OrderStatusPanel({
    required this.order,
    this.onCancel,
    this.onCallDriver,
    this.onCompleted,
    this.waitingSeconds = 0,
  });

  String get _statusText {
    switch (order.status) {
      case OrderStatus.searching:
        return 'Haydovchi qidirilmoqda...';
      case OrderStatus.found:
        return 'Haydovchi topildi!';
      case OrderStatus.driverArriving:
        return 'Haydovchi kelmoqda';
      case OrderStatus.driverArrived:
        return 'Haydovchi keldi!';
      case OrderStatus.inTrip:
        return 'Sayohat davom etmoqda';
      case OrderStatus.completed:
        return 'Sayohat yakunlandi 🎉';
      case OrderStatus.cancelled:
        return 'Bekor qilindi';
    }
  }

  Color get _statusColor {
    switch (order.status) {
      case OrderStatus.searching:
        return OrbitaColors.warning;
      case OrderStatus.found:
      case OrderStatus.driverArriving:
        return OrbitaColors.primary;
      case OrderStatus.driverArrived:
        return OrbitaColors.accent;
      case OrderStatus.inTrip:
        return OrbitaColors.success;
      case OrderStatus.completed:
        return OrbitaColors.success;
      case OrderStatus.cancelled:
        return OrbitaColors.error;
    }
  }

  String _formatWaiting(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 30),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A4E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

          // Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _statusText,
                  style: const TextStyle(
                    color: OrbitaColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Waiting timer badge
                if (order.status == OrderStatus.driverArrived && waitingSeconds > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: waitingSeconds > 15
                          ? OrbitaColors.error.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: waitingSeconds > 15
                            ? OrbitaColors.error.withOpacity(0.4)
                            : Colors.orange.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_rounded,
                          color: waitingSeconds > 15 ? OrbitaColors.error : Colors.orange,
                          size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _formatWaiting(waitingSeconds),
                          style: TextStyle(
                            color: waitingSeconds > 15 ? OrbitaColors.error : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          if (order.status == OrderStatus.driverArriving ||
              order.status == OrderStatus.driverArrived ||
              order.status == OrderStatus.inTrip) ...[
            if (order.distanceKm != null || order.durationMin != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_outlined, color: OrbitaColors.textSecondary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${order.distanceKm != null ? "${order.distanceKm!.toStringAsFixed(1)} km" : ""}'
                      '${order.distanceKm != null && order.durationMin != null ? " • " : ""}'
                      '${order.durationMin != null ? "${order.durationMin} daqiqa" : ""}',
                      style: const TextStyle(
                        color: OrbitaColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // Trip Fare & Payment Method Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // Price Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sell_outlined, color: OrbitaColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${order.price.toStringAsFixed(0)} so\'m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Payment Method Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        order.paymentMethod == 'WALLET'
                            ? Icons.account_balance_wallet_rounded
                            : Icons.money_rounded,
                        color: order.paymentMethod == 'WALLET'
                            ? OrbitaColors.primary
                            : OrbitaColors.success,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        order.paymentMethod == 'WALLET' ? 'Hamyon' : 'Naqd pul',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Driver info (if found)
          if (order.driver != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OrbitaColors.surfaceLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: OrbitaColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.driver!.fullName,
                            style: const TextStyle(
                              color: OrbitaColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${order.driver!.carModel} • ${order.driver!.carNumber}',
                            style: const TextStyle(
                              color: OrbitaColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: OrbitaColors.accent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                order.driver!.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: OrbitaColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onCallDriver != null) ...[
                      GestureDetector(
                        onTap: () => context.push('/chat/${order.id}'),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: OrbitaColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: OrbitaColors.primary.withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: OrbitaColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onCallDriver,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: OrbitaColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: OrbitaColors.success.withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            color: OrbitaColors.success,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Price
          if (order.status == OrderStatus.completed) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OrbitaColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: OrbitaColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'To\'lov summasi',
                      style: TextStyle(color: OrbitaColors.textSecondary),
                    ),
                    Text(
                      '${order.price.toStringAsFixed(0)} so\'m',
                      style: const TextStyle(
                        color: OrbitaColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: onCancel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: OrbitaColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: OrbitaColors.error.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text(
                            'Bekor qilish',
                            style: TextStyle(
                              color: OrbitaColors.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (onCompleted != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: onCompleted,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: OrbitaColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Baholash',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
