import 'package:flutter/material.dart';
import '../models/candle.dart';
import '../widgets/trading_view_chart.dart';

class TestChartScreen extends StatefulWidget {
  const TestChartScreen({super.key});

  @override
  State<TestChartScreen> createState() => _TestChartScreenState();
}

class _TestChartScreenState extends State<TestChartScreen> {
  List<Candle> testCandles = [];

  @override
  void initState() {
    super.initState();
    _generateTestData();
  }

  void _generateTestData() {
    testCandles = [];
    final DateTime baseDate = DateTime.now().subtract(const Duration(days: 7));
    double price = 50000.0;

    for (int i = 0; i < 50; i++) {
      final timestamp = baseDate.add(Duration(hours: i));
      final change = price * 0.02 * (0.5 - (i % 3) * 0.3);
      final open = price;
      final close = price + change;
      final high = open + (change * 1.5).abs();
      final low = open - (change * 1.5).abs();

      testCandles.add(
        Candle(
          timestamp: timestamp,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: 1000.0 + (i * 10),
        ),
      );

      price = close;
    }

    debugPrint(
      'TestChartScreen: Generados ${testCandles.length} velas de prueba',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Chart'),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Velas de prueba: ${testCandles.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: TradingViewChart(
                candles: testCandles,
                trades: const [],
                slPercent: null,
                slValue: null,
                tpPercent: null,
                tpValue: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
