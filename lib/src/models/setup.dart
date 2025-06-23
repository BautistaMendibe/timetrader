class Setup {
  final String id;
  final String name;
  final String asset;
  final double positionSize;
  final double stopLossPercent;
  final double takeProfitPercent;
  final bool useAdvancedRules;
  final DateTime createdAt;

  Setup({
    required this.id,
    required this.name,
    required this.asset,
    required this.positionSize,
    required this.stopLossPercent,
    required this.takeProfitPercent,
    this.useAdvancedRules = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'asset': asset,
      'positionSize': positionSize,
      'stopLossPercent': stopLossPercent,
      'takeProfitPercent': takeProfitPercent,
      'useAdvancedRules': useAdvancedRules,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Setup.fromJson(Map<String, dynamic> json) {
    return Setup(
      id: json['id'],
      name: json['name'],
      asset: json['asset'],
      positionSize: json['positionSize'].toDouble(),
      stopLossPercent: json['stopLossPercent'].toDouble(),
      takeProfitPercent: json['takeProfitPercent'].toDouble(),
      useAdvancedRules: json['useAdvancedRules'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
} 