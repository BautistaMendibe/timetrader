import 'package:flutter/foundation.dart';
import '../models/setup.dart';

class SetupProvider with ChangeNotifier {
  final List<Setup> _setups = [];
  Setup? _selectedSetup;

  List<Setup> get setups => _setups;
  Setup? get selectedSetup => _selectedSetup;

  SetupProvider() {
    _initializeSampleSetups();
  }

  void _initializeSampleSetups() {
    _setups.addAll([
      Setup(
        id: '1',
        name: 'Scalping BTC',
        asset: 'BTC/USD',
        positionSize: 100.0,
        stopLossPercent: 2.0,
        takeProfitPercent: 4.0,
        useAdvancedRules: false,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Setup(
        id: '2',
        name: 'Swing Trading EUR/USD',
        asset: 'EUR/USD',
        positionSize: 500.0,
        stopLossPercent: 1.5,
        takeProfitPercent: 3.0,
        useAdvancedRules: true,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Setup(
        id: '3',
        name: 'Day Trading S&P500',
        asset: 'S&P500',
        positionSize: 1000.0,
        stopLossPercent: 1.0,
        takeProfitPercent: 2.5,
        useAdvancedRules: false,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
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
} 