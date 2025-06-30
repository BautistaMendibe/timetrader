import 'package:flutter/foundation.dart';
import '../models/setup.dart';
import '../models/rule.dart';

class SetupProvider with ChangeNotifier {
  final List<Setup> _setups = [];
  final List<Rule> _customRules = [];
  Setup? _selectedSetup;

  List<Setup> get setups => _setups;
  List<Rule> get customRules => _customRules;
  Setup? get selectedSetup => _selectedSetup;

  SetupProvider() {
    _initializeSampleSetups();
    _initializeSampleCustomRules();
  }

  void _initializeSampleSetups() {
    _setups.addAll([
      Setup(
        id: '1',
        name: 'Scalping BTC',
        asset: 'BTC/USD',
        positionSize: 100.0,
        positionSizeType: ValueType.fixed,
        stopLossPercent: 2.0,
        stopLossType: ValueType.percentage,
        takeProfitPercent: 4.0,
        takeProfitType: ValueType.percentage,
        useAdvancedRules: true,
        rules: [
          PredefinedRules.getRuleById('ema_cross')!,
          PredefinedRules.getRuleById('morning_session')!,
          PredefinedRules.getRuleById('volume_spike')!,
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Setup(
        id: '2',
        name: 'Swing Trading EUR/USD',
        asset: 'EUR/USD',
        positionSize: 5.0,
        positionSizeType: ValueType.percentage,
        stopLossPercent: 1.5,
        stopLossType: ValueType.percentage,
        takeProfitPercent: 3.0,
        takeProfitType: ValueType.percentage,
        useAdvancedRules: true,
        rules: [
          PredefinedRules.getRuleById('rsi_oversold')!,
          PredefinedRules.getRuleById('hammer_pattern')!,
          PredefinedRules.getRuleById('support_resistance')!,
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Setup(
        id: '3',
        name: 'Day Trading S&P500',
        asset: 'S&P500',
        positionSize: 1000.0,
        positionSizeType: ValueType.fixed,
        stopLossPercent: 50.0,
        stopLossType: ValueType.fixed,
        takeProfitPercent: 100.0,
        takeProfitType: ValueType.fixed,
        useAdvancedRules: false,
        rules: [
          PredefinedRules.getRuleById('london_session')!,
        ],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  void _initializeSampleCustomRules() {
    _customRules.addAll([
      Rule(
        id: 'custom_1',
        name: 'Mi Regla de Volumen',
        description: 'Volumen 3x mayor que el promedio de 30 períodos',
        type: RuleType.technicalIndicator,
        parameters: {
          'volume_period': 30,
          'multiplier': 3.0,
        },
        isActive: true,
      ),
      Rule(
        id: 'custom_2',
        name: 'Horario Personalizado',
        description: 'Operar solo entre 2:00 PM y 6:00 PM',
        type: RuleType.timeFrame,
        parameters: {
          'start_time': '14:00',
          'end_time': '18:00',
          'timezone': 'local',
        },
        isActive: true,
      ),
    ]);
  }

  void addSetup(Setup setup) {
    _setups.add(setup);
    notifyListeners();
  }

  void updateSetup(Setup setup) {
    final index = _setups.indexWhere((s) => s.id == setup.id);
    if (index != -1) {
      _setups[index] = setup;
      notifyListeners();
    }
  }

  void deleteSetup(String id) {
    _setups.removeWhere((setup) => setup.id == id);
    notifyListeners();
  }

  void selectSetup(Setup setup) {
    _selectedSetup = setup;
    notifyListeners();
  }

  Setup? getSetupById(String id) {
    try {
      return _setups.firstWhere((setup) => setup.id == id);
    } catch (e) {
      return null;
    }
  }

  // Métodos para manejar reglas en setups
  void addRuleToSetup(String setupId, Rule rule) {
    final setup = getSetupById(setupId);
    if (setup != null) {
      final updatedSetup = setup.copyWith(
        rules: [...setup.rules, rule],
      );
      updateSetup(updatedSetup);
    }
  }

  void removeRuleFromSetup(String setupId, String ruleId) {
    final setup = getSetupById(setupId);
    if (setup != null) {
      final updatedRules = setup.rules.where((rule) => rule.id != ruleId).toList();
      final updatedSetup = setup.copyWith(rules: updatedRules);
      updateSetup(updatedSetup);
    }
  }

  void updateRuleInSetup(String setupId, Rule updatedRule) {
    final setup = getSetupById(setupId);
    if (setup != null) {
      final updatedRules = setup.rules.map((rule) {
        return rule.id == updatedRule.id ? updatedRule : rule;
      }).toList();
      final updatedSetup = setup.copyWith(rules: updatedRules);
      updateSetup(updatedSetup);
    }
  }

  void toggleRuleInSetup(String setupId, String ruleId, bool isActive) {
    final setup = getSetupById(setupId);
    if (setup != null) {
      final updatedRules = setup.rules.map((rule) {
        if (rule.id == ruleId) {
          return rule.copyWith(isActive: isActive);
        }
        return rule;
      }).toList();
      final updatedSetup = setup.copyWith(rules: updatedRules);
      updateSetup(updatedSetup);
    }
  }

  // Métodos para reglas personalizadas
  void addCustomRule(Rule rule) {
    _customRules.add(rule);
    notifyListeners();
  }

  void updateCustomRule(Rule rule) {
    final index = _customRules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _customRules[index] = rule;
      notifyListeners();
    }
  }

  void deleteCustomRule(String ruleId) {
    _customRules.removeWhere((rule) => rule.id == ruleId);
    notifyListeners();
  }

  Rule? getCustomRuleById(String id) {
    try {
      return _customRules.firstWhere((rule) => rule.id == id);
    } catch (e) {
      return null;
    }
  }

  // Métodos para obtener reglas predefinidas
  List<Rule> getPredefinedRules() {
    return PredefinedRules.commonRules;
  }

  List<Rule> getPredefinedRulesByType(RuleType type) {
    return PredefinedRules.getRulesByType(type);
  }

  Rule? getPredefinedRuleById(String id) {
    return PredefinedRules.getRuleById(id);
  }

  // Método para obtener todas las reglas disponibles (predefinidas + personalizadas)
  List<Rule> getAllAvailableRules() {
    return [...PredefinedRules.commonRules, ..._customRules];
  }

  List<Rule> getAvailableRulesByType(RuleType type) {
    final predefinedRules = PredefinedRules.getRulesByType(type);
    final customRules = _customRules.where((rule) => rule.type == type).toList();
    return [...predefinedRules, ...customRules];
  }
} 