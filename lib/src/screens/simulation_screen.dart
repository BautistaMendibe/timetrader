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

    // Calculate interval based on speed (candles per second)
    final intervalMs = (1000 / simulationProvider.simulationSpeed).round();
    
    _timer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        if (!simulationProvider.isSimulationRunning || 
            simulationProvider.simulationMode != SimulationMode.automatic) {
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

  void _showTradeModal(BuildContext context, String type) {
    final List<int> amounts = [100, 400, 1000, 1500, 3000];
    final List<int> leverages = [1, 5, 10, 20, 30, 50];
    int selectedAmount = amounts[0];
    int selectedLeverage = leverages[0];

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
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type == 'buy' ? 'Comprar' : 'Vender',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: 'Inter',
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tamaño de la operación',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: amounts.map((amount) {
                      final isSelected = selectedAmount == amount;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: () => setState(() => selectedAmount = amount),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF21CE99) : Colors.grey[400]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '\$${amount}',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: isSelected ? 18 : 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Apalancamiento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: leverages.map((lev) {
                      final isSelected = selectedLeverage == lev;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
                            onTap: () => setState(() => selectedLeverage = lev),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF1976D2) : Colors.grey[400]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${lev}x',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: isSelected ? 18 : 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == 'buy' ? const Color(0xFF21CE99) : const Color(0xFFFF5A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _executeManualTrade(type, selectedAmount, selectedLeverage);
                      },
                      child: Text(
                        'ABRIR OPERACIÓN → \$${selectedAmount}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _executeManualTrade(String type, int amount, int leverage) {
    final provider = context.read<SimulationProvider>();
    provider.executeManualTrade(type: type, amount: amount.toDouble(), leverage: leverage);
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
              // Simulation Mode Toggle
              PopupMenuButton<SimulationMode>(
                icon: Icon(
                  simulationProvider.simulationMode == SimulationMode.automatic 
                    ? Icons.speed 
                    : Icons.touch_app,
                ),
                onSelected: (mode) {
                  simulationProvider.setSimulationMode(mode);
                  if (mode == SimulationMode.automatic && simulationProvider.isSimulationRunning) {
                    _startSimulationTimer();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: SimulationMode.automatic,
                    child: Row(
                      children: [
                        Icon(
                          Icons.speed,
                          color: simulationProvider.simulationMode == SimulationMode.automatic 
                            ? const Color(0xFF21CE99) 
                            : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Automático',
                          style: TextStyle(
                            color: simulationProvider.simulationMode == SimulationMode.automatic 
                              ? const Color(0xFF21CE99) 
                              : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: SimulationMode.manual,
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: simulationProvider.simulationMode == SimulationMode.manual 
                            ? const Color(0xFF21CE99) 
                            : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Manual',
                          style: TextStyle(
                            color: simulationProvider.simulationMode == SimulationMode.manual 
                              ? const Color(0xFF21CE99) 
                              : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  simulationProvider.isSimulationRunning ? Icons.pause : Icons.play_arrow,
                ),
                onPressed: () {
                  if (simulationProvider.isSimulationRunning) {
                    simulationProvider.pauseSimulation();
                  } else {
                    simulationProvider.resumeSimulation();
                    if (simulationProvider.simulationMode == SimulationMode.automatic) {
                      _startSimulationTimer();
                    }
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
                child: Column(
                  children: [
                    // Mode Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: simulationProvider.simulationMode == SimulationMode.automatic 
                          ? const Color(0xFF21CE99) 
                          : const Color(0xFFFFA726),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            simulationProvider.simulationMode == SimulationMode.automatic 
                              ? Icons.speed 
                              : Icons.touch_app,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            simulationProvider.simulationMode == SimulationMode.automatic ? 'AUTOMÁTICO' : 'MANUAL',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Balance Row
                    Row(
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
              
              // Chart Area - 70% of available height
              Expanded(
                flex: 7, // 70% of the space
                child: Container(
                  margin: const EdgeInsets.all(16),
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
                      // Chart Header
                      Container(
                        padding: const EdgeInsets.all(16),
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
                            const SizedBox(height: 16),
                            
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
                          ],
                        ),
                      ),
                      
                      // Chart Divider
                      Container(
                        height: 1,
                        color: Colors.grey[800],
                      ),
                      
                      // Professional Chart
                      Expanded(
                        child: _buildChartWithTradeMarkers(simulationProvider.historicalData.take(simulationProvider.currentCandleIndex + 1).toList(), simulationProvider.currentTrades),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Botones de trading manual
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showTradeModal(context, 'buy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21CE99),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'COMPRAR',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showTradeModal(context, 'sell'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'VENDER',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Controls Area - 30% of available height
              Expanded(
                flex: 3, // 30% of the space
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Speed Control (only show in automatic mode)
                      if (simulationProvider.simulationMode == SimulationMode.automatic)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[700]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Velocidad de Simulación',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${simulationProvider.simulationSpeed.toStringAsFixed(1)}x',
                                    style: const TextStyle(
                                      color: Color(0xFF21CE99),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Slider(
                                value: simulationProvider.simulationSpeed,
                                min: 0.1,
                                max: 5.0,
                                divisions: 49,
                                activeColor: const Color(0xFF21CE99),
                                inactiveColor: Colors.grey[700],
                                onChanged: (value) {
                                  simulationProvider.setSimulationSpeed(value);
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '0.1x',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    '5.0x',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Manual Controls (only show in manual mode)
                      if (simulationProvider.simulationMode == SimulationMode.manual)
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
                                  fontSize: 14,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: simulationProvider.currentCandleIndex > 0
                                          ? () => simulationProvider.goToCandle(simulationProvider.currentCandleIndex - 1)
                                          : null,
                                      icon: const Icon(Icons.skip_previous),
                                      label: const Text('Anterior'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[700],
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
                                      onPressed: simulationProvider.currentCandleIndex < simulationProvider.historicalData.length - 1
                                          ? () => simulationProvider.advanceCandle()
                                          : null,
                                      icon: const Icon(Icons.skip_next),
                                      label: const Text('Siguiente'),
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
                                ],
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
                      
                      // Strategy and Status
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
                      
                      // Trades Count
                      Text(
                        'Trades: ${simulationProvider.currentTrades.length}',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
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