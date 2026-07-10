// User model
class UserModel {
  final String id;
  final String phoneNumber;
  final String? fullName;
  final String? username;
  final String? orbitaId;
  final String? avatarUrl;
  final double walletBalance;
  final bool isVerified;
  final String role; // 'CLIENT' | 'DRIVER' | 'ADMIN'

  const UserModel({
    required this.id,
    required this.phoneNumber,
    this.fullName,
    this.username,
    this.orbitaId,
    this.avatarUrl,
    this.walletBalance = 0.0,
    this.isVerified = false,
    this.role = 'CLIENT',
  });

  bool get isDriver => role == 'DRIVER';
  bool get isAdmin => role == 'ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      fullName: json['fullName'],
      username: json['username'],
      orbitaId: json['orbitaId'],
      avatarUrl: json['avatarUrl'],
      walletBalance: (json['walletBalance'] ?? 0.0).toDouble(),
      isVerified: json['isVerified'] ?? false,
      role: json['role'] ?? 'CLIENT',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'fullName': fullName,
        'username': username,
        'orbitaId': orbitaId,
        'avatarUrl': avatarUrl,
        'walletBalance': walletBalance,
        'isVerified': isVerified,
        'role': role,
      };

  UserModel copyWith({
    String? fullName,
    String? username,
    String? avatarUrl,
    double? walletBalance,
    bool? isVerified,
    String? role,
  }) {
    return UserModel(
      id: id,
      phoneNumber: phoneNumber,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      orbitaId: orbitaId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
    );
  }
}

// Order model
enum OrderStatus {
  searching,
  found,
  driverArriving,
  driverArrived,
  inTrip,
  completed,
  cancelled,
}

class OrderModel {
  final String id;
  final String userId;
  final LocationPoint fromLocation;
  final LocationPoint toLocation;
  final String fromAddress;
  final String toAddress;
  final double price;
  final OrderStatus status;
  final DriverInfo? driver;
  final DateTime createdAt;
  final String? tariff;
  final double? distanceKm; // float (masalan: 3.7 km)
  final int? durationMin;
  final String paymentMethod; // 'CASH' or 'WALLET'
  // Driver-side fields (from available orders list)
  final String? clientName;
  final String? clientPhone;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.fromLocation,
    required this.toLocation,
    required this.fromAddress,
    required this.toAddress,
    required this.price,
    required this.status,
    this.driver,
    required this.createdAt,
    this.tariff,
    this.distanceKm,
    this.durationMin,
    this.paymentMethod = 'CASH',
    this.clientName,
    this.clientPhone,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      fromLocation: LocationPoint.fromJson(json['fromLocation'] ?? {}),
      toLocation: LocationPoint.fromJson(json['toLocation'] ?? {}),
      fromAddress: json['fromAddress'] ?? '',
      toAddress: json['toAddress'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      status: _parseStatus(json['status']),
      driver: json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      tariff: json['tariff'],
      distanceKm: json['distanceKm'] != null ? (json['distanceKm'] as num).toDouble() : null,
      durationMin: (json['durationMin'] as num?)?.toInt(),
      paymentMethod: json['paymentMethod'] ?? 'CASH',
      clientName: json['clientName'],
      clientPhone: json['clientPhone'],
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status) {
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

  bool get isActive => [
    OrderStatus.searching,
    OrderStatus.found,
    OrderStatus.driverArriving,
    OrderStatus.driverArrived,
    OrderStatus.inTrip,
  ].contains(status);

  OrderModel copyWith({
    OrderStatus? status,
    DriverInfo? driver,
    double? price,
    String? paymentMethod,
  }) {
    return OrderModel(
      id: id,
      userId: userId,
      fromLocation: fromLocation,
      toLocation: toLocation,
      fromAddress: fromAddress,
      toAddress: toAddress,
      price: price ?? this.price,
      status: status ?? this.status,
      driver: driver ?? this.driver,
      createdAt: createdAt,
      tariff: tariff,
      distanceKm: distanceKm,
      durationMin: durationMin,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      clientName: clientName,
      clientPhone: clientPhone,
    );
  }
}

class LocationPoint {
  final double lat;
  final double lng;

  const LocationPoint({required this.lat, required this.lng});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class DriverInfo {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String carModel;
  final String carColor;
  final String carNumber;
  final double rating;
  final String? avatarUrl;
  final LocationPoint? currentLocation;

  const DriverInfo({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.carModel,
    required this.carColor,
    required this.carNumber,
    required this.rating,
    this.avatarUrl,
    this.currentLocation,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      carModel: json['carModel'] ?? '',
      carColor: json['carColor'] ?? '',
      carNumber: json['carNumber'] ?? '',
      rating: (json['rating'] ?? 5.0).toDouble(),
      avatarUrl: json['avatarUrl'],
      currentLocation: json['currentLocation'] != null
          ? LocationPoint.fromJson(json['currentLocation'])
          : null,
    );
  }

  DriverInfo copyWith({LocationPoint? currentLocation}) {
    return DriverInfo(
      id: id,
      fullName: fullName,
      phoneNumber: phoneNumber,
      carModel: carModel,
      carColor: carColor,
      carNumber: carNumber,
      rating: rating,
      avatarUrl: avatarUrl,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}

// Taxi tariffs
class TariffModel {
  final String id;
  final String name;
  final String icon;
  final String description;
  final double basePrice;
  final double pricePerKm;
  final int minMinutes;
  final int maxMinutes;

  const TariffModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.basePrice,
    required this.pricePerKm,
    required this.minMinutes,
    required this.maxMinutes,
  });

  static List<TariffModel> get defaults => [
        const TariffModel(
          id: 'standard',
          name: 'Standard',
          icon: '🚗',
          description: 'Qulay va arzon',
          basePrice: 8000,
          pricePerKm: 1500,
          minMinutes: 5,
          maxMinutes: 10,
        ),
        const TariffModel(
          id: 'comfort',
          name: 'Comfort',
          icon: '🚙',
          description: 'Keng va qulay',
          basePrice: 12000,
          pricePerKm: 2200,
          minMinutes: 4,
          maxMinutes: 8,
        ),
        const TariffModel(
          id: 'business',
          name: 'Business',
          icon: '🚘',
          description: 'Premium xizmat',
          basePrice: 20000,
          pricePerKm: 3500,
          minMinutes: 3,
          maxMinutes: 6,
        ),
      ];

  double calculatePrice(double distanceKm) {
    return basePrice + (pricePerKm * distanceKm);
  }
}
