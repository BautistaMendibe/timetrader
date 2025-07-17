import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../widgets/trading_view_chart.dart';
import '../routes.dart';
import '../models/simulation_result.dart';
import '../models/rule.dart';
import 'package:tuple/tuple.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  bool _showOrderContainerInline = false;
  bool _isBuyOrder = true;
  bool _showSLTPContainer = false;
  // GlobalKey para acceder al TradingViewChart
  final GlobalKey<TradingViewChartState> _chartKey =
      GlobalKey<TradingViewChartState>();
  Timeframe? _selectedTimeframe; // NUEVO: para opciones avanzadas

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
          _chartKey.currentState!.sendTickToWebView(
            candle:
                tickData['candle'] ??
                tickData['tick'], // Soporte tanto candle como tick
            trades: tickData['trades'] != null
                ? List<Map<String, dynamic>>.from(tickData['trades'])
                : null,
            stopLoss: tickData['stopLoss'],
            takeProfit: tickData['takeProfit'],
          );
        }
      });

      // Initialize default values for order container
      setState(() {
        _showSLTPContainer = false;
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
    // Calculate position parameters when showing the order container
    simulationProvider.calculatePositionParameters(isBuy ? 'buy' : 'sell');

    setState(() {
      _showOrderContainerInline = true;
      _isBuyOrder = isBuy;
    });
  }

  void _showManageSLTPContainer(
    BuildContext context,
    SimulationProvider simulationProvider,
  ) {
    setState(() {
      _showSLTPContainer = true;
    });
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
              child: Selector<SimulationProvider, Tuple2<List<Trade>, int>>(
                selector: (context, provider) =>
                    Tuple2(allTrades, provider.currentCandleIndex),
                builder: (context, data, child) {
                  return TradingViewChart(
                    key: _chartKey,
                    candles: simulationProvider.historicalData,
                    trades: data.item1,
                    currentCandleIndex: data.item2,
                    stopLoss: simulationProvider.manualStopLossPrice,
                    takeProfit: simulationProvider.manualTakeProfitPrice,
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
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[700]!),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isBuyOrder ? 'Comprar' : 'Vender',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showOrderContainerInline = false;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              // Confirm Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      simulationProvider.canCalculatePosition()
                                      ? () {
                                          // Calculate position parameters before executing
                                          simulationProvider
                                              .calculatePositionParameters(
                                                _isBuyOrder ? 'buy' : 'sell',
                                              );

                                          if (simulationProvider
                                              .setupParametersCalculated) {
                                            simulationProvider.executeManualTrade(
                                              type: _isBuyOrder
                                                  ? 'buy'
                                                  : 'sell',
                                              amount:
                                                  simulationProvider
                                                      .calculatedPositionSize ??
                                                  0.0,
                                              leverage:
                                                  simulationProvider
                                                      .calculatedLeverage
                                                      ?.toInt() ??
                                                  1,
                                            );
                                            setState(() {
                                              _showOrderContainerInline = false;
                                            });
                                          } else {
                                            // Show error snackbar
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'No se puede calcular la posición: verifica tu setup.',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Inter',
                                                  ),
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isBuyOrder
                                        ? const Color(0xFF21CE99)
                                        : const Color(0xFFFF6B6B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    _isBuyOrder ? 'Comprar' : 'Vender',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Position summary
                              if (simulationProvider
                                  .setupParametersCalculated) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[600]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        simulationProvider
                                            .getPositionSummaryText(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Stop Loss: ${simulationProvider.calculatedStopLossPrice?.toStringAsFixed(5) ?? 'N/A'}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      Text(
                                        'Take Profit: ${simulationProvider.calculatedTakeProfitPrice?.toStringAsFixed(5) ?? 'N/A'}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                                      final currentCandle =
                                          simulationProvider
                                              .historicalData[simulationProvider
                                              .currentCandleIndex];
                                      simulationProvider.closeManualPosition(
                                        currentCandle.close,
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
                  ],

                  // --- Control de simulación con timeframe integrado ---
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
                                  if (tf != null)
                                    simulationProvider.setTimeframe(tf);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // --- Botones de control principales ---
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    (simulationProvider.currentSetup != null &&
                                        !simulationProvider.isSimulationRunning)
                                    ? () {
                                        // Si no está corriendo, verificar si hay una simulación pausada
                                        if (simulationProvider
                                                .currentCandleIndex >
                                            0) {
                                          // Reanudar simulación existente
                                          simulationProvider
                                              .resumeTickSimulation();
                                        } else {
                                          // Iniciar nueva simulación
                                          simulationProvider
                                              .startTickSimulation(
                                                simulationProvider
                                                    .currentSetup!,
                                                simulationProvider
                                                    .historicalData
                                                    .first
                                                    .timestamp,
                                                simulationProvider
                                                    .simulationSpeed,
                                                simulationProvider
                                                    .currentBalance,
                                              );
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  simulationProvider.currentCandleIndex > 0
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    simulationProvider.isSimulationRunning
                                    ? () => simulationProvider
                                          .stopTickSimulation()
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
                          ],
                        ),

                        // --- Botones de siguiente vela y siguiente tick ---
                        const SizedBox(height: 8),
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

                        const SizedBox(height: 16),

                        // Factor de velocidad
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Velocidad: ${simulationProvider.ticksPerSecondFactor.toStringAsFixed(1)}x',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Slider(
                                    value:
                                        simulationProvider.ticksPerSecondFactor,
                                    min: 0.1,
                                    max: 5.0,
                                    divisions: 49,
                                    activeColor: const Color(0xFF21CE99),
                                    onChanged: (value) {
                                      simulationProvider.ticksPerSecondFactor =
                                          value;
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
                  // Setup Details Section (below controls)
                  if (simulationProvider.currentSetup != null &&
                      !_showOrderContainerInline &&
                      !_showSLTPContainer) ...[
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

  Widget _buildSetupDetailCard(
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
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 10,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
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
            size: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: TextStyle(
                    color: rule.isActive ? Colors.white : Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  rule.description,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rule.isActive
                  ? const Color(0xFF21CE99).withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              rule.isActive ? 'Activa' : 'Inactiva',
              style: TextStyle(
                color: rule.isActive ? const Color(0xFF21CE99) : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
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
      default:
        return Icons.rule;
    }
  }

  Widget _buildSetupInfoItem(
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
}

// Widget del container inline para SL/TP
class _ManageSLTPContainer extends StatefulWidget {
  final SimulationProvider simulationProvider;
  final VoidCallback onClose;
  const _ManageSLTPContainer({
    required this.simulationProvider,
    required this.onClose,
  });

  @override
  State<_ManageSLTPContainer> createState() => _ManageSLTPContainerState();
}

class _ManageSLTPContainerState extends State<_ManageSLTPContainer> {
  // Escala personalizada para SL y TP
  static const List<double> _slPercents = [
    0.1,
    0.2,
    0.3,
    0.4,
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1,
    1.2,
    1.5,
    2,
    2.5,
    3,
    4,
    5,
    7,
    10,
  ];
  static const List<double> _tpPercents = [
    0.1,
    0.2,
    0.3,
    0.4,
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1,
    1.2,
    1.5,
    2,
    2.5,
    3,
    4,
    5,
    7,
    10,
    15,
    20,
  ];

  int? _takeProfitIndex;
  int? _stopLossIndex;
  double? _partialClosePercent;
  bool _slEnabled = false;
  bool _tpEnabled = false;

  @override
  void initState() {
    super.initState();
    // Si hay valor, buscar el índice correspondiente, si no, null
    final provider = widget.simulationProvider;
    // Usar el valor manual si existe, si no, el default calculado
    double? tpPercent =
        provider.manualTakeProfitPercent ?? provider.defaultTakeProfitPercent;
    double? slPercent =
        provider.manualStopLossPercent ?? provider.defaultStopLossPercent;
    _takeProfitIndex = tpPercent != null
        ? _tpPercents.indexWhere((v) => (v - tpPercent).abs() < 0.0001)
        : null;
    _stopLossIndex = slPercent != null
        ? _slPercents.indexWhere((v) => (v - slPercent).abs() < 0.0001)
        : null;

    // Si no se encuentra el valor exacto, usar el más cercano
    if (_takeProfitIndex == -1 && tpPercent != null) {
      _takeProfitIndex = _findClosestIndex(_tpPercents, tpPercent);
    }
    if (_stopLossIndex == -1 && slPercent != null) {
      _stopLossIndex = _findClosestIndex(_slPercents, slPercent);
    }

    // Inicializar checkboxes basado en si hay valores definidos
    _tpEnabled = tpPercent != null;
    _slEnabled = slPercent != null;

    _partialClosePercent = 0.0;
  }

  // Método auxiliar para encontrar el índice más cercano
  int _findClosestIndex(List<double> values, double target) {
    int closestIndex = 0;
    double closestDistance = (values[0] - target).abs();

    for (int i = 1; i < values.length; i++) {
      double distance = (values[i] - target).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final entryPrice = widget.simulationProvider.entryPrice;
    final positionSize = widget.simulationProvider.positionSize;

    // Calcular el P&L esperado basado en el movimiento del precio
    final tpValue = _takeProfitIndex != null
        ? positionSize *
              entryPrice *
              (_tpPercents[_takeProfitIndex!] / 100) *
              (widget.simulationProvider.currentTrades.last.leverage ?? 1)
        : 0;
    final slValue = _stopLossIndex != null
        ? positionSize *
              entryPrice *
              (_slPercents[_stopLossIndex!] / 100) *
              (widget.simulationProvider.currentTrades.last.leverage ?? 1)
        : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestión Avanzada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Take Profit Section
            Row(
              children: [
                Checkbox(
                  value: _tpEnabled,
                  onChanged: (value) {
                    setState(() {
                      _tpEnabled = value ?? false;
                      if (!_tpEnabled) {
                        _takeProfitIndex = null;
                        widget.simulationProvider.setManualTakeProfit(null);
                      } else if (_takeProfitIndex == null) {
                        // Si se activa pero no hay índice, establecer uno por defecto
                        _takeProfitIndex = 9; // 1%
                        widget.simulationProvider.setManualTakeProfit(
                          _tpPercents[9],
                        );
                      }
                    });
                  },
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: Text(
                    _tpEnabled && _takeProfitIndex != null
                        ? 'TP: +\$${tpValue.toStringAsFixed(0)} (+${_tpPercents[_takeProfitIndex!].toStringAsFixed(1)}%)'
                        : 'TP: Desactivado',
                    style: TextStyle(
                      color: _tpEnabled ? Colors.green : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_tpEnabled) ...[
              Slider(
                value: _takeProfitIndex?.toDouble() ?? 0.0,
                min: 0,
                max: (_tpPercents.length - 1).toDouble(),
                divisions: _tpPercents.length - 1,
                label:
                    '+${_tpPercents[_takeProfitIndex ?? 0].toStringAsFixed(1)}%',
                activeColor: Colors.green,
                inactiveColor: Colors.green.withValues(alpha: 0.2),
                onChanged: (v) {
                  setState(() {
                    _takeProfitIndex = v.round();
                  });
                  // Actualizar el valor manual en el provider
                  widget.simulationProvider.setManualTakeProfit(
                    _tpPercents[_takeProfitIndex!],
                  );
                },
              ),
            ],
            const SizedBox(height: 6),

            // Stop Loss Section
            Row(
              children: [
                Checkbox(
                  value: _slEnabled,
                  onChanged: (value) {
                    setState(() {
                      _slEnabled = value ?? false;
                      if (!_slEnabled) {
                        _stopLossIndex = null;
                        widget.simulationProvider.setManualStopLoss(null);
                      } else if (_stopLossIndex == null) {
                        // Si se activa pero no hay índice, establecer uno por defecto
                        _stopLossIndex = 9; // 1%
                        widget.simulationProvider.setManualStopLoss(
                          _slPercents[9],
                        );
                      }
                    });
                  },
                  activeColor: Colors.red,
                ),
                Expanded(
                  child: Text(
                    _slEnabled && _stopLossIndex != null
                        ? 'SL: -\$${slValue.toStringAsFixed(0)} (-${_slPercents[_stopLossIndex!].toStringAsFixed(1)}%)'
                        : 'SL: Desactivado',
                    style: TextStyle(
                      color: _slEnabled ? Colors.red : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (_slEnabled) ...[
              Slider(
                value: _stopLossIndex?.toDouble() ?? 0.0,
                min: 0,
                max: (_slPercents.length - 1).toDouble(),
                divisions: _slPercents.length - 1,
                label:
                    '-${_slPercents[_stopLossIndex ?? 0].toStringAsFixed(1)}%',
                activeColor: Colors.red,
                inactiveColor: Colors.red.withValues(alpha: 0.2),
                onChanged: (v) {
                  setState(() {
                    _stopLossIndex = v.round();
                  });
                  // Actualizar el valor manual en el provider
                  widget.simulationProvider.setManualStopLoss(
                    _slPercents[_stopLossIndex!],
                  );
                },
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Lógica real: aplicar SL/TP y cierre parcial
                      if ((_partialClosePercent ?? 0) > 0) {
                        widget.simulationProvider.closePartialPosition(
                          _partialClosePercent ?? 0,
                        );
                      }
                      // Aplicar SL y TP de forma independiente
                      widget.simulationProvider.setManualStopLoss(
                        _slEnabled && _stopLossIndex != null
                            ? _slPercents[_stopLossIndex!]
                            : null,
                      );
                      widget.simulationProvider.setManualTakeProfit(
                        _tpEnabled && _takeProfitIndex != null
                            ? _tpPercents[_takeProfitIndex!]
                            : null,
                      );
                      // Cerrar el container
                      widget.onClose();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'HECHO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
