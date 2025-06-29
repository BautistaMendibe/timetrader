import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../widgets/trading_view_chart.dart';
import '../routes.dart';
import '../models/simulation_result.dart';
import 'package:tuple/tuple.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final double _initialBalance = 10000.0;
  double _selectedAmount = 100.0;
  int _selectedLeverage = 1;
  bool _showOrderContainerInline = false;
  bool _isBuyOrder = true;
  bool _showSLTPContainer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final simulationProvider = context.read<SimulationProvider>();
      if (simulationProvider.isSimulationRunning) {
        // Timer logic removed for manual mode
      }
    });
  }

  @override
  void dispose() {
    final simulationProvider = context.read<SimulationProvider>();
    simulationProvider.stopSimulation();
    super.dispose();
  }

  void _showOrderContainer(BuildContext context, SimulationProvider simulationProvider, bool isBuy) {
    setState(() {
      _showOrderContainerInline = true;
      _isBuyOrder = isBuy;
    });
  }

  void _showManageSLTPContainer(BuildContext context, SimulationProvider simulationProvider) {
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
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
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
                    if (simulationProvider.inPosition && simulationProvider.unrealizedPnL != 0) ...[
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
                  onPressed: () {
                    simulationProvider.stopSimulation();
                    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
                  },
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(
                    icon: Icon(Icons.trending_up),
                    text: 'Trading',
                  ),
                  Tab(
                    icon: Icon(Icons.analytics),
                    text: 'Estadísticas',
                  ),
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
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          // Chart Section (60% of screen)
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Selector<SimulationProvider, Tuple2<List<Trade>, int>>(
                  selector: (context, provider) => Tuple2(
                    provider.currentTrades,
                    provider.currentCandleIndex,
                  ),
                  builder: (context, data, child) {
                    return TradingViewChart(
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
          ),
          
          // Controls Section (40% of screen)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Order Container (when active)
                  if (_showOrderContainerInline) ...[
                    Expanded(
                      child: Container(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _showOrderContainerInline = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Amount Selection
                            Text(
                              'Monto',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [100, 400, 1000, 1500, 3000].map((amount) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedAmount = amount.toDouble();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _selectedAmount == amount
                                          ? const Color(0xFF21CE99)
                                          : const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _selectedAmount == amount
                                            ? const Color(0xFF21CE99)
                                            : Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Text(
                                      '\$${amount.toString()}',
                                      style: TextStyle(
                                        color: _selectedAmount == amount
                                            ? Colors.white
                                            : Colors.grey[300],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Leverage Selection
                            Text(
                              'Apalancamiento',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [1, 5, 10, 20, 30, 50].map((leverage) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedLeverage = leverage;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _selectedLeverage == leverage
                                          ? const Color(0xFF21CE99)
                                          : const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _selectedLeverage == leverage
                                            ? const Color(0xFF21CE99)
                                            : Colors.grey[700]!,
                                      ),
                                    ),
                                    child: Text(
                                      '${leverage}x',
                                      style: TextStyle(
                                        color: _selectedLeverage == leverage
                                            ? Colors.white
                                            : Colors.grey[300],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            
                            const Spacer(),
                            
                            // Confirm Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  simulationProvider.executeManualTrade(
                                    type: _isBuyOrder ? 'buy' : 'sell',
                                    amount: _selectedAmount,
                                    leverage: _selectedLeverage,
                                  );
                                  setState(() {
                                    _showOrderContainerInline = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isBuyOrder ? const Color(0xFF21CE99) : const Color(0xFFFF6B6B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                          ],
                        ),
                      ),
                    ),
                  ] else if (_showSLTPContainer) ...[
                    // SL/TP Container (when active)
                    Expanded(
                      child: _ManageSLTPContainer(simulationProvider: simulationProvider, onClose: () {
                        setState(() {
                          _showSLTPContainer = false;
                        });
                      }),
                    ),
                  ] else ...[
                    // Normal Controls (when no container is active)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Controles Manuales',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Manual Advance Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: simulationProvider.currentCandleIndex < simulationProvider.historicalData.length - 1
                                  ? () => simulationProvider.advanceCandle()
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Siguiente Vela'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF21CE99),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Trading Buttons Row
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: !simulationProvider.inPosition 
                                      ? () => _showOrderContainer(context, simulationProvider, true)
                                      : null,
                                  icon: const Icon(Icons.trending_up),
                                  label: const Text('Comprar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF21CE99),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: !simulationProvider.inPosition 
                                      ? () => _showOrderContainer(context, simulationProvider, false)
                                      : null,
                                  icon: const Icon(Icons.trending_down),
                                  label: const Text('Vender'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B6B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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
                                      final currentCandle = simulationProvider.historicalData[simulationProvider.currentCandleIndex];
                                      simulationProvider.closeManualPosition(currentCandle.close);
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('Cerrar Entrada'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                      _showManageSLTPContainer(context, simulationProvider);
                                    },
                                    icon: const Icon(Icons.tune),
                                    label: const Text('Gestionar SL/TP'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
    final totalTrades = trades.length;
    final winningTrades = trades.where((t) => t.pnl != null && t.pnl! > 0).length;
    final losingTrades = trades.where((t) => t.pnl != null && t.pnl! < 0).length;
    final winRate = totalTrades > 0 ? (winningTrades / totalTrades) * 100 : 0.0;
    
    final totalPnL = trades.where((t) => t.pnl != null).fold(0.0, (sum, t) => sum + t.pnl!);
    final maxProfit = trades.where((t) => t.pnl != null).fold(0.0, (max, t) => t.pnl! > max ? t.pnl! : max);
    final maxLoss = trades.where((t) => t.pnl != null).fold(0.0, (min, t) => t.pnl! < min ? t.pnl! : min);
    
    final isSimulationComplete = simulationProvider.currentCandleIndex >= simulationProvider.historicalData.length - 1;

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
                            ? (simulationProvider.currentCandleIndex + 1) / simulationProvider.historicalData.length
                            : 0.0,
                        backgroundColor: Colors.grey[700],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF21CE99)),
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
                            'Total Trades',
                            totalTrades.toString(),
                            Icons.trending_up,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Win Rate',
                            '${winRate.toStringAsFixed(1)}%',
                            Icons.check_circle,
                            winRate >= 50 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Ganadores',
                            winningTrades.toString(),
                            Icons.trending_up,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Perdedores',
                            losingTrades.toString(),
                            Icons.trending_down,
                            Colors.red,
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
                      'Análisis de P&L',
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
                    _buildPnLMetric('Mayor Ganancia', maxProfit),
                    const SizedBox(height: 8),
                    _buildPnLMetric('Mayor Pérdida', maxLoss),
                    const SizedBox(height: 8),
                    _buildPnLMetric('P&L Promedio', totalTrades > 0 ? totalPnL / totalTrades : 0.0),
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
                      
                      ...trades.take(5).map((trade) => _buildTradeItem(trade)).toList(),
                      
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
            ],

            // Final Summary (when simulation is complete)
            if (isSimulationComplete) ...[
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF21CE99).withOpacity(0.1),
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
                        '¡Excelente trabajo! Has completado la simulación con ${totalTrades} trades y un P&L total de \$${totalPnL.toStringAsFixed(2)}.',
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
            color: value >= 0 ? const Color(0xFF21CE99) : const Color(0xFFFF6B6B),
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
              ? Colors.green.withOpacity(0.3) 
              : Colors.red.withOpacity(0.3),
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
                if (trade.pnl != null)
                  Text(
                    'P&L: \$${trade.pnl!.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: trade.pnl! >= 0 ? const Color(0xFF21CE99) : const Color(0xFFFF6B6B),
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
  double? _takeProfitPercent;
  double? _stopLossPercent;
  double? _partialClosePercent;

  @override
  void initState() {
    super.initState();
    // Usar valores actuales o valores por defecto
    _takeProfitPercent = widget.simulationProvider.manualTakeProfitPercent ?? 6.0;
    _stopLossPercent = widget.simulationProvider.manualStopLossPercent ?? 2.5;
    _partialClosePercent = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.simulationProvider.currentBalance;
    final entryPrice = widget.simulationProvider.entryPrice;
    final positionSize = widget.simulationProvider.positionSize;
    final amount = positionSize * entryPrice;
    final tpValue = amount * (_takeProfitPercent! / 100);
    final slValue = amount * (_stopLossPercent! / 100);
    final partialValue = amount * (_partialClosePercent! / 100);

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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Take Profit
            Text('TP: +\$${tpValue.toStringAsFixed(0)} (+${_takeProfitPercent!.toStringAsFixed(1)}%)', 
                 style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)),
            Slider(
              value: _takeProfitPercent!,
              min: 0,
              max: 20,
              divisions: 40,
              label: '+${_takeProfitPercent!.toStringAsFixed(1)}%',
              activeColor: Colors.green,
              inactiveColor: Colors.green.withOpacity(0.2),
              onChanged: (v) {
                setState(() => _takeProfitPercent = v);
                // Actualizar en tiempo real
                widget.simulationProvider.setManualSLTP(takeProfitPercent: v);
              },
            ),
            const SizedBox(height: 6),
            
            // Stop Loss
            Text('SL: -\$${slValue.toStringAsFixed(0)} (-${_stopLossPercent!.toStringAsFixed(1)}%)', 
                 style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12)),
            Slider(
              value: _stopLossPercent!,
              min: 0,
              max: 10,
              divisions: 40,
              label: '-${_stopLossPercent!.toStringAsFixed(1)}%',
              activeColor: Colors.red,
              inactiveColor: Colors.red.withOpacity(0.2),
              onChanged: (v) {
                setState(() => _stopLossPercent = v);
                // Actualizar en tiempo real
                widget.simulationProvider.setManualSLTP(stopLossPercent: v);
              },
            ),
            const SizedBox(height: 6),
            
            // Partial Close
            Text('Parcial: \$${partialValue.toStringAsFixed(0)} (${_partialClosePercent!.toStringAsFixed(1)}%)', 
                 style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 12)),
            Slider(
              value: _partialClosePercent!,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${_partialClosePercent!.toStringAsFixed(1)}%',
              activeColor: Colors.blue,
              inactiveColor: Colors.blue.withOpacity(0.2),
              onChanged: (v) => setState(() => _partialClosePercent = v),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Lógica real: aplicar SL/TP y cierre parcial
                      if (_partialClosePercent != null && _partialClosePercent! > 0) {
                        widget.simulationProvider.closePartialPosition(_partialClosePercent!);
                      }
                      widget.simulationProvider.setManualSLTP(
                        stopLossPercent: _stopLossPercent,
                        takeProfitPercent: _takeProfitPercent,
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
                    child: const Text('HECHO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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