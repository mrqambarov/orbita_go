import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../../core/localization/translations.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

// Driver Stats Model
class DriverStats {
  final int todayTrips;
  final double todayEarnings;
  final int totalTrips;
  final double rating;
  final double walletBalance;
  final bool isOnline;
  final bool isVerified;

  const DriverStats({
    this.todayTrips = 0,
    this.todayEarnings = 0,
    this.totalTrips = 0,
    this.rating = 5.0,
    this.walletBalance = 0,
    this.isOnline = false,
    this.isVerified = false,
  });
}

// Driver Orders State
class DriverOrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool isTogglingOnline;
  final DriverStats stats;
  final String? errorMessage;
  final List<dynamic> hotspots;

  const DriverOrdersState({
    required this.orders,
    this.isLoading = false,
    this.isTogglingOnline = false,
    this.stats = const DriverStats(),
    this.errorMessage,
    this.hotspots = const [],
  });

  DriverOrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isTogglingOnline,
    DriverStats? stats,
    String? errorMessage,
    List<dynamic>? hotspots,
  }) {
    return DriverOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isTogglingOnline: isTogglingOnline ?? this.isTogglingOnline,
      stats: stats ?? this.stats,
      errorMessage: errorMessage,
      hotspots: hotspots ?? this.hotspots,
    );
  }
}

// Notifier
class DriverOrdersNotifier extends StateNotifier<DriverOrdersState> {
  final ApiService _api;
  final SocketService _socket;
  Timer? _timer;

  DriverOrdersNotifier(this._api, this._socket)
      : super(const DriverOrdersState(orders: [])) {
    loadAll();
    _setupSocketListeners();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => loadAvailableOrders());
  }

  Future<void> loadAll() async {
    await Future.wait([loadStats(), loadAvailableOrders(), loadHeatmap()]);
  }

  Future<void> loadHeatmap() async {
    try {
      final res = await _api.client.get('/api/driver/heatmap');
      if (res.data['success'] == true && mounted) {
        state = state.copyWith(hotspots: res.data['hotspots'] as List);
      }
    } catch (e) {
      debugPrint('Driver heatmap error: $e');
    }
  }

  Future<void> loadStats() async {
    try {
      final res = await _api.client.get('/api/driver/stats');
      if (res.data['success'] == true) {
        final s = res.data['stats'];
        state = state.copyWith(
          stats: DriverStats(
            todayTrips: s['todayTrips'] ?? 0,
            todayEarnings: (s['todayEarnings'] ?? 0).toDouble(),
            totalTrips: s['totalTrips'] ?? 0,
            rating: (s['rating'] ?? 5.0).toDouble(),
            walletBalance: (s['walletBalance'] ?? 0).toDouble(),
            isOnline: s['isOnline'] ?? false,
            isVerified: s['isVerified'] ?? false,
          ),
        );
      }
    } catch (e) {
      debugPrint('Driver stats error: $e');
    }
  }

  Future<void> loadAvailableOrders({bool playAlert = false}) async {
    try {
      final res = await _api.client.get('/api/order/available');
      if (res.data['success'] == true) {
        final list = res.data['orders'] as List;
        final ordersList = list.map((item) {
          return OrderModel(
            id: item['id'] as String,
            userId: item['userId'] as String,
            fromLocation: LocationPoint(
              lat: (item['fromLocation']['lat'] as num).toDouble(),
              lng: (item['fromLocation']['lng'] as num).toDouble(),
            ),
            toLocation: LocationPoint(
              lat: (item['toLocation']['lat'] as num).toDouble(),
              lng: (item['toLocation']['lng'] as num).toDouble(),
            ),
            fromAddress: item['fromAddress'] as String,
            toAddress: item['toAddress'] as String,
            price: (item['price'] as num).toDouble(),
            status: OrderStatus.searching,
            createdAt: DateTime.now(),
            distanceKm: (item['distanceKm'] as num?)?.toDouble(),
            tariff: item['tariff'] as String?,
            clientName: item['clientName'] as String?,
            clientPhone: item['clientPhone'] as String?,
          );
        }).toList();

        final oldIds = state.orders.map((o) => o.id).toSet();
        final hasNewOrder = ordersList.any((o) => !oldIds.contains(o.id));

        if (playAlert && state.stats.isOnline && hasNewOrder) {
          // Play vibration pattern (Beep/Vibe simulation)
          Future.forEach(List.generate(3, (index) => index), (_) async {
            HapticFeedback.vibrate();
            await Future.delayed(const Duration(milliseconds: 300));
          });
          SystemSound.play(SystemSoundType.click);
        }

        state = state.copyWith(orders: ordersList, errorMessage: null);
        loadHeatmap();
      }
    } catch (e) {
      debugPrint('Driver available orders error: $e');
    }
  }

  void _setupSocketListeners() {
    _socket.socket.on('new_order', (_) => loadAvailableOrders(playAlert: true));
    _socket.socket.on('order_cancelled', (_) => loadAvailableOrders());
  }

  Future<bool> acceptOrder(String orderId) async {
    try {
      final res = await _api.client.patch('/api/order/$orderId/accept');
      if (res.data['success'] == true) {
        state = state.copyWith(orders: []);
        loadStats();
        return true;
      }
      state = state.copyWith(errorMessage: res.data['message'] ?? 'Xatolik yuz berdi');
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Serverga ulanishda xatolik');
      debugPrint('Accept order error: $e');
      return false;
    }
  }

  Future<void> toggleOnline() async {
    state = state.copyWith(isTogglingOnline: true);
    try {
      final res = await _api.client.patch('/api/driver/toggle-online');
      if (res.data['success'] == true) {
        final newOnline = res.data['isOnline'] as bool;
        final current = state.stats;
        state = state.copyWith(
          isTogglingOnline: false,
          stats: DriverStats(
            todayTrips: current.todayTrips,
            todayEarnings: current.todayEarnings,
            totalTrips: current.totalTrips,
            rating: current.rating,
            walletBalance: current.walletBalance,
            isOnline: newOnline,
            isVerified: current.isVerified,
          ),
        );
        if (!newOnline) state = state.copyWith(orders: []);
      } else {
        state = state.copyWith(isTogglingOnline: false);
      }
    } catch (e) {
      state = state.copyWith(isTogglingOnline: false);
      debugPrint('Toggle online error: $e');
    }
  }

  void clearError() => state = state.copyWith(errorMessage: null);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final driverOrdersProvider =
    StateNotifierProvider<DriverOrdersNotifier, DriverOrdersState>((ref) {
  final api = ref.read(apiServiceProvider);
  final socket = ref.read(socketServiceProvider);
  return DriverOrdersNotifier(api, socket);
});

