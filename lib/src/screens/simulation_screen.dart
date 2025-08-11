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
  double? _clickPrice; // Precio capturado en el momento del clic
  // GlobalKey para acceder al TradingViewChart
  final GlobalKey<TradingViewChartState> _chartKey =
      GlobalKey<TradingViewChartState>();

  Timeframe? _selectedTimeframe; // NUEVO: para opciones avanzadas
  bool _isAdjustingSpeed =
      false; // Para controlar pausa durante ajuste de velocidad
  // Flag para mostrar sliders SL/TP en el panel de orden
  bool _showSlTpOnOrderInline = false;
  // NUEVO: Porcentajes de SL y TP
  double _slRiskPercent = 1.0;
  double _tpRiskPercent = 2.0;

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
            // debugPrint(
            //   '🔥 CALLBACK: Enviando señal de control al WebView: $tickData',
            // );
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else if (tickData.containsKey('closeOrder') ||
              tickData.containsKey('clearLines')) {
            // Es una señal de limpieza - enviar directamente
            // debugPrint(
            //   '🔥 CALLBACK: Enviando señal de limpieza al WebView: $tickData',
            // );
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else if (tickData.containsKey('resetChart')) {
            // Es una señal de reset del chart - enviar directamente
            // debugPrint(
            //   '🔥🔥🔥 CALLBACK: Enviando señal de RESET al WebView: $tickData',
            // );
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else if (tickData.containsKey('trades') &&
              !tickData.containsKey('candle') &&
              !tickData.containsKey('tick')) {
            // Es solo un mensaje de trades (cierre de posición) - enviar directamente
            // debugPrint(
            //   '🔥 CALLBACK: Enviando trades de cierre al WebView: $tickData',
            // );
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
            // debugPrint(
            //   '🔥 Enviando al WebView: SL%=${-_slRiskPercent}, SLValue=${-(simulationProvider.currentBalance * (_slRiskPercent / 100))}, TP%=$_tpRiskPercent, TPValue=${simulationProvider.currentBalance * (_tpRiskPercent / 100)}',
            // );

            // Verificar que los valores no sean NaN antes de enviar
            final slPercent = _slRiskPercent.isFinite ? -_slRiskPercent : 0.0;
            final slValue = _slRiskPercent.isFinite
                ? -(simulationProvider.currentBalance * (_slRiskPercent / 100))
                : 0.0;
            final tpPercent = _tpRiskPercent.isFinite ? _tpRiskPercent : 0.0;
            final tpValue = _tpRiskPercent.isFinite
                ? simulationProvider.currentBalance * (_tpRiskPercent / 100)
                : 0.0;
            final entryValue = simulationProvider.inPosition
                ? simulationProvider.unrealizedPnL
                : 0.0; // P&L flotante en tiempo real

            // Solo enviar datos de líneas si hay posición activa
            final hasActivePosition =
                simulationProvider.inPosition &&
                simulationProvider.entryPrice > 0;

            _chartKey.currentState?.sendMessageToWebView({
              'candle': candle,
              'trades': trades,
              'entryPrice': hasActivePosition
                  ? simulationProvider.entryPrice
                  : null,
              'stopLoss': hasActivePosition ? stopLoss : null,
              'takeProfit': hasActivePosition ? takeProfit : null,
              // añado porcentaje y valor en USD solo si hay posición activa
              'slPercent': hasActivePosition ? slPercent : null,
              'slValue': hasActivePosition ? slValue : null,
              'tpPercent': hasActivePosition ? tpPercent : null,
              'tpValue': hasActivePosition ? tpValue : null,
              'entryValue': hasActivePosition ? entryValue : null,
            });
          }
        }
      });

      // Initialize default values for order container
      setState(() {
        _showSLTPContainer = false;
        _isBuyOrder = true;
        _selectedTimeframe = simulationProvider.activeTimeframe; // NUEVO
        // debugPrint(
        //   '🔥🔥🔥 UI: Initialized _selectedTimeframe = ${_selectedTimeframe?.name}',
        // );
        // debugPrint(
        //   '🔥🔥🔥 UI: Provider activeTimeframe = ${simulationProvider.activeTimeframe.name}',
        // );
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

    // Inicializar porcentajes de SL y TP
    if (_clickPrice != null && slSetup != null && tpSetup != null) {
      // Inicializar como % de balance arriesgado y potencial
      // Por defecto, 1% riesgo, 2% potencial
      _slRiskPercent = 1.0;
      _tpRiskPercent = 2.0;
    }

    setState(() {
      _showOrderContainerInline = true;
      _isBuyOrder = isBuy;
      _showSlTpOnOrderInline = true;
    });

    // Dibujar líneas en el gráfico al abrir el panel
    if (slSetup != null) simulationProvider.updateManualStopLoss(slSetup);
    if (tpSetup != null) simulationProvider.updateManualTakeProfit(tpSetup);

    // debugPrint(
    //   '🔥 SimulationScreen: Simulación pausada y precio capturado: $_clickPrice',
    // );
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
          return Scaffold(
            body: Container(
              constraints: const BoxConstraints.expand(),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B1220), Color(0xFF0F172A)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: Container(
              constraints: const BoxConstraints.expand(),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0B1220), Color(0xFF0F172A)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Custom AppBar
                    _buildCustomAppBar(simulationProvider),

                    // TabBar
                    Container(
                      color: const Color(0xFF1F2937),
                      child: const TabBar(
                        tabs: [
                          Tab(
                            icon: Icon(
                              Icons.trending_up,
                              color: Color(0xFFF8FAFC),
                            ),
                            text: 'Trading',
                          ),
                          Tab(
                            icon: Icon(
                              Icons.analytics,
                              color: Color(0xFFF8FAFC),
                            ),
                            text: 'Estadísticas',
                          ),
                        ],
                        indicatorColor: Color(0xFF22C55E),
                        labelColor: Color(0xFFF8FAFC),
                        unselectedLabelColor: Color(0xFF94A3B8),
                        labelStyle: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // TabBarView
                    Expanded(
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomAppBar(SimulationProvider simulationProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Logo and App Name
          Row(
            children: [
              Image.asset('assets/imgs/icono.png', height: 40, width: 45),
              const SizedBox(width: 12),
              const Text(
                'Simulación',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const Spacer(),

          // Balance y P&L
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${simulationProvider.currentBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  'P&L: \$${simulationProvider.totalPnL.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: simulationProvider.totalPnL >= 0
                        ? const Color(0xFF22C55E)
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
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFFF6B6B),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Botón de cerrar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
              onPressed: () async {
                if (!mounted) return;
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1F2937),
                    title: const Text(
                      '¿Salir de la simulación?',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    content: const Text(
                      '¿Estás seguro que quieres salir? Se perderá el progreso de la simulación actual.',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontFamily: 'Inter',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Salir',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (shouldExit == true && mounted) {
                  simulationProvider.stopSimulation();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.main);
                    }
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradingTab(SimulationProvider simulationProvider) {
    // Unir trades abiertos y completados para el gráfico
    final allTrades = [
      ...simulationProvider.completedTrades,
      ...simulationProvider.currentTrades,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Chart Section - 50% of screen height
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF374151), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    offset: const Offset(0, 0),
                    blurRadius: 1,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Chart Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF374151), Color(0xFF1F2937)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.candlestick_chart,
                            color: Color(0xFF22C55E),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          simulationProvider.activeSymbol ?? 'BTCUSD',
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF22C55E,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _selectedTimeframe?.name.toUpperCase() ??
                                simulationProvider.activeTimeframe.name
                                    .toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (simulationProvider.isSimulationRunning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Color(0xFF22C55E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Chart Content
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
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
                              provider.entryPrice > 0
                                  ? provider.entryPrice
                                  : null,
                            ),
                            builder: (context, data, child) {
                              final entryPrice = _clickPrice ?? data.item5;
                              return TradingViewChart(
                                key: _chartKey,
                                candles: simulationProvider.historicalData,
                                trades: data.item1,
                                currentCandleIndex: data.item2,
                                stopLoss: data.item3,
                                takeProfit: data.item4,
                                entryPrice: entryPrice,
                                slPercent: -_slRiskPercent,
                                slValue:
                                    -(simulationProvider.currentBalance *
                                        (_slRiskPercent / 100)),
                                tpPercent: _tpRiskPercent,
                                tpValue:
                                    simulationProvider.currentBalance *
                                    (_tpRiskPercent / 100),
                                entryValue: simulationProvider.inPosition
                                    ? simulationProvider.unrealizedPnL
                                    : 0.0,
                                isRunning:
                                    simulationProvider.isSimulationRunning,
                              );
                            },
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Controls Section - Flexible
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Order Container (when active)
                  if (_showOrderContainerInline) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1F2937),
                            const Color(0xFF111827),
                            _isBuyOrder
                                ? const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.05)
                                : const Color(
                                    0xFFFF6B6B,
                                  ).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isBuyOrder
                              ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                              : const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 32,
                            spreadRadius: -4,
                          ),
                          BoxShadow(
                            color: _isBuyOrder
                                ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                                : const Color(
                                    0xFFFF6B6B,
                                  ).withValues(alpha: 0.2),
                            offset: const Offset(0, 0),
                            blurRadius: 2,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: _isBuyOrder
                                              ? [
                                                  const Color(0xFF22C55E),
                                                  const Color(0xFF16A34A),
                                                ]
                                              : [
                                                  const Color(0xFFFF6B6B),
                                                  const Color(0xFFDC2626),
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _isBuyOrder
                                                ? const Color(
                                                    0xFF22C55E,
                                                  ).withValues(alpha: 0.4)
                                                : const Color(
                                                    0xFFFF6B6B,
                                                  ).withValues(alpha: 0.4),
                                            offset: const Offset(0, 4),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _isBuyOrder
                                            ? Icons.trending_up
                                            : Icons.trending_down,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _isBuyOrder
                                              ? 'ORDEN DE COMPRA'
                                              : 'ORDEN DE VENTA',
                                          style: TextStyle(
                                            color: _isBuyOrder
                                                ? const Color(0xFF22C55E)
                                                : const Color(0xFFFF6B6B),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Inter',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Configura tu entrada al mercado',
                                          style: TextStyle(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF374151,
                                    ).withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF4B5563),
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      simulationProvider.cancelOrder();
                                      setState(() {
                                        _showOrderContainerInline = false;
                                        _showSlTpOnOrderInline = false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Enhanced Price Entry Section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF374151), Color(0xFF1F2937)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4B5563),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.price_change_rounded,
                                        color: Color(0xFF22C55E),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PRECIO DE ENTRADA',
                                          style: TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '\$${_clickPrice?.toStringAsFixed(5) ?? "--"}',
                                          style: const TextStyle(
                                            color: Color(0xFFF8FAFC),
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (_clickPrice != null &&
                              simulationProvider.calculatedPositionSize !=
                                  null &&
                              simulationProvider.calculatedPositionSize! >
                                  0) ...[
                            const SizedBox(height: 20),
                            // Enhanced SL/TP Display
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFDC2626),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFFF6B6B,
                                          ).withValues(alpha: 0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 12,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.stop_circle_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'STOP LOSS',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '\$${(() {
                                            final riskAmount = simulationProvider.currentBalance * (_slRiskPercent / 100);
                                            final priceDistance = riskAmount / simulationProvider.calculatedPositionSize!;
                                            final slPrice = _isBuyOrder ? _clickPrice! - priceDistance : _clickPrice! + priceDistance;
                                            return slPrice.toStringAsFixed(5);
                                          })()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '-${_slRiskPercent.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 10,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF22C55E),
                                          Color(0xFF16A34A),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF22C55E,
                                          ).withValues(alpha: 0.3),
                                          offset: const Offset(0, 4),
                                          blurRadius: 12,
                                          spreadRadius: -2,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.trending_up_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'TAKE PROFIT',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '\$${(() {
                                            final potentialAmount = simulationProvider.currentBalance * (_tpRiskPercent / 100);
                                            final priceDistance = potentialAmount / simulationProvider.calculatedPositionSize!;
                                            final tpPrice = _isBuyOrder ? _clickPrice! + priceDistance : _clickPrice! - priceDistance;
                                            return tpPrice.toStringAsFixed(5);
                                          })()}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '+${_tpRiskPercent.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 10,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_showSlTpOnOrderInline) ...[
                            const SizedBox(height: 24),
                            // Enhanced SL/TP Slider Section
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF374151),
                                    Color(0xFF1F2937),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF4B5563),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.tune_rounded,
                                          color: Color(0xFF3B82F6),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'CONFIGURACIÓN AVANZADA',
                                        style: TextStyle(
                                          color: Color(0xFFF8FAFC),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Inter',
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Stop Loss Slider
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_clickPrice != null &&
                                          simulationProvider
                                                  .calculatedPositionSize !=
                                              null &&
                                          simulationProvider.currentBalance > 0)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Color(0xFFFF6B6B),
                                                Color(0xFFDC2626),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFFF6B6B,
                                                ).withValues(alpha: 0.2),
                                                offset: const Offset(0, 4),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.stop_circle_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'STOP LOSS',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontFamily: 'Inter',
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${_slRiskPercent.toStringAsFixed(1)}% • \$${(simulationProvider.currentBalance * (_slRiskPercent / 100)).toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontFamily: 'Inter',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      // Enhanced Slider Controls
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4B5563),
                                                  Color(0xFF374151),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.remove_rounded,
                                                color: Color(0xFFFF6B6B),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _slRiskPercent =
                                                      (_slRiskPercent - 0.1)
                                                          .clamp(0.1, 100);
                                                });
                                                if (simulationProvider
                                                            .calculatedPositionSize !=
                                                        null &&
                                                    simulationProvider
                                                            .calculatedPositionSize! >
                                                        0) {
                                                  final riskAmount =
                                                      simulationProvider
                                                          .currentBalance *
                                                      (_slRiskPercent / 100);
                                                  final priceDistance =
                                                      riskAmount /
                                                      simulationProvider
                                                          .calculatedPositionSize!;
                                                  final slPrice = _isBuyOrder
                                                      ? _clickPrice! -
                                                            priceDistance
                                                      : _clickPrice! +
                                                            priceDistance;
                                                  simulationProvider
                                                      .updateManualStopLoss(
                                                        slPrice,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                      activeTrackColor:
                                                          const Color(
                                                            0xFFFF6B6B,
                                                          ),
                                                      inactiveTrackColor:
                                                          const Color(
                                                            0xFFFF6B6B,
                                                          ).withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      thumbColor: const Color(
                                                        0xFFFF6B6B,
                                                      ),
                                                      overlayColor: const Color(
                                                        0xFFFF6B6B,
                                                      ).withValues(alpha: 0.2),
                                                      thumbShape:
                                                          const RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                8,
                                                          ),
                                                      trackHeight: 4,
                                                    ),
                                                child: Slider(
                                                  value: _slRiskPercent.clamp(
                                                    0.1,
                                                    100,
                                                  ),
                                                  min: 0.1,
                                                  max: 100,
                                                  divisions: 999,
                                                  label:
                                                      '${_slRiskPercent.toStringAsFixed(1)}%',
                                                  onChanged: (newPercent) {
                                                    setState(
                                                      () => _slRiskPercent =
                                                          newPercent,
                                                    );
                                                    if (simulationProvider
                                                                .calculatedPositionSize !=
                                                            null &&
                                                        simulationProvider
                                                                .calculatedPositionSize! >
                                                            0) {
                                                      final riskAmount =
                                                          simulationProvider
                                                              .currentBalance *
                                                          (_slRiskPercent /
                                                              100);
                                                      final priceDistance =
                                                          riskAmount /
                                                          simulationProvider
                                                              .calculatedPositionSize!;
                                                      final slPrice =
                                                          _isBuyOrder
                                                          ? _clickPrice! -
                                                                priceDistance
                                                          : _clickPrice! +
                                                                priceDistance;
                                                      simulationProvider
                                                          .updateManualStopLoss(
                                                            slPrice,
                                                          );
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4B5563),
                                                  Color(0xFF374151),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.add_rounded,
                                                color: Color(0xFFFF6B6B),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _slRiskPercent =
                                                      (_slRiskPercent + 0.1)
                                                          .clamp(0.1, 100);
                                                });
                                                if (simulationProvider
                                                            .calculatedPositionSize !=
                                                        null &&
                                                    simulationProvider
                                                            .calculatedPositionSize! >
                                                        0) {
                                                  final riskAmount =
                                                      simulationProvider
                                                          .currentBalance *
                                                      (_slRiskPercent / 100);
                                                  final priceDistance =
                                                      riskAmount /
                                                      simulationProvider
                                                          .calculatedPositionSize!;
                                                  final slPrice = _isBuyOrder
                                                      ? _clickPrice! -
                                                            priceDistance
                                                      : _clickPrice! +
                                                            priceDistance;
                                                  simulationProvider
                                                      .updateManualStopLoss(
                                                        slPrice,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Take Profit Slider
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_clickPrice != null &&
                                          simulationProvider
                                                  .calculatedPositionSize !=
                                              null &&
                                          simulationProvider.currentBalance > 0)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                Color(0xFF22C55E),
                                                Color(0xFF16A34A),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF22C55E,
                                                ).withValues(alpha: 0.2),
                                                offset: const Offset(0, 4),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.trending_up_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'TAKE PROFIT',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontFamily: 'Inter',
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${_tpRiskPercent.toStringAsFixed(1)}% • \$${(simulationProvider.currentBalance * (_tpRiskPercent / 100)).toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontFamily: 'Inter',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4B5563),
                                                  Color(0xFF374151),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.remove_rounded,
                                                color: Color(0xFF22C55E),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _tpRiskPercent =
                                                      (_tpRiskPercent - 0.1)
                                                          .clamp(0.1, 100);
                                                });
                                                if (simulationProvider
                                                            .calculatedPositionSize !=
                                                        null &&
                                                    simulationProvider
                                                            .calculatedPositionSize! >
                                                        0) {
                                                  final potentialAmount =
                                                      simulationProvider
                                                          .currentBalance *
                                                      (_tpRiskPercent / 100);
                                                  final priceDistance =
                                                      potentialAmount /
                                                      simulationProvider
                                                          .calculatedPositionSize!;
                                                  final tpPrice = _isBuyOrder
                                                      ? _clickPrice! +
                                                            priceDistance
                                                      : _clickPrice! -
                                                            priceDistance;
                                                  simulationProvider
                                                      .updateManualTakeProfit(
                                                        tpPrice,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                          Expanded(
                                            child: Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                      activeTrackColor:
                                                          const Color(
                                                            0xFF22C55E,
                                                          ),
                                                      inactiveTrackColor:
                                                          const Color(
                                                            0xFF22C55E,
                                                          ).withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      thumbColor: const Color(
                                                        0xFF22C55E,
                                                      ),
                                                      overlayColor: const Color(
                                                        0xFF22C55E,
                                                      ).withValues(alpha: 0.2),
                                                      thumbShape:
                                                          const RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                8,
                                                          ),
                                                      trackHeight: 4,
                                                    ),
                                                child: Slider(
                                                  value: _tpRiskPercent.clamp(
                                                    0.1,
                                                    100,
                                                  ),
                                                  min: 0.1,
                                                  max: 100,
                                                  divisions: 999,
                                                  label:
                                                      '+${_tpRiskPercent.toStringAsFixed(1)}%',
                                                  onChanged: (newPercent) {
                                                    setState(
                                                      () => _tpRiskPercent =
                                                          newPercent,
                                                    );
                                                    if (simulationProvider
                                                                .calculatedPositionSize !=
                                                            null &&
                                                        simulationProvider
                                                                .calculatedPositionSize! >
                                                            0) {
                                                      final potentialAmount =
                                                          simulationProvider
                                                              .currentBalance *
                                                          (_tpRiskPercent /
                                                              100);
                                                      final priceDistance =
                                                          potentialAmount /
                                                          simulationProvider
                                                              .calculatedPositionSize!;
                                                      final tpPrice =
                                                          _isBuyOrder
                                                          ? _clickPrice! +
                                                                priceDistance
                                                          : _clickPrice! -
                                                                priceDistance;
                                                      simulationProvider
                                                          .updateManualTakeProfit(
                                                            tpPrice,
                                                          );
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF4B5563),
                                                  Color(0xFF374151),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.2),
                                                  offset: const Offset(0, 2),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.add_rounded,
                                                color: Color(0xFF22C55E),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _tpRiskPercent =
                                                      (_tpRiskPercent + 0.1)
                                                          .clamp(0.1, 100);
                                                });
                                                if (simulationProvider
                                                            .calculatedPositionSize !=
                                                        null &&
                                                    simulationProvider
                                                            .calculatedPositionSize! >
                                                        0) {
                                                  final potentialAmount =
                                                      simulationProvider
                                                          .currentBalance *
                                                      (_tpRiskPercent / 100);
                                                  final priceDistance =
                                                      potentialAmount /
                                                      simulationProvider
                                                          .calculatedPositionSize!;
                                                  final tpPrice = _isBuyOrder
                                                      ? _clickPrice! +
                                                            priceDistance
                                                      : _clickPrice! -
                                                            priceDistance;
                                                  simulationProvider
                                                      .updateManualTakeProfit(
                                                        tpPrice,
                                                      );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Confirm Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  simulationProvider.canCalculatePosition() &&
                                      _clickPrice != null &&
                                      _slRiskPercent > 0 &&
                                      _tpRiskPercent > 0
                                  ? () {
                                      // debugPrint(
                                      //   '🔥 [CONFIRMAR] Valores antes de confirmar: SL % = $_slRiskPercent, TP % = $_tpRiskPercent',
                                      // );
                                      // Calcular precios a partir de los porcentajes de riesgo/potencial
                                      final riskAmount =
                                          simulationProvider.currentBalance *
                                          (_slRiskPercent / 100);
                                      final tpAmount =
                                          simulationProvider.currentBalance *
                                          (_tpRiskPercent / 100);
                                      final slPrice = _isBuyOrder
                                          ? _clickPrice! -
                                                (riskAmount /
                                                    (simulationProvider
                                                            .calculatedPositionSize ??
                                                        1))
                                          : _clickPrice! +
                                                (riskAmount /
                                                    (simulationProvider
                                                            .calculatedPositionSize ??
                                                        1));
                                      final tpPrice = _isBuyOrder
                                          ? _clickPrice! +
                                                (tpAmount /
                                                    (simulationProvider
                                                            .calculatedPositionSize ??
                                                        1))
                                          : _clickPrice! -
                                                (tpAmount /
                                                    (simulationProvider
                                                            .calculatedPositionSize ??
                                                        1));
                                      simulationProvider.updateManualStopLoss(
                                        slPrice,
                                      );
                                      simulationProvider.updateManualTakeProfit(
                                        tpPrice,
                                      );
                                      // debugPrint(
                                      //   '🔥 [CONFIRMAR] Orden ejecutada. SL final = $slPrice, TP final = $tpPrice',
                                      // );
                                      simulationProvider.executeManualTrade(
                                        type: _isBuyOrder ? 'buy' : 'sell',
                                        amount:
                                            simulationProvider
                                                .calculatedPositionSize ??
                                            0.0,
                                        leverage:
                                            simulationProvider
                                                .calculatedLeverage
                                                ?.toInt() ??
                                            1,
                                        entryPrice: _clickPrice!,
                                      );
                                      Future.delayed(
                                        const Duration(milliseconds: 100),
                                        () {
                                          simulationProvider.resumeSimulation();
                                        },
                                      );
                                      setState(() {
                                        _showOrderContainerInline = false;
                                        _showSlTpOnOrderInline = false;
                                        _clickPrice = null;
                                      });
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
                          // Position summary - solo mostrar después de ejecutar la orden
                          if (simulationProvider.inPosition) ...[
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
                                  Text(
                                    simulationProvider.getPositionSummaryText(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Stop Loss: ${simulationProvider.manualStopLossPrice?.toStringAsFixed(5) ?? 'N/A'}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    'Take Profit: ${simulationProvider.manualTakeProfitPrice?.toStringAsFixed(5) ?? 'N/A'}',
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
                    const SizedBox(height: 16),
                  ],

                  // --- Controles de compra/venta en la sección media ---
                  if (!_showOrderContainerInline) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1F2937), Color(0xFF111827)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF374151),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            offset: const Offset(0, 6),
                            blurRadius: 20,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with enhanced styling
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF22C55E),
                                        Color(0xFF16A34A),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF22C55E,
                                        ).withValues(alpha: 0.3),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.trending_up,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Controles de Trading',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ejecuta órdenes de compra y venta',
                                      style: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Enhanced Trading Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient:
                                        (!simulationProvider.inPosition &&
                                            simulationProvider
                                                .canCalculatePosition())
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF22C55E),
                                              Color(0xFF16A34A),
                                            ],
                                          )
                                        : null,
                                    color:
                                        (!simulationProvider.inPosition &&
                                            simulationProvider
                                                .canCalculatePosition())
                                        ? null
                                        : const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow:
                                        (!simulationProvider.inPosition &&
                                            simulationProvider
                                                .canCalculatePosition())
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 4),
                                              blurRadius: 16,
                                              spreadRadius: -2,
                                            ),
                                          ]
                                        : null,
                                  ),
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
                                    icon: const Icon(
                                      Icons.trending_up,
                                      size: 22,
                                    ),
                                    label: const Text(
                                      'COMPRAR',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient:
                                        (!simulationProvider.inPosition &&
                                            simulationProvider
                                                .canCalculatePosition())
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFF6B6B),
                                              Color(0xFFDC2626),
                                            ],
                                          )
                                        : null,
                                    color:
                                        (!simulationProvider.inPosition &&
                                            simulationProvider
                                                .canCalculatePosition())
                                        ? null
                                        : const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow:
                                        (!simulationProvider.inPosition &&
                                            simulationProvider
                                                .canCalculatePosition())
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFF6B6B,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 4),
                                              blurRadius: 16,
                                              spreadRadius: -2,
                                            ),
                                          ]
                                        : null,
                                  ),
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
                                    icon: const Icon(
                                      Icons.trending_down,
                                      size: 22,
                                    ),
                                    label: const Text(
                                      'VENDER',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                        horizontal: 20,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Close Position Button (only show if position is open)
                          if (simulationProvider.inPosition) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF374151,
                                ).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF4B5563),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFF59E0B,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.account_balance_wallet,
                                          color: Color(0xFFF59E0B),
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Posición Activa',
                                        style: TextStyle(
                                          color: Color(0xFFF8FAFC),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFFF6B6B),
                                                Color(0xFFDC2626),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFFF6B6B,
                                                ).withValues(alpha: 0.3),
                                                offset: const Offset(0, 4),
                                                blurRadius: 12,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              simulationProvider
                                                  .closeManualPosition(
                                                    simulationProvider
                                                        .currentTickPrice,
                                                  );
                                            },
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'CERRAR',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor: Colors.white,
                                              shadowColor: Colors.transparent,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFF3B82F6),
                                                Color(0xFF1D4ED8),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF3B82F6,
                                                ).withValues(alpha: 0.3),
                                                offset: const Offset(0, 4),
                                                blurRadius: 12,
                                                spreadRadius: -2,
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              _showManageSLTPContainer(
                                                context,
                                                simulationProvider,
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.tune_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'SL/TP',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              foregroundColor: Colors.white,
                                              shadowColor: Colors.transparent,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Debug Button (temporary)
                    if (simulationProvider.setupParametersCalculated) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF374151)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bug_report,
                                  color: Color(0xFFF59E0B),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Debug Info',
                                  style: TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF374151),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                simulationProvider.getDebugSLTPInfo(),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],

                  // --- Enhanced Simulation Controls ---
                  if (!_showOrderContainerInline) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1F2937), Color(0xFF111827)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF374151),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            offset: const Offset(0, 6),
                            blurRadius: 20,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Header
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF1D4ED8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.3),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.speed_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Control de Simulación',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Gestiona la velocidad y marco temporal',
                                      style: TextStyle(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                // Enhanced Timeframe Selector
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF374151),
                                        Color(0xFF1F2937),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF4B5563),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        offset: const Offset(0, 2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: DropdownButton<Timeframe>(
                                    value:
                                        _selectedTimeframe ??
                                        simulationProvider.activeTimeframe,
                                    dropdownColor: const Color(0xFF1F2937),
                                    underline: Container(),
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 18,
                                    ),
                                    items: Timeframe.values.map((tf) {
                                      String label;
                                      switch (tf) {
                                        case Timeframe.d1:
                                          label = '1D';
                                          break;
                                        case Timeframe.h1:
                                          label = '1H';
                                          break;
                                        case Timeframe.m15:
                                          label = '15M';
                                          break;
                                        case Timeframe.m5:
                                          label = '5M';
                                          break;
                                        case Timeframe.m1:
                                          label = '1M';
                                          break;
                                      }
                                      return DropdownMenuItem(
                                        value: tf,
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            color: Color(0xFFF8FAFC),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
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
                          ),

                          const SizedBox(height: 20),

                          // Enhanced Simulation Control Buttons
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient:
                                        (simulationProvider.currentSetup !=
                                                null &&
                                            (simulationProvider
                                                    .isSimulationPaused ||
                                                !simulationProvider
                                                    .isSimulationRunning))
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF22C55E),
                                              Color(0xFF16A34A),
                                            ],
                                          )
                                        : null,
                                    color:
                                        (simulationProvider.currentSetup !=
                                                null &&
                                            (simulationProvider
                                                    .isSimulationPaused ||
                                                !simulationProvider
                                                    .isSimulationRunning))
                                        ? null
                                        : const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow:
                                        (simulationProvider.currentSetup !=
                                                null &&
                                            (simulationProvider
                                                    .isSimulationPaused ||
                                                !simulationProvider
                                                    .isSimulationRunning))
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF22C55E,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 4),
                                              blurRadius: 16,
                                              spreadRadius: -2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (simulationProvider.currentSetup !=
                                                null &&
                                            simulationProvider
                                                .isSimulationPaused)
                                        ? () => simulationProvider
                                              .resumeTickSimulation()
                                        : (simulationProvider.currentSetup !=
                                                  null &&
                                              !simulationProvider
                                                  .isSimulationRunning)
                                        ? () => simulationProvider
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
                                                simulationProvider
                                                        .activeSymbol ??
                                                    'BTCUSD',
                                              )
                                        : null,
                                    icon: Icon(
                                      simulationProvider.isSimulationPaused
                                          ? Icons.play_arrow_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 22,
                                    ),
                                    label: Text(
                                      simulationProvider.isSimulationPaused
                                          ? 'REANUDAR'
                                          : 'INICIAR',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient:
                                        simulationProvider.isSimulationRunning
                                        ? const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFF59E0B),
                                              Color(0xFFD97706),
                                            ],
                                          )
                                        : null,
                                    color:
                                        simulationProvider.isSimulationRunning
                                        ? null
                                        : const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow:
                                        simulationProvider.isSimulationRunning
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.3),
                                              offset: const Offset(0, 4),
                                              blurRadius: 16,
                                              spreadRadius: -2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        simulationProvider.isSimulationRunning
                                        ? () => simulationProvider
                                              .pauseTickSimulation()
                                        : null,
                                    icon: const Icon(
                                      Icons.pause_rounded,
                                      size: 22,
                                    ),
                                    label: const Text(
                                      'PAUSAR',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                          const SizedBox(height: 24),

                          // Enhanced Speed Control
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF374151), Color(0xFF1F2937)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4B5563),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.speed_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'VELOCIDAD: ${simulationProvider.ticksPerSecondFactor.toStringAsFixed(1)}x',
                                          style: const TextStyle(
                                            color: Color(0xFFF8FAFC),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Inter',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (_isAdjustingSpeed) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFF59E0B),
                                                  Color(0xFFD97706),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'PAUSADO',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Inter',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: const Color(0xFF3B82F6),
                                    inactiveTrackColor: const Color(
                                      0xFF3B82F6,
                                    ).withValues(alpha: 0.2),
                                    thumbColor: const Color(0xFF3B82F6),
                                    overlayColor: const Color(
                                      0xFF3B82F6,
                                    ).withValues(alpha: 0.2),
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 10,
                                    ),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value:
                                        simulationProvider.ticksPerSecondFactor,
                                    min: 0.1,
                                    max: 5.0,
                                    divisions: 49,
                                    label:
                                        '${simulationProvider.ticksPerSecondFactor.toStringAsFixed(1)}x',
                                    onChanged: (value) {
                                      // Pausar temporalmente mientras se ajusta la velocidad
                                      if (!_isAdjustingSpeed &&
                                          simulationProvider
                                              .isSimulationRunning) {
                                        _isAdjustingSpeed = true;
                                        simulationProvider
                                            .pauseTickSimulation();
                                      }
                                      simulationProvider.ticksPerSecondFactor =
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
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF374151)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timeline,
                          color: Color(0xFF22C55E),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Progreso de Simulación',
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: simulationProvider.historicalData.isNotEmpty
                          ? (simulationProvider.currentCandleIndex + 1) /
                                simulationProvider.historicalData.length
                          : 0.0,
                      backgroundColor: const Color(0xFF374151),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF22C55E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vela ${simulationProvider.currentCandleIndex + 1} de ${simulationProvider.historicalData.length}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Enhanced Real-time Statistics
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF374151), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estadísticas en Tiempo Real',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Resumen de tu rendimiento',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
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
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Win Rate',
                          '${(winRate * 100).toStringAsFixed(1)}%',
                          Icons.trending_up,
                          winRate >= 0.5
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFFF6B6B),
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
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'P&L Total',
                          '\$${totalPnL.toStringAsFixed(2)}',
                          Icons.trending_up,
                          totalPnL >= 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFFF6B6B),
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
                          const Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Pérdida Máx',
                          '\$${maxLoss.toStringAsFixed(2)}',
                          Icons.trending_down,
                          const Color(0xFFFF6B6B),
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
                          const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'P&L Flotante',
                          '\$${simulationProvider.unrealizedPnL.toStringAsFixed(2)}',
                          Icons.pending,
                          simulationProvider.unrealizedPnL >= 0
                              ? const Color(0xFF22C55E)
                              : const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Enhanced P&L Statistics
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF374151), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información de Trading',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Balance y gestión de capital',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F2937),
            const Color(0xFF111827),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            offset: const Offset(0, 0),
            blurRadius: 1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
