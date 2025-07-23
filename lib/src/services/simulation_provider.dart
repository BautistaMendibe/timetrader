import 'package:flutter/foundation.dart';
import '../models/simulation_result.dart';
import '../models/candle.dart';
import '../models/setup.dart';
import 'dart:async';
import 'dart:math';

// --- MODELO TICK ---
class Tick {
  final DateTime time;
  final double price;
  Tick(this.time, this.price);
}

enum SimulationMode { automatic, manual }

// --- TIMEFRAMES ---
enum Timeframe { D1, H1, M15, M5, M1 }

class SimulationProvider with ChangeNotifier {
  /// Valores de pip para los 7 pares más tradeados
  static const Map<String, double> _pipValues = {
    'EURUSD': 0.0001,
    'GBPUSD': 0.0001,
    'USDJPY': 0.01,
    'AUDUSD': 0.0001,
    'USDCAD': 0.0001,
    'NZDUSD': 0.0001,
    'BTCUSD': 1.0,
  };

  String? _activeSymbol;

  SimulationResult? _currentSimulation;
  final List<SimulationResult> _simulationHistory = [];

  // --- MULTI-TIMEFRAME DATA ---
  late Map<Timeframe, List<Candle>> _allTimeframes;
  Timeframe _activeTf = Timeframe.H1;

  static const int baseTicksPerMinute = 10;

  // Mapa de ticks por vela para cada timeframe
  static final Map<Timeframe, int> _ticksPerCandleMap = {
    Timeframe.M1: baseTicksPerMinute * 1, // 10 ticks por 1 m
    Timeframe.M5: baseTicksPerMinute * 5, // 50 ticks por 5 m = 5×10
    Timeframe.M15: baseTicksPerMinute * 15, // 150 ticks por 15 m = 15×10
    Timeframe.H1: baseTicksPerMinute * 60, // 600 ticks por 1 h = 60×10
    Timeframe.D1: baseTicksPerMinute * 1440, // 14400 ticks por 1 d = 1440×10
  };

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

  // --- TICK SIMULATION STATE ---
  List<Tick> _syntheticTicks = [];
  int _currentTickIndex = 0;
  int _ticksPerCandle = 100;
  Timer? _tickTimer;
  double _ticksPerSecondFactor = 1.0; // Para ajustar velocidad

  // --- ACUMULACIÓN DE TICKS PARA VELAS ---
  List<Tick> _currentCandleTicks = [];
  DateTime? _currentCandleStartTime;

  // --- ESTADO DE PAUSA ---
  bool _wasPaused = false;
  int _pausedTickIndex = 0;
  List<Tick> _pausedCandleTicks = [];
  DateTime? _pausedCandleStartTime;

  int _tfRemainder = 0;

  /// Fija el símbolo activo (desde SimulationSetupScreen)
  void setActiveSymbol(String symbol) {
    _activeSymbol = symbol;
    debugPrint('🔥 SimulationProvider: símbolo activo = $_activeSymbol');
  }

  double get _pipValue =>
      _pipValues[_activeSymbol] ?? 0.0001; // fallback genérico

  String? get activeSymbol => _activeSymbol;

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

