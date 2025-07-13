import 'package:flutter/foundation.dart';
import '../models/simulation_result.dart';
import '../models/candle.dart';
import '../models/setup.dart';

enum SimulationMode { automatic, manual }

class SimulationProvider with ChangeNotifier {
  SimulationResult? _currentSimulation;
  final List<SimulationResult> _simulationHistory = [];
  List<Candle> _historicalData = [];
  bool _isSimulationRunning = false;
  int _currentCandleIndex = 0;
  double _currentBalance = 10000.0;
  List<Trade> _currentTrades = [];
  List<Trade> _completedTrades =
      []; // Lista de trades individuales (para compatibilidad)
  List<CompletedTrade> _completedOperations =
      []; // Nueva lista para operaciones completas
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

  // New methods for automatic setup parameter reading and position calculation
  double? _calculatedPositionSize;
  double? _calculatedLeverage;
  double? _calculatedStopLossPrice;
  double? _calculatedTakeProfitPrice;
  bool _setupParametersCalculated = false;

  // Default SL/TP values from setup (for the sliders)
  double? _defaultStopLossPercent;
  double? _defaultTakeProfitPercent;

  // Track if SL/TP are enabled
  bool _stopLossEnabled = false;
  bool _takeProfitEnabled = false;

  double? get calculatedPositionSize => _calculatedPositionSize;
  double? get calculatedLeverage => _calculatedLeverage;
  double? get calculatedStopLossPrice => _calculatedStopLossPrice;
  double? get calculatedTakeProfitPrice => _calculatedTakeProfitPrice;
  bool get setupParametersCalculated => _setupParametersCalculated;
  double? get defaultStopLossPercent => _defaultStopLossPercent;
  double? get defaultTakeProfitPercent => _defaultTakeProfitPercent;
  bool get stopLossEnabled => _stopLossEnabled;
  bool get takeProfitEnabled => _takeProfitEnabled;

  SimulationResult? get currentSimulation => _currentSimulation;
  List<SimulationResult> get simulationHistory => _simulationHistory;
  List<Candle> get historicalData => _historicalData;
  bool get isSimulationRunning => _isSimulationRunning;
  int get currentCandleIndex => _currentCandleIndex;
  double get currentBalance => _currentBalance;
  List<Trade> get currentTrades => _currentTrades;
  List<Trade> get completedTrades =>
      _completedTrades; // Getter para trades completados
  List<CompletedTrade> get completedOperations =>
      _completedOperations; // Getter para operaciones completas
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
    if (!_inPosition || !_stopLossEnabled) return null;
    final entry = _entryPrice;

    // Si hay valores manuales y están habilitados, usarlos
    if (_manualStopLossPercent != null) {
      final price = _manualPositionType == 'buy'
          ? entry * (1 - _manualStopLossPercent! / 100)
          : entry * (1 + _manualStopLossPercent! / 100);
      debugPrint(
        '🔥 SimulationProvider: manualStopLossPrice using manual value: $price (${_manualStopLossPercent}%)',
      );
      return price;
    }

    // Si no hay valores manuales, usar los calculados del setup (solo si están habilitados)
    if (_setupParametersCalculated &&
        _calculatedStopLossPrice != null &&
        _manualStopLossPercent != null) {
      debugPrint(
        '🔥 SimulationProvider: manualStopLossPrice using calculated value: $_calculatedStopLossPrice',
      );
      return _calculatedStopLossPrice;
    }

