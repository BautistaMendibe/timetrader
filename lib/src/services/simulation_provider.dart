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
  List<Trade> _completedTrades = []; // Lista de trades individuales (para compatibilidad)
  List<CompletedTrade> _completedOperations = []; // Nueva lista para operaciones completas
  List<double> _equityCurve = [];
  Setup? _currentSetup;
  
  // Trading state
  bool _inPosition = false;
  double _entryPrice = 0.0;
  double _positionSize = 0.0;
  double _stopLossPrice = 0.0;
  double _takeProfitPrice = 0.0;
  String _manualPositionType = 'buy'; // 'buy' or 'sell'
  
  // Simulation mode
  SimulationMode _simulationMode = SimulationMode.manual;
  double _simulationSpeed = 1.0; // candles per second

  double? _manualStopLossPercent;
  double? _manualTakeProfitPercent;

  SimulationResult? get currentSimulation => _currentSimulation;
  List<SimulationResult> get simulationHistory => _simulationHistory;
  List<Candle> get historicalData => _historicalData;
  bool get isSimulationRunning => _isSimulationRunning;
  int get currentCandleIndex => _currentCandleIndex;
  double get currentBalance => _currentBalance;
  List<Trade> get currentTrades => _currentTrades;
  List<Trade> get completedTrades => _completedTrades; // Getter para trades completados
  List<CompletedTrade> get completedOperations => _completedOperations; // Getter para operaciones completas
  List<double> get equityCurve => _equityCurve;
  bool get inPosition => _inPosition;
  double get entryPrice => _entryPrice;
  double get positionSize => _positionSize;
  double get stopLossPrice => _stopLossPrice;
  double get takeProfitPrice => _takeProfitPrice;
  Setup? get currentSetup => _currentSetup;
  SimulationMode get simulationMode => _simulationMode;
  double get simulationSpeed => _simulationSpeed;
  double? get manualStopLossPercent => _manualStopLossPercent;
  double? get manualTakeProfitPercent => _manualTakeProfitPercent;

  double? get manualStopLossPrice {
    if (!_inPosition || _manualStopLossPercent == null) return null;
    final entry = _entryPrice;
    
    if (_manualPositionType == 'buy') {
      // Para compra: SL por debajo del precio de entrada
      return entry * (1 - _manualStopLossPercent! / 100);
    } else {
      // Para venta: SL por encima del precio de entrada
      return entry * (1 + _manualStopLossPercent! / 100);
    }
  }
  
  double? get manualTakeProfitPrice {
    if (!_inPosition || _manualTakeProfitPercent == null) return null;
    final entry = _entryPrice;
    
    if (_manualPositionType == 'buy') {
      // Para compra: TP por encima del precio de entrada
      return entry * (1 + _manualTakeProfitPercent! / 100);
    } else {
      // Para venta: TP por debajo del precio de entrada
      return entry * (1 - _manualTakeProfitPercent! / 100);
    }
  }

  // Calcula el P&L flotante basado en el precio actual
  double get unrealizedPnL {
    if (!_inPosition || _currentTrades.isEmpty) return 0.0;
    
    final lastTrade = _currentTrades.last;
    final currentPrice = _historicalData[_currentCandleIndex].close;
    
    if (lastTrade.type == 'buy') {
      return (currentPrice - lastTrade.price) * lastTrade.quantity * lastTrade.leverage!;
    } else {
      return (lastTrade.price - currentPrice) * lastTrade.quantity * lastTrade.leverage!;
    }
  }

  // P&L total (realizado + flotante)
  double get totalPnL {
    double realizedPnL = _currentBalance - 10000.0; // Balance inicial
    return realizedPnL + unrealizedPnL;
  }

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
    _completedTrades = []; // Limpiar trades completados
    _completedOperations = []; // Limpiar operaciones completas
    _equityCurve = [initialBalance];
    _isSimulationRunning = true;
    _currentSetup = setup;
    _simulationSpeed = speed;
    
    // Reset trading state
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
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
    
    debugPrint('🔥 SimulationProvider: Procesando vela $_currentCandleIndex: ${currentCandle.timestamp} - Precio: ${currentCandle.close}');
    
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
    
    // Check stop loss (only if it's greater than 0)
    if (_stopLossPrice > 0 && candle.low <= _stopLossPrice) {
      shouldClose = true;
      closeReason = 'Stop Loss';
    }
    
    // Check take profit (only if it's greater than 0)
    if (_takeProfitPrice > 0 && candle.high >= _takeProfitPrice) {
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
    
    // Calculate position size based on setup
    final riskAmount = _currentBalance * (_currentSetup!.stopLossPercent / 100);
    final stopLossDistance = price * (_currentSetup!.stopLossPercent / 100);
    _positionSize = riskAmount / stopLossDistance;
    
    // Set stop loss and take profit (only if percentages are greater than 0)
    if (type == 'buy') {
      _stopLossPrice = _currentSetup!.stopLossPercent > 0 ? price - stopLossDistance : 0.0;
      _takeProfitPrice = _currentSetup!.takeProfitPercent > 0 ? price + (price * _currentSetup!.takeProfitPercent / 100) : 0.0;
    } else {
      _stopLossPrice = _currentSetup!.stopLossPercent > 0 ? price + stopLossDistance : 0.0;
      _takeProfitPrice = _currentSetup!.takeProfitPercent > 0 ? price - (price * _currentSetup!.takeProfitPercent / 100) : 0.0;
    }
    
    // Execute trade
    executeTrade(type, price, _positionSize, reason);
    
    debugPrint('🔥 SimulationProvider: Posición abierta - Tipo: $type, Precio: $price, Tamaño: $_positionSize, Razón: $reason');
  }

  void _closePosition(double price, String reason) {
    if (!_inPosition) return;
    final lastTrade = _currentTrades.last;
    final closeType = lastTrade.type == 'buy' ? 'sell' : 'buy';
    final pnl = lastTrade.type == 'buy'
        ? (price - lastTrade.price) * lastTrade.quantity * (lastTrade.leverage ?? 1)
        : (lastTrade.price - price) * lastTrade.quantity * (lastTrade.leverage ?? 1);
    
    final tradeGroupId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Crear trade de cierre con el mismo tradeGroupId
    final closeTrade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _historicalData[_currentCandleIndex].timestamp,
      type: closeType,
      price: price,
      quantity: lastTrade.quantity,
      candleIndex: _currentCandleIndex,
      reason: reason,
      amount: lastTrade.amount,
      leverage: lastTrade.leverage,
      pnl: pnl,
      tradeGroupId: tradeGroupId,
    );
    
    // Actualizar el trade de entrada con el mismo tradeGroupId
    final entryTrade = Trade(
      id: lastTrade.id,
      timestamp: lastTrade.timestamp,
      type: lastTrade.type,
      price: lastTrade.price,
      quantity: lastTrade.quantity,
      candleIndex: lastTrade.candleIndex,
      reason: lastTrade.reason,
      amount: lastTrade.amount,
      leverage: lastTrade.leverage,
      pnl: 0.0, // El P&L se calcula en el trade de salida
      tradeGroupId: tradeGroupId,
    );
    
    _currentTrades.add(closeTrade);
    _currentBalance += pnl;
    
    // Crear la operación completa
    final completedOperation = CompletedTrade(
      id: tradeGroupId,
      entryTrade: entryTrade,
      exitTrade: closeTrade,
      totalPnL: pnl,
      entryTime: entryTrade.timestamp,
      exitTime: closeTrade.timestamp,
      entryPrice: entryTrade.price,
      exitPrice: closeTrade.price,
      quantity: entryTrade.quantity,
      leverage: entryTrade.leverage,
      reason: reason,
    );
    
    _completedOperations.add(completedOperation);
    
    // Mantener compatibilidad con la lista anterior
    _completedTrades.add(entryTrade);
    _completedTrades.add(closeTrade);
    
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
    _stopLossPrice = 0.0;
    _takeProfitPrice = 0.0;
    _currentTrades.clear();
    
    debugPrint('🔥 SimulationProvider: Posición cerrada - Precio: $price, Razón: $reason, P&L: $pnl');
    notifyListeners();
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
    
    // El P&L se calculará cuando se cierre la posición
    // No calcular P&L aquí para evitar duplicación
    
    notifyListeners();
  }

  void _finalizeSimulation() {
    // Usar operaciones completas para las estadísticas
    final completedOperations = _completedOperations;
    final winningTrades = completedOperations.where((t) => t.totalPnL > 0).length;
    final winRate = completedOperations.isNotEmpty ? winningTrades / completedOperations.length : 0.0;
    
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
      totalTrades: completedOperations.length, // Solo operaciones completas
      winningTrades: winningTrades,
      trades: _completedTrades, // Mantener compatibilidad
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
    _completedTrades = []; // Limpiar trades completados
    _completedOperations = []; // Limpiar operaciones completas
    _equityCurve = [];
    _isSimulationRunning = false;
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
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
    
    debugPrint('🔥 SimulationProvider: Procesando vela $_currentCandleIndex: ${currentCandle.timestamp} - Precio: ${currentCandle.close}');
    
    // Verificar SL/TP manuales si hay posición abierta
    if (_inPosition) {
      _checkManualStopLossAndTakeProfit(currentCandle);
    }
    
    // En modo manual, NO ejecutar lógica automática de stop loss/take profit ni señales de entrada
    // Solo actualizar la equity curve
    _equityCurve.add(_currentBalance);
    notifyListeners();
  }

  void _checkManualStopLossAndTakeProfit(Candle candle) {
    if (!_inPosition) return;
    
    bool shouldClose = false;
    String closeReason = '';
    double exitPrice = candle.close;
    
    // Verificar Stop Loss manual
    final slPrice = manualStopLossPrice;
    if (slPrice != null) {
      if (_manualPositionType == 'buy') {
        // Para compra: SL se activa cuando el precio baja
        if (candle.low <= slPrice) {
          shouldClose = true;
          closeReason = 'Stop Loss Manual';
          exitPrice = slPrice;
        }
      } else {
        // Para venta: SL se activa cuando el precio sube
        if (candle.high >= slPrice) {
          shouldClose = true;
          closeReason = 'Stop Loss Manual';
          exitPrice = slPrice;
        }
      }
    }
    
    // Verificar Take Profit manual
    final tpPrice = manualTakeProfitPrice;
    if (tpPrice != null) {
      if (_manualPositionType == 'buy') {
        // Para compra: TP se activa cuando el precio sube
        if (candle.high >= tpPrice) {
          shouldClose = true;
          closeReason = 'Take Profit Manual';
          exitPrice = tpPrice;
        }
      } else {
        // Para venta: TP se activa cuando el precio baja
        if (candle.low <= tpPrice) {
          shouldClose = true;
          closeReason = 'Take Profit Manual';
          exitPrice = tpPrice;
        }
      }
    }
    
    if (shouldClose) {
      closeManualPosition(exitPrice);
      debugPrint('🔥 SimulationProvider: Posición cerrada por $closeReason - Precio: $exitPrice');
    }
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

  void executeManualTrade({
    required String type,
    required double amount,
    required int leverage,
  }) {
    final candle = _historicalData[_currentCandleIndex];
    final price = candle.close;
    final margin = amount / leverage;
    final positionSize = amount / price;
    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: candle.timestamp,
      type: type,
      price: price,
      quantity: positionSize,
      candleIndex: _currentCandleIndex,
      reason: 'Manual',
      amount: amount,
      leverage: leverage,
    );
    _currentTrades.add(trade);
    _inPosition = true;
    _entryPrice = price;
    _positionSize = positionSize;
    _manualMargin = margin;
    _manualPositionType = type; // Guardar el tipo de operación
    notifyListeners();
  }

  double _manualMargin = 0.0;

  void closeManualPosition(double exitPrice) {
    if (!_inPosition) return;
    final lastTrade = _currentTrades.last;
    final closeType = lastTrade.type == 'buy' ? 'sell' : 'buy';
    final pnl = lastTrade.type == 'buy'
        ? (exitPrice - lastTrade.price) * lastTrade.quantity * lastTrade.leverage!
        : (lastTrade.price - exitPrice) * lastTrade.quantity * lastTrade.leverage!;
    
    final tradeGroupId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final closeTrade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _historicalData[_currentCandleIndex].timestamp,
      type: closeType,
      price: exitPrice,
      quantity: lastTrade.quantity,
      candleIndex: _currentCandleIndex,
      reason: 'Manual Close',
      amount: lastTrade.amount,
      leverage: lastTrade.leverage,
      pnl: pnl,
      tradeGroupId: tradeGroupId,
    );
    
    // Actualizar el trade de entrada con el mismo tradeGroupId
    final entryTrade = Trade(
      id: lastTrade.id,
      timestamp: lastTrade.timestamp,
      type: lastTrade.type,
      price: lastTrade.price,
      quantity: lastTrade.quantity,
      candleIndex: lastTrade.candleIndex,
      reason: lastTrade.reason,
      amount: lastTrade.amount,
      leverage: lastTrade.leverage,
      pnl: 0.0,
      tradeGroupId: tradeGroupId,
    );
    
    _currentTrades.add(closeTrade);
    _currentBalance += pnl;
    
    // Crear la operación completa
    final completedOperation = CompletedTrade(
      id: tradeGroupId,
      entryTrade: entryTrade,
      exitTrade: closeTrade,
      totalPnL: pnl,
      entryTime: entryTrade.timestamp,
      exitTime: closeTrade.timestamp,
      entryPrice: entryTrade.price,
      exitPrice: closeTrade.price,
      quantity: entryTrade.quantity,
      leverage: entryTrade.leverage,
      reason: 'Manual Close',
    );
    
    _completedOperations.add(completedOperation);
    
    // Mantener compatibilidad con la lista anterior
    _completedTrades.add(entryTrade);
    _completedTrades.add(closeTrade);
    
    _inPosition = false;
    _entryPrice = 0.0;
    _positionSize = 0.0;
    _manualMargin = 0.0;
    _manualPositionType = 'buy';
    _manualStopLossPercent = null;
    _manualTakeProfitPercent = null;
    _currentTrades.clear();
    notifyListeners();
  }

  void setManualSLTP({double? stopLossPercent, double? takeProfitPercent}) {
    // Si se pasa null explícitamente, limpiar el valor
    if (stopLossPercent == null) {
      _manualStopLossPercent = null;
    } else if (stopLossPercent > 0) {
      _manualStopLossPercent = stopLossPercent;
    } else {
      _manualStopLossPercent = null;
    }
    
    if (takeProfitPercent == null) {
      _manualTakeProfitPercent = null;
    } else if (takeProfitPercent > 0) {
      _manualTakeProfitPercent = takeProfitPercent;
    } else {
      _manualTakeProfitPercent = null;
    }
    
    notifyListeners();
  }

  // Métodos separados para manejar SL y TP de forma independiente
  void setManualStopLoss(double? stopLossPercent) {
    if (stopLossPercent == null) {
      _manualStopLossPercent = null;
    } else if (stopLossPercent > 0) {
      _manualStopLossPercent = stopLossPercent;
    } else {
      _manualStopLossPercent = null;
    }
    notifyListeners();
  }

  void setManualTakeProfit(double? takeProfitPercent) {
    if (takeProfitPercent == null) {
      _manualTakeProfitPercent = null;
    } else if (takeProfitPercent > 0) {
      _manualTakeProfitPercent = takeProfitPercent;
    } else {
      _manualTakeProfitPercent = null;
    }
    notifyListeners();
  }

  // Cierre parcial de la posición abierta
  void closePartialPosition(double percent) {
    if (!_inPosition || percent <= 0 || percent > 100) return;
    final lastTrade = _currentTrades.last;
    final closeType = lastTrade.type == 'buy' ? 'sell' : 'buy';
    final currentPrice = _historicalData[_currentCandleIndex].close;
    final qtyToClose = lastTrade.quantity * (percent / 100);
    final pnl = lastTrade.type == 'buy'
        ? (currentPrice - lastTrade.price) * qtyToClose * (lastTrade.leverage ?? 1)
        : (lastTrade.price - currentPrice) * qtyToClose * (lastTrade.leverage ?? 1);
    
    final tradeGroupId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final closeTrade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _historicalData[_currentCandleIndex].timestamp,
      type: closeType,
      price: currentPrice,
      quantity: qtyToClose,
      candleIndex: _currentCandleIndex,
      reason: 'Cierre Parcial',
      amount: lastTrade.amount != null ? lastTrade.amount! * (percent / 100) : null,
      leverage: lastTrade.leverage,
      pnl: pnl,
      tradeGroupId: tradeGroupId,
    );
    
    _currentTrades.add(closeTrade);
    _currentBalance += pnl;
    final newQty = lastTrade.quantity - qtyToClose;
    
    if (newQty <= 0.00001) {
      // Si se cierra completamente la posición, crear la operación completa
      final entryTrade = Trade(
        id: lastTrade.id,
        timestamp: lastTrade.timestamp,
        type: lastTrade.type,
        price: lastTrade.price,
        quantity: lastTrade.quantity,
        candleIndex: lastTrade.candleIndex,
        reason: lastTrade.reason,
        amount: lastTrade.amount,
        leverage: lastTrade.leverage,
        pnl: 0.0,
        tradeGroupId: tradeGroupId,
      );
      
      // Crear la operación completa
      final completedOperation = CompletedTrade(
        id: tradeGroupId,
        entryTrade: entryTrade,
        exitTrade: closeTrade,
        totalPnL: pnl,
        entryTime: entryTrade.timestamp,
        exitTime: closeTrade.timestamp,
        entryPrice: entryTrade.price,
        exitPrice: closeTrade.price,
        quantity: entryTrade.quantity,
        leverage: entryTrade.leverage,
        reason: 'Cierre Parcial',
      );
      
      _completedOperations.add(completedOperation);
      
      // Mantener compatibilidad con la lista anterior
      _completedTrades.add(entryTrade);
      _completedTrades.add(closeTrade);
      
      _inPosition = false;
      _entryPrice = 0.0;
      _positionSize = 0.0;
      _manualMargin = 0.0;
      _manualPositionType = 'buy';
      _manualStopLossPercent = null;
      _manualTakeProfitPercent = null;
      _currentTrades.clear();
    } else {
      _positionSize = newQty;
      _manualMargin = _manualMargin * (1 - percent / 100);
    }
    notifyListeners();
  }
} 