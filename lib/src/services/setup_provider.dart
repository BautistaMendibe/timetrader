import 'package:flutter/foundation.dart';
import '../models/setup.dart';
import '../models/rule.dart';
import 'firebase_setup_service.dart';

class SetupProvider with ChangeNotifier {
  final List<Setup> _setups = [];
  final List<Rule> _customRules = [];
  Setup? _selectedSetup;
  final FirebaseSetupService _firebaseService = FirebaseSetupService();
  bool _isLoading = false;
  String? _lastDeletedSetupName;

  List<Setup> get setups => _setups;
  List<Rule> get customRules => _customRules;
  Setup? get selectedSetup => _selectedSetup;
  bool get isLoading => _isLoading;

  SetupProvider() {
    _initializeSampleCustomRules();
    _loadSetups();
  }

  Future<void> _loadSetups() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final setups = await _firebaseService.getAllSetups();
      _setups.clear();
      _setups.addAll(setups);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Listen to setups changes
  void startListening() {
    _firebaseService.listenToAllSetups().listen((setups) {
      _setups.clear();
      _setups.addAll(setups);
      notifyListeners();
    });
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

  Future<void> addSetup(Setup setup) async {
    try {
      debugPrint('DEBUG: SetupProvider.addSetup - Iniciando...');
      
      // Temporalmente, agregar el setup localmente para testing
      _setups.add(setup);
      notifyListeners();
      debugPrint('DEBUG: SetupProvider.addSetup - Setup agregado localmente');
      
      // Intentar guardar en Firebase
      try {
        await _firebaseService.addSetup(setup);
        debugPrint('DEBUG: SetupProvider.addSetup - Completado exitosamente en Firebase');
      } catch (firebaseError) {
        debugPrint('DEBUG: SetupProvider.addSetup - Error en Firebase: $firebaseError');
        // No rethrow para que la app funcione sin Firebase
      }
    } catch (e) {
      debugPrint('DEBUG: SetupProvider.addSetup - Error: $e');
      rethrow;
    }
  }

  Future<void> updateSetup(Setup setup) async {
    try {
      await _firebaseService.updateSetup(setup);
      // The setup will be updated in the list through the stream listener
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSetup(String id, {String? setupName}) async {
    try {
      debugPrint('DEBUG: SetupProvider.deleteSetup - Iniciando eliminación del setup: $id');
      await _firebaseService.deleteSetup(id);
      debugPrint('DEBUG: SetupProvider.deleteSetup - Eliminación completada en Firebase');
      
      // Guardar el nombre del setup eliminado para mostrar el snackbar
      if (setupName != null) {
        setLastDeletedSetupName(setupName);
      }
      
      // The setup will be removed from the list through the stream listener
    } catch (e) {
      debugPrint('DEBUG: SetupProvider.deleteSetup - Error: $e');
      rethrow;
    }
  }

  void selectSetup(Setup setup) {
    _selectedSetup = setup;
    notifyListeners();
  }

  Future<Setup?> getSetupById(String id) async {
    try {
      return await _firebaseService.getSetupById(id);
    } catch (e) {
      return null;
    }
  }

  Setup? getSetupByIdSync(String id) {
    try {
      return _setups.firstWhere((setup) => setup.id == id);
    } catch (e) {
      return null;
    }
  }

  // Métodos para manejar reglas en setups
  void addRuleToSetup(String setupId, Rule rule) {
    final setup = getSetupByIdSync(setupId);
    if (setup != null) {
      final updatedSetup = setup.copyWith(
        rules: [...setup.rules, rule],
      );
      updateSetup(updatedSetup);
    }
  }

  void removeRuleFromSetup(String setupId, String ruleId) {
    final setup = getSetupByIdSync(setupId);
    if (setup != null) {
      final updatedRules = setup.rules.where((rule) => rule.id != ruleId).toList();
      final updatedSetup = setup.copyWith(rules: updatedRules);
      updateSetup(updatedSetup);
    }
  }

  void updateRuleInSetup(String setupId, Rule updatedRule) {
    final setup = getSetupByIdSync(setupId);
    if (setup != null) {
      final updatedRules = setup.rules.map((rule) {
        return rule.id == updatedRule.id ? updatedRule : rule;
      }).toList();
      final updatedSetup = setup.copyWith(rules: updatedRules);
      updateSetup(updatedSetup);
    }
  }

  void toggleRuleInSetup(String setupId, String ruleId, bool isActive) {
    final setup = getSetupByIdSync(setupId);
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

  // Métodos para manejar mensajes de confirmación
  String? get lastDeletedSetupName => _lastDeletedSetupName;
  
  void setLastDeletedSetupName(String setupName) {
    _lastDeletedSetupName = setupName;
    notifyListeners();
  }
  
  void clearLastDeletedSetupName() {
    _lastDeletedSetupName = null;
    notifyListeners();
  }
} 