// DRIVER HOME SCREEN
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  YandexMapController? _mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = ref.read(authProvider);
      final user = auth.user;
      if (user != null) {
        ref.read(socketServiceProvider).connect(user.id, isDriver: user.isDriver);
      }
      ref.read(driverOrdersProvider.notifier).loadStats();
      ref.read(driverOrdersProvider.notifier).loadAvailableOrders();
    }
  }

  Future<void> _onMapCreated(YandexMapController controller) async {
    _mapController = controller;
    await _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: Point(latitude: 41.2561, longitude: 71.5508),
          zoom: 14,
        ),
      ),
    );
  }

  Future<void> _showAcceptDialog(OrderModel order) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Buyurtmani qabul qilish',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.radio_button_checked, color: OrbitaColors.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(order.fromAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis, maxLines: 2)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on, color: OrbitaColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(order.toAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis, maxLines: 2)),
            ]),
            const Divider(color: Color(0xFF2A2A3E), height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.price.toStringAsFixed(0)} so\'m',
                  style: const TextStyle(
                      color: OrbitaColors.primary, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                if (order.distanceKm != null)
                  Text('${order.distanceKm} km',
                      style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OrbitaColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Qabul qilish',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await ref.read(driverOrdersProvider.notifier).acceptOrder(order.id);
      if (ok && mounted) {
        HapticFeedback.heavyImpact();
        context.push('/driver-order/${order.id}');
      } else if (mounted) {
        final err = ref.read(driverOrdersProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Buyurtmani qabul qilishda xatolik'),
          backgroundColor: OrbitaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        ref.read(driverOrdersProvider.notifier).clearError();
      }
    }
  }

  Future<void> _callClient(String phone) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverOrdersProvider);
    final stats = driverState.stats;

    final mapObjects = <MapObject>[];
    
    // Render hotspots heatmap overlays
    for (var i = 0; i < driverState.hotspots.length; i++) {
      final hs = driverState.hotspots[i];
      final lat = (hs['lat'] as num).toDouble();
      final lng = (hs['lng'] as num).toDouble();
      final intensity = (hs['intensity'] as num).toDouble();

      mapObjects.add(CircleMapObject(
        mapId: MapObjectId('heatmap_$i'),
        circle: Circle(
          center: Point(latitude: lat, longitude: lng),
          radius: 120.0,
        ),
        strokeColor: Colors.orange.withOpacity(0.1),
        strokeWidth: 1.0,
        fillColor: Colors.red.withOpacity(0.25 * intensity),
      ));
    }

    for (var order in driverState.orders) {
      mapObjects.add(PlacemarkMapObject(
        mapId: MapObjectId('order_${order.id}'),
        point: Point(latitude: order.fromLocation.lat, longitude: order.fromLocation.lng),
        icon: PlacemarkIcon.single(PlacemarkIconStyle(
          image: BitmapDescriptor.fromAssetImage('assets/icons/pickup_pin.png'),
          scale: 0.45,
        )),
      ));
    }

    return Scaffold(
      body: Stack(
        children: [
          YandexMap(onMapCreated: _onMapCreated, mapObjects: mapObjects, nightModeEnabled: true),

          // TOP HEADER
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Profile button
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xCC13131F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2A2A3E)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_rounded, color: OrbitaColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text('Profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),

                    // ONLINE/OFFLINE toggle with pulse animation
                    GestureDetector(
                      onTap: driverState.isTogglingOnline ? null : () async {
                        HapticFeedback.mediumImpact();
                        await ref.read(driverOrdersProvider.notifier).toggleOnline();
                      },
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, child) => Transform.scale(
                          scale: stats.isOnline ? _pulseAnimation.value : 1.0,
                          child: child,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: stats.isOnline ? const Color(0xFF1E3A2F) : const Color(0xFF2A1F1F),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: stats.isOnline ? Colors.green.withOpacity(0.6) : Colors.red.withOpacity(0.4),
                            ),
                            boxShadow: stats.isOnline
                                ? [BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)]
                                : [],
                          ),
                          child: driverState.isTogglingOnline
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Row(children: [
                                  Icon(Icons.circle,
                                      color: stats.isOnline ? Colors.green : Colors.red, size: 10),
                                  const SizedBox(width: 8),
                                  Text(stats.isOnline ? 'ONLINE' : 'OFFLINE',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ]),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Stats strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xCC13131F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(icon: Icons.directions_car_rounded, label: 'Bugungi', value: '${stats.todayTrips} ta'),
                      Container(width: 1, height: 28, color: const Color(0xFF2A2A3E)),
                      _StatItem(icon: Icons.account_balance_wallet_rounded, label: 'Daromad',
                          value: '${(stats.todayEarnings / 1000).toStringAsFixed(0)}K', valueColor: OrbitaColors.primary),
                      Container(width: 1, height: 28, color: const Color(0xFF2A2A3E)),
                      _StatItem(icon: Icons.star_rounded, label: 'Reyting',
                          value: stats.rating.toStringAsFixed(1), valueColor: Colors.amber),
                      Container(width: 1, height: 28, color: const Color(0xFF2A2A3E)),
                      GestureDetector(
                        onTap: () => context.push('/driver-wallet'),
                        child: _StatItem(icon: Icons.account_balance_wallet_outlined, label: 'Balans',
                            value: '${(stats.walletBalance / 1000).toStringAsFixed(0)}K',
                            valueColor: stats.walletBalance < 5000 ? OrbitaColors.error : Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // BOTTOM ORDERS PANEL
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.46),
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
                    const SizedBox(height: 12),
                    Center(child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: const Color(0xFF3A3A4E), borderRadius: BorderRadius.circular(2)),
                    )),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mavjud buyurtmalar',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          if (driverState.orders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: OrbitaColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${driverState.orders.length} ta',
                                  style: const TextStyle(color: OrbitaColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: !stats.isOnline
                          ? _OfflineState()
                          : driverState.orders.isEmpty
                              ? _EmptyOrdersState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                  itemCount: driverState.orders.length,
                                  itemBuilder: (context, idx) {
                                    final order = driverState.orders[idx];
                                    return _OrderCard(
                                      order: order,
                                      onAccept: () => _showAcceptDialog(order),
                                      onCall: order.clientPhone != null ? () => _callClient(order.clientPhone!) : null,
                                    );
                                  },
                                ),
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

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _StatItem({required this.icon, required this.label, required this.value, this.valueColor = Colors.white});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: valueColor, size: 15),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback? onCall;
  const _OrderCard({required this.order, required this.onAccept, this.onCall});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        children: [
          if (order.clientName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: OrbitaColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_rounded, color: OrbitaColors.primary, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(order.clientName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  if (onCall != null)
                    GestureDetector(
                      onTap: onCall,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: OrbitaColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.phone_rounded, color: OrbitaColors.success, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          Row(children: [
            const Icon(Icons.radio_button_checked, color: OrbitaColors.primary, size: 15),
            const SizedBox(width: 7),
            Expanded(child: Text(order.fromAddress,
                style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(width: 1, height: 12, color: const Color(0xFF3A3A4E)),
          ),
          Row(children: [
            const Icon(Icons.location_on, color: OrbitaColors.error, size: 15),
            const SizedBox(width: 7),
            Expanded(child: Text(order.toAddress,
                style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${order.price.toStringAsFixed(0)} so\'m',
                      style: const TextStyle(color: OrbitaColors.primary, fontSize: 17, fontWeight: FontWeight.bold)),
                  if (order.distanceKm != null)
                    Text('${order.distanceKm} km · ${order.tariff ?? 'standard'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrbitaColors.primary,
                  minimumSize: const Size(95, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 0,
                ),
                onPressed: onAccept,
                child: const Text('Qabul', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: OrbitaColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.search_rounded, color: OrbitaColors.primary, size: 28)),
        const SizedBox(height: 12),
        const Text('Yangi buyurtmalar kutilmoqda...', style: TextStyle(color: Colors.white54, fontSize: 14)),
      ]),
    ),
  );
}

class _OfflineState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 28)),
        const SizedBox(height: 12),
        const Text('ONLINE holatga o\'ting', style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Buyurtmalarni qabul qilish uchun', style: TextStyle(color: Colors.white30, fontSize: 12)),
      ]),
    ),
  );
}
