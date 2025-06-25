import 'package:flutter/foundation.dart';
import '../models/simulation_result.dart';
import '../models/candle.dart';
import '../models/setup.dart';

class SimulationProvider with ChangeNotifier {
  SimulationResult? _currentSimulation;
  final List<SimulationResult> _simulationHistory = [];
  List<Candle> _historicalData = [];
  bool _isSimulationRunning = false;
  int _currentCandleIndex = 0;
  double _currentBalance = 10000.0;
  List<Trade> _currentTrades = [];
  List<double> _equityCurve = [];
  Setup? _currentSetup;

  SimulationResult? get currentSimulation => _currentSimulation;
  List<SimulationResult> get simulationHistory => _simulationHistory;
  List<Candle> get historicalData => _historicalData;
  bool get isSimulationRunning => _isSimulationRunning;
  int get currentCandleIndex => _currentCandleIndex;
  double get currentBalance => _currentBalance;
  List<Trade> get currentTrades => _currentTrades;
  List<double> get equityCurve => _equityCurve;

  void setHistoricalData(List<Candle> data) {
    _historicalData = data;
    notifyListeners();
  }

  void startSimulation(Setup setup, DateTime startDate, double speed) {
    _currentSimulation = null;
    _currentCandleIndex = 0;
    _currentBalance = 10000.0;
    _currentTrades = [];
    _equityCurve = [10000.0];
    _isSimulationRunning = true;
    _currentSetup = setup;
    notifyListeners();
  }

  void pauseSimulation() {
    _isSimulationRunning = false;
    notifyListeners();
  }

  void resumeSimulation() {
    _isSimulationRunning = true;
    notifyListeners();
  }

  void stopSimulation() {
    _isSimulationRunning = false;
    _finalizeSimulation();
    notifyListeners();
  }

  void executeTrade(String type, double price, double quantity) {
    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      price: price,
      quantity: quantity,
    );
    _currentTrades.add(trade);
    
    // Simple P&L calculation
    if (type == 'sell' && _currentTrades.length > 1) {
      final lastBuyTrade = _currentTrades.reversed.skip(1).firstWhere((t) => t.type == 'buy');
      final pnl = (price - lastBuyTrade.price) * quantity;
      trade.pnl = pnl;
      _currentBalance += pnl;
    }
    
    _equityCurve.add(_currentBalance);
    notifyListeners();
  }

  void _finalizeSimulation() {
    if (_currentTrades.isEmpty) return;

    final winningTrades = _currentTrades.where((t) => t.pnl > 0).length;
    final winRate = _currentTrades.isNotEmpty ? winningTrades / _currentTrades.length : 0.0;
    
    final maxDrawdown = _calculateMaxDrawdown();
    
    _currentSimulation = SimulationResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      setupId: _currentSetup?.id ?? 'unknown',
      startDate: _historicalData.first.timestamp,
      endDate: _historicalData.last.timestamp,
      initialBalance: 10000.0,
      finalBalance: _currentBalance,
      netPnL: _currentBalance - 10000.0,
      winRate: winRate,
      maxDrawdown: maxDrawdown,
      totalTrades: _currentTrades.length,
      winningTrades: winningTrades,
      trades: _currentTrades,
      equityCurve: _equityCurve,
    );

    _simulationHistory.add(_currentSimulation!);
  }

  double _calculateMaxDrawdown() {
    double maxDrawdown = 0.0;
    double peak = _equityCurve.first;
    
    for (double value in _equityCurve) {
      if (value > peak) {
        peak = value;
      }
      double drawdown = (peak - value) / peak;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
      }
    }
    
    return maxDrawdown;
  }

  void reset() {
    _currentSimulation = null;
    _currentCandleIndex = 0;
    _currentBalance = 10000.0;
    _currentTrades = [];
    _equityCurve = [];
    _isSimulationRunning = false;
    notifyListeners();
  }
} 