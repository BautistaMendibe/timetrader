import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../widgets/trading_view_chart.dart';
import '../routes.dart';
import '../models/simulation_result.dart';
import 'trading_tab.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  // GlobalKey para acceder al TradingViewChart
  final GlobalKey<TradingViewChartState> _chartKey =
      GlobalKey<TradingViewChartState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final simulationProvider = context.read<SimulationProvider>();

      // Conectar el callback para enviar ticks al chart
      simulationProvider.setTickCallback((tickData) {
        if (_chartKey.currentState != null) {
          // Verificar si es una señal de control (pausa/restauración)
          if (tickData.containsKey('pause') ||
              tickData.containsKey('restore')) {
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else if (tickData.containsKey('closeOrder') ||
              tickData.containsKey('clearLines')) {
            // Es una señal de limpieza - enviar directamente
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else if (tickData.containsKey('resetChart')) {
            // Es una señal de reset del chart - enviar directamente
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else if (tickData.containsKey('trades') &&
              !tickData.containsKey('candle') &&
              !tickData.containsKey('tick')) {
            // Es solo un mensaje de trades (cierre de posición) - enviar directamente
            _chartKey.currentState!.sendMessageToWebView(tickData);
          } else {
            // Es un tick normal con vela - pasar TODOS los datos del tick
            final candle = tickData['candle'] ?? tickData['tick'];
            if (candle == null) return; // Evita error si no hay vela

            // Construir mensaje completo con todos los datos del tick
            final messageToChart = <String, dynamic>{'candle': candle};

            // Agregar todos los demás campos del tickData
            tickData.forEach((key, value) {
              if (key != 'candle' && key != 'tick') {
                messageToChart[key] = value;
              }
            });

            // Asegurar que entryPrice esté presente cuando hay posición
            if (simulationProvider.inPosition) {
              messageToChart['entryPrice'] = simulationProvider.entryPrice;
            }

            // Enviar al WebView con todos los datos
            _chartKey.currentState?.sendMessageToWebView(messageToChart);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Consumer<SimulationProvider>(
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF22C55E),
                    ),
                  ),
                ),
              ),
            );
          }

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
                          TradingTab(
                            chartKey: _chartKey,
                            simulationProvider: simulationProvider,
                          ),
                          // Tab 2: Estadísticas
                          _buildStatisticsTab(simulationProvider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
                  barrierDismissible: false,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF374151), Color(0xFF1F2937)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4B5563),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 8),
                            blurRadius: 32,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.exit_to_app_rounded,
                              size: 32,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Title
                          const Text(
                            '¿Salir de la simulación?',
                            style: TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),

                          // Content
                          Text(
                            '¿Estás seguro que quieres salir?\nSe perderá el progreso de la simulación actual.',
                            style: TextStyle(
                              color: const Color(0xFF94A3B8),
                              fontFamily: 'Inter',
                              fontSize: 14,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF374151),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF4B5563),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: Color(0xFFF8FAFC),
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
                                      colors: [
                                        Color(0xFFEF4444),
                                        Color(0xFFDC2626),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.3),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                        spreadRadius: -2,
                                      ),
                                    ],
                                  ),
                                  child: TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Salir',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
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
                  ),
                );
                if (shouldExit == true && mounted) {
                  // Properly stop the simulation and clean up timers
                  simulationProvider.stopTickSimulation();
                  simulationProvider.reset();
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
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

            // Enhanced Completed Operations History
            if (completedOperations.isNotEmpty) ...[
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
                                colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 12,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Historial de Operaciones',
                                style: TextStyle(
                                  color: Color(0xFFF8FAFC),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$winningTrades/$totalCompletedOperations ganadores',
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

                    // Operations List
                    ...completedOperations
                        .take(10)
                        .map(
                          (operation) =>
                              _buildCompletedOperationItem(operation),
                        ),

                    if (completedOperations.length > 10) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4B5563),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '... y ${completedOperations.length - 10} operaciones más',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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
    final isProfit = operation.totalPnL >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF374151), const Color(0xFF1F2937)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isProfit
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isProfit
                ? const Color(0xFF10B981).withValues(alpha: 0.1)
                : const Color(0xFFEF4444).withValues(alpha: 0.1),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header con tipo de operación y P&L
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isProfit
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isProfit
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isProfit
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isProfit
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    operation.operationType.toUpperCase(),
                    style: TextStyle(
                      color: isProfit
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isProfit
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isProfit
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '\$${operation.totalPnL.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isProfit
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Enhanced Precios de entrada y salida
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4B5563).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ENTRADA',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${operation.entryPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        operation.entryTime.toString().substring(11, 16),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 16,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'SALIDA',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isProfit
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${operation.exitPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        operation.exitTime.toString().substring(11, 16),
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Enhanced Información adicional
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF374151).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildOperationDetailChip(
                    'Cantidad',
                    '${operation.quantity.toStringAsFixed(4)}',
                    Icons.account_balance_wallet_rounded,
                  ),
                ),
                if (operation.leverage != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOperationDetailChip(
                      'Apalancamiento',
                      '${operation.leverage}x',
                      Icons.trending_up_rounded,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOperationDetailChip(
                    'Duración',
                    operation.durationFormatted,
                    Icons.timer_rounded,
                  ),
                ),
              ],
            ),
          ),
          if (operation.reason != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF374151).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4B5563).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      operation.reason!,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationDetailChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF4B5563).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9CA3AF), size: 12),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 9,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
