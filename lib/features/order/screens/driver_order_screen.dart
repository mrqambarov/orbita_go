import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../../core/localization/translations.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/orbita_button.dart';
import '../../home/screens/driver_home_screen.dart';

// Driver Order Tracking State
class DriverOrderState {
  final OrderModel? order;
  final List<Point> routePoints;
  final bool isLoading;
  final Point? driverLocation;

  const DriverOrderState({
    this.order,
    this.routePoints = const [],
    this.isLoading = true,
    this.driverLocation,
  });

  DriverOrderState copyWith({
    OrderModel? order,
    List<Point>? routePoints,
    bool? isLoading,
    Point? driverLocation,
  }) {
    return DriverOrderState(
      order: order ?? this.order,
      routePoints: routePoints ?? this.routePoints,
      isLoading: isLoading ?? this.isLoading,
      driverLocation: driverLocation ?? this.driverLocation,
    );
  }
}

class DriverOrderNotifier extends StateNotifier<DriverOrderState> {
  final ApiService _api;
  final SocketService _socket;
  final String orderId;

  DriverOrderNotifier(this._api, this._socket, this.orderId)
      : super(const DriverOrderState()) {
    _loadOrder();
    _setupSocketListeners();
    _startLocationStreaming();
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
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // Named handler references — so we can remove only OUR listener, not all listeners
  late final Function(dynamic) _statusHandler;
  late final Function(dynamic) _cancelledHandler;

  void _setupSocketListeners() {
    _statusHandler = (data) {
      try {
        if (data['orderId'] == orderId && state.order != null) {
          final statusStr = data['status'] as String;
          debugPrint('🚗 Driver screen got status update: $statusStr for order $orderId');
          state = state.copyWith(
            order: state.order!.copyWith(status: _parseStatus(statusStr)),
          );
        }
      } catch (e) {
        debugPrint('❌ Driver status handler error: $e');
      }
    };

    _cancelledHandler = (data) {
      try {
        if (data['orderId'] == orderId && state.order != null) {
          state = state.copyWith(
            order: state.order!.copyWith(status: OrderStatus.cancelled),
          );
        }
      } catch (e) {
        debugPrint('❌ Driver cancel handler error: $e');
      }
    };

    _socket.socket.on('order_status_update', _statusHandler);
    _socket.socket.on('order_cancelled', _cancelledHandler);
  }

  Timer? _locationTimer;

  void _startLocationStreaming() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (state.order != null && (state.order!.status == OrderStatus.driverArriving || state.order!.status == OrderStatus.inTrip)) {
        try {
          final permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
            final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
            _socket.socket.emit('driver_location_update', {
              'orderId': orderId,
              'lat': pos.latitude,
              'lng': pos.longitude,
            });
            state = state.copyWith(driverLocation: Point(latitude: pos.latitude, longitude: pos.longitude));
          }
        } catch (e) {
          debugPrint('GPS streaming error: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    // Remove only our specific handlers, not ALL listeners
    _socket.socket.off('order_status_update', _statusHandler);
    _socket.socket.off('order_cancelled', _cancelledHandler);
    super.dispose();
  }

  OrderStatus _parseStatus(String status) {
    switch (status) {
      case 'DRIVER_ARRIVING': return OrderStatus.driverArriving;
      case 'DRIVER_ARRIVED': return OrderStatus.driverArrived;
      case 'IN_TRIP': return OrderStatus.inTrip;
      case 'COMPLETED': return OrderStatus.completed;
      default: return OrderStatus.searching;
    }
  }

  Future<void> updateStatus(String statusStr) async {
    try {
      final res = await _api.client.patch('/api/order/$orderId/status', data: {'status': statusStr});
      if (res.data['success'] == true) {
        state = state.copyWith(
          order: state.order!.copyWith(status: _parseStatus(statusStr)),
        );
      }
    } catch (_) {}
  }
}

final driverOrderProvider =
    StateNotifierProvider.family<DriverOrderNotifier, DriverOrderState, String>((ref, orderId) {
  final api = ref.read(apiServiceProvider);
  final socket = ref.read(socketServiceProvider);
  return DriverOrderNotifier(api, socket, orderId);
});

// DRIVER ORDER SCREEN
class DriverOrderScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DriverOrderScreen({super.key, required this.orderId});

  @override
  ConsumerState<DriverOrderScreen> createState() => _DriverOrderScreenState();
}

class _DriverOrderScreenState extends ConsumerState<DriverOrderScreen> {
  YandexMapController? _mapController;
  Point? _lastCameraTarget;

