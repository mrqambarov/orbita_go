import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/home_provider.dart';
import '../widgets/address_search_bar.dart';
import '../widgets/booking_bottom_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  YandexMapController? _mapController;
  late AnimationController _bottomSheetController;
  late Animation<double> _bottomSheetAnimation;

  @override
  void initState() {
    super.initState();
    _bottomSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bottomSheetAnimation = CurvedAnimation(
      parent: _bottomSheetController,
      curve: Curves.easeOutCubic,
    );
    _bottomSheetController.forward();
    // Faol buyurtma borligini tekshiramiz
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkActiveOrder());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _bottomSheetController.dispose();
    super.dispose();
  }

  /// Faol buyurtma borligini tekshirish
  Future<void> _checkActiveOrder() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.getActiveOrder(user.id);
      if (res.data['success'] == true && res.data['order'] != null) {
        final orderId = res.data['order']['id'] as String;
        if (mounted) {
          // Faol buyurtmaga qaytish banner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.directions_car_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Faol buyurtmangiz davom etmoqda')),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      context.push('/order/$orderId');
                    },
                    child: const Text('Ko\'rish',
                      style: TextStyle(color: OrbitaColors.accent, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              backgroundColor: OrbitaColors.surfaceLight,
              duration: const Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _onMapCreated(YandexMapController controller) async {
    _mapController = controller;
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    
    final lat = position?.latitude ?? 41.2561;
    final lng = position?.longitude ?? 71.5508;
    
    await _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(
            latitude: lat,
            longitude: lng,
          ),
          zoom: 15,
        ),
      ),
    );
    
    if (position != null) {
      ref.read(homeProvider.notifier).setPickupFromPosition(position);
    } else {
      ref.read(homeProvider.notifier).setPickup(
        Point(latitude: 41.2561, longitude: 71.5508),
        'Kosonsoy markazi',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ── YANDEX MAP ──
          YandexMap(
            onMapCreated: _onMapCreated,
            mapObjects: _buildMapObjects(homeState),
            nightModeEnabled: true,
            onMapTap: (point) {
              if (homeState.selectingDestination) {
                ref.read(homeProvider.notifier).setDestination(point);
              }
            },
          ),

          // ── TOP BAR ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Menu / Avatar
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: OrbitaColors.card.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: OrbitaColors.textPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Address search (from)
                  Expanded(
                    child: AddressSearchBar(
                      hint: 'Qayerdan?',
                      value: homeState.fromAddress,
                      onTap: () => _showAddressSearch(isFrom: true),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // My location button
                  GestureDetector(
                    onTap: _goToMyLocation,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: OrbitaColors.card.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location_rounded,
                        color: OrbitaColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOTTOM BOOKING PANEL ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(_bottomSheetAnimation),
              child: BookingBottomSheet(
                homeState: homeState,
                onTariffSelected: (tariff) {
                  ref.read(homeProvider.notifier).selectTariff(tariff);
                },
                onDestinationSearch: () => _showAddressSearch(isFrom: false),
                onStopSearch: () => _showAddressSearch(isStop: true),
                onStopClear: () => ref.read(homeProvider.notifier).clearStopPoint(),
                onOrderCreate: _createOrder,
                walletBalance: ref.watch(authProvider).user?.walletBalance ?? 0.0,
                onPaymentMethodSelected: (method) {
                  ref.read(homeProvider.notifier).selectPaymentMethod(method);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<MapObject> _buildMapObjects(HomeState state) {
    final objects = <MapObject>[];

    // Pickup marker
    if (state.pickupPoint != null) {
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('pickup'),
          point: Point(
            latitude: state.pickupPoint!.lat,
            longitude: state.pickupPoint!.lng,
          ),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/icons/pickup_pin.png'),
              scale: 0.45,
            ),
          ),
        ),
      );
    }

    // Stopover marker
    if (state.stopPoint != null) {
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('stopover'),
          point: Point(
            latitude: state.stopPoint!.lat,
            longitude: state.stopPoint!.lng,
          ),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/icons/pickup_pin.png'),
              scale: 0.4,
            ),
          ),
        ),
      );
    }

    // Destination marker
    if (state.destinationPoint != null) {
      objects.add(
        PlacemarkMapObject(
          mapId: const MapObjectId('destination'),
          point: Point(
            latitude: state.destinationPoint!.lat,
            longitude: state.destinationPoint!.lng,
          ),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage(
                  'assets/icons/destination_pin.png'),
              scale: 0.45,
            ),
          ),
        ),
      );
    }

    return objects;
  }

  Future<void> _goToMyLocation() async {
    final pos =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (pos != null && _mapController != null) {
      await _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(latitude: pos.latitude, longitude: pos.longitude),
            zoom: 16,
          ),
        ),
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 0.5,
        ),
      );
    }
  }

  void _showAddressSearch({bool isFrom = false, bool isStop = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressSearchModal(
        isFrom: isFrom,
        isStop: isStop,
        onSelected: (address, point) {
          if (isFrom) {
            ref
                .read(homeProvider.notifier)
                .setPickup(point, address);
          } else if (isStop) {
            ref
                .read(homeProvider.notifier)
                .setStopPoint(point, address: address);
          } else {
            ref
                .read(homeProvider.notifier)
                .setDestination(point, address: address);
          }
        },
      ),
    );
  }

  Future<void> _createOrder() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final orderId =
        await ref.read(homeProvider.notifier).createOrder(user.id);
    if (orderId != null && mounted) {
      context.push('/order/$orderId');
    }
  }
}

