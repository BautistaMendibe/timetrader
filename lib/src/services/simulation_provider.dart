import 'package:flutter/foundation.dart';
import '../models/simulation_result.dart';
import '../models/candle.dart';
import '../models/setup.dart';
import '../models/tick.dart';
import 'data_service.dart';
import 'dart:async';
import 'dart:math';

// --- MODELO TICK ---
// Using Tick from models/tick.dart instead of local definition

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

  // --- REAL TICKS FROM CSV ---
  List<Tick> _allTicks = [];
  int _tickPointer = 0;
  DateTime _simulationClock = DateTime.now();

  // Initialize buffers for all timeframes
  void _initializeBuffers() {
    _buffers.clear();
    _currentBucket.clear();
    _lastEmittedTickCount.clear();
    _lastEmittedCount.clear();

    for (Timeframe tf in Timeframe.values) {
      _buffers[tf] = [];
      _currentBucket[tf] =
          null; // Initialize as null, will be set on first tick
      _lastEmittedTickCount[tf] = 0;
      _lastEmittedCount[tf] = 0;
    }

    debugPrint(
      '🔥 SimulationProvider: Buffers inicializados para todos los timeframes',
    );
  }

  // Calculate candle start time for a given timeframe
  DateTime _getCandleStart(DateTime tickTime, Timeframe timeframe) {
    switch (timeframe) {
      case Timeframe.m1:
        return DateTime(
          tickTime.year,
          tickTime.month,
          tickTime.day,
          tickTime.hour,
          tickTime.minute,
        );
      case Timeframe.m5:
        final minute = tickTime.minute - (tickTime.minute % 5);
        return DateTime(
          tickTime.year,
          tickTime.month,
          tickTime.day,
          tickTime.hour,
          minute,
        );
      case Timeframe.m15:
        final minute = tickTime.minute - (tickTime.minute % 15);
        return DateTime(
          tickTime.year,
          tickTime.month,
          tickTime.day,
          tickTime.hour,
          minute,
        );
      case Timeframe.h1:
        return DateTime(
          tickTime.year,
          tickTime.month,
          tickTime.day,
          tickTime.hour,
        );
      case Timeframe.d1:
        return DateTime(tickTime.year, tickTime.month, tickTime.day);
    }
  }

  // Get current bucket time safely (returns current time if bucket is null)
  DateTime _getCurrentBucketTime(Timeframe tf) {
    try {
      final bucketTime = _currentBucket[tf];
      if (bucketTime == null) {
        debugPrint(
          '🔥 GetCurrentBucketTime: Bucket null para ${tf.name}, usando DateTime.now()',
        );
        return DateTime.now();
      }
      return bucketTime;
    } catch (e) {
      debugPrint('🔥 GetCurrentBucketTime: ERROR para ${tf.name}: $e');
      return DateTime.now();
    }
  }

  // Removed _processTickForTimeframe as logic is now in _accumulateTickForCandle

  // Emit candle to WebView
  void _emitCandle(Timeframe tf, List<Tick> ticks, bool completed) {
    try {
      if (ticks.isEmpty) return;

      final prices = ticks.map((t) => t.price).toList();
      final open = prices.first;
      final close = prices.last;
      final high = prices.reduce((a, b) => a > b ? a : b);
      final low = prices.reduce((a, b) => a < b ? a : b);

      // Get the bucket time for this candle safely
      final bucketTime = _getCurrentBucketTime(tf);

      final candle = {
        'timeframe': tf.name,
        'time': bucketTime.millisecondsSinceEpoch ~/ 1000,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'completed': completed,
        'ticks_count': ticks.length,
      };

      debugPrint(
        '🔥 EmitCandle: ${tf.name} - OHLC: $open/$high/$low/$close (${completed ? 'COMPLETED' : 'partial'}) - ticks: ${ticks.length} - time: ${bucketTime.millisecondsSinceEpoch ~/ 1000}',
      );

      if (_tickCallback != null) {
        debugPrint('🔥 EmitCandle: Enviando vela al callback');
        _tickCallback!({'candle': candle, 'updateOnly': true});
      } else {
        debugPrint('🔥 EmitCandle: ERROR - _tickCallback es null');
      }
    } catch (e) {
      debugPrint('🔥 EmitCandle: ERROR emitiendo vela para ${tf.name}: $e');
    }
  }

  // Initialize chart with initial candles
  void _initializeChartWithCandles() {
    if (_tickCallback != null) {
      // Solo indicamos "resetea todo" al chart, sin mandar velas
      debugPrint('🔥 InitializeChart: Enviando reset al chart');
      _tickCallback!({'reset': true});
    }
  }

  // --- ACUMULACIÓN DE TICKS PARA VELAS ---
  final List<Tick> _currentCandleTicks = [];
  DateTime? _currentCandleStartTime;

  // --- MULTI-TIMEFRAME BUFFERS ---
  Map<Timeframe, List<Tick>> _buffers = {};
  Map<Timeframe, DateTime?> _currentBucket = {};
  Map<Timeframe, int> _lastEmittedTickCount = {};
  Map<Timeframe, int> _lastEmittedCount = {};

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

  // Get current partial candle for any timeframe
  Map<String, dynamic>? getCurrentPartialCandle(Timeframe timeframe) {
    final ticks = _buffers[timeframe];
    if (ticks == null || ticks.isEmpty) return null;

    final prices = ticks.map((t) => t.price).toList();
    final open = prices.first;
    final close = prices.last;
    final high = prices.reduce((a, b) => a > b ? a : b);
    final low = prices.reduce((a, b) => a < b ? a : b);

    // Calculate current candle start time
    final lastTick = ticks.last;
    final candleStart = _getCandleStart(lastTick.time, timeframe);

    return {
      'timeframe': timeframe.name,
      'time': candleStart.millisecondsSinceEpoch ~/ 1000,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'partial': true,
      'tickCount': ticks.length,
    };
  }

  // Get simulation progress info for any timeframe
  Map<String, dynamic> getTimeframeProgress(Timeframe timeframe) {
    final ticks = _buffers[timeframe] ?? [];
    final totalTicks = _allTicks.length;
    final processedTicks = _tickPointer;

    return {
      'timeframe': timeframe.name,
      'totalTicks': totalTicks,
      'processedTicks': processedTicks,
      'currentBufferSize': ticks.length,
      'progress': totalTicks > 0 ? (processedTicks / totalTicks) * 100 : 0.0,
      'currentTime': _simulationClock,
    };
  }

  // --- END-TO-END TEST METHOD ---
  Future<void> runEndToEndTest() async {
    debugPrint('🔥🔥🔥 INICIANDO TEST END-TO-END 🔥🔥🔥');

    try {
      // 1. Setup test data and simulation
      final testSetup = Setup(
        id: 'test_setup',
        name: 'Test Setup',
        riskPercent: 2.0,
        stopLossType: StopLossType.pips,
        stopLossDistance: 10.0,
        takeProfitRatio: TakeProfitRatio.oneToTwo,
        customTakeProfitRatio: null,
        createdAt: DateTime.now(),
      );

      debugPrint('🔥 TEST: Configurando simulación de prueba...');
      await startTickSimulation(
        testSetup,
        DateTime.now(),
        10.0, // Fast speed for testing
        10000.0,
        'EUR/USD',
      );

      // Verify CSV data consistency
      _verifyCSVConsistency();

      // 2. Run 100 ticks and monitor timeframe changes
      debugPrint('🔥 TEST: Ejecutando 100 ticks con cambios de timeframe...');

      int candleEmissionCount = 0;

      for (int i = 0; i < 100; i++) {
        // Process next tick
        _processNextTick();

        // Count candle emissions
        if (i % 10 == 0) {
          debugPrint('🔥 TEST: Tick $i - verificando emisión de velas...');
          // Check if any candles were emitted by checking buffer sizes
          for (Timeframe tf in Timeframe.values) {
            final bufferSize = _buffers[tf]?.length ?? 0;
            if (bufferSize > 0) {
              debugPrint('🔥 TEST: Buffer ${tf.name} tiene $bufferSize ticks');
            }
          }
        }

        // Change timeframes at specific points
        if (i == 25) {
          debugPrint('🔥 TEST: Cambiando a m5 en tick 25');
          setTimeframe(Timeframe.m5);
          _verifyTimeframeConsistency(Timeframe.m5, i);
        }

        if (i == 50) {
          debugPrint('🔥 TEST: Cambiando a m15 en tick 50');
          setTimeframe(Timeframe.m15);
          _verifyTimeframeConsistency(Timeframe.m15, i);
        }

        if (i == 75) {
          debugPrint('🔥 TEST: Cambiando a h1 en tick 75');
          setTimeframe(Timeframe.h1);
          _verifyTimeframeConsistency(Timeframe.h1, i);
        }

        // Verify candle consistency every 10 ticks
        if (i % 10 == 0) {
          _verifyCandleConsistency(i);
        }

        // Small delay to simulate real-time processing
        await Future.delayed(Duration(milliseconds: 50));
      }

      // 3. Test manual trade with timeframe switching
      debugPrint('🔥 TEST: Probando trade manual con cambio de timeframe...');
      await _testManualTradeWithTimeframeSwitch();

      debugPrint('🔥🔥🔥 TEST END-TO-END COMPLETADO EXITOSAMENTE 🔥🔥🔥');
    } catch (e) {
      debugPrint('🔥🔥🔥 ERROR EN TEST END-TO-END: $e 🔥🔥🔥');
    }
  }

  // Verify timeframe consistency
  void _verifyTimeframeConsistency(Timeframe timeframe, int tickIndex) {
    debugPrint(
      '🔥 VERIFY: Verificando consistencia para ${timeframe.name} en tick $tickIndex',
    );

    final progress = getTimeframeProgress(timeframe);
    final partialCandle = getCurrentPartialCandle(timeframe);

    debugPrint(
      '🔥 VERIFY: Progress - ${progress['processedTicks']}/${progress['totalTicks']} ticks',
    );
    debugPrint(
      '🔥 VERIFY: Buffer size - ${progress['currentBufferSize']} ticks',
    );

    if (partialCandle != null) {
      debugPrint(
        '🔥 VERIFY: Partial candle - OHLC: ${partialCandle['open']}/${partialCandle['high']}/${partialCandle['low']}/${partialCandle['close']}',
      );
      debugPrint('🔥 VERIFY: Timestamp - ${partialCandle['time']}');
    }

    // Verify that the timeframe is active
    assert(_activeTf == timeframe, 'Active timeframe should be $timeframe');
    debugPrint('🔥 VERIFY: Timeframe ${timeframe.name} activado correctamente');
  }

  // Verify candle consistency
  void _verifyCandleConsistency(int tickIndex) {
    debugPrint(
      '🔥 VERIFY: Verificando consistencia de velas en tick $tickIndex',
    );

    for (Timeframe tf in Timeframe.values) {
      final partialCandle = getCurrentPartialCandle(tf);
      if (partialCandle != null) {
        final open = partialCandle['open'] as double;
        final high = partialCandle['high'] as double;
        final low = partialCandle['low'] as double;
        final close = partialCandle['close'] as double;

        // Verify OHLC logic
        assert(high >= open, 'High should be >= Open');
        assert(high >= close, 'High should be >= Close');
        assert(low <= open, 'Low should be <= Open');
        assert(low <= close, 'Low should be <= Close');

        debugPrint(
          '🔥 VERIFY: ${tf.name} - OHLC válido: $open/$high/$low/$close',
        );
      }
    }
  }

  // Test manual trade with timeframe switching
  Future<void> _testManualTradeWithTimeframeSwitch() async {
    debugPrint('🔥 TRADE_TEST: Iniciando test de trade manual...');

    // 1. Open a manual trade
    debugPrint('🔥 TRADE_TEST: Abriendo posición manual...');
    executeManualTrade(type: 'buy', amount: 1000.0, leverage: 1);

    // Verify trade was opened
    assert(_inPosition, 'Should be in position after manual trade');
    assert(_currentTrades.isNotEmpty, 'Should have trades after manual trade');
    debugPrint(
      '🔥 TRADE_TEST: Posición abierta - Precio: ${_entryPrice}, SL: ${_calculatedStopLossPrice}, TP: ${_calculatedTakeProfitPrice}',
    );

    // 2. Switch timeframes and verify SL/TP alignment
    final timeframes = [
      Timeframe.m1,
      Timeframe.m5,
      Timeframe.m15,
      Timeframe.h1,
    ];

    for (Timeframe tf in timeframes) {
      debugPrint('🔥 TRADE_TEST: Cambiando a ${tf.name}...');
      setTimeframe(tf);

      // Verify SL/TP are still calculated
      assert(
        _calculatedStopLossPrice != null,
        'Stop loss should be calculated',
      );
      assert(
        _calculatedTakeProfitPrice != null,
        'Take profit should be calculated',
      );

      debugPrint(
        '🔥 TRADE_TEST: ${tf.name} - SL: ${_calculatedStopLossPrice}, TP: ${_calculatedTakeProfitPrice}',
      );

      // Process a few ticks to see if SL/TP are maintained
      for (int i = 0; i < 5; i++) {
        _processNextTick();
        await Future.delayed(Duration(milliseconds: 20));
      }

      // Verify position is still active
      assert(
        _inPosition,
        'Position should remain active after timeframe switch',
      );
      debugPrint('🔥 TRADE_TEST: Posición mantenida en ${tf.name}');
    }

    // 3. Close the position
    debugPrint('🔥 TRADE_TEST: Cerrando posición manual...');
    closeManualPosition(_currentTrades.last.price + 0.001); // Small profit

    assert(!_inPosition, 'Should not be in position after closing');
    debugPrint('🔥 TRADE_TEST: Posición cerrada exitosamente');
  }

  // Public method to trigger the end-to-end test
  Future<void> triggerEndToEndTest() async {
    debugPrint('🔥🔥🔥 TRIGGERING END-TO-END TEST 🔥🔥🔥');
    await runEndToEndTest();
  }

  // Verify callback is set
  bool isCallbackSet() {
    final isSet = _tickCallback != null;
    debugPrint('🔥 Callback verification: ${isSet ? 'SET' : 'NOT SET'}');
    return isSet;
  }

  // Verify ticks are loaded correctly
  void verifyTicksLoaded() {
    debugPrint('🔥 Verificando ticks cargados...');
    debugPrint('🔥 Total ticks: ${_allTicks.length}');
    debugPrint('🔥 Tick pointer: $_tickPointer');

    if (_allTicks.isNotEmpty) {
      debugPrint(
        '🔥 Primer tick: ${_allTicks.first.time} - ${_allTicks.first.price}',
      );
      debugPrint(
        '🔥 Último tick: ${_allTicks.last.time} - ${_allTicks.last.price}',
      );

      // Verify first few ticks
      for (int i = 0; i < _allTicks.length && i < 5; i++) {
        final tick = _allTicks[i];
        debugPrint('🔥 Tick $i: ${tick.time} - ${tick.price}');
      }
    } else {
      debugPrint('🔥 ERROR: No hay ticks cargados');
    }
  }

  // Debug current buffer state
  void debugBufferState() {
    debugPrint('🔥 DEBUG: Estado actual de buffers...');
    debugPrint('🔥 Active timeframe: ${_activeTf.name}');
    debugPrint('🔥 Simulation running: $_isSimulationRunning');

    for (Timeframe tf in Timeframe.values) {
      final buffer = _buffers[tf];
      final bucket = _currentBucket[tf];
      debugPrint(
        '🔥 ${tf.name}: ${buffer?.length ?? 0} ticks, bucket: $bucket',
      );
    }
  }

  // Simple verification method for testing
  void verifyMultiTimeframeFunctionality() {
    debugPrint('🔥🔥🔥 VERIFICANDO FUNCIONALIDAD MULTI-TIMEFRAME 🔥🔥🔥');

    // Test 1: Verify timeframe switching
    debugPrint('🔥 TEST 1: Verificando cambio de timeframes...');
    setTimeframe(Timeframe.m1);
    assert(_activeTf == Timeframe.m1, 'Timeframe should be m1');

    setTimeframe(Timeframe.m5);
    assert(_activeTf == Timeframe.m5, 'Timeframe should be m5');

    setTimeframe(Timeframe.h1);
    assert(_activeTf == Timeframe.h1, 'Timeframe should be h1');

    debugPrint('✅ TEST 1: Cambio de timeframes exitoso');

    // Test 2: Verify candle start calculation
    debugPrint('🔥 TEST 2: Verificando cálculo de inicio de velas...');
    final testTime = DateTime(2024, 1, 15, 14, 23, 45, 123);

    final m1Start = _getCandleStart(testTime, Timeframe.m1);
    final m5Start = _getCandleStart(testTime, Timeframe.m5);
    final h1Start = _getCandleStart(testTime, Timeframe.h1);

    assert(m1Start == DateTime(2024, 1, 15, 14, 23), 'm1 start incorrect');
    assert(m5Start == DateTime(2024, 1, 15, 14, 20), 'm5 start incorrect');
    assert(h1Start == DateTime(2024, 1, 15, 14), 'h1 start incorrect');

    debugPrint('✅ TEST 2: Cálculo de inicio de velas correcto');

    // Test 3: Verify buffer initialization
    debugPrint('🔥 TEST 3: Verificando inicialización de buffers...');
    _initializeBuffers();

    for (Timeframe tf in Timeframe.values) {
      assert(_buffers.containsKey(tf), 'Buffer should exist for ${tf.name}');
      assert(
        _currentBucket.containsKey(tf),
        'Current bucket should exist for ${tf.name}',
      );
      // Note: _currentBucket[tf] can be null initially, which is correct
    }

    debugPrint('✅ TEST 3: Inicialización de buffers correcta');

    // Test 4: Verify callback is set
    debugPrint('🔥 TEST 4: Verificando callback...');
    final callbackSet = isCallbackSet();
    assert(callbackSet, 'Tick callback should be set');
    debugPrint('✅ TEST 4: Callback verificado');

    // Test 5: Verify ticks are loaded
    debugPrint('🔥 TEST 5: Verificando ticks cargados...');
    verifyTicksLoaded();
    debugPrint('✅ TEST 5: Ticks verificados');

    debugPrint('🔥🔥🔥 TODAS LAS VERIFICACIONES PASARON EXITOSAMENTE 🔥🔥🔥');
  }

  // Verify CSV data consistency with real groupings
  void _verifyCSVConsistency() {
    debugPrint('🔥 CSV_VERIFY: Verificando consistencia con datos CSV...');

    if (_allTicks.isEmpty) {
      debugPrint('🔥 CSV_VERIFY: No hay ticks cargados');
      return;
    }

    // Test first 100 ticks for consistency
    final testTicks = _allTicks.take(100).toList();

    for (Timeframe tf in Timeframe.values) {
      debugPrint('🔥 CSV_VERIFY: Verificando ${tf.name}...');

      // Group ticks by timeframe manually
      final Map<DateTime, List<Tick>> groupedTicks = {};

      for (Tick tick in testTicks) {
        final candleStart = _getCandleStart(tick.time, tf);
        groupedTicks.putIfAbsent(candleStart, () => []).add(tick);
      }

      // Calculate OHLC for each group
      final sortedKeys = groupedTicks.keys.toList()..sort();
      for (DateTime key in sortedKeys) {
        final ticks = groupedTicks[key]!;
        if (ticks.length < 2) continue; // Skip incomplete candles

        final prices = ticks.map((t) => t.price).toList();
        final open = prices.first;
        final close = prices.last;
        final high = prices.reduce((a, b) => a > b ? a : b);
        final low = prices.reduce((a, b) => a < b ? a : b);

        debugPrint(
          '🔥 CSV_VERIFY: ${tf.name} - ${key} - OHLC: $open/$high/$low/$close (${ticks.length} ticks)',
        );

        // Verify OHLC logic
        assert(high >= open, 'High should be >= Open');
        assert(high >= close, 'High should be >= Close');
        assert(low <= open, 'Low should be <= Open');
        assert(low <= close, 'Low should be <= Close');
      }
    }

    debugPrint('🔥 CSV_VERIFY: Verificación completada exitosamente');
  }

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
    if (_allTicks.isEmpty) {
      final fallbackPrice = historicalData[_currentCandleIndex].close;
      // debugPrint(
      //   '🔥 SimulationProvider: currentTickPrice - usando precio de vela: $fallbackPrice (no hay ticks disponibles)',
      // );
      return fallbackPrice;
    }

    // Usar el índice anterior al actual para obtener el precio del tick procesado
    final tickIndex = _tickPointer > 0 ? _tickPointer - 1 : 0;
    if (tickIndex >= _allTicks.length) {
      final fallbackPrice = historicalData[_currentCandleIndex].close;
      return fallbackPrice;
    }

    final tickPrice = _allTicks[tickIndex].price;
    // debugPrint(
    //   '🔥 SimulationProvider: currentTickPrice - tick $tickIndex: $tickPrice (simulación ${_isSimulationRunning ? 'corriendo' : 'pausada'})',
    // );
    return tickPrice;
  }

  // Nuevo: obtener el precio del tick visible (el tick anterior al actual)
  double get lastVisibleTickPrice {
    if (_allTicks.isEmpty) return 0.0;
    final idx = _tickPointer > 0 ? _tickPointer - 1 : 0;
    final price = _allTicks[idx].price;
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

    debugPrint(
      '🔥 SimulationProvider: Cambiando timeframe de ${_activeTf.name} a ${tf.name}',
    );
    debugPrint(
      '🔥 SimulationProvider: Tick pointer actual: $_tickPointer de ${_allTicks.length}',
    );

    // 1) Actualizar timeframe activo sin tocar _tickPointer
    _activeTf = tf;

    // 2) Recalcular start y end de la vela actual según el nuevo TF
    if (_allTicks.isNotEmpty && _tickPointer > 0) {
      // Obtener el último tick procesado
      final lastTick = _allTicks[_tickPointer - 1];
      final currentCandleStart = _getCandleStart(lastTick.time, tf);

      debugPrint(
        '🔥 SimulationProvider: Último tick procesado: ${lastTick.time}',
      );
      debugPrint(
        '🔥 SimulationProvider: Start de vela actual para ${tf.name}: $currentCandleStart',
      );

      // 3) Solo actualizar el contador de emisiones para el nuevo timeframe
      final ticks = _buffers[tf] ?? [];
      if (ticks.isNotEmpty) {
        debugPrint(
          '🔥 SimulationProvider: Actualizando contador para ${tf.name} con ${ticks.length} ticks',
        );
        _lastEmittedCount[tf] = ticks.length;
      } else {
        debugPrint(
          '🔥 SimulationProvider: No hay ticks en buffer para ${tf.name}',
        );
      }
    }

    // 4) Notificar cambio sin reiniciar simulación
    _notifyUIUpdate();
    debugPrint(
      '🔥 SimulationProvider: Timeframe cambiado exitosamente a ${tf.name}',
    );
  }

  // Removed _setupTicksForCurrentCandle() as it's no longer used with real ticks

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

    // Para operaciones manuales (con entryPrice específico), usar el timestamp de la vela actual
    // Para operaciones automáticas, usar el timestamp del tick actual
    final currentTime = entryPrice != null
        ? historicalData[_currentCandleIndex]
              .timestamp // Siempre usar timestamp de la vela para operaciones manuales
        : (_allTicks.isNotEmpty && _tickPointer < _allTicks.length
              ? _allTicks[_tickPointer].time
              : historicalData[_currentCandleIndex].timestamp);

    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - Using price: $price (${entryPrice != null ? 'provided entry price' : 'current tick price'})',
    );
    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - Current tick index: $_currentTickIndex, Total ticks: ${_syntheticTicks.length}',
    );
    debugPrint(
      '🔥 SimulationProvider: executeManualTrade - Using timestamp: $currentTime (candle $_currentCandleIndex)',
    );
    if (entryPrice != null) {
      debugPrint(
        '🔥 SimulationProvider: executeManualTrade - Entry price provided: $entryPrice, will use this exact price',
      );
      debugPrint(
        '🔥 SimulationProvider: executeManualTrade - Manual trade timestamp: $currentTime',
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

    // Enviar el trade de cierre al WebView ANTES de limpiar
    if (_tickCallback != null) {
      final closeTradeMsg = {
        'trades': [
          {
            'time': closeTrade.timestamp.millisecondsSinceEpoch ~/ 1000,
            'type': closeTrade.type,
            'price': closeTrade.price,
            'amount': closeTrade.amount ?? 0.0,
            'leverage': closeTrade.leverage ?? 1,
            'reason': closeTrade.reason ?? '',
            'pnl': closeTrade.pnl,
          },
        ],
      };
      debugPrint(
        '🔥 closeManualPosition: Enviando trade de cierre al WebView: $closeTradeMsg',
      );
      _tickCallback!(closeTradeMsg);
    }

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

    // Limpiar líneas del gráfico
    debugPrint('🔥 closeManualPosition: Limpiando líneas del gráfico...');
    _clearChartLines();

    _notifyUIUpdate();
  }

  // --- MÉTODO PARA CANCELAR ÓRDENES ---
  void cancelOrder() {
    // Limpiar líneas del gráfico
    _clearChartLines();
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
    info += '• Tick Index: $_tickPointer/${_allTicks.length}\n';
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
      ticks.add(Tick(time: time, price: price));
    }
    return ticks;
  }

  // --- INICIAR SIMULACIÓN TICK A TICK ---
  Future<void> startTickSimulation(
    Setup setup,
    DateTime startDate,
    double speed,
    double initialBalance,
    String symbol,
  ) async {
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

    // Load real ticks from CSV
    debugPrint('🔥 Cargando ticks reales desde CSV...');
    try {
      _allTicks = await DataService().loadTicksFromCsv();
      _tickPointer = 0;
      debugPrint('🔥 Ticks cargados: ${_allTicks.length}');

      if (_allTicks.isNotEmpty) {
        debugPrint(
          '🔥 Primer tick: ${_allTicks.first.time} - ${_allTicks.first.price}',
        );
        debugPrint(
          '🔥 Último tick: ${_allTicks.last.time} - ${_allTicks.last.price}',
        );
      }
    } catch (e) {
      debugPrint('🔥 ERROR cargando ticks: $e');
      _allTicks = [];
      _tickPointer = 0;
    }

    // Initialize multi-timeframe buffers
    debugPrint('🔥 Inicializando buffers...');
    _initializeBuffers();

    // Initialize chart with initial candles
    debugPrint('🔥 Inicializando chart...');
    _initializeChartWithCandles();

    _isSimulationRunning = false;
    _currentSetup = setup;
    _simulationSpeed = speed;
    _ticksPerSecondFactor = 1.0;

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
      '🔥 SimulationProvider: _processNextTick - tick $_tickPointer de ${_allTicks.length}',
    );

    if (_tickPointer >= _allTicks.length) {
      debugPrint('🔥 SimulationProvider: Fin de ticks alcanzado');
      stopTickSimulation();
      return;
    }

    final tick = _allTicks[_tickPointer];
    final currentTickPrice = tick.price;
    _tickPointer++;

    // Update simulation clock with tick time
    _simulationClock = tick.time;

    debugPrint(
      '🔥 SimulationProvider: Procesando tick $currentTickPrice a las ${tick.time}',
    );
    _accumulateTickForCandle(tick);

    // Notificar cambios de UI para actualizar P&L flotante en tiempo real
    if (_inPosition) {
      _notifyUIUpdate();
    }
  }

  void _accumulateTickForCandle(Tick tick) {
    try {
      debugPrint(
        '🔥 TICK: Procesando tick - precio: ${tick.price}, tiempo: ${tick.time}',
      );
      debugPrint(
        '🔥 TICK: Estado de simulación - isSimulationRunning: $_isSimulationRunning',
      );
      debugPrint('🔥 TICK: Active timeframe: ${_activeTf.name}');

      // Verificar que la simulación esté corriendo antes de procesar
      if (!_isSimulationRunning) {
        debugPrint('🔥 TICK: Simulación pausada, no procesando tick');
        return;
      }

      // Verificar SL/TP si hay posición abierta
      if (_inPosition && _currentTrades.isNotEmpty) {
        _checkStopLossAndTakeProfit(tick.price);
      }

      // Process tick for all timeframes using bucket grouping
      for (Timeframe tf in Timeframe.values) {
        try {
          final bucket = _getCandleStart(tick.time, tf);
          final current = _currentBucket[tf];

          // Initialize bucket if this is the first tick for this timeframe
          if (current == null) {
            _currentBucket[tf] = bucket;
            debugPrint(
              '🔥 TICK: Inicializando bucket para ${tf.name}: $bucket (PRIMER TICK)',
            );
          } else if (bucket.isAfter(current)) {
            // Close the previous candle when crossing to next bucket
            final ticks = _buffers[tf]!;
            if (ticks.isNotEmpty) {
              debugPrint(
                '🔥 TICK: Cerrando vela para ${tf.name} - bucket anterior: $current, nuevo: $bucket (VELA COMPLETA)',
              );
              _emitCandle(tf, ticks, true); // vela completa
            }

            // Clear buffer and start new candle
            _buffers[tf]!.clear();
            _currentBucket[tf] = bucket;
            _lastEmittedCount[tf] = 0; // reiniciar parcial
          } else if (current != null && bucket.isAtSameMomentAs(current)) {
            // Same bucket, continue accumulating
            debugPrint(
              '🔥 TICK: Continuando en mismo bucket para ${tf.name}: $bucket',
            );
          }

          // Always add tick to buffer
          _buffers[tf]!.add(tick);

          // Emit partial candle for active timeframe in real-time
          if (tf == _activeTf) {
            final count = _buffers[tf]!.length;
            if (count != _lastEmittedCount[tf]) {
              debugPrint(
                '🔥 TICK: Emitiendo vela parcial para ${tf.name} con ${count} ticks (PRIMERA EMISIÓN: ${count == 1})',
              );
              _emitCandle(tf, _buffers[tf]!, false);
              _lastEmittedCount[tf] = count;
            }
          }
        } catch (e) {
          debugPrint('🔥 TICK: ERROR procesando timeframe ${tf.name}: $e');
        }
      }

      // Send trades to chart if available
      if (_isSimulationRunning &&
          _tickCallback != null &&
          _currentTrades.isNotEmpty) {
        final tradesMsg = {
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

        debugPrint('🔥 TICK: Enviando trades al chart: $tradesMsg');
        _tickCallback!(tradesMsg);
      }

      // Notificar cambios de UI para actualizar P&L flotante en tiempo real
      if (_inPosition) {
        _notifyUIUpdate();
      }
    } catch (e) {
      debugPrint('🔥 TICK: ERROR general procesando tick: $e');
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

  // --- MÉTODO HELPER PARA LIMPIAR LÍNEAS DEL GRÁFICO ---
  void _clearChartLines() {
    if (_tickCallback != null) {
      debugPrint(
        '🔥 SimulationProvider: Enviando señal para limpiar líneas del gráfico',
      );
      final clearMsg = {'closeOrder': true};
      debugPrint('🔥 SimulationProvider: Mensaje de limpieza: $clearMsg');
      _tickCallback!(clearMsg);

      // Esperar un momento y enviar un mensaje adicional para asegurar la limpieza
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_tickCallback != null) {
          debugPrint(
            '🔥 SimulationProvider: Enviando mensaje adicional de limpieza',
          );
          _tickCallback!({
            'entryPrice': null,
            'stopLoss': null,
            'takeProfit': null,
            'clearLines': true,
          });
        }
      });
    } else {
      debugPrint(
        '🔥 SimulationProvider: ERROR - _tickCallback es null, no se pueden limpiar las líneas',
      );
    }
  }

  // --- VERIFICACIÓN DE STOP LOSS Y TAKE PROFIT ---
  void _checkStopLossAndTakeProfit(double currentPrice) {
    if (!_inPosition || _currentTrades.isEmpty) return;

    final lastTrade = _currentTrades.last;
    String? closeReason;

    // Verificar Stop Loss
    if (_calculatedStopLossPrice != null) {
      if (lastTrade.type == 'buy' &&
          currentPrice <= _calculatedStopLossPrice!) {
        closeReason = 'Stop Loss';
        debugPrint(
          '🔥 SL/TP: Stop Loss alcanzado - Precio: $currentPrice, SL: $_calculatedStopLossPrice',
        );
      } else if (lastTrade.type == 'sell' &&
          currentPrice >= _calculatedStopLossPrice!) {
        closeReason = 'Stop Loss';
        debugPrint(
          '🔥 SL/TP: Stop Loss alcanzado - Precio: $currentPrice, SL: $_calculatedStopLossPrice',
        );
      }
    }

    // Verificar Take Profit
    if (_calculatedTakeProfitPrice != null && closeReason == null) {
      if (lastTrade.type == 'buy' &&
          currentPrice >= _calculatedTakeProfitPrice!) {
        closeReason = 'Take Profit';
        debugPrint(
          '🔥 SL/TP: Take Profit alcanzado - Precio: $currentPrice, TP: $_calculatedTakeProfitPrice',
        );
      } else if (lastTrade.type == 'sell' &&
          currentPrice <= _calculatedTakeProfitPrice!) {
        closeReason = 'Take Profit';
        debugPrint(
          '🔥 SL/TP: Take Profit alcanzado - Precio: $currentPrice, TP: $_calculatedTakeProfitPrice',
        );
      }
    }

    // Cerrar posición si se alcanzó SL o TP
    if (closeReason != null) {
      _closePositionAtPrice(currentPrice, closeReason);
    }
  }

  void _closePositionAtPrice(double closePrice, String reason) {
    if (!_inPosition || _currentTrades.isEmpty) return;

    final lastTrade = _currentTrades.last;

    // Para mayor precisión, usar el precio exacto de SL/TP cuando corresponda
    double exactClosePrice = closePrice;
    if (reason == 'Take Profit' && _calculatedTakeProfitPrice != null) {
      exactClosePrice = _calculatedTakeProfitPrice!;
      debugPrint(
        '🔥 SL/TP: Usando precio exacto de TP: $exactClosePrice en lugar de $closePrice',
      );
    } else if (reason == 'Stop Loss' && _calculatedStopLossPrice != null) {
      exactClosePrice = _calculatedStopLossPrice!;
      debugPrint(
        '🔥 SL/TP: Usando precio exacto de SL: $exactClosePrice en lugar de $closePrice',
      );
    }

    // Calcular P&L de la operación
    double pnl;
    if (lastTrade.type == 'buy') {
      pnl =
          (exactClosePrice - lastTrade.price) *
          lastTrade.quantity *
          lastTrade.leverage!;
    } else {
      pnl =
          (lastTrade.price - exactClosePrice) *
          lastTrade.quantity *
          lastTrade.leverage!;
    }

    debugPrint('🔥 SL/TP: Cálculo P&L detallado:');
    debugPrint('  - Tipo: ${lastTrade.type}');
    debugPrint('  - Precio entrada: ${lastTrade.price}');
    debugPrint('  - Precio cierre: $exactClosePrice');
    debugPrint('  - Cantidad: ${lastTrade.quantity}');
    debugPrint('  - Leverage: ${lastTrade.leverage}');
    debugPrint('  - P&L calculado: $pnl');

    // Crear trade de cierre
    final closeTrade = Trade(
      id: 'close_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: historicalData[_currentCandleIndex]
          .timestamp, // Usar timestamp de la vela actual
      type: lastTrade.type == 'buy' ? 'sell' : 'buy',
      price: exactClosePrice,
      quantity: lastTrade.quantity,
      candleIndex: _currentCandleIndex,
      reason: reason,
      leverage: lastTrade.leverage,
      pnl: pnl,
      tradeGroupId: lastTrade.tradeGroupId,
    );

    // Agregar trade de cierre a la lista
    _currentTrades.add(closeTrade);

    // Enviar el trade de cierre al WebView ANTES de limpiar
    if (_tickCallback != null) {
      final closeTradeMsg = {
        'trades': [
          {
            'time': closeTrade.timestamp.millisecondsSinceEpoch ~/ 1000,
            'type': closeTrade.type,
            'price': closeTrade.price,
            'amount': closeTrade.amount ?? 0.0,
            'leverage': closeTrade.leverage ?? 1,
            'reason': closeTrade.reason ?? '',
            'pnl': closeTrade.pnl,
          },
        ],
      };
      debugPrint(
        '🔥 SL/TP: Enviando trade de cierre al WebView: $closeTradeMsg',
      );
      _tickCallback!(closeTradeMsg);
    }

    // Crear operación completada
    final completedOperation = CompletedTrade(
      id: 'completed_${DateTime.now().millisecondsSinceEpoch}',
      entryTrade: lastTrade,
      exitTrade: closeTrade,
      totalPnL: pnl,
      entryTime: lastTrade.timestamp,
      exitTime: closeTrade.timestamp,
      entryPrice: lastTrade.price,
      exitPrice: exactClosePrice,
      quantity: lastTrade.quantity,
      leverage: lastTrade.leverage,
      reason: reason,
    );

    // Mover trades a operaciones completadas
    _completedOperations.add(completedOperation);
    _currentTrades.clear();

    // Actualizar balance
    _currentBalance += pnl;

    // Limpiar estado de posición
    _inPosition = false;
    _entryPrice = 0.0;
    _calculatedStopLossPrice = null;
    _calculatedTakeProfitPrice = null;

    debugPrint(
      '🔥 SL/TP: Posición cerrada - Precio: $exactClosePrice, P&L: $pnl, Razón: $reason',
    );

    // Limpiar líneas del gráfico
    debugPrint('🔥 SL/TP: Limpiando líneas del gráfico...');
    _clearChartLines();

    // Notificar cambios
    _notifyUIUpdate();
  }
}
