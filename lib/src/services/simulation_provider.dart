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

enum SimulationMode { manual }

// --- TIMEFRAMES ---
enum Timeframe { d1, h1, m15, m5, m1 }

class SimulationProvider with ChangeNotifier {
  /// Valores de pip para los pares más tradeados
  static const Map<String, double> _pipValues = {
    'EURUSD': 0.0001,
    'EUR/USD': 0.0001,
    'GBPUSD': 0.0001,
    'GBP/USD': 0.0001,
    'USDJPY': 0.01,
    'USD/JPY': 0.01,
    'AUDUSD': 0.0001,
    'AUD/USD': 0.0001,
    'USDCAD': 0.0001,
    'USD/CAD': 0.0001,
    'NZDUSD': 0.0001,
    'NZD/USD': 0.0001,
    'BTCUSD': 1.0,
    'BTC/USD': 1.0,
  };

  String? _activeSymbol;

  SimulationResult? _currentSimulation;
  final List<SimulationResult> _simulationHistory = [];

  // --- MULTI-TIMEFRAME DATA ---
  late Map<Timeframe, List<Candle>> _allTimeframes;
  Timeframe _activeTf = Timeframe.h1;

  static const int baseTicksPerMinute = 10;

  // Mapa de ticks por vela para cada timeframe
  static final Map<Timeframe, int> _ticksPerCandleMap = {
    Timeframe.m1: baseTicksPerMinute * 1, // 10 ticks por 1 m
    Timeframe.m5: baseTicksPerMinute * 5, // 50 ticks por 5 m = 5×10
    Timeframe.m15: baseTicksPerMinute * 15, // 150 ticks por 15 m = 15×10
    Timeframe.h1: baseTicksPerMinute * 60, // 600 ticks por 1 h = 60×10
    Timeframe.d1: baseTicksPerMinute * 1440, // 14400 ticks por 1 d = 1440×10
  };

  bool _isSimulationRunning = false;
  int _currentCandleIndex = 0;
  double _currentBalance = 10000.0;
  List<Trade> _currentTrades = [];
  List<Trade> _completedTrades = [];
  List<CompletedTrade> _completedOperations = [];
  List<double> _equityCurve = [];
  Setup? _currentSetup;

  // Trading state
  bool _inPosition = false;
  double _entryPrice = 0.0;
  double _positionSize = 0.0;
  double _stopLossPrice = 0.0;
  double _takeProfitPrice = 0.0;

  // Simulation mode
  SimulationMode _simulationMode = SimulationMode.manual;
  double _simulationSpeed = 1.0; // candles per second

  // Calculated position parameters
  double? _calculatedPositionSize;
  double? _calculatedLeverage;
  double? _calculatedStopLossPrice;
  double? _calculatedTakeProfitPrice;
  bool _setupParametersCalculated = false;

  // --- TICK SIMULATION STATE ---
  List<Tick> _syntheticTicks = [];
  int _currentTickIndex = 0;
  int _ticksPerCandle = 100;
  Timer? _tickTimer;
  double _ticksPerSecondFactor = 1.0; // Para ajustar velocidad

  // --- ACUMULACIÓN DE TICKS PARA VELAS ---
  final List<Tick> _currentCandleTicks = [];
  DateTime? _currentCandleStartTime;

  // --- ENVÍO DE TICK AL CHART ---
  Function(Map<String, dynamic>)? _tickCallback;

  /// Fija el símbolo activo (desde SimulationSetupScreen)
  void setActiveSymbol(String symbol) {
    _activeSymbol = symbol;

    // Mostrar información específica del par
    if (_activeSymbol != null) {
      if (_activeSymbol!.contains('EUR') ||
          _activeSymbol!.contains('GBP') ||
          _activeSymbol!.contains('AUD') ||
          _activeSymbol!.contains('NZD')) {
        // debugPrint(
        //   '🔥 SimulationProvider: Par de divisas mayor - pip value = 0.0001',
        // );
      } else if (_activeSymbol!.contains('JPY')) {
        // debugPrint('🔥 SimulationProvider: Par con JPY - pip value = 0.01');
      } else if (_activeSymbol!.contains('BTC')) {
        // debugPrint('🔥 SimulationProvider: Criptomoneda - pip value = 1.0');
      }
    }
  }

