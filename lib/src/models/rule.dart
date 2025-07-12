enum RuleType {
  technicalIndicator,
  candlestickPattern,
  timeFrame,
  other,
}

class Rule {
  final String id;
  final String name;
  final String description;
  final RuleType type;
  final Map<String, dynamic> parameters;
  final bool isActive;

  Rule({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.parameters = const {},
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toString(),
      'parameters': parameters,
      'isActive': isActive,
    };
  }

  factory Rule.fromJson(Map<String, dynamic> json) {
    return Rule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: RuleType.values.firstWhere(
        (e) => e.toString() == (json['type'] ?? RuleType.other.toString()),
        orElse: () => RuleType.other,
      ),
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      isActive: json['isActive'] ?? true,
    );
  }

  Rule copyWith({
    String? id,
    String? name,
    String? description,
    RuleType? type,
    Map<String, dynamic>? parameters,
    bool? isActive,
  }) {
    return Rule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      parameters: parameters ?? this.parameters,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Reglas predefinidas comunes
class PredefinedRules {
  static List<Rule> get commonRules => [
        Rule(
          id: 'ema_cross',
          name: 'EMA 10 cruza EMA 5',
          description: 'Cuando la EMA de 10 períodos cruza por encima de la EMA de 5 períodos',
          type: RuleType.technicalIndicator,
          parameters: {
            'ema1': 10,
            'ema2': 5,
            'direction': 'bullish',
          },
        ),
        Rule(
          id: 'rsi_oversold',
          name: 'RSI en sobreventa',
          description: 'Cuando el RSI está por debajo de 30',
          type: RuleType.technicalIndicator,
          parameters: {
            'rsi_period': 14,
            'threshold': 30,
            'condition': 'below',
          },
        ),
        Rule(
          id: 'rsi_overbought',
          name: 'RSI en sobrecompra',
          description: 'Cuando el RSI está por encima de 70',
          type: RuleType.technicalIndicator,
          parameters: {
            'rsi_period': 14,
            'threshold': 70,
            'condition': 'above',
          },
        ),
        Rule(
          id: 'doji_pattern',
          name: 'Patrón Doji',
          description: 'Formación de vela Doji (apertura y cierre similares)',
          type: RuleType.candlestickPattern,
          parameters: {
            'pattern': 'doji',
            'sensitivity': 0.1,
          },
        ),
        Rule(
          id: 'hammer_pattern',
          name: 'Patrón Martillo',
          description: 'Formación de vela Martillo (reversión alcista)',
          type: RuleType.candlestickPattern,
          parameters: {
            'pattern': 'hammer',
            'body_ratio': 0.3,
          },
        ),
        Rule(
          id: 'shooting_star',
          name: 'Patrón Estrella Fugaz',
          description: 'Formación de vela Estrella Fugaz (reversión bajista)',
          type: RuleType.candlestickPattern,
          parameters: {
            'pattern': 'shooting_star',
            'body_ratio': 0.3,
          },
        ),
        Rule(
          id: 'morning_session',
          name: 'Sesión de Mañana',
          description: 'Operar solo entre 10:00 AM y 1:00 PM',
          type: RuleType.timeFrame,
          parameters: {
            'start_time': '10:00',
            'end_time': '13:00',
            'timezone': 'local',
          },
        ),
        Rule(
          id: 'london_session',
          name: 'Sesión de Londres',
          description: 'Operar durante la sesión de Londres (8:00 AM - 4:00 PM GMT)',
          type: RuleType.timeFrame,
          parameters: {
            'start_time': '08:00',
            'end_time': '16:00',
            'timezone': 'GMT',
          },
        ),
        Rule(
          id: 'volume_spike',
          name: 'Pico de Volumen',
          description: 'Cuando el volumen es 50% mayor que el promedio de los últimos 20 períodos',
          type: RuleType.technicalIndicator,
          parameters: {
            'volume_period': 20,
            'multiplier': 1.5,
          },
        ),
        Rule(
          id: 'support_resistance',
          name: 'Soporte y Resistencia',
          description: 'Precio cerca de niveles clave de soporte o resistencia',
          type: RuleType.technicalIndicator,
          parameters: {
            'tolerance_percent': 0.5,
            'lookback_periods': 50,
          },
        ),
      ];

  static List<Rule> getRulesByType(RuleType type) {
    return commonRules.where((rule) => rule.type == type).toList();
  }

  static Rule? getRuleById(String id) {
    try {
      return commonRules.firstWhere((rule) => rule.id == id);
    } catch (e) {
      return null;
    }
  }
} 