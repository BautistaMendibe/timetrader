import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../models/candle.dart';
import '../models/simulation_result.dart';
import '../widgets/trading_view_chart.dart';
import '../routes.dart';
import 'package:url_launcher/url_launcher.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  Timer? _timer;
  int _currentCandleIndex = 0;
  final double _initialBalance = 10000.0; // Default initial balance

  @override
  void initState() {
    super.initState();
    _startSimulationTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSimulationTimer() {
    final simulationProvider = context.read<SimulationProvider>();
    
    if (simulationProvider.historicalData.isEmpty) {
      Navigator.pop(context);
      return;
    }

    _timer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (timer) {
        if (!simulationProvider.isSimulationRunning) {
          timer.cancel();
          return;
        }

        // Process next candle automatically
        simulationProvider.processNextCandle();
        
        // Check if simulation is complete
        if (simulationProvider.currentCandleIndex >= simulationProvider.historicalData.length - 1) {
          timer.cancel();
          _stopSimulation();
        }
      },
    );
  }

  void _stopSimulation() {
    final simulationProvider = context.read<SimulationProvider>();
    simulationProvider.stopSimulation();
    Navigator.pushReplacementNamed(context, AppRoutes.simulationSummary);
  }

  void _showOrderModal(String type) {
    final simulationProvider = context.read<SimulationProvider>();
    final currentCandle = simulationProvider.historicalData[simulationProvider.currentCandleIndex];
    final maxLots = 100; // Maximum lots available
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            int lots = 1;
            double takeProfit = currentCandle.close * 1.02; // 2% above current price
            double stopLoss = currentCandle.close * 0.98; // 2% below current price
            int multiplier = 1;
            
            double totalCost = lots * currentCandle.close * multiplier;
            
            return Padding(
              padding: EdgeInsets.only(
                left: 16, 
                right: 16, 
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type == 'buy' ? 'Comprar' : 'Vender',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Current Price
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Precio Actual:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '\$${currentCandle.close.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Lots Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Número de lotes',
                            suffixText: 'Max: $maxLots',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (v) {
                            final val = int.tryParse(v) ?? 1;
                            setState(() => lots = val.clamp(1, maxLots));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Lots Slider
                  Slider(
                    value: lots.toDouble(),
                    min: 1,
                    max: maxLots.toDouble(),
                    divisions: maxLots - 1,
                    onChanged: (v) => setState(() => lots = v.toInt()),
                  ),
                  const SizedBox(height: 16),
                  
                  // Take Profit and Stop Loss
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Take Profit',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          controller: TextEditingController(text: takeProfit.toStringAsFixed(2)),
                          onChanged: (v) => setState(() => takeProfit = double.tryParse(v) ?? currentCandle.close),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Stop Loss',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          controller: TextEditingController(text: stopLoss.toStringAsFixed(2)),
                          onChanged: (v) => setState(() => stopLoss = double.tryParse(v) ?? currentCandle.close),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Multiplier
                  Row(
                    children: [
                      const Text('Multiplicador: '),
                      DropdownButton<int>(
                        value: multiplier,
                        items: [1, 10, 100].map((m) => 
                          DropdownMenuItem(value: m, child: Text('x$m'))
                        ).toList(),
                        onChanged: (v) => setState(() => multiplier = v ?? 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Total Cost
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Costo Total:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '\$${totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == 'buy' ? const Color(0xFF21CE99) : const Color(0xFFFF5A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final provider = context.read<SimulationProvider>();
                        provider.executeTrade(type, currentCandle.close, lots * multiplier.toDouble());
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Orden de $type ejecutada a \$${currentCandle.close.toStringAsFixed(2)}'),
                            backgroundColor: type == 'buy' ? const Color(0xFF21CE99) : const Color(0xFFFF5A5F),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text(
                        '${type == 'buy' ? 'Comprar' : 'Vender'}: \$${currentCandle.close.toStringAsFixed(2)}',
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SimulationProvider>(
      builder: (context, simulationProvider, child) {
        if (simulationProvider.historicalData.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text(
                'No hay datos disponibles',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final currentCandle = simulationProvider.historicalData[simulationProvider.currentCandleIndex];
        final progress = (simulationProvider.currentCandleIndex + 1) / simulationProvider.historicalData.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Simulación'),
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  simulationProvider.isSimulationRunning ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  if (simulationProvider.isSimulationRunning) {
                    simulationProvider.pauseSimulation();
                  } else {
                    simulationProvider.resumeSimulation();
                    _startSimulationTimer();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: _stopSimulation,
              ),
            ],
          ),
          body: Column(
            children: [
              // Balance Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF2C2C2C),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          '\$${simulationProvider.currentBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'P&L',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          '\$${(simulationProvider.currentBalance - _initialBalance).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: simulationProvider.currentBalance >= _initialBalance 
                              ? const Color(0xFF21CE99) 
                              : const Color(0xFFFF5A5F),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Progress Bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF21CE99)),
              ),
              
              // Position Status
              if (simulationProvider.inPosition)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Posición Abierta',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF21CE99),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              simulationProvider.currentTrades.last.type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPositionInfo('Entrada', simulationProvider.entryPrice.toStringAsFixed(2), Colors.blue),
                          ),
                          Expanded(
                            child: _buildPositionInfo('Stop Loss', simulationProvider.stopLossPrice.toStringAsFixed(2), const Color(0xFFFF5A5F)),
                          ),
                          Expanded(
                            child: _buildPositionInfo('Take Profit', simulationProvider.takeProfitPrice.toStringAsFixed(2), const Color(0xFF21CE99)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              
              // Chart Area
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Actual',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${currentCandle.close.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Candle Info
                      Row(
                        children: [
                          Expanded(
                            child: _buildCandleInfo('Apertura', currentCandle.open, Colors.blue),
                          ),
                          Expanded(
                            child: _buildCandleInfo('Máximo', currentCandle.high, const Color(0xFF21CE99)),
                          ),
                          Expanded(
                            child: _buildCandleInfo('Mínimo', currentCandle.low, const Color(0xFFFF5A5F)),
                          ),
                          Expanded(
                            child: _buildCandleInfo('Cierre', currentCandle.close, 
                              currentCandle.close >= currentCandle.open ? const Color(0xFF21CE99) : const Color(0xFFFF5A5F)),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Professional Chart
                      Expanded(
                        child: _buildChartWithTradeMarkers(simulationProvider.historicalData.take(simulationProvider.currentCandleIndex + 1).toList(), simulationProvider.currentTrades),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Trading Controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Balance and P&L
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            Text(
                              '\$${simulationProvider.currentBalance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'P&L',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            Text(
                              '\$${(simulationProvider.currentBalance - 10000.0).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: simulationProvider.currentBalance >= 10000.0 
                                  ? Colors.green 
                                  : Colors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Trade Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Estrategia',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  simulationProvider.currentSetup?.name ?? 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Estado',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: simulationProvider.isSimulationRunning 
                                      ? const Color(0xFF21CE99) 
                                      : Colors.grey[600],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    simulationProvider.isSimulationRunning ? 'EJECUTANDO' : 'PAUSADO',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Trading Statistics
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
                            'Estadísticas de Trading',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatistic('Total Trades', simulationProvider.currentTrades.length.toString(), Colors.blue),
                              ),
                              Expanded(
                                child: _buildStatistic('Win Rate', '${_calculateWinRate(simulationProvider.currentTrades).toStringAsFixed(1)}%', Colors.green),
                              ),
                              Expanded(
                                child: _buildStatistic('Avg P&L', '\$${_calculateAvgPnL(simulationProvider.currentTrades).toStringAsFixed(2)}', Colors.orange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Trades Count
                    Text(
                      'Trades: ${simulationProvider.currentTrades.length}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: TextButton(
            onPressed: () => launchUrl(Uri.parse('https://github.com/tradingview/lightweight-charts')),
            child: const Text(
              'Gráficos realizados con Lightweight Charts™ de TradingView',
              style: TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCandleInfo(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400], 
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildPositionInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400], 
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildChartWithTradeMarkers(List<Candle> candles, List<Trade> trades) {
    debugPrint('🔥 SimulationScreen: _buildChartWithTradeMarkers() - Candles: ${candles.length}, Trades: ${trades.length}');
    
    if (candles.isEmpty) {
      debugPrint('🔥 SimulationScreen: No hay datos de velas disponibles');
      return const Center(
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    debugPrint('🔥 SimulationScreen: Construyendo TradingViewChart con ${candles.length} velas');
    return TradingViewChart(
      candles: candles,
      trades: trades,
    );
  }

  double _calculateWinRate(List<Trade> trades) {
    if (trades.isEmpty) return 0.0;
    
    int winCount = 0;
    for (var trade in trades) {
      if (trade.pnl > 0) {
        winCount++;
      }
    }
    return (winCount / trades.length) * 100;
  }

  double _calculateAvgPnL(List<Trade> trades) {
    if (trades.isEmpty) return 0.0;
    
    double totalPnL = 0;
    for (var trade in trades) {
      totalPnL += trade.pnl;
    }
    return totalPnL / trades.length;
  }

  Widget _buildStatistic(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400], 
            fontSize: 12,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
} 