  double get _pipValue =>
      _pipValues[_activeSymbol] ?? 0.0001; // fallback genérico

  String? get activeSymbol => _activeSymbol;

  double? get calculatedPositionSize => _calculatedPositionSize;
  double? get calculatedLeverage => _calculatedLeverage;
  double? get calculatedStopLossPrice => _calculatedStopLossPrice;
  double? get calculatedTakeProfitPrice => _calculatedTakeProfitPrice;
  bool get setupParametersCalculated => _setupParametersCalculated;

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
  List<Trade> get completedTrades => _completedTrades;
  List<CompletedTrade> get completedOperations => _completedOperations;
  List<double> get equityCurve => _equityCurve;
  bool get inPosition => _inPosition;
  double get entryPrice => _entryPrice;
  double get positionSize => _positionSize;
  double get stopLossPrice => _stopLossPrice;
  double get takeProfitPrice => _takeProfitPrice;
  Setup? get currentSetup => _currentSetup;
  SimulationMode get simulationMode => _simulationMode;
  double get simulationSpeed => _simulationSpeed;

  // Get current tick price (for manual trades when simulation is paused)
  double get currentTickPrice {
    if (_syntheticTicks.isEmpty ||
        _currentTickIndex >= _syntheticTicks.length) {
      final fallbackPrice = historicalData[_currentCandleIndex].close;
      // debugPrint(
      //   '🔥 SimulationProvider: currentTickPrice - usando precio de vela: $fallbackPrice (no hay ticks disponibles)',
      // );
      return fallbackPrice;
    }
    final tickPrice = _syntheticTicks[_currentTickIndex].price;
    // debugPrint(
    //   '🔥 SimulationProvider: currentTickPrice - tick $_currentTickIndex: $tickPrice (simulación ${_isSimulationRunning ? 'corriendo' : 'pausada'})',
    // );
    return tickPrice;
  }

  // Nuevo: obtener el precio del tick visible (el tick anterior al actual)
  double get lastVisibleTickPrice {
    if (_syntheticTicks.isEmpty) return 0.0;
    final idx = _currentTickIndex > 0 ? _currentTickIndex - 1 : 0;
    final price = _syntheticTicks[idx].price;
    // debugPrint(
    //   '🔥 SimulationProvider: lastVisibleTickPrice - idx: $idx, price: $price',
    // );
    return price;
  }