  // --- MULTI-TIMEFRAME GETTERS ---
  List<Candle> get historicalData => _allTimeframes[_activeTf]!;
  Timeframe get activeTimeframe => _activeTf;
  Map<Timeframe, List<Candle>> get allTimeframes => _allTimeframes;

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
    final currentPrice = historicalData[_currentCandleIndex].close;

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
    loadRawData(data);
  }

  // --- MULTI-TIMEFRAME METHODS ---
  void loadRawData(List<Candle> raw) {
    debugPrint(
      '🔥 SimulationProvider: loadRawData() - Procesando ${raw.length} velas raw',
    );

    // Reagrupar datos en todos los timeframes
    _allTimeframes = {
      Timeframe.D1: reaggregate(raw, const Duration(days: 1)),
      Timeframe.H1: reaggregate(raw, const Duration(hours: 1)),
      Timeframe.M15: reaggregate(raw, const Duration(minutes: 15)),
      Timeframe.M5: reaggregate(raw, const Duration(minutes: 5)),
      Timeframe.M1: reaggregate(raw, const Duration(minutes: 1)),
    };

    // Inicializar con H1 por defecto
    _activeTf = Timeframe.H1;
    _currentCandleIndex = 0;

    // Actualizar _ticksPerCandle según el timeframe inicial
    _ticksPerCandle = _ticksPerCandleMap[_activeTf]!;
    debugPrint(
      '🔥 SimulationProvider: _ticksPerCandle inicializado a $_ticksPerCandle para ${_activeTf.name}',
    );

    debugPrint('🔥 SimulationProvider: Timeframes generados:');
    for (final tf in Timeframe.values) {
      debugPrint('  ${tf.name}: ${_allTimeframes[tf]!.length} velas');
    }

    _notifyChartReset();
  }

  List<Candle> reaggregate(List<Candle> raw, Duration interval) {
    if (raw.isEmpty) return [];

    final List<Candle> aggregated = [];
    final Map<DateTime, List<Candle>> grouped = {};

    // Agrupar velas por intervalo
    for (final candle in raw) {
      final intervalStart = DateTime(
        candle.timestamp.year,
        candle.timestamp.month,
        candle.timestamp.day,
        candle.timestamp.hour,
        candle.timestamp.minute -
            (candle.timestamp.minute % interval.inMinutes),
      );

      grouped.putIfAbsent(intervalStart, () => []).add(candle);
    }

    // Crear velas agregadas
    final sortedKeys = grouped.keys.toList()..sort();
    for (final key in sortedKeys) {
      final candles = grouped[key]!;
      if (candles.isEmpty) continue;

      final open = candles.first.open;
      final close = candles.last.close;
      final high = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
      final low = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
      final volume = candles.map((c) => c.volume).reduce((a, b) => a + b);

      aggregated.add(
        Candle(
          timestamp: key,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ),
      );
    }

    return aggregated;
  }

  int _findClosestByTimestamp(List<Candle> candles, DateTime ts) {
    int closestIndex = 0;
    int minDifference = double.maxFinite.toInt();
    for (int i = 0; i < candles.length; i++) {
      final difference = (candles[i].timestamp.difference(
        ts,
      )).abs().inMilliseconds;
      if (difference < minDifference) {
        minDifference = difference;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  void setTimeframe(Timeframe tf) {
    if (tf == _activeTf) return;

    final oldTf = _activeTf;
    final oldIndex = _currentCandleIndex;
    final oldTicks = _ticksPerCandleMap[oldTf]!;
    final newTicks = _ticksPerCandleMap[tf]!;

    // 1) cambia TF y _ticksPerCandle
    _activeTf = tf;
    _ticksPerCandle = newTicks;

    int newIndex;
    if (newTicks > oldTicks) {
      // paso de TF menor → mayor: agrupo “factor” velas y guardo el resto
      final factor = newTicks ~/ oldTicks;
      final fullGroups = oldIndex ~/ factor;
      _tfRemainder = oldIndex % factor;
      newIndex = fullGroups;
    } else {
      // paso de TF mayor → menor: subdivido y reaplico el resto
      final factor = oldTicks ~/ newTicks;
      newIndex = oldIndex * factor + _tfRemainder;
      _tfRemainder = 0;
    }

    // 2) clamp y notifica
    final maxIdx = _allTimeframes[tf]!.length - 1;
    _currentCandleIndex = newIndex.clamp(0, maxIdx);

    _setupTicksForCurrentCandle();
    _notifyChartReset();
  }

  Duration _durationForTimeframe(Timeframe tf) {
    switch (tf) {
      case Timeframe.M1:
        return const Duration(minutes: 1);
      case Timeframe.M5:
        return const Duration(minutes: 5);
      case Timeframe.M15:
        return const Duration(minutes: 15);
      case Timeframe.H1:
        return const Duration(hours: 1);
      case Timeframe.D1:
        return const Duration(days: 1);
    }
  }

  void _setupTicksForCurrentCandle() {
    if (_currentCandleIndex >= historicalData.length) {
      debugPrint(
        '🔥 SimulationProvider: _setupTicksForCurrentCandle - índice fuera de rango: $_currentCandleIndex',
      );
      return;
    }
    final candle = historicalData[_currentCandleIndex];
    debugPrint(
      '🔥 SimulationProvider: Configurando ticks para vela $_currentCandleIndex: ${candle.timestamp} - OHLC: ${candle.open}/${candle.high}/${candle.low}/${candle.close}',
    );
    int? nextMs;
    if (_currentCandleIndex < historicalData.length - 1) {
      nextMs = historicalData[_currentCandleIndex + 1]
          .timestamp
          .millisecondsSinceEpoch;
    }
    // Generar exactamente _ticksPerCandle ticks por vela
    _syntheticTicks = generateSyntheticTicks(candle, _ticksPerCandle, nextMs);
    debugPrint(
      '🔥 SimulationProvider: Generados ${_syntheticTicks.length} ticks para la vela',
    );
    // Reiniciar tick index y ticks acumulados
    _currentTickIndex = 0;
    _currentCandleTicks.clear();
    _currentCandleStartTime = null;
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

    _notifyChartReset();
  }

  void pauseSimulation() {
    _isSimulationRunning = false;
    _notifySimulationState();
  }

  void resumeSimulation() {
    _isSimulationRunning = true;
    _notifySimulationState();
  }

  void stopSimulation() {
    _isSimulationRunning = false;
    _finalizeSimulation();
    _notifySimulationState();
  }

  // Process next candle in simulation
  void processNextCandle() {
    if (!_isSimulationRunning ||
        _currentCandleIndex >= historicalData.length - 1) {
      stopSimulation();
      return;
    }

    _currentCandleIndex++;
    final currentCandle = historicalData[_currentCandleIndex];

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
    _notifyUIUpdate();
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
    final highPrices = historicalData
        .skip(_currentCandleIndex - lookbackPeriod)
        .take(lookbackPeriod)
        .map((c) => c.high)
        .toList();

    final lowPrices = historicalData
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
    final volumes = historicalData
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
      timestamp: historicalData[_currentCandleIndex].timestamp,
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
    _notifyUIUpdate();
  }

  void executeTrade(
    String type,
    double price,
    double quantity, [
    String? reason,
  ]) {
    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: historicalData[_currentCandleIndex].timestamp,
      type: type,
      price: price,
      quantity: quantity,
      candleIndex: _currentCandleIndex,
      reason: reason,
    );
    _currentTrades.add(trade);

    // El P&L se calculará cuando se cierre la posición
    // No calcular P&L aquí para evitar duplicación

    _notifyUIUpdate();
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
      startDate: historicalData.first.timestamp,
      endDate: historicalData.last.timestamp,
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
    _notifyChartReset();
  }

  void setSimulationMode(SimulationMode mode) {
    _simulationMode = mode;
    debugPrint('🔥 SimulationProvider: Modo de simulación cambiado a: $mode');
    _notifySimulationState();
  }

  void setSimulationSpeed(double speed) {
    _simulationSpeed = speed;
    debugPrint(
      '🔥 SimulationProvider: Velocidad de simulación cambiada a: $speed',
    );
    _notifySimulationState();
  }

  void advanceCandle() {
    if (_simulationMode != SimulationMode.manual) {
      debugPrint(
        '🔥 SimulationProvider: No se puede avanzar manualmente en modo automático',
      );
      return;
    }

    if (_currentCandleIndex >= historicalData.length - 1) {
      debugPrint('🔥 SimulationProvider: Ya se llegó al final de los datos');
      return;
    }

    _advanceCandleManually();
    debugPrint(
      '🔥 SimulationProvider: Vela avanzada manualmente a índice: $_currentCandleIndex',
    );
  }

  void _advanceCandleManually() {
    if (_currentCandleIndex >= historicalData.length - 1) {
      return;
    }

    _currentCandleIndex++;
    final currentCandle = historicalData[_currentCandleIndex];

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
    _notifyUIUpdate();
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
    if (index < 0 || index >= historicalData.length) {
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
    _notifyUIUpdate();
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

    final candle = historicalData[_currentCandleIndex];
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

    _notifyUIUpdate();
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
      timestamp: historicalData[_currentCandleIndex].timestamp,
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
    _notifyUIUpdate();
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

    _notifyUIUpdate();
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
    _notifyUIUpdate();
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
    _notifyUIUpdate();
  }

  // Cierre parcial de la posición abierta
  void closePartialPosition(double percent) {
    if (!_inPosition || percent <= 0 || percent > 100) return;
    final lastTrade = _currentTrades.last;
    final closeType = lastTrade.type == 'buy' ? 'sell' : 'buy';
    final currentPrice = historicalData[_currentCandleIndex].close;
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
      timestamp: historicalData[_currentCandleIndex].timestamp,
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
    _notifyUIUpdate();
  }

  // New methods for automatic setup parameter reading and position calculation
  void calculatePositionParameters(String tradeType) {
    if (_currentSetup == null || historicalData.isEmpty) {
      _setupParametersCalculated = false;
      return;
    }

    final currentPrice = historicalData[_currentCandleIndex].close;

    // 1. Calculate risk amount
    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);

    // 2. Calculate stop loss distance in price
    double slPriceDistance;
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      // Convert pips to price using the appropriate pip value for the active symbol
      final double pipValue = _pipValue;
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
    if (_currentSetup == null || historicalData.isEmpty) return false;

    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);
    if (riskAmount <= 0) return false;

    double slPriceDistance;
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      final double pipValue = _pipValue;
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

  // Exponer configuración para la UI
  int get ticksPerCandle => _ticksPerCandle;
  set ticksPerCandle(int value) {
    _ticksPerCandle = value;
    _notifySimulationState();
  }

  double get ticksPerSecondFactor => _ticksPerSecondFactor;
  set ticksPerSecondFactor(double value) {
    _ticksPerSecondFactor = value;
    _notifySimulationState();
  }

  // --- GENERADOR DE TICKS ---
  static List<Tick> generateSyntheticTicks(
    Candle candle,
    int steps, [
    int? nextCandleMs,
  ]) {
    final List<Tick> ticks = [];
    // Calcular duración de la vela
    final durationMs = nextCandleMs != null
        ? nextCandleMs - candle.timestamp.millisecondsSinceEpoch
        : 60 * 60 * 1000; // fallback: 1h
    final dt = durationMs ~/ steps;
    final range = candle.high - candle.low;
    final Random rnd = Random(candle.timestamp.millisecondsSinceEpoch);
    for (int i = 0; i < steps; i++) {
      final base =
          candle.open + (candle.close - candle.open) * (i / (steps - 1));
      final jitter =
          (rnd.nextDouble() * 2 - 1) * (range * 0.2); // ±20% del rango
      final price = (base + jitter).clamp(candle.low, candle.high);
      final time = candle.timestamp.add(Duration(milliseconds: dt * i));
      ticks.add(Tick(time, price));
    }
    return ticks;
  }

  // --- INICIAR SIMULACIÓN TICK A TICK ---
  void startTickSimulation(
    Setup setup,
    DateTime startDate,
    double speed,
    double initialBalance,
    String symbol,
  ) {
    setActiveSymbol(symbol);
    debugPrint('🔥🔥🔥 INICIANDO SIMULACIÓN TICK A TICK 🔥🔥🔥');
    debugPrint('🔥 Setup: ${setup.name}');
    debugPrint('🔥 Velocidad: $speed');
    debugPrint('🔥 Balance inicial: $initialBalance');
    debugPrint(
      '🔥 Datos históricos disponibles: ${historicalData.length} velas',
    );
    debugPrint('🔥 Timeframe activo: ${_activeTf.name}');
    debugPrint('🔥 Ticks por vela: $_ticksPerCandle');

    // Reinicializar todo para nueva simulación
    _currentSimulation = null;
    _currentCandleIndex = 0;
    _currentBalance = initialBalance;
    _currentTrades = [];
    _completedTrades = [];
    _completedOperations = [];
    _equityCurve = [initialBalance];

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
    _defaultStopLossPercent = null;
    _defaultTakeProfitPercent = null;
    _stopLossEnabled = false;
    _takeProfitEnabled = false;

    // Reset tick simulation state
    _currentCandleTicks.clear();
    _currentCandleStartTime = null;
    _currentTickIndex = 0;
    _wasPaused = false;
    _pausedTickIndex = 0;
    _pausedCandleTicks.clear();
    _pausedCandleStartTime = null;

    _isSimulationRunning = false;
    _currentSetup = setup;
    _simulationSpeed = speed;
    _ticksPerSecondFactor = 1.0;

    // Configurar ticks para la vela actual
    _setupTicksForCurrentCandle();
    notifyListeners();
    _isSimulationRunning = true;
    debugPrint('🔥 Simulación marcada como corriendo: $_isSimulationRunning');
    _startTickTimer();
    notifyListeners();
    debugPrint('🔥🔥🔥 SIMULACIÓN INICIADA COMPLETAMENTE 🔥🔥🔥');
  }

  void _startTickTimer() {
    _tickTimer?.cancel();
    if (!_isSimulationRunning) {
      debugPrint(
        '🔥 SimulationProvider: No se puede iniciar timer - simulación no está corriendo',
      );
      return; // Verificar que esté corriendo
    }

    final intervalMs = (1000 ~/ (_simulationSpeed * _ticksPerSecondFactor))
        .clamp(1, 1000);

    debugPrint(
      '🔥 SimulationProvider: Iniciando timer con intervalo ${intervalMs}ms, velocidad: $_simulationSpeed, factor: $_ticksPerSecondFactor',
    );

    _tickTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      debugPrint(
        '🔥 Timer callback ejecutado - isSimulationRunning: $_isSimulationRunning',
      );
      if (_isSimulationRunning) {
        debugPrint('🔥 SimulationProvider: Procesando tick...');
        _processNextTick();
      } else {
        debugPrint(
          '🔥 SimulationProvider: Timer activo pero simulación no está corriendo',
        );
      }
    });

    debugPrint('🔥 Timer creado exitosamente con ID: ${_tickTimer.hashCode}');
  }

  void stopTickSimulation() {
    _tickTimer?.cancel();
    stopSimulation();
  }

  void pauseTickSimulation() {
    debugPrint('🔥 PAUSE: Iniciando pausa de simulación');

    // Guardar estado actual antes de pausar
    _wasPaused = true;
    _pausedTickIndex = _currentTickIndex;
    _pausedCandleTicks = List.from(_currentCandleTicks);
    _pausedCandleStartTime = _currentCandleStartTime;

    debugPrint(
      '🔥 PAUSE: Estado guardado - tick: $_pausedTickIndex, ticks acumulados: ${_pausedCandleTicks.length}',
    );

    // Detener timer
    _tickTimer?.cancel();

    // Enviar señal de pausa al gráfico
    if (_tickCallback != null) {
      final msg = {
        'pause': true,
        'trades': _currentTrades
            .map(
              (t) => {
                'time': t.timestamp.millisecondsSinceEpoch ~/ 1000,
                'type': t.type,
                'price': t.price,
                'amount': t.amount ?? 0.0,
                'leverage': t.leverage ?? 1,
                'reason': t.reason ?? '',
              },
            )
            .toList(),
        'stopLoss': stopLossPrice > 0 ? stopLossPrice : null,
        'takeProfit': takeProfitPrice > 0 ? takeProfitPrice : null,
      };
      debugPrint('🔥 PAUSE: Enviando señal de pausa al gráfico');
      _tickCallback!(msg);
    }

    // Pausar simulación
    pauseSimulation();
    debugPrint('🔥 PAUSE: Simulación pausada');
  }

  void resumeTickSimulation() {
    debugPrint('🔥 RESUME: Método resumeTickSimulation() llamado');

    if (!_wasPaused) {
      debugPrint('🔥 RESUME: No estaba pausado, saliendo');
      return;
    }

    debugPrint('🔥 RESUME: Restaurando estado guardado');

    // Restaurar estado guardado
    _currentTickIndex = _pausedTickIndex;
    _currentCandleTicks = List.from(_pausedCandleTicks);
    _currentCandleStartTime = _pausedCandleStartTime;

    debugPrint(
      '🔥 RESUME: Estado restaurado - tick: $_currentTickIndex, ticks acumulados: ${_currentCandleTicks.length}',
    );

    // Marcar como corriendo
    _isSimulationRunning = true;

    // Reiniciar timer
    _startTickTimer();

    // Enviar señal de reanudación al gráfico
    if (_tickCallback != null) {
      final resumeMsg = {'pause': false};
      debugPrint('🔥 RESUME: Enviando señal de reanudación al chart');
      _tickCallback!(resumeMsg);
    }

    // Limpiar estado de pausa
    _wasPaused = false;
    _pausedTickIndex = 0;
    _pausedCandleTicks.clear();
    _pausedCandleStartTime = null;

    // Notificar cambios
    _notifySimulationState();
    debugPrint('🔥 RESUME: Simulación reanudada');
  }

  // --- LOOP DE SIMULACIÓN POR TICK ---
  void _processNextTick() {
    if (!_isSimulationRunning) {
      debugPrint(
        '🔥 SimulationProvider: _processNextTick - simulación no está corriendo',
      );
      return;
    }

    debugPrint(
      '🔥 SimulationProvider: _processNextTick - tick $_currentTickIndex de ${_syntheticTicks.length}',
    );

    if (_currentTickIndex >= _syntheticTicks.length) {
      debugPrint('🔥 SimulationProvider: Cambiando a siguiente vela');
      _currentCandleIndex++;
      if (_currentCandleIndex >= historicalData.length) {
        debugPrint('🔥 SimulationProvider: Fin de datos alcanzado');
        stopTickSimulation();
        return;
      }
      _setupTicksForCurrentCandle();
    }

    if (_currentTickIndex < _syntheticTicks.length) {
      final tick = _syntheticTicks[_currentTickIndex++];
      debugPrint(
        '🔥 SimulationProvider: Procesando tick ${tick.price} a las ${tick.time}',
      );
      _accumulateTickForCandle(tick);
    } else {
      debugPrint('🔥 SimulationProvider: Índice de tick fuera de rango');
    }
  }

  void _accumulateTickForCandle(Tick tick) {
    debugPrint(
      '🔥 TICK: Procesando tick - precio: ${tick.price}, tiempo: ${tick.time}',
    );
    debugPrint(
      '🔥 TICK: Estado de simulación - isSimulationRunning: $_isSimulationRunning',
    );

    // Verificar que la simulación esté corriendo antes de procesar
    if (!_isSimulationRunning) {
      debugPrint('🔥 TICK: Simulación pausada, no procesando tick');
      return;
    }

    // Inicializar tiempo de inicio de la vela si es el primer tick
    if (_currentCandleTicks.isEmpty) {
      _currentCandleStartTime = tick.time;
      debugPrint('🔥 TICK: Iniciando nueva vela a las ${tick.time}');
    }

    // Agregar tick a la vela actual
    _currentCandleTicks.add(tick);
    debugPrint(
      '🔥 TICK: Tick agregado. Total acumulados: ${_currentCandleTicks.length}',
    );

    // Calcular OHLC de los ticks acumulados hasta ahora
    final prices = _currentCandleTicks.map((t) => t.price).toList();
    final o = prices.first, c = prices.last;
    final h = prices.reduce((a, b) => a > b ? a : b);
    final l = prices.reduce((a, b) => a < b ? a : b);
    final ts =
        (_currentCandleStartTime ?? tick.time).millisecondsSinceEpoch ~/ 1000;

    debugPrint(
      '🔥 TICK: Vela actualizada - OHLC: $o/$h/$l/$c, ticks: ${_currentCandleTicks.length}/$_ticksPerCandle',
    );
    debugPrint('🔥 TICK: Timestamp de vela: $ts');

    // Solo enviar vela actualizada al gráfico si la simulación está corriendo
    if (_isSimulationRunning && _tickCallback != null) {
      final msg = {
        'candle': {'time': ts, 'open': o, 'high': h, 'low': l, 'close': c},
        'trades': _currentTrades
            .map(
              (t) => {
                'time': t.timestamp.millisecondsSinceEpoch ~/ 1000,
                'type': t.type,
                'price': t.price,
                'amount': t.amount ?? 0.0,
                'leverage': t.leverage ?? 1,
                'reason': t.reason ?? '',
              },
            )
            .toList(),
        'stopLoss': stopLossPrice > 0 ? stopLossPrice : null,
        'takeProfit': takeProfitPrice > 0 ? takeProfitPrice : null,
      };

      debugPrint('🔥 TICK: Enviando vela al chart: $msg');
      _tickCallback!(msg); // sólo enviamos al WebView
    } else {
      debugPrint(
        '🔥 TICK: No enviando vela - simulación pausada o callback null',
      );
    }

    // Si hemos acumulado suficientes ticks, finalizar la vela y pasar a la siguiente
    if (_currentCandleTicks.length >= _ticksPerCandle) {
      debugPrint('🔥 TICK: Vela completada, limpiando ticks acumulados');
      _currentCandleTicks.clear();
      _currentCandleStartTime = null;
    }
  }

  // --- MODO MANUAL: AVANZAR UN TICK ---
  void advanceTick() {
    if (_simulationMode != SimulationMode.manual) return;
    _processNextTick();
  }

  // --- ENVÍO DE TICK AL CHART (mantener para compatibilidad) ---
  Function(Map<String, dynamic>)? _tickCallback;

  void setTickCallback(Function(Map<String, dynamic>) callback) {
    _tickCallback = callback;
  }

  bool get isSimulationPaused => _wasPaused;

  // --- NOTIFICACIONES GRANULARES ---

  /// Notifica cambios que NO requieren reinicio del gráfico
  void _notifyUIUpdate() {
    notifyListeners();
  }

  /// Notifica cambios que SÍ requieren reinicio del gráfico (solo cuando cambian las velas base)
  void _notifyChartReset() {
    notifyListeners();
  }

  /// Notifica cambios de estado de simulación sin reiniciar gráfico
  void _notifySimulationState() {
    notifyListeners();
  }
}