// ── ADDRESS SEARCH MODAL ──
class _AddressSearchModal extends ConsumerStatefulWidget {
  final bool isFrom;
  final bool isStop;
  final Function(String address, Point point) onSelected;

  const _AddressSearchModal({
    required this.isFrom,
    this.isStop = false,
    required this.onSelected,
  });

  @override
  ConsumerState<_AddressSearchModal> createState() => _AddressSearchModalState();
}

class _AddressSearchModalState extends ConsumerState<_AddressSearchModal> {
  final _controller = TextEditingController();
  bool _searching = false;
  List<dynamic> _favorites = [];
  bool _loadingFavorites = false;

  // Popular Kosonsoy places as initial list
  static const _popularPlaces = [
    _Place('Kosonsoy Markazi (Oila markazi)', 41.2561, 71.5508),
    _Place('Kosonsoy Dehqon Bozori', 41.2612, 71.5471),
    _Place('Kosonsoy Markaziy Shifoxonasi', 41.2530, 71.5550),
    _Place('Kosonsoy Istirohat Bog\'i', 41.2590, 71.5450),
    _Place('Kosonsoy 1-sonli Maktab', 41.2575, 71.5535),
    _Place('Kosonsoy Hokimiyati (MFY)', 41.2565, 71.5495),
  ];