  // Calcula el P&L flotante basado en el precio actual del tick
  double get unrealizedPnL {
    if (!_inPosition || _currentTrades.isEmpty) return 0.0;

    final lastTrade = _currentTrades.last;
    final currentPrice = currentTickPrice;

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

  // Getters para compatibilidad con la UI
  double? get manualStopLossPrice => _calculatedStopLossPrice;
  double? get manualTakeProfitPrice => _calculatedTakeProfitPrice;
  bool get isSimulationPaused => !_isSimulationRunning;

  // Getters para SL/TP manuales (compatibilidad)
  double? get manualStopLossPercent =>
      null; // No se usan en la versión simplificada
  double? get manualTakeProfitPercent =>
      null; // No se usan en la versión simplificada
  double? get defaultStopLossPercent =>
      null; // No se usan en la versión simplificada
  double? get defaultTakeProfitPercent =>
      null; // No se usan en la versión simplificada

  void setHistoricalData(List<Candle> data) {
    // debugPrint(
    //   '🔥 SimulationProvider: setHistoricalData() - Datos recibidos: ${data.length} velas',
    // );
    if (data.isNotEmpty) {
      // debugPrint(
      //   '🔥 SimulationProvider: Primera vela: ${data.first.timestamp} - ${data.first.close}',
      // );
      // debugPrint(
      //   '🔥 SimulationProvider: Última vela: ${data.last.timestamp} - ${data.last.close}',
      // );
    }
    loadRawData(data);
  }

  // --- MULTI-TIMEFRAME METHODS ---
  void loadRawData(List<Candle> raw) {
    // debugPrint(
    //   '🔥 SimulationProvider: loadRawData() - Procesando ${raw.length} velas raw',
    // );

    // Reagrupar datos en todos los timeframes
    _allTimeframes = {
      Timeframe.d1: reaggregate(raw, const Duration(days: 1)),
      Timeframe.h1: reaggregate(raw, const Duration(hours: 1)),
      Timeframe.m15: reaggregate(raw, const Duration(minutes: 15)),
      Timeframe.m5: reaggregate(raw, const Duration(minutes: 5)),
      Timeframe.m1: reaggregate(raw, const Duration(minutes: 1)),
    };

    // Inicializar con H1 por defecto
    _activeTf = Timeframe.h1;
    _currentCandleIndex = 0;

    // Actualizar _ticksPerCandle según el timeframe inicial
    _ticksPerCandle = _ticksPerCandleMap[_activeTf]!;
    // debugPrint(
    //   '🔥 SimulationProvider: _ticksPerCandle inicializado a $_ticksPerCandle para ${_activeTf.name}',
    // );

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
      // paso de TF menor → mayor: agrupo "factor" velas y guardo el resto
      final factor = newTicks ~/ oldTicks;
      final fullGroups = oldIndex ~/ factor;
      newIndex = fullGroups;
    } else {
      // paso de TF mayor → menor: subdivido y reaplico el resto
      final factor = oldTicks ~/ newTicks;
      newIndex = oldIndex * factor;
    }

    // 2) clamp y notifica
    final maxIdx = _allTimeframes[tf]!.length - 1;
    _currentCandleIndex = newIndex.clamp(0, maxIdx);

    _setupTicksForCurrentCandle();
    _notifyChartReset();
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
    _completedTrades = [];
    _completedOperations = [];
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
      totalTrades: completedOperations.length,
      winningTrades: winningTrades,
      trades: _completedTrades,
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
    _completedTrades = [];
    _completedOperations = [];
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

    // En modo manual, solo actualizar la equity curve
    _equityCurve.add(_currentBalance);
    _notifyUIUpdate();
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

  // --- MÉTODO PRINCIPAL: CÁLCULO DE PARÁMETROS DE POSICIÓN ---
  void calculatePositionParameters(String type, double entryPrice) {
    if (_currentSetup == null || historicalData.isEmpty) {
      _setupParametersCalculated = false;
      return;
    }

    // 1. Calculate risk amount
    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);

    // 2. Calculate stop loss distance in price
    double priceDistance;
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      // Convert pips to price using the appropriate pip value for the active symbol
      final double pipValue = _pipValue;
      priceDistance = _currentSetup!.stopLossDistance * pipValue;
      debugPrint(
        '🔥 SimulationProvider: SL calculation - Setup SL: ${_currentSetup!.stopLossDistance} pips, Pip Value: $pipValue, Active Symbol: $_activeSymbol, SL Distance: $priceDistance',
      );
    } else {
      // Use price distance directly
      priceDistance = _currentSetup!.stopLossDistance;
      debugPrint(
        '🔥 SimulationProvider: SL calculation - Setup SL: ${_currentSetup!.stopLossDistance} (price distance), SL Distance: $priceDistance',
      );
    }

    // 3. Calculate position size
    if (priceDistance <= 0) {
      _setupParametersCalculated = false;
      return;
    }

    _calculatedPositionSize = riskAmount / priceDistance;

    // 4. Set leverage (use setup leverage if defined, otherwise 1x)
    _calculatedLeverage = 1.0; // Default leverage

    // 5. Calculate stop loss and take profit prices using ENTRY PRICE
    final takeProfitRR = _currentSetup!.getEffectiveTakeProfitRatio();

