class TransactionModel {
  final String id;
  final String userId;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final String type;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.type,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      isCredit: json['isCredit'] ?? false,
      type: json['type'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'isCredit': isCredit,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
      };
}