  List<_Place> _results = _popularPlaces;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loadingFavorites = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.getFavoriteAddresses();
      if (res.data['success'] == true && mounted) {
        setState(() {
          _favorites = res.data['favorites'] as List;
          _loadingFavorites = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingFavorites = false);
      }
    }
  }

  Future<void> _saveToFavorites(_Place place) async {
    final labelController = TextEditingController(text: place.name);
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13131F),
        title: const Text('Sevimli manzil sifatida saqlash', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: labelController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nomi (masalan, Uy, Ish)',
            hintStyle: TextStyle(color: OrbitaColors.textHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish', style: TextStyle(color: OrbitaColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, labelController.text.trim()),
            child: const Text('Saqlash', style: TextStyle(color: OrbitaColors.primary)),
          ),
        ],
      ),
    );

    if (label != null && label.isNotEmpty) {
      try {
        final api = ref.read(apiServiceProvider);
        final res = await api.addFavoriteAddress(
          label: label,
          address: place.subtitle,
          lat: place.lat,
          lng: place.lng,
          iconType: label.toLowerCase().contains('uy')
              ? 'HOME'
              : (label.toLowerCase().contains('ish') ? 'WORK' : 'HEART'),
        );
        if (res.data['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sevimli manzil saqlandi')),
          );
          _loadFavorites();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xatolik yuz berdi')),
          );
        }
      }
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = _popularPlaces;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.searchAddress(query);
      if (res.data['success'] == true) {
        final list = res.data['results'] as List;
        final places = list.map((item) {
          final addressParts = (item['address'] as String? ?? '').split(',');
          final subtitle = addressParts.length > 2
              ? '${addressParts[1].trim()}, ${addressParts[2].trim()}'
              : (addressParts.length > 1 ? addressParts[1].trim() : 'Kosonsoy');
          return _Place(
            item['name'] as String,
            (item['lat'] as num).toDouble(),
            (item['lng'] as num).toDouble(),
            subtitle: subtitle,
          );
        }).toList();
        if (mounted) {
          setState(() {
            _results = places;
            _searching = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryEmpty = _controller.text.trim().isEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF13131F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A4E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.isFrom
                    ? 'Qayerdan?'
                    : (widget.isStop ? 'Yo\'l-yo\'lakay to\'xtash?' : 'Qayerga?'),
                prefixIcon: Icon(
                  widget.isFrom
                      ? Icons.radio_button_checked
                      : (widget.isStop ? Icons.adjust_rounded : Icons.location_on),
                  color: widget.isFrom
                      ? OrbitaColors.primary
                      : (widget.isStop ? Colors.purpleAccent : OrbitaColors.error),
                ),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(OrbitaColors.primary),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          if (queryEmpty)
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  if (_favorites.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'Saqlangan manzillar',
                        style: TextStyle(
                          color: OrbitaColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    ..._favorites.map((fav) {
                      final icon = fav['iconType'] == 'HOME'
                          ? Icons.home_rounded
                          : (fav['iconType'] == 'WORK' ? Icons.work_rounded : Icons.favorite_rounded);
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: OrbitaColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: OrbitaColors.primary, size: 20),
                        ),
                        title: Text(
                          fav['label'] as String,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          fav['address'] as String,
                          style: const TextStyle(color: OrbitaColors.textHint, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: OrbitaColors.error, size: 20),
                          onPressed: () async {
                            try {
                              await ref.read(apiServiceProvider).deleteFavoriteAddress(fav['id']);
                              _loadFavorites();
                            } catch (_) {}
                          },
                        ),
                        onTap: () {
                          widget.onSelected(
                            fav['address'] as String,
                            Point(
                                latitude: (fav['lat'] as num).toDouble(),
                                longitude: (fav['lng'] as num).toDouble()),
                          );
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const Divider(color: Color(0xFF2A2A3E), height: 30),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Ommabop joylar',
                      style: TextStyle(
                        color: OrbitaColors.textHint,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ..._popularPlaces.map((place) {
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.place_rounded, color: Colors.white70, size: 20),
                      ),
                      title: Text(
                        place.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        place.subtitle,
                        style: const TextStyle(color: OrbitaColors.textHint, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite_border_rounded, color: OrbitaColors.primary, size: 20),
                        onPressed: () => _saveToFavorites(place),
                      ),
                      onTap: () {
                        widget.onSelected(
                          place.name,
                          Point(latitude: place.lat, longitude: place.lng),
                        );
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final place = _results[i];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: OrbitaColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: OrbitaColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      place.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      place.subtitle,
                      style: const TextStyle(color: OrbitaColors.textHint, fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite_border_rounded, color: OrbitaColors.primary, size: 20),
                      onPressed: () => _saveToFavorites(place),
                    ),
                    onTap: () {
                      widget.onSelected(
                        place.name,
                        Point(latitude: place.lat, longitude: place.lng),
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Place {
  final String name;
  final String subtitle;
  final double lat;
  final double lng;

  const _Place(this.name, this.lat, this.lng, {this.subtitle = 'Kosonsoy, Namangan'});
}
