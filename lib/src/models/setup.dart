import 'rule.dart';

enum ValueType {
  percentage,
  fixed,
}

class Setup {
  final String id;
  final String name;
  final String asset;
  final double positionSize;
  final ValueType positionSizeType;
  final double stopLossPercent;
  final ValueType stopLossType;
  final double takeProfitPercent;
  final ValueType takeProfitType;
  final bool useAdvancedRules;
  final List<Rule> rules;
  final DateTime createdAt;

  Setup({
    required this.id,
    required this.name,
    required this.asset,
    required this.positionSize,
    this.positionSizeType = ValueType.fixed,
    required this.stopLossPercent,
    this.stopLossType = ValueType.percentage,
    required this.takeProfitPercent,
    this.takeProfitType = ValueType.percentage,
    this.useAdvancedRules = false,
    this.rules = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'asset': asset,
      'positionSize': positionSize,
      'positionSizeType': positionSizeType.toString(),
      'stopLossPercent': stopLossPercent,
      'stopLossType': stopLossType.toString(),
      'takeProfitPercent': takeProfitPercent,
      'takeProfitType': takeProfitType.toString(),
      'useAdvancedRules': useAdvancedRules,
      'rules': rules.map((rule) => rule.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Setup.fromJson(Map<String, dynamic> json) {
    return Setup(
      id: json['id'],
      name: json['name'],
      asset: json['asset'],
      positionSize: json['positionSize'].toDouble(),
      positionSizeType: ValueType.values.firstWhere(
        (e) => e.toString() == json['positionSizeType'],
        orElse: () => ValueType.fixed,
      ),
      stopLossPercent: json['stopLossPercent'].toDouble(),
      stopLossType: ValueType.values.firstWhere(
        (e) => e.toString() == json['stopLossType'],
        orElse: () => ValueType.percentage,
      ),
      takeProfitPercent: json['takeProfitPercent'].toDouble(),
      takeProfitType: ValueType.values.firstWhere(
        (e) => e.toString() == json['takeProfitType'],
        orElse: () => ValueType.percentage,
      ),
      useAdvancedRules: json['useAdvancedRules'] ?? false,
      rules: (json['rules'] as List<dynamic>?)
              ?.map((ruleJson) => Rule.fromJson(ruleJson))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Setup copyWith({
    String? id,
    String? name,
    String? asset,
    double? positionSize,
    ValueType? positionSizeType,
    double? stopLossPercent,
    ValueType? stopLossType,
    double? takeProfitPercent,
    ValueType? takeProfitType,
    bool? useAdvancedRules,
    List<Rule>? rules,
    DateTime? createdAt,
  }) {
    return Setup(
      id: id ?? this.id,
      name: name ?? this.name,
      asset: asset ?? this.asset,
      positionSize: positionSize ?? this.positionSize,
      positionSizeType: positionSizeType ?? this.positionSizeType,
      stopLossPercent: stopLossPercent ?? this.stopLossPercent,
      stopLossType: stopLossType ?? this.stopLossType,
      takeProfitPercent: takeProfitPercent ?? this.takeProfitPercent,
      takeProfitType: takeProfitType ?? this.takeProfitType,
      useAdvancedRules: useAdvancedRules ?? this.useAdvancedRules,
      rules: rules ?? this.rules,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Métodos de conveniencia para manejar reglas
  void addRule(Rule rule) {
    rules.add(rule);
  }

  void removeRule(String ruleId) {
    rules.removeWhere((rule) => rule.id == ruleId);
  }

  void updateRule(Rule updatedRule) {
    final index = rules.indexWhere((rule) => rule.id == updatedRule.id);
    if (index != -1) {
      rules[index] = updatedRule;
    }
  }

  List<Rule> getActiveRules() {
    return rules.where((rule) => rule.isActive).toList();
  }

  List<Rule> getRulesByType(RuleType type) {
    return rules.where((rule) => rule.type == type).toList();
  }

  // Métodos de conveniencia para obtener valores formateados
  String getPositionSizeDisplay() {
    if (positionSizeType == ValueType.percentage) {
      return '${positionSize.toStringAsFixed(1)}%';
    } else {
      return '\$${positionSize.toStringAsFixed(0)}';
    }
  }

  String getStopLossDisplay() {
    if (stopLossType == ValueType.percentage) {
      return '${stopLossPercent.toStringAsFixed(1)}%';
    } else {
      return '\$${stopLossPercent.toStringAsFixed(0)}';
    }
  }

  String getTakeProfitDisplay() {
    if (takeProfitType == ValueType.percentage) {
      return '${takeProfitPercent.toStringAsFixed(1)}%';
    } else {
      return '\$${takeProfitPercent.toStringAsFixed(0)}';
    }
  }
} 