import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../widgets/trading_view_chart.dart';
import '../widgets/order_container.dart';
import '../widgets/manage_sltp_container.dart';
import '../routes.dart';
import '../models/simulation_result.dart';
import '../models/rule.dart';
import '../models/setup.dart';
import 'package:tuple/tuple.dart';
import '../constants/pip_values.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  double _activePipValue(SimulationProvider simulationProvider) {
    final symbol = simulationProvider.activeSymbol;
    return symbol != null ? kPipValues[symbol] ?? 0.0001 : 0.0001;
  }

  bool _showOrderContainerInline = false;
  bool _isBuyOrder = true;
  double? _clickPrice; // Precio capturado en el momento del clic
  // GlobalKey para acceder al TradingViewChart
  final GlobalKey<TradingViewChartState> _chartKey =
      GlobalKey<TradingViewChartState>();
  Timeframe? _selectedTimeframe; // NUEVO: para opciones avanzadas
  bool _isAdjustingSpeed =
      false; // Para controlar pausa durante ajuste de velocidad

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final simulationProvider = context.read<SimulationProvider>();

      // No iniciar automáticamente la simulación - el usuario debe presionar el botón
      // if (simulationProvider.isSimulationRunning) {
      //   // Timer logic removed for manual mode
      // }

      // Conectar el callback para enviar ticks al chart
      simulationProvider.setTickCallback((tickData) {
        if (_chartKey.currentState != null) {
          // Verificar si es una señal de control (pausa/restauración)
          if (tickData.containsKey('pause') ||
              tickData.containsKey('restore')) {
            debugPrint(
              '🔥 CALLBACK: Enviando señal de control al WebView: $tickData',
            );
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else {
            // Es un tick normal con vela
            final candle = tickData['candle'] ?? tickData['tick'];
            if (candle == null) return; // Evita error si no hay vela
            final trades = tickData['trades'] != null
                ? List<Map<String, dynamic>>.from(tickData['trades'])
                : null;
            final stopLoss = tickData['stopLoss'];
            final takeProfit = tickData['takeProfit'];

            // Enviar al WebView
            _chartKey.currentState!.sendTickToWebView(
              candle: candle,
              trades: trades,
              stopLoss: stopLoss,
              takeProfit: takeProfit,
              entryPrice: simulationProvider.entryPrice > 0
                  ? simulationProvider.entryPrice
                  : null,
            );
          }
        }
      });

      // Initialize default values for order container
      setState(() {
        _isBuyOrder = true;
        _selectedTimeframe = simulationProvider.activeTimeframe; // NUEVO
      });
    });
  }

  @override
  void dispose() {
    // No acceder al contexto en dispose() ya que el widget puede estar desactivado
    super.dispose();
  }

  void _showOrderContainer(
    BuildContext context,
    SimulationProvider simulationProvider,
    bool isBuy,
  ) {
    // Primero pausar la simulación para congelar el precio
    simulationProvider.pauseSimulation();

    // Luego capturar el precio exacto del tick visible (el tick anterior al actual)
    _clickPrice = simulationProvider.lastVisibleTickPrice;

    // Calcular parámetros del setup para el precio de entrada
    if (_clickPrice != null) {
      simulationProvider.calculatePositionParameters(
        isBuy ? 'buy' : 'sell',
        _clickPrice!,
      );
    }
    final slSetup = simulationProvider.calculatedStopLossPrice;
    final tpSetup = simulationProvider.calculatedTakeProfitPrice;

    setState(() {
      _showOrderContainerInline = true;
      _isBuyOrder = isBuy;
    });

    // Dibujar líneas en el gráfico al abrir el panel
    if (slSetup != null) simulationProvider.updateManualStopLoss(slSetup);
    if (tpSetup != null) simulationProvider.updateManualTakeProfit(tpSetup);

    debugPrint(
      '🔥 SimulationScreen: Simulación pausada y precio capturado: $_clickPrice',
    );
  }

  void _showManageSLTPContainer(
    BuildContext context,
    SimulationProvider simulationProvider,
  ) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ManageSLTPContainer(
          simulationProvider: simulationProvider,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SimulationProvider>(
      builder: (context, simulationProvider, child) {
        if (simulationProvider.historicalData.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Simulación'),
              backgroundColor: const Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              actions: [
                // Balance y P&L en el AppBar
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${simulationProvider.currentBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      'P&L: \$${simulationProvider.totalPnL.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: simulationProvider.totalPnL >= 0
                            ? const Color(0xFF21CE99)
                            : const Color(0xFFFF6B6B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (simulationProvider.inPosition &&
                        simulationProvider.unrealizedPnL != 0) ...[
                      Text(
                        'Flotante: \$${simulationProvider.unrealizedPnL.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: simulationProvider.unrealizedPnL >= 0
                              ? const Color(0xFF21CE99)
                              : const Color(0xFFFF6B6B),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    if (!mounted) return;
                    final shouldExit = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('¿Salir de la simulación?'),
                        content: const Text(
                          '¿Estás seguro que quieres salir? Se perderá el progreso de la simulación actual.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF21CE99),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Salir'),
                          ),
                        ],
                      ),
                    );
                    if (shouldExit == true && mounted) {
                      simulationProvider.stopSimulation();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.dashboard,
                          );
                        }
                      });
                    }
                  },
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.trending_up), text: 'Trading'),
                  Tab(icon: Icon(Icons.analytics), text: 'Estadísticas'),
                ],
                indicatorColor: Color(0xFF21CE99),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
              ),
            ),
            body: Container(
              color: const Color(0xFF1E1E1E),
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Tab 1: Trading
                  _buildTradingTab(simulationProvider),
                  // Tab 2: Estadísticas
                  _buildStatisticsTab(simulationProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTradingTab(SimulationProvider simulationProvider) {
    // Unir trades abiertos y completados para el gráfico
    final allTrades = [
      ...simulationProvider.completedTrades,
      ...simulationProvider.currentTrades,
    ];
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Chart Section - 50% of screen height
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Container(
              margin: const EdgeInsets.all(12),
              child:
                  Selector<
                    SimulationProvider,
                    Tuple5<List<Trade>, int, double?, double?, double?>
                  >(
                    selector: (context, provider) => Tuple5(
                      allTrades,
                      provider.currentCandleIndex,
                      provider.manualStopLossPrice,
                      provider.manualTakeProfitPrice,
                      provider.entryPrice > 0 ? provider.entryPrice : null,
                    ),
                    builder: (context, data, child) {
                      final entryPrice = _clickPrice != null
                          ? _clickPrice
                          : data.item5;
                      return TradingViewChart(
                        key: _chartKey,
                        candles: simulationProvider.historicalData,
                        trades: data.item1,
                        currentCandleIndex: data.item2,
                        stopLoss: data.item3,
                        takeProfit: data.item4,
                        entryPrice: entryPrice,
                        isRunning: simulationProvider.isSimulationRunning,
                      );
                    },
                  ),
            ),
          ),

          // Controls Section - Flexible
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Order Container (when active)
                  if (_showOrderContainerInline) ...[
                    OrderContainer(
                      provider: simulationProvider,
                      isBuy: _isBuyOrder,
                      price: _clickPrice ?? 0,
                      onClose: () {
                        setState(() {
                          _showOrderContainerInline = false;
                          _clickPrice = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  ],

                  // --- Controles de compra/venta en la sección media ---
                  if (!_showOrderContainerInline) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Color(0xFF21CE99),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Controles de Trading',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Trading Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (!simulationProvider.inPosition &&
                                          simulationProvider
                                              .canCalculatePosition())
                                      ? () => _showOrderContainer(
                                          context,
                                          simulationProvider,
                                          true,
                                        )
                                      : null,
                                  icon: const Icon(Icons.trending_up),
                                  label: const Text('Comprar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF21CE99),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (!simulationProvider.inPosition &&
                                          simulationProvider
                                              .canCalculatePosition())
                                      ? () => _showOrderContainer(
                                          context,
                                          simulationProvider,
                                          false,
                                        )
                                      : null,
                                  icon: const Icon(Icons.trending_down),
                                  label: const Text('Vender'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B6B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Close Position Button (only show if position is open)
                          if (simulationProvider.inPosition) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      simulationProvider.closeManualPosition(
                                        simulationProvider.currentTickPrice,
                                      );
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('Cerrar Entrada'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _showManageSLTPContainer(
                                        context,
                                        simulationProvider,
                                      );
                                    },
                                    icon: const Icon(Icons.tune),
                                    label: const Text('Gestionar SL/TP'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Debug Button (temporary)
                    if (simulationProvider.setupParametersCalculated) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[600]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bug_report,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Debug Info',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              simulationProvider.getDebugSLTPInfo(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // --- Control de simulación con timeframe integrado ---
                  if (!_showOrderContainerInline) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header con título y timeframe
                          Row(
                            children: [
                              const Icon(Icons.speed, color: Color(0xFF21CE99)),
                              const SizedBox(width: 8),
                              const Text(
                                'Control de simulación',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const Spacer(),
                              // Dropdown de timeframe integrado
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: DropdownButton<Timeframe>(
                                  value: _selectedTimeframe,
                                  dropdownColor: const Color(0xFF2C2C2C),
                                  underline: Container(), // Sin línea
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                  items: Timeframe.values.map((tf) {
                                    String label;
                                    switch (tf) {
                                      case Timeframe.D1:
                                        label = '1D';
                                        break;
                                      case Timeframe.H1:
                                        label = '1H';
                                        break;
                                      case Timeframe.M15:
                                        label = '15M';
                                        break;
                                      case Timeframe.M5:
                                        label = '5M';
                                        break;
                                      case Timeframe.M1:
                                        label = '1M';
                                        break;
                                    }
                                    return DropdownMenuItem(
                                      value: tf,
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (tf) {
                                    setState(() => _selectedTimeframe = tf);
                                    if (tf != null) {
                                      simulationProvider.setTimeframe(tf);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // --- Controles de simulación ---
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (simulationProvider.currentSetup !=
                                              null &&
                                          simulationProvider.isSimulationPaused)
                                      ? () => simulationProvider
                                            .resumeTickSimulation()
                                      : (simulationProvider.currentSetup !=
                                                null &&
                                            !simulationProvider
                                                .isSimulationRunning)
                                      ? () => simulationProvider
                                            .startTickSimulation(
                                              simulationProvider.currentSetup!,
                                              simulationProvider
                                                  .historicalData
                                                  .first
                                                  .timestamp,
                                              simulationProvider
                                                  .simulationSpeed,
                                              simulationProvider.currentBalance,
                                              simulationProvider.activeSymbol ??
                                                  'BTCUSD', // fallback to BTCUSD if no symbol set
                                            )
                                      : null,
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(
                                    simulationProvider.isSimulationPaused
                                        ? 'Reanudar'
                                        : 'Iniciar',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF21CE99),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      simulationProvider.isSimulationRunning
                                      ? () => simulationProvider
                                            .pauseTickSimulation()
                                      : null,
                                  icon: const Icon(Icons.pause),
                                  label: const Text('Pausar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              // Botón de detener comentado temporalmente
                              /*
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      simulationProvider.isSimulationRunning
                                      ? () {
                                          _isAdjustingSpeed =
                                              false; // Resetear estado de ajuste
                                          simulationProvider.stopTickSimulation();
                                        }
                                      : null,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Detener'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B6B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              */
                            ],
                          ),

                          // --- Botones de siguiente vela y siguiente tick ---
                          // -- Por el momento esto se comentara, ya que no funciona correctamente y no es escencial en el MVP.
                          /*
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      simulationProvider.simulationMode ==
                                          SimulationMode.manual
                                      ? () => simulationProvider.advanceCandle()
                                      : null,
                                  icon: const Icon(Icons.skip_next),
                                  label: const Text('Siguiente Vela'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C2C2C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey[700]!),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      simulationProvider.simulationMode ==
                                          SimulationMode.manual
                                      ? () => simulationProvider.advanceTick()
                                      : null,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Siguiente Tick'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C2C2C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey[700]!),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          */
                          const SizedBox(height: 16),

                          // Factor de velocidad
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Velocidad: ${simulationProvider.ticksPerSecondFactor.toStringAsFixed(1)}x',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                        if (_isAdjustingSpeed) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.orange,
                                                width: 1,
                                              ),
                                            ),
                                            child: const Text(
                                              'PAUSADO',
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Slider(
                                      value: simulationProvider
                                          .ticksPerSecondFactor,
                                      min: 0.1,
                                      max: 5.0,
                                      divisions: 49,
                                      activeColor: const Color(0xFF21CE99),
                                      onChanged: (value) {
                                        // Pausar temporalmente mientras se ajusta la velocidad
                                        if (!_isAdjustingSpeed &&
                                            simulationProvider
                                                .isSimulationRunning) {
                                          _isAdjustingSpeed = true;
                                          simulationProvider
                                              .pauseTickSimulation();
                                        }

                                        simulationProvider
                                                .ticksPerSecondFactor =
                                            value;
                                      },
                                      onChangeEnd: (value) {
                                        // Reanudar después de ajustar la velocidad
                                        if (_isAdjustingSpeed &&
                                            simulationProvider.currentSetup !=
                                                null) {
                                          _isAdjustingSpeed = false;
                                          simulationProvider
                                              .resumeTickSimulation();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Setup Details Section (below controls)
                  if (simulationProvider.currentSetup != null &&
                      !_showOrderContainerInline) ...[
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.settings,
                                color: const Color(0xFF21CE99),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Setup: ${simulationProvider.currentSetup!.name}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Setup details in compact format
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactSetupDetail(
                                  'Riesgo',
                                  simulationProvider.currentSetup!
                                      .getRiskPercentDisplay(),
                                  Icons.security,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactSetupDetail(
                                  'SL',
                                  simulationProvider.currentSetup!
                                      .getStopLossDisplay(),
                                  Icons.trending_down,
                                  Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactSetupDetail(
                                  'TP',
                                  simulationProvider.currentSetup!
                                      .getTakeProfitRatioDisplay(),
                                  Icons.trending_up,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),

                          // Advanced Rules Section
                          if (simulationProvider
                              .currentSetup!
                              .rules
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Reglas Avanzadas',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Scrollable rules list
                            Container(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: simulationProvider
                                      .currentSetup!
                                      .rules
                                      .map(
                                        (rule) => _buildCompactRuleItem(rule),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(SimulationProvider simulationProvider) {
    final trades = simulationProvider.currentTrades;
    final completedOperations = simulationProvider.completedOperations;
    final totalTrades = trades.length;

    // Calcular estadísticas de operaciones completadas
    final totalCompletedOperations = completedOperations.length;
    final winningTrades = completedOperations
        .where((t) => t.totalPnL > 0)
        .length;
    final winRate = totalCompletedOperations > 0
        ? winningTrades / totalCompletedOperations
        : 0.0;

    // Calcular P&L total de operaciones completadas
    final totalPnL = completedOperations.fold(
      0.0,
      (sum, operation) => sum + operation.totalPnL,
    );
    final maxProfit = completedOperations.isNotEmpty
        ? completedOperations
              .map((t) => t.totalPnL)
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    final maxLoss = completedOperations.isNotEmpty
        ? completedOperations
              .map((t) => t.totalPnL)
              .reduce((a, b) => a < b ? a : b)
        : 0.0;

    final isSimulationComplete =
        simulationProvider.currentCandleIndex >=
        simulationProvider.historicalData.length - 1;

    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            if (!isSimulationComplete) ...[
              Card(
                color: const Color(0xFF2C2C2C),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso de Simulación',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: simulationProvider.historicalData.isNotEmpty
                            ? (simulationProvider.currentCandleIndex + 1) /
                                  simulationProvider.historicalData.length
                            : 0.0,
                        backgroundColor: Colors.grey[700],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF21CE99),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vela ${simulationProvider.currentCandleIndex + 1} de ${simulationProvider.historicalData.length}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Real-time Statistics
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estadísticas en Tiempo Real',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Key Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Trades Abiertos',
                            trades.length.toString(),
                            Icons.pending,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Win Rate',
                            '${(winRate * 100).toStringAsFixed(1)}%',
                            Icons.trending_up,
                            winRate >= 0.5 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Operaciones Completadas',
                            totalCompletedOperations.toString(),
                            Icons.check_circle,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'P&L Total',
                            '\$${totalPnL.toStringAsFixed(2)}',
                            Icons.trending_up,
                            totalPnL >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Ganancia Máx',
                            '\$${maxProfit.toStringAsFixed(2)}',
                            Icons.trending_up,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Pérdida Máx',
                            '\$${maxLoss.toStringAsFixed(2)}',
                            Icons.trending_down,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Balance Actual',
                            '\$${simulationProvider.currentBalance.toStringAsFixed(2)}',
                            Icons.account_balance_wallet,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'P&L Flotante',
                            '\$${simulationProvider.unrealizedPnL.toStringAsFixed(2)}',
                            Icons.pending,
                            simulationProvider.unrealizedPnL >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // P&L Statistics
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de Trading',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildPnLMetric('P&L Total', totalPnL),
                    const SizedBox(height: 8),
                    _buildPnLMetric('Balance Inicial', 10000.0),
                    const SizedBox(height: 8),
                    _buildPnLMetric(
                      'Balance Actual',
                      simulationProvider.currentBalance,
                    ),
                    const SizedBox(height: 8),
                    _buildPnLMetric(
                      'P&L Flotante',
                      simulationProvider.unrealizedPnL,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent Trades
            if (trades.isNotEmpty) ...[
              Card(
                color: const Color(0xFF2C2C2C),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trades Recientes',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 16),

                      ...trades.take(5).map((trade) => _buildTradeItem(trade)),

                      if (trades.length > 5) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '... y ${trades.length - 5} trades más',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Completed Operations History
            if (completedOperations.isNotEmpty) ...[
              Card(
                color: const Color(0xFF2C2C2C),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historial de Operaciones Completadas',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          Text(
                            '$winningTrades/$totalCompletedOperations ganadores',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ...completedOperations
                          .take(10)
                          .map(
                            (operation) =>
                                _buildCompletedOperationItem(operation),
                          ),

                      if (completedOperations.length > 10) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            '... y ${completedOperations.length - 10} operaciones más',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Final Summary (when simulation is complete)
            if (isSimulationComplete) ...[
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF21CE99).withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.flag,
                            color: Color(0xFF21CE99),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Simulación Completada',
                            style: const TextStyle(
                              color: Color(0xFF21CE99),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '¡Excelente trabajo! Has completado la simulación con $totalTrades trades y un P&L total de \$${totalPnL.toStringAsFixed(2)}.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnLMetric(String title, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: value >= 0
                ? const Color(0xFF21CE99)
                : const Color(0xFFFF6B6B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildTradeItem(Trade trade) {
    // Todos los trades en el historial ahora son abiertos

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: trade.type == 'buy'
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            trade.type == 'buy' ? Icons.trending_up : Icons.trending_down,
            color: trade.type == 'buy' ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trade.type.toUpperCase()} \$${trade.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  'Cantidad: ${trade.quantity.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
                if (trade.leverage != null)
                  Text(
                    'Apalancamiento: ${trade.leverage}x',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                      fontFamily: 'Inter',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedOperationItem(CompletedTrade operation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: operation.totalPnL >= 0
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con tipo de operación y P&L
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    operation.totalPnL >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: operation.totalPnL >= 0 ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    operation.operationType.toUpperCase(),
                    style: TextStyle(
                      color: operation.totalPnL >= 0
                          ? Colors.green
                          : Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              Text(
                '\$${operation.totalPnL.toStringAsFixed(2)}',
                style: TextStyle(
                  color: operation.totalPnL >= 0 ? Colors.green : Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Precios de entrada y salida
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrada: \$${operation.entryPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      operation.entryTime.toString().substring(
                        11,
                        16,
                      ), // Solo hora:minuto
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Salida: \$${operation.exitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    Text(
                      operation.exitTime.toString().substring(
                        11,
                        16,
                      ), // Solo hora:minuto
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Información adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cantidad: ${operation.quantity.toStringAsFixed(4)}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                  fontFamily: 'Inter',
                ),
              ),
              if (operation.leverage != null)
                Text(
                  'Apalancamiento: ${operation.leverage}x',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
              Text(
                'Duración: ${operation.durationFormatted}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          if (operation.reason != null) ...[
            const SizedBox(height: 4),
            Text(
              'Razón: ${operation.reason}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactSetupDetail(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 9,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRuleItem(Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: rule.isActive
              ? const Color(0xFF21CE99).withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getRuleIcon(rule.type),
            color: rule.isActive ? const Color(0xFF21CE99) : Colors.grey,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: TextStyle(
                    color: rule.isActive ? Colors.white : Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  rule.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 9,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: rule.isActive
                  ? const Color(0xFF21CE99).withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rule.isActive ? 'ON' : 'OFF',
              style: TextStyle(
                color: rule.isActive ? const Color(0xFF21CE99) : Colors.grey,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRuleIcon(RuleType type) {
    switch (type) {
      case RuleType.technicalIndicator:
        return Icons.analytics;
      case RuleType.candlestickPattern:
        return Icons.candlestick_chart;
      case RuleType.timeFrame:
        return Icons.schedule;
      case RuleType.other:
        return Icons.rule;
    }
