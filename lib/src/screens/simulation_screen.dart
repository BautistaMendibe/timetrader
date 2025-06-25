import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simulation_provider.dart';
import '../models/candle.dart';
import '../routes.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  Timer? _timer;
  int _currentCandleIndex = 0;

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

        setState(() {
          if (_currentCandleIndex < simulationProvider.historicalData.length - 1) {
            _currentCandleIndex++;
          } else {
            // Simulation completed
            timer.cancel();
            _stopSimulation();
          }
        });
      },
    );
  }

  void _stopSimulation() {
    final simulationProvider = context.read<SimulationProvider>();
    simulationProvider.stopSimulation();
    Navigator.pushReplacementNamed(context, AppRoutes.simulationSummary);
  }

  void _executeTrade(String type) {
    final simulationProvider = context.read<SimulationProvider>();
    final currentCandle = simulationProvider.historicalData[_currentCandleIndex];
    final quantity = 1.0; // Fixed quantity for simplicity
    
    simulationProvider.executeTrade(type, currentCandle.close, quantity);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Orden de $type ejecutada a \$${currentCandle.close.toStringAsFixed(2)}'),
        backgroundColor: const Color(0xFF21CE99),
        duration: const Duration(seconds: 1),
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
              child: Text(
                'No hay datos disponibles',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final currentCandle = simulationProvider.historicalData[_currentCandleIndex];
        final progress = (_currentCandleIndex + 1) / simulationProvider.historicalData.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Simulación'),
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
              // Progress Bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF21CE99)),
              ),
              
              // Chart Area
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio Actual',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${currentCandle.close.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Candle Info
                      Row(
                        children: [
                          Expanded(
                            child: _buildCandleInfo('Apertura', currentCandle.open, Colors.blue),
                          ),
                          Expanded(
                            child: _buildCandleInfo('Máximo', currentCandle.high, Colors.green),
                          ),
                          Expanded(
                            child: _buildCandleInfo('Mínimo', currentCandle.low, Colors.red),
                          ),
                          Expanded(
                            child: _buildCandleInfo('Cierre', currentCandle.close, 
                              currentCandle.close >= currentCandle.open ? Colors.green : Colors.red),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Simple Chart Representation
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[600]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CustomPaint(
                            painter: CandleChartPainter(
                              candles: simulationProvider.historicalData.take(_currentCandleIndex + 1).toList(),
                            ),
                          ),
                        ),
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
                          child: ElevatedButton(
                            onPressed: () => _executeTrade('buy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'COMPRAR',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _executeTrade('sell'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'VENDER',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class CandleChartPainter extends CustomPainter {
  final List<Candle> candles;
  
  CandleChartPainter({required this.candles});
  
  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final fillPaint = Paint()
      ..style = PaintingStyle.fill;
    
    final double minPrice = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final double maxPrice = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final double priceRange = maxPrice - minPrice;
    
    final double candleWidth = size.width / candles.length;
    
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * candleWidth + candleWidth / 2;
      
      // Calculate y positions
      final openY = size.height - ((candle.open - minPrice) / priceRange) * size.height;
      final closeY = size.height - ((candle.close - minPrice) / priceRange) * size.height;
      final highY = size.height - ((candle.high - minPrice) / priceRange) * size.height;
      final lowY = size.height - ((candle.low - minPrice) / priceRange) * size.height;
      
      // Draw wick
      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        paint,
      );
      
      // Draw body
      final isGreen = candle.close >= candle.open;
      fillPaint.color = isGreen ? Colors.green : Colors.red;
      
      final bodyHeight = (closeY - openY).abs();
      final bodyY = isGreen ? closeY : openY;
      
      canvas.drawRect(
        Rect.fromLTWH(x - candleWidth * 0.3, bodyY, candleWidth * 0.6, bodyHeight),
        fillPaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 