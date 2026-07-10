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
