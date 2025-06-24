import 'package:flutter/foundation.dart';
import '../models/setup.dart';

class SetupProvider with ChangeNotifier {
  final List<Setup> _setups = [];
  Setup? _selectedSetup;

  List<Setup> get setups => _setups;
  Setup? get selectedSetup => _selectedSetup;

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