    debugPrint(
      '🔥 SimulationProvider: manualStopLossPrice returning null (disabled)',
    );
    return null;
  }

  double? get manualTakeProfitPrice {
    if (!_inPosition || !_takeProfitEnabled) return null;
    final entry = _entryPrice;

    // Si hay valores manuales y están habilitados, usarlos
    if (_manualTakeProfitPercent != null) {
      final price = _manualPositionType == 'buy'
          ? entry * (1 + _manualTakeProfitPercent! / 100)
          : entry * (1 - _manualTakeProfitPercent! / 100);
      debugPrint(
        '🔥 SimulationProvider: manualTakeProfitPrice using manual value: $price (${_manualTakeProfitPercent}%)',
      );
      return price;
    }

    // Si no hay valores manuales, usar los calculados del setup (solo si están habilitados)
    if (_setupParametersCalculated &&
        _calculatedTakeProfitPrice != null &&
        _manualTakeProfitPercent != null) {
      debugPrint(
        '🔥 SimulationProvider: manualTakeProfitPrice using calculated value: $_calculatedTakeProfitPrice',
      );
      return _calculatedTakeProfitPrice;
    }

    debugPrint(
      '🔥 SimulationProvider: manualTakeProfitPrice returning null (disabled)',
    );
    return null;
  }

  // Calcula el P&L flotante basado en el precio actual
  double get unrealizedPnL {
    if (!_inPosition || _currentTrades.isEmpty) return 0.0;

    final lastTrade = _currentTrades.last;
    final currentPrice = _historicalData[_currentCandleIndex].close;

    if (lastTrade.type == 'buy') {
      return (currentPrice - lastTrade.price) *
          lastTrade.quantity *
          lastTrade.leverage!;
    } else {
      return (lastTrade.price - currentPrice) *
          lastTrade.quantity *
          lastTrade.leverage!;
    }
  }

  // P&L total (realizado + flotante)
  double get totalPnL {
    double realizedPnL = _currentBalance - 10000.0; // Balance inicial
    return realizedPnL + unrealizedPnL;
  }

  void setHistoricalData(List<Candle> data) {
    debugPrint(
      '🔥 SimulationProvider: setHistoricalData() - Datos recibidos: ${data.length} velas',
    );
    if (data.isNotEmpty) {
      debugPrint(
        '🔥 SimulationProvider: Primera vela: ${data.first.timestamp} - ${data.first.close}',
      );
      debugPrint(
        '🔥 SimulationProvider: Última vela: ${data.last.timestamp} - ${data.last.close}',
      );
    }
    _historicalData = data;
    notifyListeners();
  }

  void startSimulation(
    Setup setup,
    DateTime startDate,
    double speed,
    double initialBalance,
  ) {
    debugPrint(
      '🔥 SimulationProvider: startSimulation() - Setup: ${setup.name}, Balance inicial: $initialBalance',
    );
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

    // Reset calculated parameters
    _calculatedPositionSize = null;
    _calculatedLeverage = null;
    _calculatedStopLossPrice = null;
    _calculatedTakeProfitPrice = null;
    _setupParametersCalculated = false;
    // Reset default SL/TP values
    _defaultStopLossPercent = null;
    _defaultTakeProfitPercent = null;

    // Reset SL/TP enabled state
    _stopLossEnabled = false;
    _takeProfitEnabled = false;

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
    if (!_isSimulationRunning ||
        _currentCandleIndex >= _historicalData.length - 1) {
      stopSimulation();
      return;
    }

    _currentCandleIndex++;
    final currentCandle = _historicalData[_currentCandleIndex];

    debugPrint(
      '🔥 SimulationProvider: Procesando vela $_currentCandleIndex: ${currentCandle.timestamp} - Precio: ${currentCandle.close}',
    );

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
    if (_currentCandleIndex < 20)
      return; // Need at least 20 candles for analysis

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
    if (candle.close > resistanceLevel &&
        candle.volume > _getAverageVolume(lookbackPeriod) * 1.5) {
      _openPosition('buy', candle.close, 'Breakout Long');
    } else if (candle.close < supportLevel &&
        candle.volume > _getAverageVolume(lookbackPeriod) * 1.5) {
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

    // Calcular el tamaño de la posición basado en el riesgo del setup
    double riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);

    // Calcular el tamaño de la posición basado en la distancia del stop loss
    double stopLossDistance = _currentSetup!.stopLossDistance;
    double positionSize;

    if (_currentSetup!.stopLossType == StopLossType.pips) {
      // Convertir pips a precio (asumiendo que 1 pip = 0.0001 para la mayoría de pares)
      double pipValue = 0.0001;
      double priceDistance = stopLossDistance * pipValue;
      positionSize = riskAmount / priceDistance;
    } else {
      // Usar distancia en precio directamente
      positionSize = riskAmount / stopLossDistance;
    }

    _positionSize = positionSize;

    // Calcular stop loss y take profit
    double takeProfitRatio = _currentSetup!.getEffectiveTakeProfitRatio();

    if (type == 'buy') {
      _stopLossPrice = price - stopLossDistance;
      _takeProfitPrice = price + (stopLossDistance * takeProfitRatio);
    } else {
      _stopLossPrice = price + stopLossDistance;
      _takeProfitPrice = price - (stopLossDistance * takeProfitRatio);
    }

    // Execute trade
    executeTrade(type, price, _positionSize, reason);

    debugPrint(
      '🔥 SimulationProvider: Posición abierta - Tipo: $type, Precio: $price, Tamaño: $_positionSize, Razón: $reason',
    );
  }

  void _closePosition(double price, String reason) {
    if (!_inPosition) return;
    final lastTrade = _currentTrades.last;
    final closeType = lastTrade.type == 'buy' ? 'sell' : 'buy';
    final pnl = lastTrade.type == 'buy'
        ? (price - lastTrade.price) *
              lastTrade.quantity *
              (lastTrade.leverage ?? 1)
        : (lastTrade.price - price) *
              lastTrade.quantity *
              (lastTrade.leverage ?? 1);

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

    // Reset default SL/TP values
    _defaultStopLossPercent = null;
    _defaultTakeProfitPercent = null;

    // Reset SL/TP enabled state
    _stopLossEnabled = false;
    _takeProfitEnabled = false;

    debugPrint(
      '🔥 SimulationProvider: Posición cerrada - Precio: $price, Razón: $reason, P&L: $pnl',
    );
    notifyListeners();
  }

  void executeTrade(
    String type,
    double price,
    double quantity, [
    String? reason,
  ]) {
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
    final winningTrades = completedOperations
        .where((t) => t.totalPnL > 0)
        .length;
    final winRate = completedOperations.isNotEmpty
        ? winningTrades / completedOperations.length
        : 0.0;

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

    debugPrint(
      '🔥 SimulationProvider: Simulación finalizada - P&L: ${_currentSimulation!.netPnL}, Win Rate: ${_currentSimulation!.winRate}',
    );
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
    debugPrint(
      '🔥 SimulationProvider: Velocidad de simulación cambiada a: $speed',
    );
    notifyListeners();
  }

  void advanceCandle() {
    if (_simulationMode != SimulationMode.manual) {
      debugPrint(
        '🔥 SimulationProvider: No se puede avanzar manualmente en modo automático',
      );
      return;
    }

    if (_currentCandleIndex >= _historicalData.length - 1) {
      debugPrint('🔥 SimulationProvider: Ya se llegó al final de los datos');
      return;
    }

    _advanceCandleManually();
    debugPrint(
      '🔥 SimulationProvider: Vela avanzada manualmente a índice: $_currentCandleIndex',
    );
  }

  void _advanceCandleManually() {
    if (_currentCandleIndex >= _historicalData.length - 1) {
      return;
    }

    _currentCandleIndex++;
    final currentCandle = _historicalData[_currentCandleIndex];

    debugPrint(
      '🔥 SimulationProvider: Procesando vela $_currentCandleIndex: ${currentCandle.timestamp} - Precio: ${currentCandle.close}',
    );

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
      debugPrint(
        '🔥 SimulationProvider: Checking SL at $slPrice (manual: $_manualStopLossPercent%, default: $_defaultStopLossPercent%)',
      );
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
      debugPrint(
        '🔥 SimulationProvider: Checking TP at $tpPrice (manual: $_manualTakeProfitPercent%, default: $_defaultTakeProfitPercent%)',
      );
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
      debugPrint(
        '🔥 SimulationProvider: Posición cerrada por $closeReason - Precio: $exitPrice',
      );
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
    if (_currentSetup == null) return;

    // Calculate position parameters first
    calculatePositionParameters(type);

    if (!_setupParametersCalculated) {
      debugPrint('🔥 SimulationProvider: Cannot calculate position parameters');
      return;
    }

    final candle = _historicalData[_currentCandleIndex];
    final price = candle.close;

    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: candle.timestamp,
      type: type,
      price: price,
      quantity: _calculatedPositionSize!,
      candleIndex: _currentCandleIndex,
      reason: 'Manual',
      amount: _currentBalance * (_currentSetup!.riskPercent / 100),
      leverage: _calculatedLeverage!.toInt(),
    );
    _currentTrades.add(trade);
    _inPosition = true;
    _entryPrice = price;
    _positionSize = _calculatedPositionSize!;
    _manualMargin = _currentBalance * (_currentSetup!.riskPercent / 100);
    _manualPositionType = type; // Guardar el tipo de operación

    // Set the calculated SL/TP prices for the chart and default values for sliders
    // Solo establecer los valores por defecto si no hay valores manuales previos
    if (_manualStopLossPercent == null) {
      _manualStopLossPercent = _defaultStopLossPercent;
      _stopLossEnabled = _defaultStopLossPercent != null;
      debugPrint(
        '🔥 SimulationProvider: Setting default SL: $_manualStopLossPercent%, Enabled: $_stopLossEnabled',
      );
    } else {
      _stopLossEnabled = true;
      debugPrint(
        '🔥 SimulationProvider: Keeping manual SL: $_manualStopLossPercent%, Enabled: $_stopLossEnabled',
      );
    }
    if (_manualTakeProfitPercent == null) {
      _manualTakeProfitPercent = _defaultTakeProfitPercent;
      _takeProfitEnabled = _defaultTakeProfitPercent != null;
      debugPrint(
        '🔥 SimulationProvider: Setting default TP: $_manualTakeProfitPercent%, Enabled: $_takeProfitEnabled',
      );
    } else {
      _takeProfitEnabled = true;
      debugPrint(
        '🔥 SimulationProvider: Keeping manual TP: $_manualTakeProfitPercent%, Enabled: $_takeProfitEnabled',
      );
    }

    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - SL: $_manualStopLossPercent%, TP: $_manualTakeProfitPercent%',
    );
    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - SL Price: ${manualStopLossPrice}, TP Price: ${manualTakeProfitPrice}',
    );

    notifyListeners();
  }

  double _manualMargin = 0.0;

  void closeManualPosition(double exitPrice) {
    if (!_inPosition) return;
    final lastTrade = _currentTrades.last;
    final closeType = lastTrade.type == 'buy' ? 'sell' : 'buy';
    final pnl = lastTrade.type == 'buy'
        ? (exitPrice - lastTrade.price) *
              lastTrade.quantity *
              lastTrade.leverage!
        : (lastTrade.price - exitPrice) *
              lastTrade.quantity *
              lastTrade.leverage!;

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

    // Reset calculated parameters
    _calculatedPositionSize = null;
    _calculatedLeverage = null;
    _calculatedStopLossPrice = null;
    _calculatedTakeProfitPrice = null;
    _setupParametersCalculated = false;

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
      _stopLossEnabled = false;
    } else if (stopLossPercent > 0) {
      _manualStopLossPercent = stopLossPercent;
      _stopLossEnabled = true;
    } else {
      _manualStopLossPercent = null;
      _stopLossEnabled = false;
    }
    debugPrint(
      '🔥 SimulationProvider: setManualStopLoss - SL: $_manualStopLossPercent%, Enabled: $_stopLossEnabled',
    );
    notifyListeners();
  }

  void setManualTakeProfit(double? takeProfitPercent) {
    if (takeProfitPercent == null) {
      _manualTakeProfitPercent = null;
      _takeProfitEnabled = false;
    } else if (takeProfitPercent > 0) {
      _manualTakeProfitPercent = takeProfitPercent;
      _takeProfitEnabled = true;
    } else {
      _manualTakeProfitPercent = null;
      _takeProfitEnabled = false;
    }
    debugPrint(
      '🔥 SimulationProvider: setManualTakeProfit - TP: $_manualTakeProfitPercent%, Enabled: $_takeProfitEnabled',
    );
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
        ? (currentPrice - lastTrade.price) *
              qtyToClose *
              (lastTrade.leverage ?? 1)
        : (lastTrade.price - currentPrice) *
              qtyToClose *
              (lastTrade.leverage ?? 1);

    final tradeGroupId = DateTime.now().millisecondsSinceEpoch.toString();

    final closeTrade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: _historicalData[_currentCandleIndex].timestamp,
      type: closeType,
      price: currentPrice,
      quantity: qtyToClose,
      candleIndex: _currentCandleIndex,
      reason: 'Cierre Parcial',
      amount: lastTrade.amount != null
          ? lastTrade.amount! * (percent / 100)
          : null,
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

  // New methods for automatic setup parameter reading and position calculation
  void calculatePositionParameters(String tradeType) {
    if (_currentSetup == null || _historicalData.isEmpty) {
      _setupParametersCalculated = false;
      return;
    }

    final currentPrice = _historicalData[_currentCandleIndex].close;

    // 1. Calculate risk amount
    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);

    // 2. Calculate stop loss distance in price
    double slPriceDistance;
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      // Convert pips to price (assuming 1 pip = 0.0001 for most pairs)
      const double pipValue = 0.0001;
      slPriceDistance = _currentSetup!.stopLossDistance * pipValue;
    } else {
      // Use price distance directly
      slPriceDistance = _currentSetup!.stopLossDistance;
    }

    // 3. Calculate position size
    if (slPriceDistance <= 0) {
      _setupParametersCalculated = false;
      return;
    }

    _calculatedPositionSize = riskAmount / slPriceDistance;

    // 4. Set leverage (use setup leverage if defined, otherwise 1x)
    _calculatedLeverage = 1.0; // Default leverage

    // 5. Calculate stop loss and take profit prices
    final takeProfitRatio = _currentSetup!.getEffectiveTakeProfitRatio();

    if (tradeType == 'buy') {
      _calculatedStopLossPrice = currentPrice - slPriceDistance;
      _calculatedTakeProfitPrice =
          currentPrice + (slPriceDistance * takeProfitRatio);
    } else {
      _calculatedStopLossPrice = currentPrice + slPriceDistance;
      _calculatedTakeProfitPrice =
          currentPrice - (slPriceDistance * takeProfitRatio);
    }

    // 6. Calculate default SL/TP percentages for the sliders
    if (tradeType == 'buy') {
      _defaultStopLossPercent = (slPriceDistance / currentPrice) * 100;
      _defaultTakeProfitPercent =
          (slPriceDistance * takeProfitRatio / currentPrice) * 100;
    } else {
      _defaultStopLossPercent = (slPriceDistance / currentPrice) * 100;
      _defaultTakeProfitPercent =
          (slPriceDistance * takeProfitRatio / currentPrice) * 100;
    }

    _setupParametersCalculated = true;
    debugPrint(
      '🔥 SimulationProvider: Position parameters calculated - Size: $_calculatedPositionSize, SL: $_calculatedStopLossPrice, TP: $_calculatedTakeProfitPrice',
    );
    debugPrint(
      '🔥 SimulationProvider: Default percentages - SL: ${_defaultStopLossPercent?.toStringAsFixed(2)}%, TP: ${_defaultTakeProfitPercent?.toStringAsFixed(2)}%',
    );
  }

  // Validate if position can be calculated
  bool canCalculatePosition() {
    if (_currentSetup == null || _historicalData.isEmpty) return false;

    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);
    if (riskAmount <= 0) return false;

    double slPriceDistance;
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      const double pipValue = 0.0001;
      slPriceDistance = _currentSetup!.stopLossDistance * pipValue;
    } else {
      slPriceDistance = _currentSetup!.stopLossDistance;
    }

    return slPriceDistance > 0;
  }

  // Get position summary text
  String getPositionSummaryText() {
    if (!_setupParametersCalculated || _currentSetup == null) {
      return 'No se puede calcular la posición';
    }

    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);
    return 'Posición: ${_calculatedPositionSize!.toStringAsFixed(4)} unidades @ ${_calculatedLeverage!.toStringAsFixed(0)}x (riesgo ${_currentSetup!.riskPercent.toStringAsFixed(1)}% = \$${riskAmount.toStringAsFixed(0)})';
  }
}
