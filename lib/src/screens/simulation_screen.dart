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

  void _showOrderModal(BuildContext context, SimulationProvider simulationProvider, bool isBuy) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuy ? 'Comprar' : 'Vender',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Amount Selection
                    Text(
                      'Monto',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [100, 400, 1000, 1500, 3000].map((amount) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAmount = amount.toDouble();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedAmount == amount
                                  ? const Color(0xFF21CE99)
                                  : const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(8),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Leverage Selection
                    Text(
                      'Apalancamiento',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [1, 5, 10, 20, 30, 50].map((leverage) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLeverage = leverage;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedLeverage == leverage
                                  ? const Color(0xFF21CE99)
                                  : const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(8),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          simulationProvider.executeManualTrade(
                            type: isBuy ? 'buy' : 'sell',
                            amount: _selectedAmount,
                            leverage: _selectedLeverage,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isBuy ? const Color(0xFF21CE99) : const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isBuy ? 'Comprar' : 'Vender',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Simulación'),
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  simulationProvider.stopSimulation();
                  Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
                },
              ),
            ],
          ),
          body: Container(
            color: const Color(0xFF1E1E1E),
            child: Column(
              children: [
                // Chart Section (70% of screen)
                Expanded(
                  flex: 7,
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
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Controls Section (30% of screen)
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Balance Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Balance: \$${simulationProvider.currentBalance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'P&L: \$${simulationProvider.totalPnL.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: simulationProvider.totalPnL >= 0 
                                          ? const Color(0xFF21CE99) 
                                          : const Color(0xFFFF6B6B),
                                      fontSize: 16,
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Manual Controls
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
                                            ? () => _showOrderModal(context, simulationProvider, true)
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
                                            ? () => _showOrderModal(context, simulationProvider, false)
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
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final currentCandle = simulationProvider.historicalData[simulationProvider.currentCandleIndex];
                                        simulationProvider.closeManualPosition(currentCandle.close);
                                      },
                                      icon: const Icon(Icons.close),
                                      label: const Text('Cerrar Posición'),
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
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 