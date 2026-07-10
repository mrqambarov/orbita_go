class QuestModel {
  final String id;
  final String title;
  final String description;
  final String targetType; // 'LOCATION' | 'STEPS'
  final int targetSteps;
  final double? targetLat;
  final double? targetLng;
  final String targetName;
  final double rewardCoins;
  final String rewardCoupon;
  final String rewardPromoCode;
  final bool isCompleted;
  final double? distanceToTarget; // in meters, local calculation only

  const QuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetType,
    this.targetSteps = 0,
    this.targetLat,
    this.targetLng,
    this.targetName = '',
    this.rewardCoins = 0.0,
    this.rewardCoupon = '',
    this.rewardPromoCode = '',
    this.isCompleted = false,
    this.distanceToTarget,
  });

  QuestModel copyWith({
    bool? isCompleted,
    double? distanceToTarget,
  }) {
    return QuestModel(
      id: id,
      title: title,
      description: description,
      targetType: targetType,
      targetSteps: targetSteps,
      targetLat: targetLat,
      targetLng: targetLng,
      targetName: targetName,
      rewardCoins: rewardCoins,
      rewardCoupon: rewardCoupon,
      rewardPromoCode: rewardPromoCode,
      isCompleted: isCompleted ?? this.isCompleted,
      distanceToTarget: distanceToTarget ?? this.distanceToTarget,
    );
  }

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      targetType: json['targetType'] ?? 'STEPS',
      targetSteps: json['targetSteps'] ?? 0,
      targetLat: json['targetLat']?.toDouble(),
      targetLng: json['targetLng']?.toDouble(),
      targetName: json['targetName'] ?? '',
      rewardCoins: (json['rewardCoins'] ?? 0.0).toDouble(),
      rewardCoupon: json['rewardCoupon'] ?? '',
      rewardPromoCode: json['rewardPromoCode'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetType': targetType,
        'targetSteps': targetSteps,
        'targetLat': targetLat,
        'targetLng': targetLng,
        'targetName': targetName,
        'rewardCoins': rewardCoins,
        'rewardCoupon': rewardCoupon,
        'rewardPromoCode': rewardPromoCode,
        'isCompleted': isCompleted,
      };
}