    debugPrint(
      '🔥 SimulationProvider: DEBUG - Entry Price: $entryPrice, Price Distance: $priceDistance, Take Profit RR: $takeProfitRR',
    );
    debugPrint(
      '🔥 SimulationProvider: DEBUG - Setup Take Profit Ratio: ${_currentSetup!.takeProfitRatio}, Custom Value: ${_currentSetup!.customTakeProfitRatio}',
    );

    // Mostrar cálculo de pips para mayor claridad
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      final pipsDistance = _currentSetup!.stopLossDistance;
      final calculatedPips = priceDistance / _pipValue;
      debugPrint(
        '🔥 SimulationProvider: DEBUG - Pips calculation: $pipsDistance pips × $_pipValue pip value = $calculatedPips price distance',
      );
    }

    if (type == 'buy') {
      _calculatedStopLossPrice = entryPrice - priceDistance;
      _calculatedTakeProfitPrice = entryPrice + (priceDistance * takeProfitRR);
      debugPrint(
        '🔥 SimulationProvider: DEBUG - BUY - SL: $_calculatedStopLossPrice ($entryPrice - $priceDistance), TP: $_calculatedTakeProfitPrice ($entryPrice + $priceDistance * $takeProfitRR)',
      );
    } else {
      _calculatedStopLossPrice = entryPrice + priceDistance;
      _calculatedTakeProfitPrice = entryPrice - (priceDistance * takeProfitRR);
      debugPrint(
        '🔥 SimulationProvider: DEBUG - SELL - SL: $_calculatedStopLossPrice ($entryPrice + $priceDistance), TP: $_calculatedTakeProfitPrice ($entryPrice - $priceDistance * $takeProfitRR)',
      );
    }

    _setupParametersCalculated = true;
    debugPrint(
      '🔥 SimulationProvider: Position parameters calculated - Entry: $entryPrice, Size: $_calculatedPositionSize, SL: $_calculatedStopLossPrice, TP: $_calculatedTakeProfitPrice',
    );
  }

  // --- MÉTODO PARA EJECUTAR TRADE MANUAL ---
  void executeManualTrade({
    required String type,
    required double amount,
    required int leverage,
    double? entryPrice, // Precio de entrada específico (opcional)
  }) {
    if (_currentSetup == null) return;

    // Use provided entry price or current tick price
    final price = entryPrice ?? currentTickPrice;

    // Si se proporciona un precio específico, usar el tiempo del tick actual
    // para mantener la sincronización temporal
    final currentTime = entryPrice != null
        ? (_syntheticTicks.isNotEmpty &&
                  _currentTickIndex < _syntheticTicks.length
              ? _syntheticTicks[_currentTickIndex].time
              : historicalData[_currentCandleIndex].timestamp)
        : (_syntheticTicks.isNotEmpty &&
                  _currentTickIndex < _syntheticTicks.length
              ? _syntheticTicks[_currentTickIndex].time
              : historicalData[_currentCandleIndex].timestamp);

    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - Using price: $price (${entryPrice != null ? 'provided entry price' : 'current tick price'})',
    );
    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - Current tick index: $_currentTickIndex, Total ticks: ${_syntheticTicks.length}',
    );
    if (entryPrice != null) {
      debugPrint(
        '🔥 SimulationProvider: executeManualTrade - Entry price provided: $entryPrice, will use this exact price',
      );
    }

    // Solo calcular parámetros si SL o TP no fueron seteados manualmente
    if (_calculatedStopLossPrice == null ||
        _calculatedTakeProfitPrice == null) {
      debugPrint(
        '🔥 SimulationProvider: executeManualTrade - Calculando parámetros con precio: $price (no hay SL/TP manual)',
      );
      calculatePositionParameters(type, price);
    } else {
      debugPrint(
        '🔥 SimulationProvider: executeManualTrade - Usando SL/TP manual: SL=$_calculatedStopLossPrice, TP=$_calculatedTakeProfitPrice',
      );
    }

    final trade = Trade(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: currentTime,
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

    // Enviar datos al WebView para dibujar las líneas
    if (_tickCallback != null) {
      final msg = {
        'entryPrice': price,
        'stopLoss': _calculatedStopLossPrice,
        'takeProfit': _calculatedTakeProfitPrice,
      };
      debugPrint(
        '🔥 SimulationProvider: Enviando datos de posición al WebView: $msg',
      );
      _tickCallback!(msg);
    }

    _notifyUIUpdate();
  }

  // --- MÉTODO PARA CERRAR POSICIÓN MANUAL ---
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

    // Reset calculated parameters
    _calculatedPositionSize = null;
    _calculatedLeverage = null;
    _calculatedStopLossPrice = null;
    _calculatedTakeProfitPrice = null;
    _setupParametersCalculated = false;

    _currentTrades.clear();

    // Enviar señal de cierre de orden al WebView para limpiar las líneas
    if (_tickCallback != null) {
      final closeOrderMsg = {'closeOrder': true};
      debugPrint('🔥 SimulationProvider: Enviando señal closeOrder al WebView');
      _tickCallback!(closeOrderMsg);
    }

    _notifyUIUpdate();
  }

  // --- MÉTODO PARA CANCELAR ÓRDENES ---
  void cancelOrder() {
    // Enviar señal de cierre de orden al WebView para limpiar las líneas
    if (_tickCallback != null) {
      final closeOrderMsg = {'closeOrder': true};
      debugPrint(
        '🔥 SimulationProvider: Enviando señal closeOrder al WebView (cancelación)',
      );
      _tickCallback!(closeOrderMsg);
    }
  }

  // Validate if position can be calculated
  bool canCalculatePosition() {
    if (_currentSetup == null || historicalData.isEmpty) return false;

    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);
    if (riskAmount <= 0) return false;

    double priceDistance;
    if (_currentSetup!.stopLossType == StopLossType.pips) {
      final double pipValue = _pipValue;
      priceDistance = _currentSetup!.stopLossDistance * pipValue;
    } else {
      priceDistance = _currentSetup!.stopLossDistance;
    }

    if (priceDistance <= 0) return false;

    // Verificar que se pueda calcular el tamaño de la posición
    final positionSize = riskAmount / priceDistance;
    return positionSize > 0;
  }

  // Get position summary text
  String getPositionSummaryText() {
    if (!_setupParametersCalculated || _currentSetup == null) {
      return 'No se puede calcular la posición';
    }

    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);
    return 'Posición: ${_calculatedPositionSize!.toStringAsFixed(4)} unidades @ ${_calculatedLeverage!.toStringAsFixed(0)}x (riesgo ${_currentSetup!.riskPercent.toStringAsFixed(1)}% = \$${riskAmount.toStringAsFixed(0)})';
  }

  // Debug method to show detailed SL/TP calculation info
  String getDebugSLTPInfo() {
    if (_currentSetup == null) {
      return 'No hay setup configurado';
    }

    final currentPrice = currentTickPrice;
    final riskAmount = _currentBalance * (_currentSetup!.riskPercent / 100);
    final pipValue = _pipValue;
    final takeProfitRatio = _currentSetup!.getEffectiveTakeProfitRatio();

    String info = '🔍 DEBUG SL/TP INFO:\n';
    info += '• Activo: $_activeSymbol\n';
    info += '• Pip Value: $pipValue\n';
    info +=
        '• Setup SL: ${_currentSetup!.stopLossDistance} ${_currentSetup!.stopLossType == StopLossType.pips ? 'pips' : 'price'}\n';
    info += '• Setup TP Ratio: $takeProfitRatio\n';
    info += '• Current Tick Price: $currentPrice\n';
    info +=
        '• Candle Close Price: ${historicalData[_currentCandleIndex].close}\n';
    info += '• Tick Index: $_currentTickIndex/${_syntheticTicks.length}\n';
    info += '• Risk Amount: \$${riskAmount.toStringAsFixed(2)}\n';
    info += '• In Position: $_inPosition\n';
    info += '• Entry Price: ${_entryPrice.toStringAsFixed(5)}\n';
    info +=
        '• Calculated SL Price: ${_calculatedStopLossPrice?.toStringAsFixed(5) ?? 'N/A'}\n';
    info +=
        '• Calculated TP Price: ${_calculatedTakeProfitPrice?.toStringAsFixed(5) ?? 'N/A'}';

    // Agregar información de diferencias para mayor claridad
    if (_calculatedStopLossPrice != null &&
        _calculatedTakeProfitPrice != null &&
        _entryPrice > 0) {
      final slDiff = _calculatedStopLossPrice! - _entryPrice;
      final tpDiff = _calculatedTakeProfitPrice! - _entryPrice;
      final slPercent = (slDiff / _entryPrice) * 100;
      final tpPercent = (tpDiff / _entryPrice) * 100;

      info +=
          '\n• SL Distance: ${slDiff.toStringAsFixed(6)} (${slPercent.toStringAsFixed(4)}%)\n';
      info +=
          '• TP Distance: ${tpDiff.toStringAsFixed(6)} (${tpPercent.toStringAsFixed(4)}%)\n';
      info += '• TP/SL Ratio: ${(tpDiff / slDiff).abs().toStringAsFixed(2)}:1';
    }

    return info;
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

    // Reset tick simulation state
    _currentCandleTicks.clear();
    _currentCandleStartTime = null;
    _currentTickIndex = 0;

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
      return;
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
    _tickTimer?.cancel();
    pauseSimulation();
    debugPrint('🔥 PAUSE: Simulación pausada');
  }

  void resumeTickSimulation() {
    debugPrint('🔥 RESUME: Método resumeTickSimulation() llamado');
    _isSimulationRunning = true;
    _startTickTimer();
    _notifySimulationState();
    debugPrint('🔥 RESUME: Simulación reanudada');
  }

  // Métodos para compatibilidad con la UI (no se usan en la versión simplificada)
  void setManualTakeProfit(double? takeProfitPercent) {
    // No se implementa en la versión simplificada
    debugPrint(
      '🔥 SimulationProvider: setManualTakeProfit no implementado en versión simplificada',
    );
  }

  void setManualStopLoss(double? stopLossPercent) {
    // No se implementa en la versión simplificada
    debugPrint(
      '🔥 SimulationProvider: setManualStopLoss no implementado en versión simplificada',
    );
  }

  void closePartialPosition(double percent) {
    // No se implementa en la versión simplificada
    debugPrint(
      '🔥 SimulationProvider: closePartialPosition no implementado en versión simplificada',
    );
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
      };

      debugPrint('🔥 TICK: Enviando vela al chart: $msg');
      _tickCallback!(msg);
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

  // --- ENVÍO DE TICK AL CHART ---
  void setTickCallback(Function(Map<String, dynamic>) callback) {
    _tickCallback = callback;
  }

  // --- NUEVOS MÉTODOS PARA SL/TP MANUAL ---
  void updateManualStopLoss(double price) {
    _calculatedStopLossPrice = price;
    debugPrint('updateManualStopLoss: nuevo SL =  [33m$price [0m');
    if (_tickCallback != null && _entryPrice > 0) {
      _tickCallback!({
        'entryPrice': _entryPrice,
        'stopLoss': _calculatedStopLossPrice,
        'takeProfit': _calculatedTakeProfitPrice,
      });
    }
    notifyListeners();
  }

  void updateManualTakeProfit(double price) {
    _calculatedTakeProfitPrice = price;
    debugPrint('updateManualTakeProfit: nuevo TP =  [32m$price [0m');
    if (_tickCallback != null && _entryPrice > 0) {
      _tickCallback!({
        'entryPrice': _entryPrice,
        'stopLoss': _calculatedStopLossPrice,
        'takeProfit': _calculatedTakeProfitPrice,
      });
    }
    notifyListeners();
  }

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