  Future<void> _onMapCreated(YandexMapController controller, List<Point> routePts) async {
    _mapController = controller;
    if (routePts.isNotEmpty) {
      // Focus map bounds on route
      await _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: routePts.first,
            zoom: 14,
          ),
        ),
      );
    }
  }

  void _trackDriverCamera(Point driverPoint) {
    if (_mapController == null) return;
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

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(driverOrderProvider(widget.orderId));
    final order = trackingState.order;

    if (trackingState.isLoading || order == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF13131F),
        body: Center(
          child: CircularProgressIndicator(color: OrbitaColors.primary),
        ),
      );
    }

    // Handle cancelled order
    if (order.status == OrderStatus.cancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Buyurtma mijoz tomonidan bekor qilindi'),
              backgroundColor: OrbitaColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          context.go('/home');
        }
      });
    }

    // Centering camera on driver's location if it updates
    final driverLoc = trackingState.driverLocation;
    if (driverLoc != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackDriverCamera(driverLoc);
      });
    }

    final mapObjects = <MapObject>[];
    if (trackingState.routePoints.isNotEmpty) {
      mapObjects.add(PolylineMapObject(
        mapId: const MapObjectId('route'),
        polyline: Polyline(points: trackingState.routePoints),
        strokeColor: OrbitaColors.primary,
        strokeWidth: 4.5,
        outlineColor: Colors.black.withOpacity(0.4),
        outlineWidth: 1.5,
      ));
    }

    mapObjects.add(PlacemarkMapObject(
      mapId: const MapObjectId('pickup'),
      point: Point(latitude: order.fromLocation.lat, longitude: order.fromLocation.lng),
      icon: PlacemarkIcon.single(PlacemarkIconStyle(
        image: BitmapDescriptor.fromAssetImage('assets/icons/pickup_pin.png'),
        scale: 0.45,
      )),
    ));

    mapObjects.add(PlacemarkMapObject(
      mapId: const MapObjectId('destination'),
      point: Point(latitude: order.toLocation.lat, longitude: order.toLocation.lng),
      icon: PlacemarkIcon.single(PlacemarkIconStyle(
        image: BitmapDescriptor.fromAssetImage('assets/icons/destination_pin.png'),
        scale: 0.45,
      )),
    ));

    // Render driver's own location
    if (trackingState.driverLocation != null) {
      mapObjects.add(PlacemarkMapObject(
        mapId: const MapObjectId('driver'),
        point: trackingState.driverLocation!,
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/icons/car_pin.png'),
          scale: 0.45,
        )),
      ));
    }

    // Get current status button configs
    String actionLabel = '';
    String nextStatus = '';
    VoidCallback? onAction;

    if (order.status == OrderStatus.driverArriving) {
      actionLabel = context.tr('arrived');
      nextStatus = 'DRIVER_ARRIVED';
      onAction = () => ref.read(driverOrderProvider(widget.orderId).notifier).updateStatus(nextStatus);
    } else if (order.status == OrderStatus.driverArrived) {
      actionLabel = context.tr('start_trip');
      nextStatus = 'IN_TRIP';
      onAction = () => ref.read(driverOrderProvider(widget.orderId).notifier).updateStatus(nextStatus);
    } else if (order.status == OrderStatus.inTrip) {
      actionLabel = context.tr('end_trip');
      nextStatus = 'COMPLETED';
      onAction = () async {
        await ref.read(driverOrderProvider(widget.orderId).notifier).updateStatus(nextStatus);
        ref.read(driverOrdersProvider.notifier).loadAll();
        if (context.mounted) {
          context.go('/home');
        }
      };
    } else if (order.status == OrderStatus.completed) {
      actionLabel = 'Yopish';
      onAction = () {
        ref.read(driverOrdersProvider.notifier).loadAll();
        context.go('/home');
      };
    }

    return Scaffold(
      body: Stack(
        children: [
          // Map
          YandexMap(
            onMapCreated: (ctrl) => _onMapCreated(ctrl, trackingState.routePoints),
            mapObjects: mapObjects,
            nightModeEnabled: true,
          ),

          // Bottom Action Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF13131F),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.status == OrderStatus.driverArriving
                              ? context.tr('driver_arriving')
                              : order.status == OrderStatus.driverArrived
                                  ? context.tr('driver_arrived')
                                  : order.status == OrderStatus.inTrip
                                      ? context.tr('in_trip')
                                      : context.tr('completed'),
                          style: const TextStyle(
                            color: OrbitaColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                              onPressed: () => context.push('/chat/${order.id}'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Fare & Payment type row for driver
                    Row(
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
                                order.paymentMethod == 'WALLET' ? 'Hamyon (Balansga)' : 'Naqd pul',
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.radio_button_checked, color: OrbitaColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.fromAddress,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: OrbitaColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.toAddress,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OrbitaButton(
                      label: actionLabel,
                      onPressed: onAction,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
