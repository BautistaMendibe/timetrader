import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../models/simulation_result.dart';
import '../routes.dart';
import '../widgets/top_snack_bar.dart';

class SimulationSummaryScreen extends StatelessWidget {
  const SimulationSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SimulationProvider>(
      builder: (context, simulationProvider, child) {
        final simulation = simulationProvider.currentSimulation;
        
        if (simulation == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Resumen de Simulación'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay datos de simulación disponibles',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Resumen de Simulación'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // TODO: Implement share functionality
                  TopSnackBar.showInfo(
                    context: context,
                    message: 'Función de compartir próximamente',
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with main results
                Card(
                  color: const Color(0xFF2C2C2C),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'P&L Neto',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${simulation.netPnL.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: simulation.netPnL >= 0 ? Colors.green : Colors.red,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Win Rate',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(simulation.winRate * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMetric('Balance Final', '\$${simulation.finalBalance.toStringAsFixed(2)}'),
                            _buildMetric('Max Drawdown', '${(simulation.maxDrawdown * 100).toStringAsFixed(1)}%'),
                            _buildMetric('Total Trades', simulation.totalTrades.toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Equity Curve Chart
                Card(
                  color: const Color(0xFF2C2C2C),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Curva de Equity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: _buildEquityCurveChart(simulation.equityCurve),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Trades List
                Card(
                  color: const Color(0xFF2C2C2C),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Historial de Trades',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${simulation.winningTrades}/${simulation.totalTrades} ganadores',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (simulation.trades.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No se realizaron trades',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: simulation.trades.length,
                            itemBuilder: (context, index) {
                              final trade = simulation.trades[index];
                              return _buildTradeItem(trade, index + 1);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          simulationProvider.reset();
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.dashboard,
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF21CE99),
                          side: const BorderSide(color: Color(0xFF21CE99)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Nueva Simulación'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.dashboard,
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21CE99),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Ir al Dashboard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTradeItem(Trade trade, int tradeNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: trade.type == 'buy' ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: trade.type == 'buy' ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Trade #$tradeNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      trade.type.toUpperCase(),
                      style: TextStyle(
                        color: trade.type == 'buy' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${trade.price.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    if (trade.pnl != 0)
                      Text(
                        '\$${trade.pnl.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: trade.pnl > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquityCurveChart(List<double> equityCurve) {
    if (equityCurve.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[600]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'No hay datos de equity',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: EquityCurvePainter(equityCurve: equityCurve),
      size: const Size(double.infinity, 200),
    );
  }
}

class EquityCurvePainter extends CustomPainter {
  final List<double> equityCurve;
  
  EquityCurvePainter({required this.equityCurve});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (equityCurve.isEmpty) return;
    
    final paint = Paint()
      ..color = const Color(0xFF21CE99)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..color = const Color(0xFF21CE99).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    
    final double minValue = equityCurve.reduce((a, b) => a < b ? a : b);
    final double maxValue = equityCurve.reduce((a, b) => a > b ? a : b);
    final double range = maxValue - minValue;
    
    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < equityCurve.length; i++) {
      final x = (i / (equityCurve.length - 1)) * size.width;
      final y = size.height - ((equityCurve[i] - minValue) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 