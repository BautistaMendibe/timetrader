import 'rule.dart';

enum ValueType { percentage, fixed }

enum StopLossType { pips, price }

enum TakeProfitRatio {
  oneToOne('1:1'),
  oneToTwo('1:2'),
  oneToThree('1:3'),
  twoToOne('2:1'),
  threeToOne('3:1'),
  custom('Personalizado');

  const TakeProfitRatio(this.displayName);
  final String displayName;

  double get ratio {
    switch (this) {
      case TakeProfitRatio.oneToOne:
        return 1.0;
      case TakeProfitRatio.oneToTwo:
        return 2.0;
      case TakeProfitRatio.oneToThree:
        return 3.0;
      case TakeProfitRatio.twoToOne:
        return 0.5;
      case TakeProfitRatio.threeToOne:
        return 0.33;
      case TakeProfitRatio.custom:
        return 1.0; // Default for custom
    }
  }
}

class Setup {
  final String id;
  final String name;
  final String asset;
  final double riskPercent;
  final double stopLossDistance;
  final StopLossType stopLossType;
  final TakeProfitRatio takeProfitRatio;
  final double? customTakeProfitRatio;
  final bool useAdvancedRules;
  final List<Rule> rules;
  final DateTime createdAt;
  final bool isExample;
  final String? userId;

  Setup({
    required this.id,
    required this.name,
    required this.asset,
    required this.riskPercent,
    required this.stopLossDistance,
    this.stopLossType = StopLossType.pips,
    this.takeProfitRatio = TakeProfitRatio.oneToTwo,
    this.customTakeProfitRatio,
    this.useAdvancedRules = false,
    this.rules = const [],
    required this.createdAt,
    this.isExample = false,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'asset': asset,
      'riskPercent': riskPercent,
      'stopLossDistance': stopLossDistance,
      'stopLossType': stopLossType.toString(),
      'takeProfitRatio': takeProfitRatio.toString(),
      'customTakeProfitRatio': customTakeProfitRatio,
      'useAdvancedRules': useAdvancedRules,
      'rules': rules.map((rule) => rule.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isExample': isExample,
      'userId': userId,
    };
  }

  factory Setup.fromJson(Map<String, dynamic> json) {
    return Setup(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      asset: json['asset'] ?? '',
      riskPercent: (json['riskPercent'] ?? 1.0).toDouble(),
      stopLossDistance: (json['stopLossDistance'] ?? 0.0).toDouble(),
      stopLossType: StopLossType.values.firstWhere(
        (e) =>
            e.toString() ==
            (json['stopLossType'] ?? StopLossType.pips.toString()),
        orElse: () => StopLossType.pips,
      ),
      takeProfitRatio: TakeProfitRatio.values.firstWhere(
        (e) =>
            e.toString() ==
            (json['takeProfitRatio'] ?? TakeProfitRatio.oneToTwo.toString()),
        orElse: () => TakeProfitRatio.oneToTwo,
      ),
      customTakeProfitRatio: json['customTakeProfitRatio']?.toDouble(),
      useAdvancedRules: json['useAdvancedRules'] ?? false,
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map((ruleJson) => Rule.fromJson(ruleJson))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isExample: json['isExample'] ?? false,
      userId: json['userId'],
    );
  }

  Setup copyWith({
    String? id,
    String? name,
    String? asset,
    double? riskPercent,
    double? stopLossDistance,
    StopLossType? stopLossType,
    TakeProfitRatio? takeProfitRatio,
    double? customTakeProfitRatio,
    bool? useAdvancedRules,
    List<Rule>? rules,
    DateTime? createdAt,
    bool? isExample,
    String? userId,
  }) {
    return Setup(
      id: id ?? this.id,
      name: name ?? this.name,
      asset: asset ?? this.asset,
      riskPercent: riskPercent ?? this.riskPercent,
      stopLossDistance: stopLossDistance ?? this.stopLossDistance,
      stopLossType: stopLossType ?? this.stopLossType,
      takeProfitRatio: takeProfitRatio ?? this.takeProfitRatio,
      customTakeProfitRatio:
          customTakeProfitRatio ?? this.customTakeProfitRatio,
      useAdvancedRules: useAdvancedRules ?? this.useAdvancedRules,
      rules: rules ?? this.rules,
      createdAt: createdAt ?? this.createdAt,
      isExample: isExample ?? this.isExample,
      userId: userId ?? this.userId,
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
  String getRiskPercentDisplay() {
    return '${riskPercent.toStringAsFixed(1)}%';
  }

  String getStopLossDisplay() {
    if (stopLossType == StopLossType.pips) {
      return '${stopLossDistance.toStringAsFixed(1)} pips';
    } else {
      return '\$${stopLossDistance.toStringAsFixed(2)}';
    }
  }

  String getTakeProfitRatioDisplay() {
    if (takeProfitRatio == TakeProfitRatio.custom &&
        customTakeProfitRatio != null) {
      return '1:${customTakeProfitRatio!.toStringAsFixed(1)}';
    }
    return takeProfitRatio.displayName;
  }

  double getEffectiveTakeProfitRatio() {
    if (takeProfitRatio == TakeProfitRatio.custom &&
        customTakeProfitRatio != null) {
      return customTakeProfitRatio!;
    }
    return takeProfitRatio.ratio;
  }
}
