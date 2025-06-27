import 'package:flutter/foundation.dart';
import '../models/simulation_result.dart';
import '../models/candle.dart';
import '../models/setup.dart';

enum SimulationMode {
  automatic,
  manual,
}

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
  
  // Trading state
  bool _inPosition = false;
  double _entryPrice = 0.0;
  double _positionSize = 0.0;
  int _entryCandleIndex = 0;
  double _stopLossPrice = 0.0;
  double _takeProfitPrice = 0.0;
  
  // Simulation mode
  SimulationMode _simulationMode = SimulationMode.automatic;
  double _simulationSpeed = 1.0; // candles per second

  SimulationResult? get currentSimulation => _currentSimulation;
  List<SimulationResult> get simulationHistory => _simulationHistory;
  List<Candle> get historicalData => _historicalData;
  bool get isSimulationRunning => _isSimulationRunning;
  int get currentCandleIndex => _currentCandleIndex;
  double get currentBalance => _currentBalance;
  List<Trade> get currentTrades => _currentTrades;
  List<double> get equityCurve => _equityCurve;
  bool get inPosition => _inPosition;
  double get entryPrice => _entryPrice;
  double get positionSize => _positionSize;
  double get stopLossPrice => _stopLossPrice;
  double get takeProfitPrice => _takeProfitPrice;
  Setup? get currentSetup => _currentSetup;
  SimulationMode get simulationMode => _simulationMode;
  double get simulationSpeed => _simulationSpeed;

  void setHistoricalData(List<Candle> data) {
    debugPrint('🔥 SimulationProvider: setHistoricalData() - Datos recibidos: ${data.length} velas');
    if (data.isNotEmpty) {
      debugPrint('🔥 SimulationProvider: Primera vela: ${data.first.timestamp} - ${data.first.close}');
      debugPrint('🔥 SimulationProvider: Última vela: ${data.last.timestamp} - ${data.last.close}');
    }
    _historicalData = data;
    notifyListeners();
  }

  void startSimulation(Setup setup, DateTime startDate, double speed, double initialBalance) {
    debugPrint('🔥 SimulationProvider: startSimulation() - Setup: ${setup.name}, Balance inicial: $initialBalance');
    _currentSimulation = null;
    _currentCandleIndex = 0;
    _currentBalance = initialBalance;
    _currentTrades = [];
    _equityCurve = [initialBalance];
    _isSimulationRunning = true;
    _currentSetup = setup;
    _simulationSpeed = speed;
    
    // Reset trading state
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
    _entryCandleIndex = 0;
    _stopLossPrice = 0.0;
    _takeProfitPrice = 0.0;
    
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

  // Process next candle in simulation
  void processNextCandle() {
    if (!_isSimulationRunning || _currentCandleIndex >= _historicalData.length - 1) {
      stopSimulation();
      return;
    }

    _currentCandleIndex++;
    final currentCandle = _historicalData[_currentCandleIndex];
    
    debugPrint('🔥 SimulationProvider: Procesando vela ${_currentCandleIndex}: ${currentCandle.timestamp} - Precio: ${currentCandle.close}');
    
    // Check if we need to close position due to stop loss or take profit
    if (_inPosition) {
      _checkStopLossAndTakeProfit(currentCandle);
    }
    
    // Check for new entry signals
    if (!_inPosition) {
      _checkEntrySignals(currentCandle);
    }
    
    // Update equity curve
    _equityCurve.add(_currentBalance);
    notifyListeners();
  }

  void _checkStopLossAndTakeProfit(Candle candle) {
    if (!_inPosition) return;
    
    bool shouldClose = false;
    String closeReason = '';
    
    // Check stop loss
    if (candle.low <= _stopLossPrice) {
      shouldClose = true;
      closeReason = 'Stop Loss';
    }
    
    // Check take profit
    if (candle.high >= _takeProfitPrice) {
      shouldClose = true;
      closeReason = 'Take Profit';
    }
    
    if (shouldClose) {
      _closePosition(candle.close, closeReason);
    }
  }

  void _checkEntrySignals(Candle candle) {
    if (_inPosition || _currentSetup == null) return;
    
    // Simple breakout strategy for demonstration
    // You can implement more sophisticated strategies here
    if (_currentCandleIndex < 20) return; // Need at least 20 candles for analysis
    
    final lookbackPeriod = 20;
    final highPrices = _historicalData
        .skip(_currentCandleIndex - lookbackPeriod)
        .take(lookbackPeriod)
        .map((c) => c.high)
        .toList();
    
    final lowPrices = _historicalData
        .skip(_currentCandleIndex - lookbackPeriod)
        .take(lookbackPeriod)
        .map((c) => c.low)
        .toList();
    
    final resistanceLevel = highPrices.reduce((a, b) => a > b ? a : b);
    final supportLevel = lowPrices.reduce((a, b) => a < b ? a : b);
    
    // Breakout strategy
    if (candle.close > resistanceLevel && candle.volume > _getAverageVolume(lookbackPeriod) * 1.5) {
      _openPosition('buy', candle.close, 'Breakout Long');
    } else if (candle.close < supportLevel && candle.volume > _getAverageVolume(lookbackPeriod) * 1.5) {
      _openPosition('sell', candle.close, 'Breakout Short');
    }
  }

  double _getAverageVolume(int period) {
    final volumes = _historicalData
        .skip(_currentCandleIndex - period)
        .take(period)
        .map((c) => c.volume)
        .toList();
    return volumes.reduce((a, b) => a + b) / volumes.length;
  }

  void _openPosition(String type, double price, String reason) {
    if (_currentSetup == null) return;
    
    _inPosition = true;
    _entryPrice = price;
    _entryCandleIndex = _currentCandleIndex;
    
    // Calculate position size based on setup
    final riskAmount = _currentBalance * (_currentSetup!.stopLossPercent / 100);
    final stopLossDistance = price * (_currentSetup!.stopLossPercent / 100);
    _positionSize = riskAmount / stopLossDistance;
    
    // Set stop loss and take profit
    if (type == 'buy') {
      _stopLossPrice = price - stopLossDistance;
      _takeProfitPrice = price + (price * _currentSetup!.takeProfitPercent / 100);
    } else {
      _stopLossPrice = price + stopLossDistance;
      _takeProfitPrice = price - (price * _currentSetup!.takeProfitPercent / 100);
    }
    
    // Execute trade
    executeTrade(type, price, _positionSize, reason);
    
    debugPrint('🔥 SimulationProvider: Posición abierta - Tipo: $type, Precio: $price, Tamaño: $_positionSize, Razón: $reason');
  }

  void _closePosition(double price, String reason) {
    if (!_inPosition) return;
    
    // Determine trade type for closing
    final closeType = _currentTrades.last.type == 'buy' ? 'sell' : 'buy';
    
    // Execute closing trade
    executeTrade(closeType, price, _positionSize, reason);
    
    // Reset position state
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
    _entryCandleIndex = 0;
    _stopLossPrice = 0.0;
    _takeProfitPrice = 0.0;
    
    debugPrint('🔥 SimulationProvider: Posición cerrada - Precio: $price, Razón: $reason');
  }

  void executeTrade(String type, double price, double quantity, [String? reason]) {
    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _historicalData[_currentCandleIndex].timestamp,
      type: type,
      price: price,
      quantity: quantity,
      candleIndex: _currentCandleIndex,
      reason: reason,
    );
    _currentTrades.add(trade);
    
    // Calculate P&L for closing trades
    if (_currentTrades.length > 1 && _currentTrades.length % 2 == 0) {
      final openTrade = _currentTrades[_currentTrades.length - 2];
      final closeTrade = _currentTrades[_currentTrades.length - 1];
      
      if (openTrade.type != closeTrade.type) {
        double pnl;
        if (openTrade.type == 'buy') {
          pnl = (closeTrade.price - openTrade.price) * quantity;
        } else {
          pnl = (openTrade.price - openTrade.price) * quantity;
        }
        
        closeTrade.pnl = pnl;
        _currentBalance += pnl;
        
        debugPrint('🔥 SimulationProvider: P&L calculado: $pnl, Balance: $_currentBalance');
      }
    }
    
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
    
    debugPrint('🔥 SimulationProvider: Simulación finalizada - P&L: ${_currentSimulation!.netPnL}, Win Rate: ${_currentSimulation!.winRate}');
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
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
    _entryCandleIndex = 0;
    _stopLossPrice = 0.0;
    _takeProfitPrice = 0.0;
    notifyListeners();
  }

  void setSimulationMode(SimulationMode mode) {
    _simulationMode = mode;
    debugPrint('🔥 SimulationProvider: Modo de simulación cambiado a: $mode');
    notifyListeners();
  }

  void setSimulationSpeed(double speed) {
    _simulationSpeed = speed;
    debugPrint('🔥 SimulationProvider: Velocidad de simulación cambiada a: $speed');
    notifyListeners();
  }

  void advanceCandle() {
    if (_simulationMode != SimulationMode.manual) {
      debugPrint('🔥 SimulationProvider: No se puede avanzar manualmente en modo automático');
      return;
    }
    
    if (_currentCandleIndex >= _historicalData.length - 1) {
      debugPrint('🔥 SimulationProvider: Ya se llegó al final de los datos');
      return;
    }
    
    _advanceCandleManually();
    debugPrint('🔥 SimulationProvider: Vela avanzada manualmente a índice: $_currentCandleIndex');
  }

  void _advanceCandleManually() {
    if (_currentCandleIndex >= _historicalData.length - 1) {
      return;
    }

    _currentCandleIndex++;
    final currentCandle = _historicalData[_currentCandleIndex];
    
    debugPrint('🔥 SimulationProvider: Procesando vela ${_currentCandleIndex}: ${currentCandle.timestamp} - Precio: ${currentCandle.close}');
    
    // Check if we need to close position due to stop loss or take profit
    if (_inPosition) {
      _checkStopLossAndTakeProfit(currentCandle);
    }
    
    // Check for new entry signals
    if (!_inPosition) {
      _checkEntrySignals(currentCandle);
    }
    
    // Update equity curve
    _equityCurve.add(_currentBalance);
    notifyListeners();
  }

  void goToCandle(int index) {
    if (index < 0 || index >= _historicalData.length) {
      debugPrint('🔥 SimulationProvider: Índice de vela inválido: $index');
      return;
    }
    
    _currentCandleIndex = index;
    
    // Update equity curve to match the current position
    if (_equityCurve.length <= index) {
      // Fill missing equity curve entries
      while (_equityCurve.length <= index) {
        _equityCurve.add(_currentBalance);
      }
    } else {
      // Trim equity curve to current position
      _equityCurve = _equityCurve.take(index + 1).toList();
    }
    
    debugPrint('🔥 SimulationProvider: Saltando a vela: $index');
    notifyListeners();
  }
} 